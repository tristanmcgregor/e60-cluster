#!/usr/bin/env python3
"""Fake head-unit video forwarder (ClusterVideo.kt wire format) for testing the plugin.
Serves test.h264 (Annex-B) as [u32 BE length][access unit], 30 fps, looping."""
import socket, struct, sys, time

data = open(sys.argv[1], "rb").read()
# split into NAL units, then group into access units (a VCL NAL starts a new AU after the previous VCL)
starts = [i for i in range(len(data) - 3) if data[i:i+3] == b"\0\0\1" and (i == 0 or data[i-1] != 0 or True)]
nals, i = [], 0
pos = [i for i in range(len(data) - 3) if data[i:i+3] == b"\0\0\1"]
for k, p in enumerate(pos):
    s = p - 1 if p > 0 and data[p-1] == 0 else p
    e = (pos[k+1] - 1 if pos[k+1] > 0 and data[pos[k+1]-1] == 0 else pos[k+1]) if k + 1 < len(pos) else len(data)
    nals.append(data[s:e])
aus, cur = [], b""
for n in nals:
    t = n[n.index(b"\0\0\1") + 3] & 0x1f
    cur += n
    if t in (1, 5):
        aus.append(cur); cur = b""
print(f"{len(aus)} access units", flush=True)
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 8766)); srv.listen(1)
while True:
    c, _ = srv.accept(); print("client connected", flush=True)
    try:
        for au in aus * 3:
            c.sendall(struct.pack(">I", len(au)) + au); time.sleep(1 / 30)
    except OSError:
        pass
    c.close()
