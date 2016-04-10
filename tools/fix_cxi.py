#!/usr/bin/env python2

import hashlib
from sys import argv
from struct import pack

f = open(argv[1], "r+b")
xorpad = bytearray(open(argv[2], "rb").read(0x400))

def xor(bytes, xorpad):
    if len(bytes) > len(xorpad):
        raise Exception("xorpad is too small")

    result = b""
    for x in range(len(bytes)):
        result += pack("B", bytes[x] ^ xorpad[x])
    return bytearray(result)

def sha256(s):
    h = hashlib.sha256()
    h.update(s)
    return h.digest()

# get titleid
f.seek(0x118)
titleid = f.read(8)
# get exheader
f.seek(0x200)
exheader = bytearray(f.read(0x400))
# decrypt exheader
exheader = xor(exheader, xorpad)
# verify exheader sha256sum
f.seek(0x160)
orig_sha256 = f.read(0x20)
if sha256(exheader) != orig_sha256:
    raise Exception("xorpad invalid")
# set sd flag in exheader
exh_flags = exheader[0xD]
exh_flags = exh_flags | 2
exheader = exheader[:0xD] + pack("B", exh_flags) + exheader[0xE:]
# write back modified exheader
f.seek(0x200)
f.write(xor(exheader, xorpad))
# reset the hash
f.seek(0x160)
f.write(sha256(exheader))
