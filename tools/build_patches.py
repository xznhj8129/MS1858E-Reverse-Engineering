#!/usr/bin/env python3
"""Rebuild the patched images from a 2 KB stock dump (CPython).

    python3 tools/build_patches.py firmware/stock.bin

Writes noblue.bin, noblue_skipe67a.bin and bootfix_skipe67a_fixed.bin next to
the input if the input lives under firmware/, otherwise into the current
directory.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

HEADER_START = 0x0A
HEADER_END = 0x36  # exclusive
CODE_START = 0x40

# noblue (length unchanged). List of (slice-or-offset, value) so it also works
# on Python versions where slice objects are not hashable (e.g. 3.11).
NOBLUE = [
    (slice(0x008B, 0x008E), bytes([0x00, 0x00, 0x00])),  # NOP LJMP E4FF
    (slice(0x00A1, 0x00A4), bytes([0x00, 0x00, 0x00])),  # NOP LJMP E4FF
    (0x0131, 0x00),  # F8B9 = 0
    (0x0137, 0x80),  # SJMP: never write E1F4=FF
    (0x0313, 0x00),  # EC01 stays 0
]

# Cave at 0x350: if new E1F4 (R7) >= 7 skip E67A(0x11), set EC00=FF, jump 0x82;
# else E67A(0x11) and continue at 0x75.
CAVE = bytes(
    [
        0xEF, 0xC3, 0x94, 0x07, 0x50, 0x08,  # MOV A,R7; CLR C; SUBB #7; JNC skip
        0x7F, 0x11, 0x12, 0xE6, 0x7A,  # MOV R7,#0x11; LCALL E67A
        0x02, 0x00, 0x75,  # LJMP 0x0075
        0x90, 0xEC, 0x00, 0x74, 0xFF, 0xF0,  # MOVX EC00,#0xFF
        0x02, 0x00, 0x82,  # LJMP 0x0082
    ]
)


# bootfix_skipe67a_fixed:
# - one-time F8B9=0 / E2EA=1 on the first valid-video frame (EC07 flag),
#   routed from the video commit at 0x00A4.
# - E67A(0x11) skipped only while unlocked; the stock 0x0075 path still updates
#   EC01=0 and EC00=E1F4, so relock reinitializes normally.
# - 0294 disabled: no E67A(0xCC) blue flash on quality drop.
BOOT_CAVE = bytes(
    [
        0x90, 0xEC, 0x07,  # MOV DPTR,#EC07
        0xE0,              # MOVX A,@DPTR
        0x70, 0x11,        # JNZ 0x0377 (already done)
        0x90, 0xF8, 0xB9,  # MOV DPTR,#F8B9
        0xE4, 0xF0,        # F8B9 = 0
        0x90, 0xE2, 0xEA,  # MOV DPTR,#E2EA
        0x74, 0x01, 0xF0,  # E2EA = 1
        0x90, 0xEC, 0x07,  # MOV DPTR,#EC07
        0x74, 0x01, 0xF0,  # EC07 = 1
        0x12, 0xE6, 0xBD,  # LCALL E6BD (video commit)
        0x02, 0x00, 0xA7,  # LJMP 0x00A7
    ]
)

SKIP_CAVE = bytes(
    [
        0xEF,              # MOV A,R7 (new E1F4)
        0xC3,              # CLR C
        0x94, 0x07,        # SUBB A,#7
        0x40, 0x05,        # JC 0x039B (locked -> reinit)
        0x02, 0x00, 0x75,  # LJMP 0x0075 (unlock: skip reinit)
        0x7F, 0x11,        # MOV R7,#0x11
        0x12, 0xE6, 0x7A,  # LCALL E67A
        0x02, 0x00, 0x75,  # LJMP 0x0075
    ]
)


def checksums(fw: bytearray) -> tuple[int, int, int]:
    length = (fw[0x0A] << 8) | fw[0x0B]
    header = sum(fw[HEADER_START:HEADER_END]) & 0xFFFF
    code = sum(fw[CODE_START : CODE_START + length]) & 0xFFFF
    return length, header, code


def store_checksums(fw: bytearray) -> None:
    length, header, code = checksums(fw)
    pos = CODE_START + length
    fw[pos] = (header >> 8) & 0xFF
    fw[pos + 1] = header & 0xFF
    fw[pos + 2] = (code >> 8) & 0xFF
    fw[pos + 3] = code & 0xFF


def apply_map(fw: bytearray, mapping) -> None:
    for key, val in mapping:
        fw[key] = val


def make_noblue(stock: bytes) -> bytearray:
    fw = bytearray(stock)
    apply_map(fw, NOBLUE)
    store_checksums(fw)
    return fw


def make_skipe67a(stock: bytes) -> bytearray:
    fw = make_noblue(stock)
    # length 0x0310 → 0x0327 (cave after old checksums)
    fw[0x0A] = 0x03
    fw[0x0B] = 0x27
    fw[0x0070:0x0073] = bytes([0x02, 0x03, 0x50])  # LJMP 0x0350
    fw[0x0350 : 0x0350 + len(CAVE)] = CAVE
    store_checksums(fw)
    return fw


def make_bootfix(stock: bytes) -> bytearray:
    fw = make_noblue(stock)

    # 0294 quality/OSD handler: RET (no E67A(0xCC) blue flash)
    fw[0x294] = 0x22

    # video commit at 0x00A4 -> boot cave
    fw[0x00A4:0x00A7] = bytes([0x02, 0x03, 0x60])
    fw[0x360 : 0x360 + len(BOOT_CAVE)] = BOOT_CAVE

    # E1F4-change handler -> skip cave
    fw[0x0070:0x0073] = bytes([0x02, 0x03, 0x90])
    fw[0x390 : 0x390 + len(SKIP_CAVE)] = SKIP_CAVE

    # length 0x0310 -> 0x0370; old checksum area is inert padding
    fw[0x0A] = 0x03
    fw[0x0B] = 0x70
    fw[0x350:0x360] = b"\xFF" * 0x10
    fw[0x37D:0x390] = b"\xFF" * (0x390 - 0x37D)
    fw[0x390 + len(SKIP_CAVE) : 0x3B0] = b"\xFF" * (
        0x3B0 - (0x390 + len(SKIP_CAVE))
    )

    store_checksums(fw)
    return fw


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("stock", type=Path, help="2048-byte stock EEPROM dump")
    p.add_argument("-o", "--outdir", type=Path, default=None)
    args = p.parse_args()
    stock = args.stock.read_bytes()
    if len(stock) != 2048:
        print("need 2048 bytes, got", len(stock), file=sys.stderr)
        return 1
    if stock[:10] != b"MSES8858SE":
        print("warning: magic is", stock[:10], file=sys.stderr)

    outdir = args.outdir or args.stock.parent
    outdir.mkdir(parents=True, exist_ok=True)

    noblue = make_noblue(stock)
    skip = make_skipe67a(stock)
    bootfix = make_bootfix(stock)

    (outdir / "noblue.bin").write_bytes(noblue)
    (outdir / "noblue_skipe67a.bin").write_bytes(skip)
    (outdir / "bootfix_skipe67a_fixed.bin").write_bytes(bootfix)

    for name, fw in (
        ("noblue.bin", noblue),
        ("noblue_skipe67a.bin", skip),
        ("bootfix_skipe67a_fixed.bin", bootfix),
    ):
        length, header, code = checksums(fw)
        pos = CODE_START + length
        stored = (fw[pos] << 24) | (fw[pos + 1] << 16) | (fw[pos + 2] << 8) | fw[pos + 3]
        print(
            f"{name}: length=0x{length:04X} header=0x{header:04X} "
            f"code=0x{code:04X} stored@{pos:03X}={stored:08X}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
