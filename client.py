#!/usr/bin/env python3
"""
client.py — demo client for the buffer-overflow teaching server.

Usage:
    python3 client.py normal          # send a short, well-behaved request
    python3 client.py overflow [N]    # send N 'A's (default 200) to overflow

Target defaults to 127.0.0.1:8888 and can be overridden with env vars
HOST / PORT. This only sends plain bytes to a server you control inside
the sandbox; it contains no exploit payload.
"""

import os
import socket
import sys

HOST = os.environ.get("HOST", "127.0.0.1")
PORT = int(os.environ.get("PORT", "8888"))


def send(payload: bytes) -> None:
    with socket.create_connection((HOST, PORT), timeout=5) as s:
        s.sendall(payload)
        try:
            reply = s.recv(1024)
            print(f"[client] server replied: {reply!r}")
        except (socket.timeout, ConnectionResetError):
            # No reply / connection dropped is the expected outcome when
            # the server crashes on the overflow.
            print("[client] no reply — server connection closed (likely crashed)")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "normal"

    if mode == "normal":
        payload = b"Hello"
        print(f"[client] sending normal request: {payload!r}")
    elif mode == "overflow":
        length = int(sys.argv[2]) if len(sys.argv) > 2 else 200
        payload = b"A" * length
        print(f"[client] sending overflow request: {length} bytes of 'A'")
    else:
        print(__doc__)
        sys.exit(1)

    send(payload)


if __name__ == "__main__":
    main()
