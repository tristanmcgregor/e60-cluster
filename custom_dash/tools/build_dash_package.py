#!/usr/bin/env python3
"""
Build USB update packages for the custom dashboard.

    python3 build_dash_package.py install  <patched_Launcher> <etc_model> out/install/dashboard.zip
    python3 build_dash_package.py restore  <Launcher_original> <etc_model> out/restore/dashboard.zip

install: patched Launcher + /etc/model + /etc/d.qml + /etc/dash/* (+ /etc/qml/ClusterVideo if built)
restore: original Launcher + /etc/model (stock UI comes back; d.qml is left
         on disk but nothing loads it)

Both go through the unit's own etc/mdev/update.sh (update_bin + update_etc).
No fex/, kernel modules or bootloader writes are included.
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def zip_password():
    """JLY's USB-update zip password: jly.zip.password in updater/updater.properties (not in git)."""
    path = os.path.join(HERE, "..", "..", "updater", "updater.properties")
    if os.path.isfile(path):
        for line in open(path):
            if line.startswith("jly.zip.password="):
                return line.split("=", 1)[1].strip()
    sys.exit("set jly.zip.password in updater/updater.properties")


DEVICE_ETC = os.path.join(HERE, "..", "device", "etc")


def main():
    if len(sys.argv) != 5 or sys.argv[1] not in ("install", "restore"):
        sys.exit(__doc__)
    mode, launcher, model, out_zip = sys.argv[1:]
    if not shutil.which("zip"):
        sys.exit("'zip' not found on PATH")

    with tempfile.TemporaryDirectory() as td:
        root = os.path.join(td, "dashboard")
        os.makedirs(os.path.join(root, "usr", "bin"))
        etc = os.path.join(root, "etc")
        os.makedirs(etc)

        dst = os.path.join(root, "usr", "bin", "Launcher")
        shutil.copy2(launcher, dst)
        os.chmod(dst, 0o755)
        shutil.copy2(model, os.path.join(etc, "model"))

        if mode == "install":
            shutil.copy2(os.path.join(DEVICE_ETC, "d.qml"), os.path.join(etc, "d.qml"))
            shutil.copytree(os.path.join(DEVICE_ETC, "dash"), os.path.join(etc, "dash"),
                            ignore=shutil.ignore_patterns(".DS_Store"))
            # Release number of this USB-installed dash; d.qml prefers an over-the-air
            # release only when it is newer (DASH_RELEASE is set by updater/release.py).
            with open(os.path.join(etc, "dash", "RELEASE"), "w") as f:
                f.write(os.environ.get("DASH_RELEASE", "0") + "\n")
            # Over-the-air dash updater (updater/PROTOCOL.md)
            os.makedirs(os.path.join(etc, "init.d"), exist_ok=True)
            dst = os.path.join(etc, "init.d", "S61dashupdate")
            shutil.copy2(os.path.join(DEVICE_ETC, "init.d", "S61dashupdate"), dst)
            os.chmod(dst, 0o755)
            # Native live-map plugin (cluster_video/build/build_plugin.sh), if it has been built.
            # /etc/qml is on QML2_IMPORT_PATH; without it the dash falls back to the NavCard.
            plugin = os.path.join(HERE, "..", "..", "cluster_video", "out", "qml", "ClusterVideo")
            if os.path.isdir(plugin):
                shutil.copytree(plugin, os.path.join(etc, "qml", "ClusterVideo"))
            else:
                print("note: cluster_video plugin not built; package has no live map")
            # Keep the Wi-Fi startup script in step (it publishes the head unit's address
            # to /tmp/nav_gateway for Nav.qml / ClusterMap.qml).
            wifi_etc = os.path.join(HERE, "..", "..", "wifi_driver", "pkg", "install", "dashboard", "etc")
            if os.path.isdir(wifi_etc):
                os.makedirs(os.path.join(etc, "init.d"), exist_ok=True)
                shutil.copy2(os.path.join(wifi_etc, "init.d", "S60wifi"), os.path.join(etc, "init.d", "S60wifi"))
                shutil.copytree(os.path.join(wifi_etc, "wifi"), os.path.join(etc, "wifi"))

        out_zip = os.path.abspath(out_zip)
        os.makedirs(os.path.dirname(out_zip), exist_ok=True)
        if os.path.exists(out_zip):
            os.remove(out_zip)
        subprocess.run(["zip", "-q", "-r", "-P", zip_password(), out_zip, "dashboard"], cwd=td, check=True)
        listing = subprocess.run(["unzip", "-l", out_zip], capture_output=True, text=True).stdout

    print(listing)
    print(f"wrote {out_zip} ({mode})")


if __name__ == "__main__":
    main()
