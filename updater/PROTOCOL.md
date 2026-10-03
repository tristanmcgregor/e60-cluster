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
  `dash` and `apk` are each optional: a release may carry only one of them.
  `sig` is the release signature; see "Signing" below.
- The files named in the manifest.

The phone lists recent releases (`GET /repos/{owner}/{repo}/releases?per_page=20`). It takes:

- the highest release whose manifest has a `dash` newer than the head unit's `dashRelease`;
- the highest release whose manifest has an `apk` newer than the head unit's `apkRelease`.

For a private repo, every GitHub request carries `Authorization: Bearer <token>`. Assets are downloaded through the asset API URL (`assets[].url`) with `Accept: application/octet-stream`.

## Head unit HTTP (port 8765, plain HTTP on the car Wi-Fi)

The head unit is the default gateway of the car Wi-Fi network (the hotspot).

**`GET /update/status`** returns `200 application/json`:
```json
{"service": "e60-update", "apkRelease": N, "apkVersionCode": 200000, "pendingApkRelease": 0,
 "dashRelease": N, "clusterDashRelease": M}
```
A value of 0 means none/unknown. `service` identifies this endpoint, so the phone knows it has found the car.

**`POST /update/dash?release=N&sha256=<hex>`** and **`POST /update/apk?release=N&sha256=<hex>`**

- Headers: `X-Update-Signature: <sig from the manifest>` and `Content-Length: <bytes>`. The body is the raw file.
- Replies: `200 ok`, `401` for a bad signature, `400` for a bad request or checksum mismatch, `409` if the release is not newer.
- An APK upload is staged. The head unit asks for install confirmation when it is not projecting.

**`GET /dash/manifest.txt?have=M`**

- Called by the cluster. `M` is the release the cluster has active; the head unit records it as `clusterDashRelease`.
- Returns `200 text/plain` with `release=N`, `sha256=<hex>` and `size=<bytes>`, one per line. Returns `404` when the head unit holds no dash bundle.

**`GET /dash/bundle.tar.gz`** returns the bundle bytes.

## Dash bundle

`dash-N.tar.gz` is a gzip tar. Its top level contains the dash files directly (`Dashboard.qml`, `qmldir`, `icons/`, `fonts/`, …) plus a `RELEASE` file containing `N`.

## Cluster layout

- `/etc/dashv/<N>/`: installed releases. The current one and the previous one are kept.
- `/etc/dash_active`: the release number to load. `/etc/dash_prev` holds the previous one.
- `/etc/dash/`: the base version installed by USB; the last fallback.
- `/etc/d.qml` loads `dashv/<active>/Dashboard.qml`. If that fails it tries the previous release, then `/etc/dash`, then the stock UI.

## Signing

Neither app contains a secret.

- `release.py` signs `"<kind>\n<release>\n<sha256>\n"` (kind is `dash` or `apk`) with ECDSA P-256 / SHA-256, using `updater/signing_key.pem`. That file never leaves the release Mac and is not in git.
- The head unit has the public half (`updater/signing_pub.pem`) built in.
- The head unit checks the signature before it reads the body, then checks the body against that sha256.
- An upload must also be a newer release than the head unit already has, so an old signed release cannot be replayed.

**Keep a backup of `signing_key.pem`.** Without it, new releases are refused by the installed app until a new app is installed from USB.
