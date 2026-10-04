#!/usr/bin/env python3
"""Builds the speed-limit file for the head unit from OpenStreetMap (south-east Queensland).

    python3 updater/speedlimits.py OUT.bin [--cache DIR]

Roads come from the Overpass API in tiles: drivable `highway` ways with a `maxspeed`
tag, plus residential streets without one, which take Queensland's 50 km/h urban
default. School zones come from `maxspeed:conditional` on the same ways
("40 @ (Mo-Fr 07:00-09:00,14:00-16:00; PH off; SH off)"), cameras from
`highway=speed_camera` nodes and `type=enforcement` relations. Everything is only as
good as OpenStreetMap.

File format (little endian), read by the head unit's SpeedLimits.kt:
    magic "E6SL", int32 version = 1
    int32 minLat, minLon            microdegrees, south-west corner of the grid
    int32 cell                      microdegrees per grid cell (square)
    int32 cols, rows
    int32 segments                  N
    int32 offsets[cols*rows + 1]    start of each cell's run in refs[]
    int32 refs[offsets[-1]]         segment numbers per cell (row-major cells)
    N x { int32 lat1, lon1, lat2, lon2 }   segment end points, microdegrees
    N x uint8 kph
then, padded to 4 bytes, the "E6X1" extension (older head units stop reading before it):
    "E6X1"
    int32 S; S x { uint8 kph, uint8 days (bit 0 = Monday), uint8 flags (1 PH off, 2 SH off),
                   uint8 ranges, 4 x { uint16 fromMin, uint16 toMin } }     school-hours limits
    N x uint8 schedule        1-based index into the table above, 0 = none; padded to 4
    int32 C; C x { int32 lat, lon; uint8 kind (1 speed, 2 red light, 3 average-speed start);
                   uint8 kph; uint16 0 }                                     cameras
    int32 H; H x int32 yyyymmdd                                              Queensland public holidays
    int32 T; T x { int32 fromYmd, toYmd }                                    state school terms
"""
import argparse
import datetime
import re
import json
import math
import os
import struct
import sys
import time
import urllib.parse
import urllib.request

BBOX = (-28.3, 152.3, -26.0, 153.6)    # south, west, north, east: Gold Coast to Noosa, Toowoomba
TILE = 0.5                             # degrees per Overpass query
CELL = 0.005                           # grid cell, about 550 m
# the main server is often too busy; the others mirror it
OVERPASS = ["https://overpass-api.de/api/interpreter",
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
            "https://overpass.private.coffee/api/interpreter"]
ROADS = ("motorway|motorway_link|trunk|trunk_link|primary|primary_link|secondary|secondary_link|"
         "tertiary|tertiary_link|unclassified|residential|living_street|road")
IMPLIED = {"AU:urban": 50, "AU:rural": 100, "AU:motorway": 110, "AU:living_street": 10, "walk": 10}


def kph(tags):
    """Speed in km/h from OSM tags, or None if unusable."""
    v = tags.get("maxspeed")
    if v is None:
        # Queensland's urban default; only residential streets are safe to assume urban
        return 50 if tags.get("highway") in ("residential",) else None
    v = v.strip()
    if v in IMPLIED:
        return IMPLIED[v]
    if v.endswith(" mph"):
        try:
            return round(float(v[:-4]) * 1.609)
        except ValueError:
            return None
    try:
        n = int(float(v.split(";")[0]))
    except ValueError:
        return None
    return n if 5 <= n <= 130 else None


