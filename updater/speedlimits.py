#!/usr/bin/env python3
"""Builds the speed-limit file for the head unit from OpenStreetMap (south-east Queensland).

    python3 updater/speedlimits.py OUT.bin [--cache DIR]

Roads come from the Overpass API in tiles: drivable `highway` ways with a `maxspeed`
tag, plus residential streets without one, which take Queensland's 50 km/h urban
default. Limits are only as good as OpenStreetMap; `maxspeed:conditional` (school
zones and the like) is not used.

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
"""
import argparse
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
OVERPASS = "https://overpass-api.de/api/interpreter"
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


def fetch_tile(s, w, n, e, cache):
    path = os.path.join(cache, f"tile_{s:.2f}_{w:.2f}.json") if cache else None
    if path and os.path.isfile(path):
        return json.load(open(path))
    query = (f'[out:json][timeout:300];'
             f'(way["highway"~"^({ROADS})$"]["maxspeed"]({s},{w},{n},{e});'
             f' way["highway"="residential"][!"maxspeed"]({s},{w},{n},{e}););out tags geom;')
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(OVERPASS, data=data, headers={"User-Agent": "e60-cluster speedlimit builder"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=360) as r:
                body = json.load(r)
            break
        except Exception as ex:                        # busy server: back off and retry
            print(f"  tile {s},{w}: {ex}; retrying", file=sys.stderr)
            time.sleep(30 * (attempt + 1))
    else:
        sys.exit(f"tile {s},{w} failed")
    if path:
        json.dump(body, open(path, "w"))
    time.sleep(5)                                      # be polite to the public server
    return body


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--cache", help="keep downloaded tiles here and reuse them")
    args = ap.parse_args()
    if args.cache:
        os.makedirs(args.cache, exist_ok=True)

    s0, w0, n0, e0 = BBOX
    seen, segs = set(), []
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
                for a, b in zip(pts, pts[1:]):
                    segs.append((round(a["lat"] * 1e6), round(a["lon"] * 1e6),
                                 round(b["lat"] * 1e6), round(b["lon"] * 1e6), speed))
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
    print(f"{len(seen)} ways, {len(segs)} segments, {len(refs)} cell refs -> {args.out} "
          f"({os.path.getsize(args.out) / 1e6:.1f} MB)", file=sys.stderr)


if __name__ == "__main__":
    main()
