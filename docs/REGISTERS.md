# Registers

There is **no public register datasheet**. Everything below is from the EEPROM overlay (`MOV DPTR,#imm` / `MOVX`) plus live HDMI tests.

Confidence:

- **confirmed** — encoded in instructions and/or proven on hardware
- **likely** — consistent with code + behaviour, no datasheet
- **guess** — unverified; random writes can brick analog/HDMI

These are **8051 XDATA** addresses (16-bit), not EEPROM offsets.

---

## Confirmed

| Address | Overlay access | Meaning |
|---------|----------------|---------|
| **E1F4** | R/W | Detected CVBS standard. `0–6` = lock, `≥7` or `0xFF` = no/bad sync. Change vs `EC00` calls `E67A(0x11)`. Hook `012D` may write `0xFF` if `EC01`. **Leave `E1F4 ≥ 7` on loss for ADC snow.** Forcing a valid standard here **blanks** the TVD (no snow). |
| **EC00** | R/W | Overlay RAM: previous `E1F4` |
| **EC01** | R/W | Software no-signal flag. `1` → path to ROM `E4FF`. Set by `02FD`, cleared on reinit / `032B` |
| **F026** | W | On a good path, written `0x11` — video enable / not muted |
| **F8B9** | W | `012D` writes `1` on no-signal. `noblue` writes `0`: blue latch off (black + OSD instead of blue) |
| **F270** | W | Scaler timing. `0x16` when `E1F4 ∈ {2,4,6}` (PAL-ish), `0x02` otherwise. If `E21A ≠ 0`, then `−2`. **Snow needs `0x16` left in the PAL immediate (`EEPROM[0xC2]`). Forcing `0x02` kills snow.** |
| **F271** | W | Always `0x78`, then maybe `−2` if `E21A ≠ 0` |
| **F272** | W | Copy of `EC06` (per-standard parameter) |

### `E1F4` vs `F270` (overlay math, confirmed)

`F270 = 0x16` iff standard is **2, 4, or 6**; else `0x02`.

Then a switch on original `E1F4` fills `EC06` / `F272` (values depend on `E21A`):

| E1F4 | F270 | EC06 if E21A≠0 / =0 |
|------|------|---------------------|
| 1 | `02` | `75` / `AB` |
| 2 | `16` | `58` / `80` |
| 3 | `02` | `42` / `5F` |
| 4, 6 | `16` | `42` / `5F` |

On **no lock**, if `E1F4` stays in `{2,4,6}` (last PAL or decoder default), snow uses **`F270=0x16`**. Patching that immediate to `0x02` (`noblue_ntsc`) **removed snow** on a PAL FPV setup.

---

## Likely (hardware), role inferred

| Address | R/W | Hypothesis |
|---------|-----|------------|
| `E1CE`,`E1CD` | R | 16-bit line/period. Compared to **`0x983A`** (after `SETB C`): below → `F1A0 \|= 0x60`, else `\|= 0x20`. PAL vs NTSC timing bit |
| `F1A0` | RMW | Output mode. Low nibble kept; bits 5–6 from `E1CE/CD` |
| `F24D` | R | Scaler/HDMI state. Overlay requires `(val & 7) == 6`, else `LJMP E4ED` |
| `E21A` | R | If ≠0, `F270` and `F271` decremented by 2 (50/60 or overscan) |
| `E2EA` | W | `032B` writes `1` when signal returns — unblank |
| `E2AE` | W | `0x10` scaler init |
| `E2A7` | W | `0x30` |
| `E2AA`/`AB` | W | `00 24` |
| `E2A8`/`A9` | W | `00 20` |
| `E2B6`/`B7` | W | `00 22` |
| `E2B2`/`B3` | W | `00 41` |
| `E2B0`/`B1` | W | `00 3F` |
| `F212`/`F213` | R | HDMI/HPD counter or state; `01CC` walks ~`0x20–0x24` and nudges `F08D` |
| `F08C`,`F08D`,`F08E` | R/W | HDMI PHY-ish; `02BA` / `01CC` |
| `F081`,`F082` | R/W | Init `0x3F`; `02DD` uses `F082` as a delay counter |
| `F2D6` | W | Pulse `1` then `0` — kick `021E` state machine |
| `F2D9` | R | Busy: wait until `(val & 0x3F) == 0` |
| `EC03`–`EC06` | R/W | Overlay scratch (`021E` args, loop count, `F272` source) |

Window `E2A7–E2B7` looks 1080p-ish (blanking/active). **Likely.**

---

## Address-space guess (family: MS2109-style)

| Range | Confidence | Block |
|-------|------------|--------|
| `E1xx` | likely | Analog TV decoder (standard, H-period). **AGC/slicer not in overlay** |
| `E2xx` | likely | Scaler / output window / unblank |
| `F0xx` | likely | HDMI TX (`F08x`, `F026`) |
| `F1xx` | likely | Output format (`F1A0`) |
| `F2xx` | likely | Scaler state (`F24D`, `F270`, `F212`, `F2D6`) |
| `F8xx` | likely | Pattern/blue latch (`F8B9`) |
| `ECxx` | **confirmed** | Overlay XRAM, not a silicon IP |

Do **not** inject “MS2109 AGC/HSync” values into `E1xx`. That map is not verified on MS1858E.

---

## Mask ROM entry points

| Address | How called | Confidence | Role |
|---------|------------|------------|------|
| **E4FF** | `LJMP` from `008B`, `00A1` | **confirmed** | Blue fill / no-signal path. NOP → snow |
| **E4ED** | `LJMP` from `0098` if `F24D&7 ≠ 6` | likely | Other blank/wait |
| **E67A** | `LCALL`, `R7` = command | **confirmed** for `0x11` and `0xCC` | `R7=0x11` video reinit (needed for fast FPV recover). `R7=0xCC` “No Signal” OSD. `0x88` weaker OSD (**likely**). `0x77` hide OSD (**likely**) |
| **E6BD** | `LCALL` in hook `0043` | likely | Apply/commit video |
| **E6F7** | `LCALL`, result in `A` | **confirmed** as a quality number | Thresholds `9 / 0x11 / 0x20` — **not** AGC |
| **E654** | `LCALL` at `02FD` | likely | Enter no-signal / OSD |
| **E5DE** | `LCALL` 1, 0, 1 | likely | Mute/OSD layer toggle. `noblue` still calls this and **still snows** |
| **E701** | `LCALL`, `R7=0x1E` or `0x32` | likely | Delay |
| **E6D6** | `LJMP` from `0040` | **confirmed** | ROM boot continue |
| **E547** | `LJMP` from C_STARTUP | **confirmed** | ROM main |
| **E70F** | `LJMP` | **confirmed** | Keil exit |
| **E58C / E69D** | `021E` | guess | Retry variants |
| **E61A / E6EB / E403** | `0316` on `R7` | guess | Event dispatcher |
| **1E48** | `LCALL` from `0341` | guess | OSD/string helper |

---

## Header bytes that are *not* XDATA

See [EEPROM.md](EEPROM.md). Overlay **does not program AGC or H/V slicer thresholds**. Those live in mask ROM, possibly fed by header `0x28` / `0x2E` / `0x32` (**guess / likely**).
