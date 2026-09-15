# EEPROM layout

24C16, 2048 bytes. Used range **`0x0000–0x0353`** on stock (overlay may grow if `length` is increased). Rest is `0xFF`.

EEPROM offset **equals** 8051 CODE PC for the overlay.

## Header

| Offset | Stock | Confidence | Meaning |
|--------|-------|------------|---------|
| `00–09` | `MSES8858SE` | **confirmed** | Magic; ROM probes this first |
| `0A–0B` | `03 10` | **confirmed** | Overlay length, big-endian (`0x0310` = 784 bytes) → code at `0x40 … 0x34F` |
| `0C` | `A0` | **confirmed** | 24Cxx I²C write address |
| `0D` | `00` | guess | Padding |
| `0E–0F` | `0E D0` | guess | ROM symbol / version |
| `10–11` | `50 00` | likely | Hook flags (bit4 + bit6), similar to MS2107 CommonFlags |
| `12–21` | four `69 xx 00 yy` | likely | GPIO table (`cmd, pin, 0, state`): `69 8D 00 00`, `69 74 00 00`, `69 8D 00 00`, `69 64 00 01` |
| `22–25` | `02 02 00 00` | likely | I/O / output mode |
| `26–27` | `15 09` | guess | Timing / VIC-ish pair |
| `28` | `E1` | guess | Analog/AGC related; **not** verified |
| `29–2C` | `32 32 32 32` | likely | BSCH (brightness, saturation, contrast, hue), 0–100, default 50 |
| `2D` | `00` | | |
| `2E` | `FA` | likely | Timeout before ROM treats input as gone (~250) |
| `2F` | `00` | | |
| `30` | `01` | likely | OSD / no-signal screen enable |
| `31` | `00` | | |
| `32` | `5F` | likely | Lock debounce (~95 frames) |
| `33–3F` | `FF` | **confirmed** | Pad; bytes `33–35` **are** in the header checksum |

## Code and checksums

| Offset | Stock | Meaning |
|--------|-------|---------|
| `40–34F` | 8051 overlay | Length from `0A–0B` |
| `350–351` | `0B 9A` | Header checksum |
| `352–353` | `A3 4C` | Code checksum |
| `354–7FF` | `FF` | Unused |

### Algorithm (**confirmed**, matches stock 1:1)

```
header_csum = sum(eeprom[0x0A : 0x36]) & 0xFFFF   # stored BE at 0x40+length
code_csum   = sum(eeprom[0x40 : 0x40+length]) & 0xFFFF
```

Stock: header `0x0B9A`, code `0xA34C`.

If you change `length`, checksums move to `0x40 + length`. ROM ignores a bad overlay.

## Boot I²C (`docs/i2c_boot_capture.txt`)

The capture logs **8-bit EEPROM offsets only** (no bank). Bank increments when the offset wraps `0xFF → 0x00`.

Order:

1. `0x00–0x0C` magic + length + `0xA0`
2. Jump to `addr=0x50` which is **bank 3** → absolute **`0x350–0x353`** (checksums)
3. Sequential `0x0D … 0x34F`

## Banks

| I²C | Range | Stock contents |
|-----|-------|----------------|
| `0x50` | `000–0FF` | Header + overlay start |
| `0x51` | `100–1FF` | Overlay |
| `0x52` | `200–2FF` | Overlay |
| `0x53` | `300–3FF` | Overlay end + checksums |
| `0x54–0x57` | `400–7FF` | `FF` |