def overpass(query, what, path):
    """Runs an Overpass query, trying each server in turn; cached in [path] when given."""
    if path and os.path.isfile(path):
        return json.load(open(path))
    data = urllib.parse.urlencode({"data": query}).encode()
    for attempt in range(6):
        url = OVERPASS[attempt % len(OVERPASS)]
        req = urllib.request.Request(url, data=data, headers={"User-Agent": "e60-cluster speedlimit builder"})
        try:
            with urllib.request.urlopen(req, timeout=360) as r:
                body = json.load(r)
            break
        except Exception as ex:                        # busy server: back off and retry
            print(f"  {what} ({url}): {ex}; retrying", file=sys.stderr)
            time.sleep(20 * (attempt // len(OVERPASS) + 1))
    else:
        sys.exit(f"{what} failed")
    if path:
        json.dump(body, open(path, "w"))
    time.sleep(5)                                      # be polite to the public servers
    return body


def fetch_tile(s, w, n, e, cache):
    query = (f'[out:json][timeout:300];'
             f'(way["highway"~"^({ROADS})$"]["maxspeed"]({s},{w},{n},{e});'
             f' way["highway"="residential"][!"maxspeed"]({s},{w},{n},{e}););out tags geom;')
    return overpass(query, f"tile {s},{w}", os.path.join(cache, f"tile_{s:.2f}_{w:.2f}.json") if cache else None)


# ---- school zones ----

DAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]


def schedule(tags):
    """maxspeed:conditional as (kph, days mask, flags, ((from, to) minutes, ...)), or None.

    Handles the forms Queensland mappers use: "40 @ (Mo-Fr 07:00-09:00,14:00-16:00; PH off;
    SH off)" and variations in spacing and order. Month ranges and other rules are skipped.
    """
    v = tags.get("maxspeed:conditional")
    if not v:
        return None
    v = v.split("=", 1)[-1] if v.startswith("maxspeed:conditional=") else v
    m = re.fullmatch(r"\s*(\d+)\s*@\s*\((.*)\)\s*", v)
    if not m:
        return None
    kph, days, flags, ranges = int(m.group(1)), 0, 0, []
    for part in (p.strip() for p in m.group(2).split(";")):
        if not part:
            continue
        off = re.fullmatch(r"((?:SH|PH)(?:\s*,\s*(?:SH|PH))*)(?:\s+Mo-Fr)?\s+off", part)
        if off:
            flags |= (2 if "SH" in off.group(1) else 0) | (1 if "PH" in off.group(1) else 0)
            continue
        dm = re.match(r"(Mo|Tu|We|Th|Fr|Sa|Su)(?:-(Mo|Tu|We|Th|Fr|Sa|Su))?\s+", part)
        if dm:
            a = DAYS.index(dm.group(1)); b = DAYS.index(dm.group(2) or dm.group(1))
            for i in range(a, b + 1):
                days |= 1 << i
            part = part[dm.end():]
        times = re.findall(r"(\d\d):(\d\d)-(\d\d):(\d\d)", part)
        if not times or re.sub(r"[\d:,\s-]", "", part):
            return None                                  # months, sunrise, etc.: not handled
        ranges += [(int(h1) * 60 + int(m1), int(h2) * 60 + int(m2)) for h1, m1, h2, m2 in times]
    if not ranges or len(ranges) > 4 or not 5 <= kph <= 130:
        return None
    return kph, days or 0x7f, flags, tuple(ranges)


# Queensland state school terms (education.qld.gov.au, "School holidays and term dates" and
# "Future school dates"). School zones marked "SH off" are not in force outside these.
TERMS = [
    ("2026-01-27", "2026-04-02"), ("2026-04-20", "2026-06-26"), ("2026-07-13", "2026-09-18"), ("2026-10-06", "2026-12-11"),
    ("2027-01-27", "2027-03-25"), ("2027-04-12", "2027-06-25"), ("2027-07-12", "2027-09-17"), ("2027-10-05", "2027-12-10"),
    ("2028-01-24", "2028-03-31"), ("2028-04-18", "2028-06-23"), ("2028-07-10", "2028-09-15"), ("2028-10-03", "2028-12-08"),
    ("2029-01-22", "2029-03-29"), ("2029-04-16", "2029-06-22"), ("2029-07-09", "2029-09-14"), ("2029-10-02", "2029-12-07"),
]


def easter(year):
    """Easter Sunday (anonymous Gregorian algorithm)."""
    a, b, c = year % 19, year // 100, year % 100
    d, e = b // 4, b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    return datetime.date(year, month, (h + l - 7 * m + 114) % 31 + 1)


def holidays(years):
    """Queensland statewide public holidays (Holidays Act 1983), including Monday substitutes."""
    out = set()
    for y in years:
        def nth_monday(month, n):
            d = datetime.date(y, month, 1)
            d += datetime.timedelta(days=(7 - d.weekday()) % 7)
            return d + datetime.timedelta(weeks=n - 1)

        def observed(d):                                 # a weekend holiday also gives the Monday
            out.add(d)
            if d.weekday() >= 5:
                out.add(d + datetime.timedelta(days=7 - d.weekday()))

        observed(datetime.date(y, 1, 1))
        observed(datetime.date(y, 1, 26))
        e = easter(y)
        for off in (-2, -1, 0, 1):
            out.add(e + datetime.timedelta(days=off))
        anzac = datetime.date(y, 4, 25)
        out.add(anzac)
        if anzac.weekday() == 6:
            out.add(anzac + datetime.timedelta(days=1))
        out.add(nth_monday(5, 1))                        # Labour Day
        out.add(nth_monday(10, 1))                       # King's Birthday
        xmas, boxing = datetime.date(y, 12, 25), datetime.date(y, 12, 26)
        out.update((xmas, boxing))
        if xmas.weekday() == 5:                          # Sat/Sun -> Mon/Tue
            out.update((xmas + datetime.timedelta(days=2), boxing + datetime.timedelta(days=2)))
        elif xmas.weekday() == 6:
            out.add(boxing + datetime.timedelta(days=1))
        elif boxing.weekday() == 5:
            out.add(boxing + datetime.timedelta(days=2))
    return sorted(out)


def ymd(d):
    if isinstance(d, str):
        d = datetime.date.fromisoformat(d)
    return d.year * 10000 + d.month * 100 + d.day


# ---- cameras ----

def fetch_cameras(cache):
    s, w, n, e = BBOX
    query = (f'[out:json][timeout:300];'
             f'(node["highway"="speed_camera"]({s},{w},{n},{e});'
             f' relation["type"="enforcement"]({s},{w},{n},{e}););'
             f'out body;>;out skel qt;')
    return overpass(query, "cameras", os.path.join(cache, "cameras.json") if cache else None)


def cameras(body):
    """[(lat, lon, kind, kph)] in microdegrees; kind 1 speed, 2 red light, 3 average-speed start."""
    nodes = {e["id"]: e for e in body.get("elements", []) if e["type"] == "node"}
    out, used = [], set()

    def add(node_id, kind, kph):
        nd = nodes.get(node_id)
        if nd is None or "lat" not in nd or (node_id, kind) in used:
            return
        used.add((node_id, kind))
        out.append((round(nd["lat"] * 1e6), round(nd["lon"] * 1e6), kind, kph))

    def limit(tags):
        k = kph({"maxspeed": tags["maxspeed"]}) if "maxspeed" in tags else None
        return k or 0

    for e in body.get("elements", []):
        if e["type"] != "relation":
            continue
        tags = e.get("tags", {})
        enf = tags.get("enforcement", "")
        kinds = ([3] if "average_speed" in enf else []) + ([2] if "traffic_signals" in enf else []) + \
                ([1] if "maxspeed" in enf else [])
        roles = {}
        for m in e.get("members", []):
            if m["type"] == "node":
                roles.setdefault(m["role"], []).append(m["ref"])
        for kind in kinds:
            # an average-speed zone is announced where it starts; others at the camera itself
            at = (roles.get("from") or roles.get("device")) if kind == 3 else \
                 (roles.get("device") or roles.get("to") or roles.get("from"))
            for ref in (at or [])[:1]:
                add(ref, kind, limit(tags))
    for nd in nodes.values():
        tags = nd.get("tags", {})
        if tags.get("highway") == "speed_camera":
            add(nd["id"], 1, limit(tags))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--cache", help="keep downloaded tiles here and reuse them")
    args = ap.parse_args()
    if args.cache:
        os.makedirs(args.cache, exist_ok=True)

    s0, w0, n0, e0 = BBOX
    seen, segs = set(), []
    sched_ix, sched_of = {}, []                        # schedule -> 1-based index; per segment index
    lat = s0
    while lat < n0 - 1e-9:
        lon = w0
        while lon < e0 - 1e-9:
            tile = (round(lat, 3), round(lon, 3), round(min(lat + TILE, n0), 3), round(min(lon + TILE, e0), 3))
            body = fetch_tile(*tile, args.cache)
            before = len(segs)
            for way in body.get("elements", []):
                if way.get("type") != "way" or way["id"] in seen:
                    continue                           # ways crossing tile edges come twice
                seen.add(way["id"])
                speed = kph(way.get("tags", {}))
                pts = way.get("geometry") or []
                if speed is None or len(pts) < 2:
                    continue
                sch = schedule(way.get("tags", {}))
                ix = sched_ix.setdefault(sch, len(sched_ix) + 1) if sch else 0
                if ix > 255:
                    ix = 0
                for a, b in zip(pts, pts[1:]):
                    segs.append((round(a["lat"] * 1e6), round(a["lon"] * 1e6),
                                 round(b["lat"] * 1e6), round(b["lon"] * 1e6), speed))
                    sched_of.append(ix)
            print(f"tile {tile}: +{len(segs) - before} segments", file=sys.stderr)
            lon += TILE
        lat += TILE

    cell = round(CELL * 1e6)
    min_lat, min_lon = round(s0 * 1e6), round(w0 * 1e6)
    cols = math.ceil((e0 - w0) / CELL)
    rows = math.ceil((n0 - s0) / CELL)
    cells = [[] for _ in range(cols * rows)]
    for i, (a_lat, a_lon, b_lat, b_lon, _) in enumerate(segs):
        # every cell the segment's bounding box touches (segments are short)
        r0 = (min(a_lat, b_lat) - min_lat) // cell; r1 = (max(a_lat, b_lat) - min_lat) // cell
        c0 = (min(a_lon, b_lon) - min_lon) // cell; c1 = (max(a_lon, b_lon) - min_lon) // cell
        for r in range(max(0, r0), min(rows - 1, r1) + 1):
            for c in range(max(0, c0), min(cols - 1, c1) + 1):
                cells[r * cols + c].append(i)

    offsets, refs = [0], []
    for c in cells:
        refs.extend(c)
        offsets.append(len(refs))
    with open(args.out, "wb") as f:
        f.write(b"E6SL" + struct.pack("<i", 1))
        f.write(struct.pack("<6i", min_lat, min_lon, cell, cols, rows, len(segs)))
        f.write(struct.pack(f"<{len(offsets)}i", *offsets))
        f.write(struct.pack(f"<{len(refs)}i", *refs))
        f.write(b"".join(struct.pack("<4i", *s[:4]) for s in segs))
        f.write(bytes(s[4] for s in segs))

        def pad():
            f.write(b"\0" * (-f.tell() % 4))

        pad()
        f.write(b"E6X1")
        table = sorted((i, s) for s, i in sched_ix.items() if i <= 255)
        f.write(struct.pack("<i", len(table)))
        for _, (k, days, flags, ranges) in table:
            r = list(ranges) + [(0, 0)] * (4 - len(ranges))
            f.write(struct.pack("<4B8H", k, days, flags, len(ranges), *[x for pair in r for x in pair]))
        f.write(bytes(sched_of))
        pad()
        cams = cameras(fetch_cameras(args.cache))
        f.write(struct.pack("<i", len(cams)))
        for lat, lon, kind, k in cams:
            f.write(struct.pack("<2i2BH", lat, lon, kind, k, 0))
        years = range(datetime.date.fromisoformat(TERMS[0][0]).year, datetime.date.fromisoformat(TERMS[-1][1]).year + 1)
        ph = [ymd(d) for d in holidays(years)]
        f.write(struct.pack(f"<i{len(ph)}i", len(ph), *ph))
        f.write(struct.pack("<i", len(TERMS)))
        for a, b in TERMS:
            f.write(struct.pack("<2i", ymd(a), ymd(b)))
    zoned = sum(1 for i in sched_of if i)
    print(f"{len(seen)} ways, {len(segs)} segments ({zoned} in school zones, {len(sched_ix)} schedules), "
          f"{len(cams)} cameras, {len(refs)} cell refs -> {args.out} "
          f"({os.path.getsize(args.out) / 1e6:.1f} MB)", file=sys.stderr)


if __name__ == "__main__":
    main()
