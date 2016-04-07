#!/usr/bin/env python2

from sys import argv
from struct import pack, unpack

f = open(argv[1], "r+b")
xorpad = bytearray(open(argv[2], "rb").read(0x400))

def xor(bytes, xorpad):
    if len(bytes) > len(xorpad):
        raise Exception("xorpad is too small")

    result = b""
    for x in range(len(bytes)):
        result += pack("B", bytes[x] ^ xorpad[x])
    return bytearray(result)

def roundup(x, y):
    x = int(x)
    y = int(y)
    m = x % y
    return x if m == 0 else (x - m + y)

# first locate cxi & exheader in the cia file
header_size = unpack('<I', f.read(4))[0]
f.seek(0x08)
cert_size = unpack('<I', f.read(4))[0]
f.seek(0x0C)
ticket_size = unpack('<I', f.read(4))[0]
f.seek(0x10)
tmd_size = unpack('<I', f.read(4))[0]
cxi_ofs = roundup(header_size, 0x40) + roundup(cert_size, 0x40) + roundup(ticket_size, 0x40) + roundup(tmd_size, 0x40)
exh_ofs = cxi_ofs + 0x200
# extract exheader
f.seek(exh_ofs, 0)
exheader = bytearray(f.read(0x400))
# decrypt exheader
f.seek(cxi_ofs + 0x118)
titleid = f.read(8)
exheader = xor(exheader, xorpad)
# locate save data size in tmd
tmd_ofs = roundup(header_size, 0x40) + roundup(cert_size, 0x40) + roundup(ticket_size, 0x40)
f.seek(tmd_ofs)
tmd_sig_type = unpack('>I', f.read(4))[0]
if tmd_sig_type == 0x010000:
  tmd_hdr_ofs = tmd_ofs + 0x240
elif tmd_sig_type == 0x010001:
  tmd_hdr_ofs = tmd_ofs + 0x140
elif tmd_sig_type == 0x010002:
  tmd_hdr_ofs = tmd_ofs + 0x80
elif tmd_sig_type == 0x010003:
  tmd_hdr_ofs = tmd_ofs + 0x240
elif tmd_sig_type == 0x010004:
  tmd_hdr_ofs = tmd_ofs + 0x140
elif tmd_sig_type == 0x010005:
  tmd_hdr_ofs = tmd_ofs + 0x80
else:
  print("HURP?")
# fix save data size
save_data_size = exheader[0x1C0:0x1C4]
f.seek(tmd_hdr_ofs + 0x5A);
f.write(save_data_size)
