# E60 cluster over-the-air update protocol

Three parts:

- **GitHub releases**: the source of updates.
- **Phone updater app** (`phone_updater/`): downloads releases over mobile data and pushes them to the head unit over the car Wi-Fi.
- **Head unit app** (Open Headunit fork): installs its own APK and serves dash bundles to the cluster.
- **Cluster** (`S61dashupdate`): pulls dash bundles from the head unit.

Release numbers are plain increasing integers (`N`); the GitHub tag is `vN`.

## GitHub release `vN`

Assets:

- `manifest.json`:
  ```json
  {"release": N,
   "dash": {"name": "dash-N.tar.gz", "sha256": "<hex>", "size": 123, "sig": "<base64>"},
   "apk":  {"name": "OpenHeadunit-e60-N.apk", "sha256": "<hex>", "size": 123, "versionCode": 200000,
            "sig": "<base64>"}}
  ```
  `dash`, `apk`, `speedlimits` and `usb` are each optional. `usb` (`dashboard-N.zip`) is the JLY USB update package for the cluster; `release.py` includes it only when the parts a USB install alone delivers (Launcher, `d.qml`, init scripts, Wi-Fi) changed since the last published one (`updater/usb_base`), or with `--usb`. `speedlimits` (`speedlimits-N.bin.gz`) is gzip-compressed road speed-limit data built by `updater/speedlimits.py` (format in its docstring). Since release 6 it also carries school-zone times, cameras, Queensland public holidays and school terms, in an extension older head unit builds skip.
  `sig` is the release signature; see "Signing" below.
- The files named in the manifest.

The phone lists recent releases (`GET /repos/{owner}/{repo}/releases?per_page=20`). It takes:

- the highest release whose manifest has a `dash` newer than the head unit's `dashRelease`;
- the highest release whose manifest has an `apk` newer than the head unit's `apkRelease`;
- likewise for `speedlimits` against `speedLimitsRelease`.

- likewise for `usb` against `usbRelease`, only when the head unit's status has a `usbRelease` field (apps before release 11 have no `/update/usb`).

The phone uploads in the order dash, speedlimits, usb, apk. The APK goes last because installing it restarts the head unit app.

For a private repo, every GitHub request carries `Authorization: Bearer <token>`. Assets are downloaded through the asset API URL (`assets[].url`) with `Accept: application/octet-stream`.

## Head unit HTTP (port 8765, plain HTTP on the car Wi-Fi)

The head unit is the default gateway of the car Wi-Fi network (the hotspot).

**`GET /update/status`** returns `200 application/json`:
```json
{"service": "e60-update", "apkRelease": N, "apkVersionCode": 200000, "pendingApkRelease": 0,
 "dashRelease": N, "clusterDashRelease": M, "speedLimitsRelease": N,
 "usbRelease": N, "clusterUsbRelease": U}
```
A value of 0 means none/unknown. `service` identifies this endpoint, so the phone knows it has found the car.

**`POST /update/{dash|apk|speedlimits|usb}?release=N&sha256=<hex>`**

- Headers: `X-Update-Signature: <sig from the manifest>` and `Content-Length: <bytes>`. The body is the raw file.
- Replies: `200 ok`, `401` for a bad signature, `400` for a bad request or checksum mismatch, `409` if the release is not newer.
- An APK upload is staged. The head unit asks for install confirmation when it is not projecting.
- A speedlimits upload is unpacked and loaded straight away.

**`GET /dash/manifest.txt?have=M&usb=U`**

- Called by the cluster. `M` is the release the cluster has active; the head unit records it as `clusterDashRelease`. `U` is the release of the cluster's last USB install (`/etc/dash/RELEASE`), recorded as `clusterUsbRelease`; a cluster script older than release 11 sends no `usb` and counts as 0.
- Returns `200 text/plain` with `release=N`, `sha256=<hex>` and `size=<bytes>`, one per line. Returns `404` when the head unit holds no dash bundle.

**`GET /dash/bundle.tar.gz`** returns the bundle bytes.

## Cluster USB package on a stick

