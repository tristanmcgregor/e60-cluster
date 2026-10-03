#!/usr/bin/env python3
"""
Point the stock JLY Launcher at /etc/d.qml instead of its built-in qrc:/main.qml.

    python3 patch_launcher_qml_path.py Launcher_original Launcher_customdash

The root QML URL is a QStringLiteral (static QArrayData header + UTF-16 chars):
    header: ref=-1, size=13, alloc=0, offset=24   then  u"qrc:/main.qml\\0" + zero padding
There is zero padding up to the next 8-byte-aligned symbol, which leaves room
for exactly 15 chars + terminator, so "file:/etc/d.qml" fits. Only the size
field and the character bytes change; nothing else in the binary moves.

The stock UI is untouched inside the binary and d.qml falls back to it
(qrc:/main.qml) if the custom dashboard fails to load.
"""
import hashlib
import struct
import sys

OLD = "qrc:/main.qml"
NEW = "file:/etc/d.qml"


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1:]
    data = bytearray(open(src, "rb").read())

    old_u16 = OLD.encode("utf-16le")
    hits = [i for i in range(len(data)) if data.startswith(old_u16, i)] if data.count(old_u16) else []
    if len(hits) != 1:
        sys.exit(f"expected exactly one {OLD!r} literal, found {len(hits)}")
    chars = hits[0]
    hdr = chars - 24

    ref, size, alloc, offset = struct.unpack_from("<iiIxxxxq", data, hdr)
    if (ref, size, alloc, offset) != (-1, len(OLD), 0, 24):
        sys.exit(f"unexpected QArrayData header at {hdr:#x}: {(ref, size, alloc, offset)}")

    room = (len(NEW) + 1) * 2
    tail = data[chars + len(old_u16):chars + room]
    if any(tail):
        sys.exit(f"not enough zero padding after literal at {chars:#x}: {tail.hex()}")

    struct.pack_into("<i", data, hdr + 4, len(NEW))
    data[chars:chars + room] = NEW.encode("utf-16le") + b"\0\0"

    open(dst, "wb").write(data)
    print(f"patched literal at file offset {chars:#x} (header {hdr:#x})")
    print(f"  {OLD!r} -> {NEW!r}")
    print(f"  sha1 {hashlib.sha1(data).hexdigest()}  -> {dst}")


if __name__ == "__main__":
    main()
