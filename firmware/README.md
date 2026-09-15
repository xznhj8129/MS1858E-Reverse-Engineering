# Firmware images (24C16, 2048 bytes)

| File | Status | Notes |
|------|--------|--------|
| `stock.bin` | original dump | checksums `0x0B9A` / `0xA34C` |
| `noblue.bin` | **tested** | no blue fill → ADC snow; fast FPV recover |
| `noblue_skipe67a.bin` | **tested** | noblue + skip `E67A(0x11)` on unlock only |

Rebuild from stock:

```bash
python3 tools/build_patches.py firmware/stock.bin
```

See [docs/PATCHES.md](../docs/PATCHES.md).
