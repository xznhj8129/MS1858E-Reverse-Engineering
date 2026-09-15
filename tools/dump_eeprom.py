"""Dump the on-board 24C16 (2 KB) over I2C. MicroPython on Raspberry Pi Pico.

Wiring (see hardware/README.md):
  Pico GP2 = SDA, GP3 = SCL, GND common.
  24C16 banks 0x50–0x57.

Copy this file to the Pico and run it. Output: ms1858e_eeprom_backup.bin
on the Pico filesystem (then copy it off with Thonny / mpremote).

If the MS1858E is mastering the bus, hold it in reset or power only the EEPROM.
"""
from machine import Pin, I2C

i2c = I2C(1, scl=Pin(3), sda=Pin(2), freq=100_000)

BASE = 0x50
BANKS = 8
CHUNK = 64
FILENAME = "ms1858e_eeprom_backup.bin"

print("Dumping 2048 bytes to", FILENAME)
try:
    with open(FILENAME, "wb") as f:
        for bank in range(BANKS):
            addr = BASE + bank
            print("--- bank", hex(addr), "---")
            for offset in range(0, 256, CHUNK):
                data = i2c.readfrom_mem(addr, offset, CHUNK)
                f.write(data)
                g = bank * 256 + offset
                print("0x%04X:" % g, " ".join("%02X" % b for b in data))
    print("OK", FILENAME)
except Exception as e:
    print("I2C read failed:", e)
