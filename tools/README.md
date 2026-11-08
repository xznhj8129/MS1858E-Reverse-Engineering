# Tools

## Pico (MicroPython)

Copy onto the Pico filesystem with Thonny or `mpremote fs cp`:

| File | What it does |
|------|----------------|
| `dump_eeprom.py` | Read 2048 B → `ms1858e_eeprom_backup.bin` |
| `flash_eeprom.py` | Write + verify a 2048 B image |

Also copy the image you want to flash (`firmware/noblue_skipe67a.bin` renamed or as-is; set `FILENAME` in `flash_eeprom.py`).

I²C: **GP2 = SDA, GP3 = SCL**, 100 kHz, banks `0x50`–`0x57`. Writes are **one byte + 5 ms** (24C16 page/write cycle).

The MS1858E must **not** own the bus while you dump/flash. Solder onto the EEPROM, hold the SoC in reset, or power the EEPROM from the Pico only.

After a successful verify, **power-cycle** the converter.

## Host (CPython)

```bash
python3 tools/build_patches.py firmware/stock.bin
```

Rebuilds `noblue.bin`, `noblue_skipe67a.bin` and
`bootfix_skipe67a_fixed.bin` and prints checksums.

Expected:

| Image | length | header | code |
|-------|--------|--------|------|
| stock | `0x0310` | `0x0B9A` | `0xA34C` |
| noblue | `0x0310` | `0x0B9A` | `0x9FA0` |
| noblue_skipe67a | `0x0327` | `0x0BB1` | `0xA8D4` |
| bootfix_skipe67a_fixed | `0x0370` | `0x0BFA` | `0xE5A3` |
