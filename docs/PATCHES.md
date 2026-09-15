# Patches

Rebuild from stock with `python3 tools/build_patches.py firmware/stock.bin`.

Always recompute checksums (see [EEPROM.md](EEPROM.md)). Header checksum only changes if you touch `0x0A–0x35`.

---

## `noblue.bin` — tested, keep this as baseline

Code checksum `0x9FA0`. Header unchanged (`0x0B9A`). `F270` PAL immediate **stays `0x16`**.

| Offset | Stock | Patch | Effect |
|--------|-------|-------|--------|
| `008B` | `02 E4 FF` (`LJMP E4FF`) | `00 00 00` | No ROM blue fill → ADC snow |
| `00A1` | `02 E4 FF` | `00 00 00` | Same when `EC01` |
| `0131` | `01` (`F8B9=1`) | `00` | Blue latch off |
| `0137` | `60` (`JZ` → maybe `E1F4=FF`) | `80` (`SJMP`) | Never poison standard |
| `0313` | `01` (`EC01=1`) | `00` | Overlay does not raise no-signal flag |

Still runs `E67A(0x11)` on every `E1F4` change (including lock→unlock) and still calls `E654`/`E5DE` in `02FD`. Fast recover, snow on silence.

---

## `noblue_skipe67a.bin` — tested (noblue + one extra)

Same five `noblue` bytes, plus:

When `E1F4` **changes to `≥ 7`**, do **not** `E67A(0x11)`. Set `EC00=0xFF` so a later valid lock still looks like a change and reinit runs.

Implementation: `0070` `LJMP 0x0350` cave; overlay length `0x0310` → `0x0327`; checksums at `0x367`.

```
; 0070: LJMP 0x0350   (R7 still holds the new E1F4)
0350: MOV  A,R7
      CLR  C
      SUBB A,#0x07
      JNC  unlock          ; E1F4 >= 7
      MOV  R7,#0x11
      LCALL E67A
      LJMP 0x0075          ; stock: EC01=0, EC00=E1F4
unlock:
      MOV  DPTR,#EC00
      MOV  A,#0xFF
      MOVX @DPTR,A
      LJMP 0x0082          ; skip reinit; next insn is E1F4>=7 snow path
```

Does **not** change `F270`, does not fake `E1F4`, does not `RET` `02FD`.

---

## Tried and rejected (do not ship)

| Experiment | Idea | Result |
|------------|------|--------|
| Force `E1F4` to last PAL/NTSC | “freerun / snow mode” | **No snow** — TVD blanks |
| `0x00C2`: `16→02` (hard NTSC `F270`) | Gemini “NTSC freerun” | **No snow** — PAL snow path needs `0x16` |
| Skip `E67A` **and** fake `E1F4` / `RET 02FD` (`nons.bin`) | Hold picture | Slow or no recover |
| Random `E1xx` AGC/slicer writes | MS2109 folklore | **Not tested; no map** |

### Rules from hardware

1. Do not put a valid standard in `E1F4` if you want snow.
2. Do not NOP `E67A(0x11)` on **relock** if you want fast FPV recover.
3. Do not change EEPROM `0xC2` (`MOV A,#0x16`) if you want PAL snow.
4. Skip `E67A` only for **unlock** (`E1F4≥7`) if you want less scaler thrash on weak sync.
