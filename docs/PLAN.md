# E60 project: status and next steps

Last updated 2026-10-04. Covers the cluster dash, the head unit app (Open Headunit fork), the phone updater and the planned custom home screen.

## Where things stand

**Released:** v6 at https://github.com/tristanmcgregor/e60-cluster/releases.

| Part | State |
|---|---|
| Cluster dash | Range Rover style UI. Android Auto map, directions, media and calls. Indicator fix. Sport layout and shift lights (S/M). Oil-temperature redline map (4500→7250 rpm, linear). 0–60 / 0–100 timer. Own warnings. Speed-limit sign. Developer page (hold BC on INFO). Release number on INFO. |
| Head unit app | Fork `tristanmcgregor/open-headunit`, branch `e60`. Cluster link (WebSocket :8765) and cluster map video. Signed OTA updates. Settings page (phone and head unit screen). SEQ speed limits from GPS + OSM. |
| Phone updater | `phone_updater/`. Pulls GitHub releases over mobile data and pushes them to the head unit. Works alongside Android Auto (own Wi-Fi request). In-app car settings. |
| Releases | `python3 updater/release.py [--dash] [--apk] [--speedlimits [--osm-cache updater/out/osm_cache]] --publish`. Signed with `updater/signing_key.pem`: never commit it, and keep a backup. |

### Confirmed in the car

- Phone updater pushed release 3 to the head unit, once the VPN excluded `au.jly.e60updater`.
- Indicators, cluster Wi-Fi link and the Android Auto cluster map work.

### Still to confirm on a drive

- **HUD:**
  - Does it work again? This tests the menuId interface-packet fix.
  - Its speed reading compared with GPS.
- **Gear strings:** what the developer page shows for the gear in D, S and M. `Car.gearboxSport` currently assumes `S3` / `M4` style strings.
- **Values:** `oilTempInt` populated, and the battery voltage scale (assumed tenths).
- **Sport layout and redline:** sport layout in S/M; redline rising with oil temperature.
- **Speed-limit sign:** shows on real roads.
- **Phone settings page:** changes apply live and persist.
- **Cluster OTA:** is the cluster pulling updates? The updater showed "cluster v0", so the USB `dashboard.zip` with `S61dashupdate` may not be installed yet.
- **Hotspot auto-start:** turns on at start-up with Auto-start on boot + Auto-enable hotspot.

## In release 5

