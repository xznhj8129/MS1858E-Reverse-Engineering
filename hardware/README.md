# Hardware connection

## Photo

Put a picture of the soldered EEPROM + Pico wiring in:

**`hardware/photos/wiring.jpg`**

The root README embeds it as:

```markdown
![EEPROM wiring](hardware/photos/wiring.jpg)
```

Useful to show in the photo:

- 24C16 package and pin 1
- Wires on **SDA / SCL / GND** (and VCC if the Pico powers the EEPROM)
- Pico GP2 = SDA, GP3 = SCL
- Whether the converter is powered or held in reset

## 24C16 pins (typical SOIC-8)

| Pin | Name | Hookup |
|-----|------|--------|
| 1–3 | A0–A2 | usually GND → I²C base `0x50` |
| 4 | GND | Pico GND |
| 5 | SDA | Pico GP2 |
| 6 | SCL | Pico GP3 |
| 7 | WP | GND to allow writes |
| 8 | VCC | 3.3 V |

The MS1858E is also on this bus in master mode. If I²C transactions fail or verify mismatches, the SoC is driving the bus — reset the MS1858E or power only the EEPROM.

## After flash

Power-cycle the converter. The internal MCU reloads the EEPROM at boot. Check HDMI: `noblue` should snow on no CVBS instead of a solid blue screen.
