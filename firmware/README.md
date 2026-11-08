# Firmware images (24C16, 2048 bytes)

| File | Status | Notes |
|------|--------|--------|
| `stock.bin` | original dump | checksums `0x0B9A` / `0xA34C` |
| `noblue.bin` | **tested** | no blue fill → ADC snow; fast FPV recover; ROM OSD text remains |
| `noblue_skipe67a.bin` | **did not reproduce** | original skip attempt; on the 2026-11-08 board: ~1 s snow, then blue + OSD |
| `bootfix_skipe67a_fixed.bin` | **tested, recommended** | noblue + boot-with-signal fix + corrected skip on unlock; checksums `0x0BFA` / `0xE5A3` |

Rebuild from stock:

```bash
python3 tools/build_patches.py firmware/stock.bin
```

See [docs/PATCHES.md](../docs/PATCHES.md).
