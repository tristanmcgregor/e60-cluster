#!/usr/bin/env python3
"""Build an over-the-air release and (optionally) publish it to GitHub.

    python3 updater/release.py [--dash] [--apk] [--speedlimits] [--publish] [--notes "..."]

With none of --dash, --apk or --speedlimits, the dash and the APK are built. Speed-limit
data (OpenStreetMap, south-east Queensland) changes rarely, so it is only built on request. The release number is one more than the
highest seen so far (updater/last_release, and the repo's vN tags when --publish can
ask GitHub). Output: updater/out/release-N/ with manifest.json and the files it names,
in the format of updater/PROTOCOL.md. --publish uploads them as GitHub release vN
using the gh CLI and github.repo from updater/updater.properties.

Also rebuilds the USB package (custom_dash/out/install/dashboard.zip) stamped with the
same release, so a USB install and the over-the-air copy agree on what is newest.
"""
import argparse
import base64
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
JLY = os.path.dirname(HERE)
DASH_SRC = os.path.join(JLY, "custom_dash", "device", "etc", "dash")
HEADUNIT = os.path.join(JLY, "headunit", "open-headunit")
COUNTER = os.path.join(HERE, "last_release")
GH = shutil.which("gh") or os.path.expanduser("~/tools/gh/bin/gh")


def props():
    out = {}
    path = os.path.join(HERE, "updater.properties")
    if os.path.isfile(path):
        for line in open(path):
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip()
    return out


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sign(kind, n, digest):
    """Signs "<kind>\\n<release>\\n<sha256>\\n" with the release key (ECDSA P-256, SHA-256).

    The head unit checks this against the public key built into it (signing_pub.pem), so an
    upload is accepted only if it came from this tool. signing_key.pem never leaves this Mac.
    """
    key = os.path.join(HERE, "signing_key.pem")
    if not os.path.isfile(key):
        sys.exit("updater/signing_key.pem is missing; releases cannot be signed")
    sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key],
                         input=f"{kind}\n{n}\n{digest}\n".encode(), capture_output=True, check=True).stdout
    return base64.b64encode(sig).decode()


def github_highest(repo):
    try:
        tags = subprocess.run([GH, "release", "list", "--repo", repo, "--limit", "100",
                               "--json", "tagName", "--jq", ".[].tagName"],
                              capture_output=True, text=True, check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError) as e:
        sys.exit(f"could not list releases on {repo}: {e}")
    return max([int(t[1:]) for t in tags if t[:1] == "v" and t[1:].isdigit()] or [0])


def build_dash(n, outdir):
    """dash-N.tar.gz: the dash files at the top level plus RELEASE."""
    path = os.path.join(outdir, f"dash-{n}.tar.gz")

    def clean(info):
        # no macOS metadata, root-owned like the files the USB installer writes
        if os.path.basename(info.name) in (".DS_Store",) or "/._" in "/" + info.name:
            return None
        info.uid = info.gid = 0
        info.uname = info.gname = "root"
        return info

    with tarfile.open(path, "w:gz", format=tarfile.USTAR_FORMAT) as tar:
        for name in sorted(os.listdir(DASH_SRC)):
            if name != "RELEASE":
                tar.add(os.path.join(DASH_SRC, name), arcname=name, filter=clean)
        rel = os.path.join(outdir, "RELEASE")
        with open(rel, "w") as f:
            f.write(f"{n}\n")
        tar.add(rel, arcname="RELEASE", filter=clean)
        os.remove(rel)
    return path


def build_env():
    env = dict(os.environ)
    jdk = os.path.expanduser("~/tools/jdk")
    homes = [os.path.join(jdk, d, "Contents", "Home") for d in sorted(os.listdir(jdk))] if os.path.isdir(jdk) else []
    if homes and not os.path.isdir(env.get("JAVA_HOME", "")):
        env["JAVA_HOME"] = homes[0]
    env.setdefault("ANDROID_HOME", os.path.expanduser("~/Library/Android/sdk"))
    return env


def build_apk(n, outdir):
    env = build_env()
    subprocess.run(["./gradlew", "--no-daemon", "-q", f"-Pe60Release={n}", "assembleGithubDebug"],
                   cwd=HEADUNIT, env=env, check=True)
    built = os.path.join(HEADUNIT, "app", "build", "outputs", "apk", "github", "debug")
    apks = [f for f in os.listdir(built) if f.endswith(".apk")]
    if len(apks) != 1:
        sys.exit(f"expected one APK in {built}, found {apks}")
    path = os.path.join(outdir, f"OpenHeadunit-e60-{n}.apk")
    shutil.copy2(os.path.join(built, apks[0]), path)
    return path