While `clusterUsbRelease` is below `usbRelease`, the head unit app (`UsbStick.kt`) writes the package as `dashboard.zip` to the root of any USB stick mounted on it (checked on mount, when a package arrives and when the cluster reports), verifies it by sha256 and shows a notification "Cluster update ready on USB". Write order: the plain path, then root (`/mnt/media_rw/<uuid>`), then Android folder access; for the last, a notification asks to allow the stick once (remembered per stick). The user moves the stick to the cluster, which installs it through JLY's USB updater and then reports the new `usb` release.

## Dash bundle

`dash-N.tar.gz` is a gzip tar. Its top level contains the dash files directly (`Dashboard.qml`, `qmldir`, `icons/`, `fonts/`, …) plus a `RELEASE` file containing `N`.

## Cluster layout

- `/etc/dashv/<N>/`: installed releases. The current one and the previous one are kept.
- `/etc/dash_active`: the release number to load. `/etc/dash_prev` holds the previous one.
- `/etc/dash/`: the base version installed by USB; the last fallback.
- `/etc/d.qml` loads `dashv/<active>/Dashboard.qml`. If that fails it tries the previous release, then `/etc/dash`, then the stock UI.

## Signing

Neither app contains a secret.

- `release.py` signs `"<kind>\n<release>\n<sha256>\n"` (kind is `dash`, `apk`, `speedlimits` or `usb`) with ECDSA P-256 / SHA-256, using `updater/signing_key.pem`. That file never leaves the release Mac and is not in git.
- The head unit has the public half (`updater/signing_pub.pem`) built in.
- The head unit checks the signature before it reads the body, then checks the body against that sha256.
- An upload must also be a newer release than the head unit already has, so an old signed release cannot be replayed.

**Keep a backup of `signing_key.pem`.** Without it, new releases are refused by the installed app until a new app is installed from USB.

## Cluster messages (ClusterLink WebSocket, port 8765)

Besides `nav` and `call`, these messages go to the cluster:

- `{"type":"settings", ...}`: display settings from the phone page at `http://<head unit>:8765/settings` (`GET`/`POST /settings.json`).
- `{"type":"limit","kph":N,"school":bool}`: the speed limit of the current road, from GPS matched to the speed-limit data. `0` means unknown. `school` is true while a school-zone limit is in force (weekday school hours, in term, not a public holiday); `kph` is then that limit.
- `{"type":"camera","kind":"speed"|"redlight"|"average","kph":N,"distM":M}`: a camera ahead (an average-speed zone at its start), sent every GPS fix while approaching; `{"type":"camera","distM":-1}` once passed. Not replayed.
- `{"type":"gps","kph":X,"acc":M}`: the head unit's GPS speed (one decimal) and position accuracy in metres, every fix. Not replayed. Used by the developer page's speed check.
- `{"type":"media","title":...,"artist":...,"album":...,"playing":bool,"duration":S,"position":S}`: now playing. `duration` and `position` are in seconds; `0` means unknown.
- `{"type":"mediaart","art":"data:image/jpeg;base64,..."}`: the cover of the current track (128×128 JPEG), sent once per track. An empty `art` clears it.

The latest message of each type is replayed when the cluster connects.

## Applying a dash release (release 10 on)

The dash bundle also carries `ClusterVideo/` (the live-map plugin and a `qmldir` with no
`module` line, so it loads from whichever `/etc/dashv/N` it is unpacked to). ClusterMap.qml
imports it through `VideoLocal.qml`, falling back to `/etc/qml/ClusterVideo` (`VideoSystem.qml`).

S61dashupdate checks every 20 s. After an install it writes `/tmp/dash_restart_expected`.
d.qml sees `/etc/dash_active` change, waits until `car.speed` has been 0 for 5 s and quits;
the Launcher is respawned by JLY's process.sh, or else by S61dashupdate's guard (same command
line, environment and directory as the Launcher it last saw), within about 8 s. The guard does
nothing without a recent install, or when process.sh has stopped too (a JLY USB update).
d.qml, S61dashupdate and the first plugin-in-bundle support arrive by USB install only.
