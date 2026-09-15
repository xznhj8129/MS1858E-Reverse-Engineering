"""Flash a 2048-byte EEPROM image over I2C, then verify. MicroPython / Pico.

Wiring: Pico GP2 = SDA, GP3 = SCL, GND. 24C16 banks 0x50–0x57.

1. Copy this script AND the .bin onto the Pico filesystem.
2. Set FILENAME below (stock.bin / noblue.bin / noblue_skipe67a.bin).
3. Run. Bytewise write + 5 ms delay (24C16 write cycle).
4. Power-cycle the converter so the MS1858E reloads the overlay.

If verify fails, the SoC is probably driving I2C — reset MS1858E / WP=GND.
"""
from machine import Pin, I2C
import time

i2c = I2C(1, scl=Pin(3), sda=Pin(2), freq=100_000)
BASE = 0x50

# Image sitting next to this script on the Pico:
FILENAME = "noblue_skipe67a.bin"

print("Opening", FILENAME)
try:
    with open(FILENAME, "rb") as f:
        data = f.read()

    if len(data) != 2048:
        print("WARNING: file is", len(data), "bytes; expected 2048")

    print("Writing (~10 s)...")
    for i in range(len(data)):
        bank = i // 256
        offset = i % 256
        i2c.writeto_mem(BASE + bank, offset, bytes([data[i]]))
        time.sleep_ms(5)
        if offset == 0:
            print("bank", hex(BASE + bank))

    print("Verifying...")
    ok = True
    for i in range(len(data)):
        bank = i // 256
        offset = i % 256
        got = i2c.readfrom_mem(BASE + bank, offset, 1)[0]
        if got != data[i]:
            print("mismatch @", hex(i), "got", hex(got), "want", hex(data[i]))
            ok = False
            break

    print("OK — power-cycle the converter" if ok else "VERIFY FAILED")
except Exception as e:
    print("I2C error:", e)
