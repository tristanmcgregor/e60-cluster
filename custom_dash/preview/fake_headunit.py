"""
Stand-in for the head unit's ClusterLink (Open Headunit build) during desktop preview.

Serves the same JSON on ws://127.0.0.1:8765/nav and writes /tmp/nav_gateway, so the
dash's real Nav.qml connection code is exercised. Drives a short simulated route.
"""
import base64
import os
import hashlib
import json
import socket
import threading
import sys
import time

MODE = sys.argv[1] if len(sys.argv) > 1 else "nav"     # nav | media | call

PORT = 8765
GATEWAY_FILE = "/tmp/nav_gateway"
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# (AA NavigationType, road, metres to the manoeuvre, roundabout exit)
ROUTE = [
    (8, "Pacific Highway", 650, -1),
    (33, "Military Road", 420, 2),
    (5, "Spit Road", 900, -1),
    (14, "Warringah Freeway", 1800, -1),
    (41, "Destination", 300, -1),
]
SPEED_MPS = 60


def _frame(text):
    data = text.encode()
    if len(data) < 126:
        header = bytes([0x81, len(data)])
    else:
        header = bytes([0x81, 126, len(data) >> 8, len(data) & 0xFF])
    return header + data


class FakeHeadUnit:
    def __init__(self):
        self.clients = []
        self.lock = threading.Lock()

    def start(self):
        with open(GATEWAY_FILE, "w") as f:
            f.write("127.0.0.1\n")
        srv = socket.socket()
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind(("127.0.0.1", PORT))
        srv.listen()
        threading.Thread(target=self._accept, args=(srv,), daemon=True).start()
        if MODE == "nav":
            threading.Thread(target=self._drive, daemon=True).start()
        if MODE in ("camera", "redlight", "gps"):
            threading.Thread(target=self._gps, daemon=True).start()

    def _accept(self, srv):
        while True:
            conn, _ = srv.accept()
            req = b""
            while b"\r\n\r\n" not in req:
                chunk = conn.recv(1024)
                if not chunk:
                    break
                req += chunk
            key = next((l.split(b":", 1)[1].strip() for l in req.split(b"\r\n")
                        if l.lower().startswith(b"sec-websocket-key")), None)
            if key is None:
                conn.close()
                continue
            accept = base64.b64encode(hashlib.sha1(key + WS_GUID.encode()).digest()).decode()
            conn.sendall(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
                          "Connection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n" % accept).encode())
            with self.lock:
                self.clients.append(conn)
            if MODE in ("media", "call", "media_art"):
                self._send({"type": "media", "title": "Blinding Lights", "artist": "The Weeknd",
                            "album": "After Hours", "playing": True, "duration": 200, "position": 74})
                if MODE == "media_art":       # cover as a data: URL, sent once per track like the head unit
                    art = base64.b64encode(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                             "sample_cover.jpg"), "rb").read()).decode()
                    self._send({"type": "mediaart", "art": "data:image/jpeg;base64," + art})
            # size of the map in the cluster video (the head unit's wide stream: 1280x480 drawn)
            self._send({"type": "clustermap", "width": 1280, "height": 480, "videoWidth": 1280, "videoHeight": 720})
            if MODE.startswith("limit"):   # e.g. limit60: the road's speed limit from SpeedLimits
                self._send({"type": "limit", "kph": int(MODE[5:])})
            if MODE == "school":           # a school-zone limit in force
                self._send({"type": "limit", "kph": 40, "school": True})
            if MODE in ("camera", "redlight"):
                self._send({"type": "limit", "kph": 60})
            if MODE == "settings":      # as saved from the phone settings page
                self._send({"type": "settings", "speedCorrection": 0, "sport": "always", "shiftLights": True,
                            "shiftWindow": 1500, "shiftMargin": 300, "redline": [[0, 5000], [60, 6000], [90, 7000]],
                            "speedLimit": True, "speedLimitMargin": 3, "defaultPage": 1})
            if MODE == "call":
                self._send({"type": "call", "active": True, "state": 1, "name": "Mum",
                            "number": "0412 345 678", "seconds": 83})

    def _send(self, msg):
        frame = _frame(json.dumps(msg))
        with self.lock:
            for c in list(self.clients):
                try:
                    c.sendall(frame)
                except OSError:
                    self.clients.remove(c)

    def _gps(self):
        """GPS speed every second (the preview car's speed is ~5 % above the MCU's), and for the
        camera modes a camera counting down from 400 m, then passed."""
        dist = 400
        while True:
            self._send({"type": "gps", "kph": 104.6, "acc": 4})
            if MODE in ("camera", "redlight"):
                if dist >= 0:
                    self._send({"type": "camera", "kind": "speed" if MODE == "camera" else "redlight",
                                "kph": 60, "distM": dist})
                    dist -= 30
                else:
                    self._send({"type": "camera", "distM": -1})
            time.sleep(1)

    def _drive(self):
        total = sum(step[2] for step in ROUTE)
        while True:
            done = 0
            for maneuver, road, length, exit_no in ROUTE:
                left = length
                while left > 0:
                    remaining = total - done - (length - left)
                    eta = time.strftime("%H:%M", time.localtime(time.time() + remaining / 14))
                    self._send({
                        "active": True, "maneuver": maneuver, "action": "", "road": road,
                        "distance_m": int(left), "time_s": int(left / 14),
                        "roundabout_exit": exit_no, "turn_angle": -1, "turn_side": 3,
                        "total_distance_m": int(remaining), "total_time_s": int(remaining / 14),
                        "eta": eta,
                    })
                    time.sleep(1)
                    left -= SPEED_MPS
                done += length
            self._send({"active": False})
            time.sleep(5)


if __name__ == "__main__":
    FakeHeadUnit().start()
    while True:
        time.sleep(3600)