- **Full-screen map mode:**
  - The AA map fills the whole cluster behind the dials (dial faces 95 % opaque); the centre menu gives way to open map. Top/bottom fades keep the status and bottom rows legible.
  - Hold BC to switch (any page but INFO). Phone setting "Full-screen map when a route starts".
  - The head unit now asks for a **1280×720 cluster stream with 240 px bottom margin** (1280×480 map, the cluster's shape) and tells the cluster the map size.
  - **To test in the car:** decode smoothness on the cluster CPU (software decode + RGB conversion). If it stutters, turn off "Wide map stream" in settings.
- **FUEL page:** level, range, now; 30-min consumption graph; this tank (km, average, litres, cost); refuel log (≥10 % jump starts a new tank). Settings: tank 70 L, price, reserve.
- **Fuel to destination:**
  - range compared with AA remaining route;
  - bottom range turns amber (arrive inside the reserve) or red (short);
  - one warning per route.
- **Album art card:** cover, title and artist. The head unit sends the cover once per track as a `mediaart` message (128×128 JPEG). Without art it falls back to the one-line pill.
- **Song progress line:** across the bottom of the media card. `media` messages now carry `duration` and `position` (seconds); the cluster advances the position itself between updates.
- **"Classic BMW" theme:** always-on amber text and dials, chosen in the phone settings (Theme: Standard / Classic BMW). No automatic night switching (Tristan's choice).
- **"Update ready" notice:** when `S61dashupdate` installs a newer release mid-drive, a popup says "Release N ready — loads at next start" and the INFO page adds "N loads next start". It only triggers on a change to `/etc/dash_active` seen while running, so a release that d.qml fell back from is not announced. (`UpdateWatch.qml`; preview scenes `update`, `update_info`.)

### Factory HUD turn arrows: research result

Not available through current interfaces:
- EventHub has no navigation/HUD setters, only turn-signal reads.
- The JLY MCU firmware has no navigation messages.
- "Bmw hud turn show/hide" refers to the indicator arrows.

Doing it would need sniffing the E60 CCC→HUD navigation CAN messages from a working car, plus MCU firmware changes. Parked.

## In release 6

- **School zones:** OpenStreetMap `maxspeed:conditional` on ~9,000 road segments in SEQ (nearly all `40 @ Mo-Fr 07:00-09:00,14:00-16:00; PH off; SH off`). The head unit applies them on weekdays in those hours, skipping Queensland public holidays (computed) and days outside state school terms (education.qld.gov.au, 2026–2029; after 2029 every weekday counts until the list is extended in `speedlimits.py`). The sign gets a yellow SCHOOL plate and a popup on entry. Phone setting "School zones".
- **Camera alerts:** 72 cameras mapped in OSM for SEQ (49 speed, 19 red-light, 4 average-speed starts). Within 350–800 m ahead (25 s at current speed) and within 30° of the heading: popup once, then a countdown in the speedo where the cruise readout sits. Mobile cameras are not in OSM. Phone setting "Camera alerts".
- **GPS speed check:** DEVELOPER page shows GPS / MCU / dash speed and the measured correction (steady driving above 40 km/h, ≥30 s). This is the number for the HUD firmware fix.
- **Where I parked (phone app):** when the phone's Bluetooth link to the car drops, the phone saves its own location and shows a "Car parked" notification that opens the map; also in the app. Set up in the app: choose the car's Bluetooth, allow Nearby devices and Location "Allow all the time". (The head unit can't be asked: Android Auto owns the car Wi-Fi during a drive.)
- **To ship:** needs a speed-limit data release as well: `release.py --speedlimits --osm-cache updater/out/osm_cache --publish`. Old head unit builds ignore the new data; the new build reads old data without school zones/cameras. The phone APK is attached to the release for manual install.

## Built after release 6 (not yet released)

- **Automatic speed correction:** the cluster learns the correction from GPS (GpsCheck: steady driving above 40 km/h, GPS/MCU within 25 %), kept across drives in LocalStorage, halved past an hour of samples so tyre changes work in. Used once 2 minutes are measured; the manual % applies until then or with "Learn correction from GPS" off. "Start learning again" in the phone settings clears it. The developer page shows the measured value and which one is in use. The HUD still shows the uncorrected MCU speed.
- **Speed correction now −6 %:** the speedo read high with +6 %, so the default manual correction is −6 % (dash and head unit). A stored +6 from older settings (no `version`) is read as −6; anything else set on the phone is kept. A GPS-learned value still takes over once measured, with learning on.
- **Live map position fix:** Android Auto centres the map between equal margins, so the wide 1280×720 stream has its 1280×480 map at y 120, not at the top. The cluster cropped from the top: a black strip over the map and the car arrow cut off. ClusterMap now crops the centred area; the head unit's `clustermap` message also carries `videoWidth`/`videoHeight` (older builds: the dash infers 1280×720 / 800×480). Dash-only fix; the native plugin is unchanged.
- **Check-control messages once per drive:** a message the MCU keeps repeating is shown once (at most 10 s) and not again until the ignition next comes on; service reminders the same. The warning light stays in the status row. Preview scene `msg_repeat`.
- **Hold BC fixed:** the dash assumed the MCU reports a hold as code + 128, never confirmed on the car. It now times the press itself (held 0.8 s, acted on while still held, the release swallowed) and still accepts a + 128 code. A hold on INFO was also handled twice (DEVELOPER opened, then the full map switched on and hid it); one handler now does DEVELOPER on INFO, the full map elsewhere. The MCU's menuId now follows the page shown (it lagged one page behind). INFO's "LAST BUTTON CODE" shows 154 after a hold. Preview scenes `fullmap_hold`, `page_dev_hold`.
- **Live map no longer drops in and out:** Android Auto only sends a cluster frame when the picture changes, and the plugin's `streaming` went false after 2 s without one, so a still map (stopped at lights) vanished and full-screen map mode collapsed until the next frame. ClusterMap now keeps the last picture while connected and only gives up after 15 s without a frame (QML only; the plugin is unchanged). Head unit: a cluster that falls behind is no longer disconnected (2 s retry + backlog replay); the queue (now ~2 s, was ~4 s) is dropped, the phone is asked for a keyframe (unsolicited focus), and sending resumes from it; only with no keyframe in 3 s is the cluster dropped as before. Look for "cluster is behind" / "keyframe after" in the head unit log to see how often it happens.
- **Head unit (open-headunit `e60`):** −6 % default with the settings migration, and `videoWidth`/`videoHeight` in `clustermap`. Needs a head unit release as well as the dash one.

## Next: custom home screen for the head unit

**Goal:** replace the ZLH launcher with our own home screen, styled to match the cluster. It must be fully usable with the iDrive and delivered through the existing OTA pipeline.

### Needed from Tristan before building

1. **Photos/screenshots:**
   - current ZLH home screen (all pages) and the app drawer;
   - Open Headunit → Settings → **Keymap** key codes for each iDrive action: rotate left/right one click, push, tilt up/down/left/right, MENU, BACK, and any other buttons.
2. **Default home app:** whether Android Settings → Apps → Default apps → **Home app** exists and what it lists. Some ZLH units lock the launcher.
3. **Preferences:**
   - style: cluster's Range Rover look or something else, with reference pictures;
   - main-screen tiles: Android Auto, media/now playing, map or next turn, phone, radio, car info, settings, app drawer…
   - car data wanted on the home screen;
   - dislikes about the ZLH screen.

### Build plan (once the above is in)

1. **New app:** `homescreen/` (Kotlin, plain Views or Compose). HOME + DEFAULT intent filter, so it can be picked as the home app.
2. **Layout:** a 1920×720-class landscape layout with tiles per the preferences. Fonts and palette shared with the dash (Titillium, `Theme.qml` colours).
3. **iDrive navigation:**
   - explicit focus order for every tile;
   - rotate moves focus, push opens, BACK/MENU return home;
   - mapped from the key codes captured in step 1.
4. **Live data:**
   - now playing from the head unit's media sessions (NotificationListener / MediaSessionManager);
   - Android Auto status, next turn and speed limit from Open Headunit (local broadcast or the ClusterLink WebSocket on 127.0.0.1:8765);
   - optional car data the head unit can see.
5. **Launching:** Android Auto (Open Headunit), ZLH radio/music/settings, the app drawer.
6. **Preview first:** mock-up screenshots for approval before anything goes on the car.
7. **Ship:** add the APK to `release.py` as a new signed kind, `homescreen` (CarUpdate + phone updater + PROTOCOL.md), same pattern as `speedlimits`.

## iDrive

- **Inside Android Auto (our app):** rotation must reach Open Headunit as `SOFT_LEFT` / `SOFT_RIGHT`, which it sends as Android Auto scroll-wheel events. If the ZLH unit reports rotation as D-pad keys, Android Auto jumps between columns (same report from an E91 CCC owner on XDA).
  - **Quick fix:** Keymap → map rotate to Soft Left/Right, push to D-Pad Center, tilts to D-pad, BACK to Back, MENU to Home.
  - **Then:** make those the defaults in our build, once the key codes are known.
- **Native ZLH menus:** firmware/MCU. Check Factory setting → CAN protocol / car type is **CCC** (E60), not CIC/NBT.
- **Open:** what exactly "doesn't feel right" means (lag / skipping / direction / no smooth scroll), and where (Android Auto, native, both).

## Head unit firmware (research done 2026-10-04)

- **Hardware:** Unisoc **UIS8581A** (SC9863A class). Actually **Android 10 (API 29)**; the settings screen's "14" is spoofed. MCU `ZLH_BMH221130S_8581`, firmware `ZLH_BM_OS_6.40`, ZLINK5 (also runs the BT module).
- **Newer Android / LineageOS GSI:** not recommended. ZLH's car stack (MCU/iDrive service, CAN, camera, radio, audio routing, BT module) is tied to their Android 10 build, so a GSI would likely lose the iDrive. No known working GSI on these BMW UIS8581 units.
- **Root (later, optional):**
  - Method: Magisk-patched boot via the unit's own USB update, as done on other UIS8581A units (XDA "Android 10 UIS8581A (SC9863a), MCU: ZA001").
  - Recovery: full `.pac` + Unisoc ResearchDownload.
  - Prerequisite: the exact ZLH package for this unit (`ZLH_BM_OS_8581_*`, installed from a `HUTUpdate` folder), as both work source and recovery copy. XDA blocks automated downloads, so Tristan needs to fetch it.
  - Root would enable: silent installs, reliable hotspot control, removing the ZLH UI.

## Backlog

- **HUD speed:** (the speedo was found to read high, not low; recheck with the GPS check before any of this) if the drive confirms the HUD reads ~6% low, patch the cluster MCU firmware (`jly_can1293.bin`) to ×1.06. Rework the September speedfix (it divides; it needs to multiply). Trace that the HUD message uses the patched value, then remove the dash's ×1.06. Original firmware is the fallback.
- Brightness already follows day/night (confirmed by Tristan).
- **Trip history:** per-drive stats and best times on the settings page.
- **Parking sensors:** reverse graphic on the cluster, if the developer page shows the radar values are filled in.
- **Speed-limit data refresh:** `release.py --speedlimits` (Overpass is slow; `--osm-cache` reuses tiles).

## Key paths

- Dash QML: `custom_dash/device/etc/dash/`. Loader: `custom_dash/device/etc/d.qml`. Cluster updater: `custom_dash/device/etc/init.d/S61dashupdate`.
- Desktop preview: `custom_dash/preview/preview.py --scene <name> --shot out.png`. Fake head unit: `fake_headunit.py`.
- Head unit app: `headunit/open-headunit` (`aap/CarUpdate.kt`, `CarSettings.kt`, `SpeedLimits.kt`, `ClusterLink.kt`).
- Phone updater: `phone_updater/`.
- Protocol: `updater/PROTOCOL.md`. Release tool: `updater/release.py`.
- Android 10 test emulator: AVD `hu29` (`~/Library/Android/sdk/emulator/emulator -avd hu29 -no-window`).
