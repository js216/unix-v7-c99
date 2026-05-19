#!/usr/bin/env python3
import os
import stat
import sys
from pathlib import Path


def pdp_long(buf):
    hi = buf[0] | (buf[1] << 8)
    lo = buf[2] | (buf[3] << 8)
    return (hi << 16) | lo


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract-old-ar.py archive outdir")
    archive = Path(sys.argv[1])
    outdir = Path(sys.argv[2])
    data = archive.read_bytes()
    if len(data) < 2 or data[0] != 0x65 or data[1] != 0xff:
        raise SystemExit(f"{archive}: bad old-ar magic")
    outdir.mkdir(parents=True, exist_ok=True)
    pos = 2
    while pos + 26 <= len(data):
        rawname = data[pos:pos + 14]
        name = rawname.split(b"\0", 1)[0].decode("ascii")
        mode = data[pos + 20] | (data[pos + 21] << 8)
        size = pdp_long(data[pos + 22:pos + 26])
        pos += 26
        if pos + size > len(data):
            raise SystemExit(f"{archive}: truncated member {name}")
        body = data[pos:pos + size]
        pos += size
        if size & 1:
            pos += 1
        if not name:
            continue
        if "/" in name or name in (".", ".."):
            raise SystemExit(f"{archive}: unsafe member name {name!r}")
        path = outdir / name
        path.write_bytes(body)
        os.chmod(path, stat.S_IMODE(mode))


if __name__ == "__main__":
    main()
