# E60 cluster

Custom software for a BMW E60 with a JLY aftermarket digital instrument cluster and an Android head unit:

- a Range Rover–style dash for the cluster;
- Android Auto directions, the live map, music and calls on the cluster;
- over-the-air updates from this repo's releases.

## Parts

| Folder | What it is |
|---|---|
| `custom_dash/device/etc/` | The cluster dash (Qt Quick 5.14) and its loader `d.qml`, plus the over-the-air updater script `init.d/S61dashupdate` |
| `custom_dash/tools/` | Builds the JLY USB update package, and the generators for the dash's message and icon tables |
| `custom_dash/preview/` | Runs the dash on a desktop with a simulated car (PyQt5) |
| `cluster_video/` | Qt Quick plugin that decodes the Android Auto cluster map stream on the cluster |
| `wifi_driver/.../S60wifi` | Joins the cluster to the head unit's hotspot |
| `updater/` | Release tool and the update protocol (`PROTOCOL.md`) |
| `phone_updater/` | Phone app: downloads releases over mobile data and pushes them to the car |

The head unit app is a fork of [Open Headunit](https://github.com/andreknieriem/open-headunit) (AGPL-3.0), kept on the `main` branch of [tristanmcgregor/open-headunit](https://github.com/tristanmcgregor/open-headunit) (merged with upstream 3.5.0-beta3; the old `e60` branch is retired). Both repos use `main` only.

## Releasing

```
python3 updater/release.py --publish            # dash + head unit app
python3 updater/release.py --dash --publish     # dash only
```

The phone updater picks a new release up the next time the phone joins the car's Wi-Fi. The head unit installs the app update once confirmed on its home screen. The cluster switches to the new dash at its next start-up.

Releases are signed with `updater/signing_key.pem`, which stays on the release machine and out of git (keep a backup). The head unit app only accepts uploads that verify against the public key `updater/signing_pub.pem`, so neither app contains a secret. `updater/updater.properties` (not in git) holds local settings such as the JLY USB package password.