def build_phone(n, outdir, env):
    """E60CarUpdater.apk numbered with this release. Attached to the release for installing on
    the phone; not in the manifest, since the car never receives it."""
    phone = os.path.join(JLY, "phone_updater")
    subprocess.run(["./gradlew", "--no-daemon", "-q", f"-Pe60Release={n}", "assembleDebug"],
                   cwd=phone, env=env, check=True)
    built = os.path.join(phone, "app", "build", "outputs", "apk", "debug")
    apks = [f for f in os.listdir(built) if f.endswith(".apk")]
    if len(apks) != 1:
        sys.exit(f"expected one APK in {built}, found {apks}")
    path = os.path.join(outdir, "E60CarUpdater.apk")
    shutil.copy2(os.path.join(built, apks[0]), path)
    return path


def build_speedlimits(n, outdir, cache=None):
    """speedlimits-N.bin.gz: updater/speedlimits.py output, gzipped (the head unit unpacks it).

    Downloads fresh OpenStreetMap tiles unless [cache] names a folder of tiles to reuse
    (the public Overpass server is often slow or busy)."""
    raw = os.path.join(outdir, "speedlimits.bin")
    subprocess.run([sys.executable, os.path.join(HERE, "speedlimits.py"), raw,
                    "--cache", cache or os.path.join(outdir, "osm_cache")], check=True)
    path = os.path.join(outdir, f"speedlimits-{n}.bin.gz")
    with open(raw, "rb") as src, gzip.open(path, "wb", compresslevel=9) as dst:
        shutil.copyfileobj(src, dst)
    os.remove(raw)
    return path


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dash", action="store_true", help="include a dash bundle")
    ap.add_argument("--apk", action="store_true", help="include the head unit APK")
    ap.add_argument("--speedlimits", action="store_true", help="include fresh speed-limit data")
    ap.add_argument("--osm-cache", help="reuse OpenStreetMap tiles from this folder instead of downloading")
    ap.add_argument("--publish", action="store_true", help="upload as a GitHub release")
    ap.add_argument("--notes", default="", help="release notes")
    args = ap.parse_args()
    if not args.dash and not args.apk and not args.speedlimits:
        args.dash = args.apk = True

    p = props()
    repo = p.get("github.repo", "")
    if args.publish and not repo:
        sys.exit("set github.repo in updater/updater.properties first")
    last = int(open(COUNTER).read().strip() or 0) if os.path.isfile(COUNTER) else 0
    if args.publish:
        last = max(last, github_highest(repo))
    n = last + 1

    outdir = os.path.join(HERE, "out", f"release-{n}")
    shutil.rmtree(outdir, ignore_errors=True)
    os.makedirs(outdir)
    manifest = {"release": n}
    files = []
    if args.dash:
        f = build_dash(n, outdir)
        digest = sha256(f)
        manifest["dash"] = {"name": os.path.basename(f), "sha256": digest, "size": os.path.getsize(f),
                            "sig": sign("dash", n, digest)}
        files.append(f)
        # USB package stamped with the same release
        subprocess.run([sys.executable, os.path.join(JLY, "custom_dash", "tools", "build_dash_package.py"),
                        "install", "out/Launcher_r19917_customdash", "device_etc_model",
                        "out/install/dashboard.zip"],
                       cwd=os.path.join(JLY, "custom_dash"), env=dict(os.environ, DASH_RELEASE=str(n)),
                       check=True, stdout=subprocess.DEVNULL)
    if args.apk:
        f = build_apk(n, outdir)
        digest = sha256(f)
        manifest["apk"] = {"name": os.path.basename(f), "sha256": digest, "size": os.path.getsize(f),
                           "versionCode": 200000 + n, "sig": sign("apk", n, digest)}
        files.append(f)
    if args.speedlimits:
        f = build_speedlimits(n, outdir, args.osm_cache)
        digest = sha256(f)
        manifest["speedlimits"] = {"name": os.path.basename(f), "sha256": digest, "size": os.path.getsize(f),
                                   "sig": sign("speedlimits", n, digest)}
        files.append(f)
    mpath = os.path.join(outdir, "manifest.json")
    with open(mpath, "w") as fh:
        json.dump(manifest, fh, indent=1)
    files.insert(0, mpath)
    files.append(build_phone(n, outdir, build_env()))

    if args.publish:
        title = f"E60 v{n}"
        notes = args.notes or ", ".join(k for k in ("dash", "apk", "speedlimits") if k in manifest)
        subprocess.run([GH, "release", "create", f"v{n}", "--repo", repo, "--title", title,
                        "--notes", notes] + files, check=True)
        with open(COUNTER, "w") as fh:     # only published numbers count
            fh.write(f"{n}\n")
    print(json.dumps(manifest, indent=1))
    print(f"release {n} in {outdir}" + (" (published)" if args.publish else " (not published)"))


if __name__ == "__main__":
    main()
