# Firmware images (24C16, 2048 bytes)

| File | Status | Notes |
|------|--------|--------|
| `stock.bin` | original dump | checksums `0x0B9A` / `0xA34C` |
| `noblue.bin` | **tested, recommended** | no blue fill → ADC snow; works with VTX off at boot; no blue on drop/re-lock; ROM OSD text remains |
| `noblue_skipe67a.bin` | **did not reproduce** | original skip attempt; on the 2026-11-08 board: ~1 s snow, then blue + OSD |
| `bootfix_skipe67a_fixed.bin` | **experimental** | boot-with-VTX-on handling only. Blue-screens if booted with VTX off; not recommended for VTX-off boot |

Rebuild from stock:

```bash
python3 tools/build_patches.py firmware/stock.bin
```

See [docs/PATCHES.md](../docs/PATCHES.md).
