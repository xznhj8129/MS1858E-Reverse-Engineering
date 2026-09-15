# 8051 overlay

PC = EEPROM offset. Linked with Keil C51 from `0x0000`. Mask ROM at `0xE4xx–0xE7xx` and `0x1E48`.

Full listing: [`overlay_disasm.asm`](overlay_disasm.asm).  
`017F–0189` and `034A–034F` are **data**, not real code (bit masks / Keil tail).

## Hooks ROM calls

| Address | Confidence | Role |
|---------|------------|------|
| `0040` | confirmed | `LJMP 0xE6D6` boot trampoline — do not remove |
| `0043` | confirmed | Periodic video hook (standard, HDMI, blue) |
| `012D` | confirmed | No-signal: `F8B9=1`, optionally `E1F4=FF` |
| `0140` | confirmed | Keil C_STARTUP: clear IRAM, `SP=7`, `LJMP E547` |
| `014C` | confirmed | `LJMP E70F` |
| `014F` | confirmed | Keil `?C_INIT` |
| `01CC` | likely | HDMI/HPD loop on `F212` vs `0x20–0x24` |
| `021E` | likely | Retry until `F24D&7==6` |
| `025A` | confirmed writes | Scaler window init |
| `0294` | confirmed | Quality `E6F7` → `E67A(R7)` OSD |
| `02BA` | likely | HDMI PHY `F08x`, `LJMP E701` |
| `02DD` | likely | Delay on `F082` |
| `02FD` | confirmed | Enter no-signal |
| `0316` | likely | `R7` dispatcher → ROM |
| `032B` | confirmed | Exit no-signal: `E2EA=1`, `EC01=0` |
| `0337` | confirmed as code | `F213 − F212` |
| `0341` | likely | `EC05=R7`, `LCALL 0x1E48` |

## Hook `0043` (stock)

```
F1A0 = (F1A0 & 0x0F) | 0x20  or | 0x60
       depending on (E1CE:E1CD) < 0x983A

if E1F4 != EC00:
    E67A(0x11)          # scaler/mode reinit — fast FPV recover
    EC01 = 0
    EC00 = E1F4

if E1F4 >= 7:     LJMP E4FF      # ROM blue fill
if (F24D & 7) != 6: LJMP E4ED
if EC01 != 0:     LJMP E4FF

E6BD()
F026 = 0x11
# F270/F271/F272 from E1F4 and E21A
RET
```

**Snow vs shapes (live tests):**

- `E1F4 >= 7` and **do not** call `E4FF` → unlocked ADC → **snow** (`noblue`)
- Write last PAL/NTSC into `E1F4` → TVD thinks it is locked → **blank, no snow**
- Skipping `E67A(0x11)` only while `E1F4 >= 7` → less scaler reset on flickering lock (`noblue_skipe67a`), snow kept

## Hook `0294` — OSD from quality (not AGC)

```
A = E6F7()
if A < 0x09:    E67A(0xCC)    # "No Signal"  (weak FPV often lands here)
elif A < 0x11:  E67A(0x88)
elif A >= 0x20: E67A(0x77)    # hide OSD
else: nop
```

## `02FD` / `012D` / `032B`

```
02FD: E654(); E5DE(1); E5DE(0); E5DE(1); EC01 = 1
012D: F8B9 = 1; if EC01: E1F4 = 0xFF
032B: E2EA = 1; EC01 = 0
```

## Scaler window at `025A` (values confirmed)

```
E2AE=10  E2A7=30
E2AA=00  E2AB=24
E2A8=00  E2A9=20
E2B6=00  E2B7=22
E2B2=00  E2B3=41
E2B0=00  E2B1=3F
```
