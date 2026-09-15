; MS1858E EEPROM overlay — stock dump (firmware/stock.bin)
;
; PC = EEPROM offset = 8051 CODE address (Keil C51, linked at 0x0000).
; LCALL/LJMP 0xE4xx–0xE7xx and 0x1E48 are mask ROM.
; XDATA ECxx = overlay RAM. See REGISTERS.md / OVERLAY.md / PATCHES.md.
;
; Confidence in comments:
;   [confirmed]  in the opcodes and/or live HDMI test
;   [likely]     consistent, no datasheet
;   [guess]      unverified
;
; 017F–0189 and 034A–034F are DATA, disassembled as code by mistake.

; =============================================================================
; 0040  boot trampoline — ROM vector, do not remove          [confirmed]
; =============================================================================
0040: 02 E6 D6      LJMP 0xE6D6           ; continue mask-ROM boot

; =============================================================================
; 0043  periodic video hook (ROM calls this)                 [confirmed]
;   F1A0 bits from TVD period, reinit on E1F4 change,
;   blue-fill if unlocked, then scaler timing F270/F271/F272.
; =============================================================================
0043: 90 F1 A0      MOV DPTR,#0xF1A0      ; HDMI/output mode
0046: E0            MOVX A,@DPTR
0047: 54 0F         ANL A,#0x0F           ; keep low nibble
0049: FF            MOV R7,A
004A: D3            SETB C                ; 16-bit compare uses C as extra borrow
004B: 90 E1 CE      MOV DPTR,#0xE1CE      ; TVD period high                 [likely]
004E: E0            MOVX A,@DPTR
004F: 94 98         SUBB A,#0x98          ; compare (E1CE:E1CD) vs 0x983A
0051: 90 E1 CD      MOV DPTR,#0xE1CD      ; TVD period low                  [likely]
0054: E0            MOVX A,@DPTR
0055: 94 3A         SUBB A,#0x3A
0057: EF            MOV A,R7
0058: 40 04         JC 0x005E             ; period < 0x983A ?
005A: 44 20         ORL A,#0x20           ; no  → F1A0 |= 0x20
005C: 80 02         SJMP 0x0060
005E: 44 60         ORL A,#0x60           ; yes → F1A0 |= 0x60 (PAL-ish)   [likely]
0060: 90 F1 A0      MOV DPTR,#0xF1A0
0063: F0            MOVX @DPTR,A

; --- standard change → scaler reinit -----------------------------------------
0064: 90 E1 F4      MOV DPTR,#0xE1F4      ; detected CVBS standard          [confirmed]
0067: E0            MOVX A,@DPTR          ; 0–6 = lock, >=7 / FF = no sync
0068: FF            MOV R7,A
0069: 90 EC 00      MOV DPTR,#0xEC00      ; previous E1F4
006C: E0            MOVX A,@DPTR
006D: 6F            XRL A,R7
006E: 60 12         JZ 0x0082             ; unchanged → skip reinit
0070: 7F 11         MOV R7,#0x11          ; noblue_skipe67a: LJMP cave 0350
0072: 12 E6 7A      LCALL 0xE67A          ; ROM cmd 0x11 = video reinit     [confirmed]
0075: E4            CLR A
0076: 90 EC 01      MOV DPTR,#0xEC01      ; software no-signal flag
0079: F0            MOVX @DPTR,A          ; EC01 = 0
007A: 90 E1 F4      MOV DPTR,#0xE1F4
007D: E0            MOVX A,@DPTR
007E: 90 EC 00      MOV DPTR,#0xEC00
0081: F0            MOVX @DPTR,A          ; EC00 = current E1F4

; --- lock / scaler-ready checks ----------------------------------------------
0082: 90 E1 F4      MOV DPTR,#0xE1F4
0085: E0            MOVX A,@DPTR
0086: C3            CLR C
0087: 94 07         SUBB A,#0x07
0089: 40 03         JC 0x008E             ; E1F4 < 7 → locked, continue
008B: 02 E4 FF      LJMP 0xE4FF           ; ROM blue fill  [noblue: NOP NOP NOP]

008E: 90 F2 4D      MOV DPTR,#0xF24D      ; scaler/HDMI state               [likely]
0091: E0            MOVX A,@DPTR
0092: 54 07         ANL A,#0x07
0094: 64 06         XRL A,#0x06
0096: 60 03         JZ 0x009B             ; (F24D & 7) == 6 → ready
0098: 02 E4 ED      LJMP 0xE4ED           ; other blank/wait                [likely]

009B: 90 EC 01      MOV DPTR,#0xEC01
009E: E0            MOVX A,@DPTR
009F: 60 03         JZ 0x00A4             ; EC01 == 0 → show video
00A1: 02 E4 FF      LJMP 0xE4FF           ; software no-signal → blue
                                          ; [noblue: NOP NOP NOP]

; --- commit video + scaler timing --------------------------------------------
00A4: 12 E6 BD      LCALL 0xE6BD          ; apply/commit video              [likely]
00A7: 90 F0 26      MOV DPTR,#0xF026      ; video enable                    [confirmed]
00AA: 74 11         MOV A,#0x11
00AC: F0            MOVX @DPTR,A          ; F026 = 0x11 (unmuted)

; F270 = 0x16 if E1F4 in {2,4,6} (PAL-ish), else 0x02 (NTSC-ish)  [confirmed]
; Trickle ADD: A-4==0 → 4; A-6==0 → 6; A-2==0 → 2; else NTSC.
; Live test: do NOT patch the 0x16 immediate (EEPROM 0xC2) or PAL snow dies.
00AD: 90 E1 F4      MOV DPTR,#0xE1F4
00B0: E0            MOVX A,@DPTR
00B1: FF            MOV R7,A              ; keep original standard
00B2: 24 FC         ADD A,#0xFC           ; A = E1F4 - 4
00B4: 60 08         JZ 0x00BE             ; standard 4
00B6: 24 FE         ADD A,#0xFE           ; A = E1F4 - 6
00B8: 60 04         JZ 0x00BE             ; standard 6
00BA: 24 04         ADD A,#0x04           ; A = E1F4 - 2
00BC: 70 08         JNZ 0x00C6            ; not 2,4,6 → F270 = 0x02
00BE: 90 F2 70      MOV DPTR,#0xF270
00C1: 74 16         MOV A,#0x16           ; PAL-ish timing (keep for snow)
00C3: F0            MOVX @DPTR,A
00C4: 80 06         SJMP 0x00CC
00C6: 90 F2 70      MOV DPTR,#0xF270
00C9: 74 02         MOV A,#0x02           ; NTSC-ish
00CB: F0            MOVX @DPTR,A

00CC: 90 F2 71      MOV DPTR,#0xF271
00CF: 74 78         MOV A,#0x78
00D1: F0            MOVX @DPTR,A          ; F271 = 0x78 always, then maybe -2
00D2: 90 E2 1A      MOV DPTR,#0xE21A      ; 50/60 or overscan flag          [likely]
00D5: E0            MOVX A,@DPTR
00D6: FE            MOV R6,A
00D7: 60 0C         JZ 0x00E5             ; E21A == 0 → skip decrement
00D9: 90 F2 70      MOV DPTR,#0xF270
00DC: E0            MOVX A,@DPTR
00DD: 24 FE         ADD A,#0xFE           ; F270 -= 2
00DF: F0            MOVX @DPTR,A
00E0: A3            INC DPTR              ; F271
00E1: E0            MOVX A,@DPTR
00E2: 24 FE         ADD A,#0xFE           ; F271 -= 2
00E4: F0            MOVX @DPTR,A

; switch(E1F4) → EC06 → F272
;   1 → 0x75 / 0xAB    2 → 0x58 / 0x80    3,4,6 → 0x42 / 0x5F
;   (first value if E21A != 0, second if E21A == 0)
00E5: EF            MOV A,R7              ; original E1F4
00E6: 14            DEC A
00E7: 60 1C         JZ 0x0105             ; E1F4 == 1
00E9: 14            DEC A
00EA: 60 0E         JZ 0x00FA             ; E1F4 == 2
00EC: 14            DEC A
00ED: 60 24         JZ 0x0113             ; E1F4 == 3
00EF: 14            DEC A
00F0: 60 21         JZ 0x0113             ; E1F4 == 4
00F2: 24 FE         ADD A,#0xFE
00F4: 60 1D         JZ 0x0113             ; E1F4 == 6
00F6: 24 06         ADD A,#0x06           ; restore; 0 falls into case 2
00F8: 70 2A         JNZ 0x0124            ; other (5,7,…) → keep old EC06

00FA: EE            MOV A,R6              ; case 2 (and E1F4==0 fallthrough)
00FB: 60 04         JZ 0x0101
00FD: 7F 58         MOV R7,#0x58          ; E21A != 0
00FF: 80 1E         SJMP 0x011F
0101: 7F 80         MOV R7,#0x80          ; E21A == 0
0103: 80 1A         SJMP 0x011F

0105: 90 E2 1A      MOV DPTR,#0xE21A      ; case 1
0108: E0            MOVX A,@DPTR
0109: 60 04         JZ 0x010F
010B: 7F 75         MOV R7,#0x75
010D: 80 02         SJMP 0x0111
010F: 7F AB         MOV R7,#0xAB
0111: 80 0C         SJMP 0x011F

0113: 90 E2 1A      MOV DPTR,#0xE21A      ; case 3 / 4 / 6
0116: E0            MOVX A,@DPTR
0117: 60 04         JZ 0x011D
0119: 7F 42         MOV R7,#0x42
011B: 80 02         SJMP 0x011F
011D: 7F 5F         MOV R7,#0x5F

011F: 90 EC 06      MOV DPTR,#0xEC06
0122: EF            MOV A,R7
0123: F0            MOVX @DPTR,A          ; EC06 = per-standard param
0124: 90 EC 06      MOV DPTR,#0xEC06
0127: E0            MOVX A,@DPTR
0128: 90 F2 72      MOV DPTR,#0xF272
012B: F0            MOVX @DPTR,A          ; F272 = EC06
012C: 22            RET

; =============================================================================
; 012D  no-signal hook                                       [confirmed]
;   F8B9=1 latches blue/pattern. If EC01 set, poison E1F4=FF
;   (TVD looks unlocked). noblue: F8B9=0 and SJMP over the poison.
; =============================================================================
012D: 90 F8 B9      MOV DPTR,#0xF8B9      ; blue / pattern latch
0130: 74 01         MOV A,#0x01           ; [noblue: 00]
0132: F0            MOVX @DPTR,A
0133: 90 EC 01      MOV DPTR,#0xEC01
0136: E0            MOVX A,@DPTR
0137: 60 06         JZ 0x013F             ; [noblue: 80 = SJMP, never poison]
0139: 90 E1 F4      MOV DPTR,#0xE1F4
013C: 74 FF         MOV A,#0xFF
013E: F0            MOVX @DPTR,A          ; E1F4 = 0xFF
013F: 22            RET

; =============================================================================
; 0140  Keil C_STARTUP                                       [confirmed]
; =============================================================================
0140: 78 7F         MOV R0,#0x7F          ; clear IRAM 0x7F → 0x00
0142: E4            CLR A
0143: F6            MOV @R0,A
0144: D8 FD         DJNZ R0,0x0143
0146: 75 81 07      MOV 0x81,#0x07        ; SP = 7
0149: 02 E5 47      LJMP 0xE547           ; ROM main

014C: 02 E7 0F      LJMP 0xE70F           ; Keil exit / end of ?C_INIT

; =============================================================================
; 014F  Keil ?C_INIT — copy packed init records from CODE    [confirmed]
;   Records at DPTR: type/len then payload → IRAM or XDATA.
; =============================================================================
014F: E4            CLR A                 ; byte-copy into IRAM (@R0) or XDATA
0150: 93            MOVC A,@A+DPTR
0151: A3            INC DPTR
0152: F8            MOV R0,A              ; dest
0153: E4            CLR A
0154: 93            MOVC A,@A+DPTR
0155: A3            INC DPTR
0156: 40 03         JC 0x015B             ; C set → MOVX, else MOV
0158: F6            MOV @R0,A
0159: 80 01         SJMP 0x015C
015B: F2            MOVX @R0,A
015C: 08            INC R0
015D: DF F4         DJNZ R7,0x0153
015F: 80 29         SJMP 0x018A           ; next record

0161: E4            CLR A                 ; bit-init using table @ 017F
0162: 93            MOVC A,@A+DPTR
0163: A3            INC DPTR
0164: F8            MOV R0,A
0165: 54 07         ANL A,#0x07
0167: 24 0C         ADD A,#0x0C           ; index 0–7 → PC+0x0C = 017F
0169: C8            XCH A,R0
016A: C3            CLR C
016B: 33            RLC A
016C: C4            SWAP A
016D: 54 0F         ANL A,#0x0F
016F: 44 20         ORL A,#0x20
0171: C8            XCH A,R0
0172: 83            MOVC A,@A+PC          ; bit mask 01,02,04,…,80
0173: 40 04         JC 0x0179
0175: F4            CPL A
0176: 56            ANL A,@R0             ; clear bit
0177: 80 01         SJMP 0x017A
0179: 46            ORL A,@R0             ; set bit
017A: F6            MOV @R0,A
017B: DF E4         DJNZ R7,0x0161
017D: 80 0B         SJMP 0x018A

; --- DATA: bit masks for MOVC @ 0172, not instructions ----------------------
017F: 01 02         AJMP 0x0002           ; DATA 01 02
0181: 04            INC A                 ; DATA 04
0182: 08            INC R0                ; DATA 08
0183: 10 20 40      JBC 0x20,0x01A6       ; DATA 10 20 40
0186: 80 90         SJMP 0x0118           ; DATA 80, then 90 E7 0A (init stream)
0188: E7            MOV A,@R1
0189: 0A            INC R2

018A: E4            CLR A                 ; ?C_INIT record loop
018B: 7E 01         MOV R6,#0x01
018D: 93            MOVC A,@A+DPTR
018E: 60 BC         JZ 0x014C             ; 0 terminator → LJMP E70F
0190: A3            INC DPTR
0191: FF            MOV R7,A              ; type/length byte
0192: 54 3F         ANL A,#0x3F
0194: 30 E5 09      JNB ACC.5,0x01A0      ; ACC.5 selects long vs short
0197: 54 1F         ANL A,#0x1F
0199: FE            MOV R6,A
019A: E4            CLR A
019B: 93            MOVC A,@A+DPTR
019C: A3            INC DPTR
019D: 60 01         JZ 0x01A0
019F: 0E            INC R6
01A0: CF            XCH A,R7
01A1: 54 C0         ANL A,#0xC0           ; type in bits 7–6
01A3: 25 E0         ADD A,ACC             ; dispatch: 00=byte, 40=bit, 80=word
01A5: 60 A8         JZ 0x014F             ; type 0 → byte copy
01A7: 40 B8         JC 0x0161             ; type 1 → bit init
01A9: E4            CLR A                 ; type 2 → XDATA word fill
01AA: 93            MOVC A,@A+DPTR
01AB: A3            INC DPTR
01AC: FA            MOV R2,A
01AD: E4            CLR A
01AE: 93            MOVC A,@A+DPTR
01AF: A3            INC DPTR
01B0: F8            MOV R0,A
01B1: E4            CLR A
01B2: 93            MOVC A,@A+DPTR
01B3: A3            INC DPTR
01B4: C8            XCH A,R0              ; DPTR = dest from stream
01B5: C5 82         XCH A,DPL
01B7: C8            XCH A,R0
01B8: CA            XCH A,R2
01B9: C5 83         XCH A,DPH
01BB: CA            XCH A,R2
01BC: F0            MOVX @DPTR,A
01BD: A3            INC DPTR
01BE: C8            XCH A,R0              ; restore DPTR to init stream
01BF: C5 82         XCH A,DPL
01C1: C8            XCH A,R0
01C2: CA            XCH A,R2
01C3: C5 83         XCH A,DPH
01C5: CA            XCH A,R2
01C6: DF E9         DJNZ R7,0x01B1
01C8: DE E7         DJNZ R6,0x01B1
01CA: 80 BE         SJMP 0x018A           ; next record

; =============================================================================
; 01CC  HDMI / HPD loop on F212                              [likely]
;   If F212 in ~0x20–0x24: latch F08D → F08C and return.
;   If F212 < 0x20: decrement F08D (floor 0) with E701(0x1E) delay.
;   If F212 > 0x24: increment F08D toward 0x1F, same delay.
; =============================================================================
01CC: 90 F2 12      MOV DPTR,#0xF212      ; HDMI/HPD counter or state
01CF: E0            MOVX A,@DPTR
01D0: FF            MOV R7,A
01D1: C3            CLR C
01D2: 94 20         SUBB A,#0x20
01D4: 40 06         JC 0x01DC             ; F212 < 0x20 → not in window
01D6: EF            MOV A,R7
01D7: D3            SETB C
01D8: 94 24         SUBB A,#0x24          ; C=1 → compare vs 0x25
01DA: 40 39         JC 0x0215             ; 0x20 <= F212 <= 0x24 → done

01DC: EF            MOV A,R7              ; outside window
01DD: C3            CLR C
01DE: 94 22         SUBB A,#0x22
01E0: 50 18         JNC 0x01FA            ; F212 >= 0x22 → increment F08D

01E2: 90 F2 12      MOV DPTR,#0xF212      ; wait until F212 >= 0x22
01E5: E0            MOVX A,@DPTR
01E6: C3            CLR C
01E7: 94 22         SUBB A,#0x22
01E9: 50 E1         JNC 0x01CC
01EB: 90 F0 8D      MOV DPTR,#0xF08D      ; HDMI PHY-ish
01EE: E0            MOVX A,@DPTR
01EF: 60 DB         JZ 0x01CC             ; already 0
01F1: 14            DEC A
01F2: F0            MOVX @DPTR,A          ; F08D--
01F3: 7F 1E         MOV R7,#0x1E
01F5: 12 E7 01      LCALL 0xE701          ; ROM delay                     [likely]
01F8: 80 E8         SJMP 0x01E2

01FA: 90 F2 12      MOV DPTR,#0xF212      ; increment path
01FD: E0            MOVX A,@DPTR
01FE: D3            SETB C
01FF: 94 22         SUBB A,#0x22
0201: 40 C9         JC 0x01CC             ; dropped below window
0203: 90 F0 8D      MOV DPTR,#0xF08D
0206: E0            MOVX A,@DPTR
0207: 64 1F         XRL A,#0x1F
0209: 60 C1         JZ 0x01CC             ; already 0x1F
020B: E0            MOVX A,@DPTR
020C: 04            INC A
020D: F0            MOVX @DPTR,A          ; F08D++
020E: 7F 1E         MOV R7,#0x1E
0210: 12 E7 01      LCALL 0xE701
0213: 80 E5         SJMP 0x01FA

0215: 90 F0 8D      MOV DPTR,#0xF08D      ; in window: latch
0218: E0            MOVX A,@DPTR
0219: 90 F0 8C      MOV DPTR,#0xF08C
021C: F0            MOVX @DPTR,A          ; F08C = F08D
021D: 22            RET

; =============================================================================
; 021E  retry until scaler ready                             [likely]
;   Pulse F2D6, ROM helper from EC03, up to 3 tries or until
;   (F2D9 & 0x3F)==0 and (F24D & 7)==6.
; =============================================================================
021E: 90 EC 03      MOV DPTR,#0xEC03
0221: EF            MOV A,R7
0222: F0            MOVX @DPTR,A          ; EC03 = arg (selects ROM helper)
0223: E4            CLR A
0224: A3            INC DPTR
0225: F0            MOVX @DPTR,A          ; EC04 = 0 (try counter)
0226: 90 F2 D6      MOV DPTR,#0xF2D6
0229: 74 01         MOV A,#0x01
022B: F0            MOVX @DPTR,A
022C: E4            CLR A
022D: F0            MOVX @DPTR,A          ; pulse F2D6 1 → 0
022E: 90 EC 03      MOV DPTR,#0xEC03
0231: E0            MOVX A,@DPTR
0232: 60 05         JZ 0x0239
0234: 12 E5 8C      LCALL 0xE58C          ; retry variant A                [guess]
0237: 80 03         SJMP 0x023C
0239: 12 E6 9D      LCALL 0xE69D          ; retry variant B                [guess]
023C: 90 EC 04      MOV DPTR,#0xEC04
023F: E0            MOVX A,@DPTR
0240: 04            INC A
0241: F0            MOVX @DPTR,A
0242: E0            MOVX A,@DPTR
0243: 64 03         XRL A,#0x03
0245: 60 12         JZ 0x0259             ; 3 tries → give up
0247: 90 F2 D9      MOV DPTR,#0xF2D9      ; busy flags
024A: E0            MOVX A,@DPTR
024B: 54 3F         ANL A,#0x3F
024D: 70 D7         JNZ 0x0226            ; still busy → pulse again
024F: 90 F2 4D      MOV DPTR,#0xF24D
0252: E0            MOVX A,@DPTR
0253: 54 07         ANL A,#0x07
0255: FF            MOV R7,A
0256: BF 06 CD      CJNE R7,#0x06,0x0226  ; not ready → retry
0259: 22            RET

; =============================================================================
; 025A  scaler output window                                 [values confirmed]
;   16-bit pairs look 1080p-ish (blanking / active).        [likely]
; =============================================================================
025A: 90 E2 AE      MOV DPTR,#0xE2AE
025D: 74 10         MOV A,#0x10
025F: F0            MOVX @DPTR,A          ; E2AE = 0x10
0260: 90 E2 A7      MOV DPTR,#0xE2A7
0263: 74 30         MOV A,#0x30
0265: F0            MOVX @DPTR,A          ; E2A7 = 0x30
0266: 90 E2 AA      MOV DPTR,#0xE2AA
0269: E4            CLR A
026A: F0            MOVX @DPTR,A          ; E2AA:AB = 0x0024
026B: A3            INC DPTR
026C: 74 24         MOV A,#0x24
026E: F0            MOVX @DPTR,A
026F: 90 E2 A8      MOV DPTR,#0xE2A8
0272: E4            CLR A
0273: F0            MOVX @DPTR,A          ; E2A8:A9 = 0x0020
0274: A3            INC DPTR
0275: 74 20         MOV A,#0x20
0277: F0            MOVX @DPTR,A
0278: 90 E2 B6      MOV DPTR,#0xE2B6
027B: E4            CLR A
027C: F0            MOVX @DPTR,A          ; E2B6:B7 = 0x0022
027D: A3            INC DPTR
027E: 74 22         MOV A,#0x22
0280: F0            MOVX @DPTR,A
0281: 90 E2 B2      MOV DPTR,#0xE2B2
0284: E4            CLR A
0285: F0            MOVX @DPTR,A          ; E2B2:B3 = 0x0041
0286: A3            INC DPTR
0287: 74 41         MOV A,#0x41
0289: F0            MOVX @DPTR,A
028A: 90 E2 B0      MOV DPTR,#0xE2B0
028D: E4            CLR A
028E: F0            MOVX @DPTR,A          ; E2B0:B1 = 0x003F
028F: A3            INC DPTR
0290: 74 3F         MOV A,#0x3F
0292: F0            MOVX @DPTR,A
0293: 22            RET

; =============================================================================
; 0294  OSD from quality metric — NOT AGC                    [confirmed]
;   A = E6F7():  <9 → E67A(0xCC) "No Signal" (weak FPV often here)
;                <0x11 → E67A(0x88) weaker OSD               [likely]
;                >=0x20 → E67A(0x77) hide OSD                [likely]
; =============================================================================
0294: 12 E6 F7      LCALL 0xE6F7          ; quality number in A
0297: C3            CLR C
0298: 94 09         SUBB A,#0x09
029A: 50 04         JNC 0x02A0
029C: 7F CC         MOV R7,#0xCC          ; "No Signal"
029E: 80 16         SJMP 0x02B6
02A0: 12 E6 F7      LCALL 0xE6F7
02A3: C3            CLR C
02A4: 94 11         SUBB A,#0x11
02A6: 50 04         JNC 0x02AC
02A8: 7F 88         MOV R7,#0x88
02AA: 80 0A         SJMP 0x02B6
02AC: 12 E6 F7      LCALL 0xE6F7
02AF: D3            SETB C
02B0: 94 20         SUBB A,#0x20
02B2: 40 05         JC 0x02B9             ; 0x11 <= quality < 0x20 → nop
02B4: 7F 77         MOV R7,#0x77          ; hide OSD
02B6: 12 E6 7A      LCALL 0xE67A          ; ROM command in R7
02B9: 22            RET

; =============================================================================
; 02BA  HDMI PHY poke + delay                                [likely]
;   F08E = R7, F081=F082=0x3F,
;   F08C=F08D = (R7 < 0x88) ? 0x10 : 0, then E701(0x32).
; =============================================================================
02BA: 90 F0 8E      MOV DPTR,#0xF08E
02BD: EF            MOV A,R7
02BE: F0            MOVX @DPTR,A          ; F08E = R7
02BF: 90 F0 81      MOV DPTR,#0xF081
02C2: 74 3F         MOV A,#0x3F
02C4: F0            MOVX @DPTR,A          ; F081 = 0x3F
02C5: A3            INC DPTR
02C6: F0            MOVX @DPTR,A          ; F082 = 0x3F
02C7: EF            MOV A,R7
02C8: C3            CLR C
02C9: 94 88         SUBB A,#0x88
02CB: 90 F0 8C      MOV DPTR,#0xF08C
02CE: 50 04         JNC 0x02D4            ; R7 >= 0x88 → 0
02D0: 74 10         MOV A,#0x10
02D2: 80 01         SJMP 0x02D5
02D4: E4            CLR A
02D5: F0            MOVX @DPTR,A          ; F08C
02D6: A3            INC DPTR
02D7: F0            MOVX @DPTR,A          ; F08D = same
02D8: 7F 32         MOV R7,#0x32
02DA: 02 E7 01      LJMP 0xE701           ; delay, no return here

; =============================================================================
; 02DD  wait loop on F082 while quality < 0x1E               [likely]
; =============================================================================
02DD: 12 E6 F7      LCALL 0xE6F7
02E0: C3            CLR C
02E1: 94 1E         SUBB A,#0x1E
02E3: 50 0F         JNC 0x02F4            ; quality >= 0x1E → done
02E5: 90 F0 82      MOV DPTR,#0xF082
02E8: E0            MOVX A,@DPTR
02E9: 60 09         JZ 0x02F4             ; counter expired
02EB: 14            DEC A
02EC: F0            MOVX @DPTR,A          ; F082--
02ED: 7F 1E         MOV R7,#0x1E
02EF: 12 E7 01      LCALL 0xE701
02F2: 80 E9         SJMP 0x02DD
02F4: 90 F0 82      MOV DPTR,#0xF082
02F7: E0            MOVX A,@DPTR
02F8: 90 F0 81      MOV DPTR,#0xF081
02FB: F0            MOVX @DPTR,A          ; F081 = F082
02FC: 22            RET

; =============================================================================
; 02FD  enter no-signal (ROM calls this on loss)             [confirmed]
;   noblue still runs this; snow comes from NOP of E4FF, not from skipping here.
;   [noblue: EC01 write changed 01 → 00]
; =============================================================================
02FD: 12 E6 54      LCALL 0xE654          ; enter no-signal / OSD          [likely]
0300: 7F 01         MOV R7,#0x01
0302: 12 E5 DE      LCALL 0xE5DE          ; mute/OSD layer on              [likely]
0305: E4            CLR A
0306: FF            MOV R7,A
0307: 12 E5 DE      LCALL 0xE5DE          ; off
030A: 7F 01         MOV R7,#0x01
030C: 12 E5 DE      LCALL 0xE5DE          ; on
030F: 90 EC 01      MOV DPTR,#0xEC01
0312: 74 01         MOV A,#0x01           ; [noblue: 00]
0314: F0            MOVX @DPTR,A          ; EC01 = 1 → hook 0043 takes E4FF
0315: 22            RET

; =============================================================================
; 0316  R7 event dispatcher → ROM                            [guess]
;   0 → E61A,  1 → E6EB,  2 → E403,  else RET
; =============================================================================
0316: EF            MOV A,R7
0317: 14            DEC A
0318: 60 0A         JZ 0x0324             ; R7 == 1
031A: 14            DEC A
031B: 60 0A         JZ 0x0327             ; R7 == 2
031D: 24 02         ADD A,#0x02           ; restore; 0 → E61A
031F: 70 09         JNZ 0x032A
0321: 02 E6 1A      LJMP 0xE61A           ; R7 == 0
0324: 02 E6 EB      LJMP 0xE6EB           ; R7 == 1
0327: 12 E4 03      LCALL 0xE403          ; R7 == 2
032A: 22            RET

; =============================================================================
; 032B  exit no-signal                                       [confirmed]
; =============================================================================
032B: 90 E2 EA      MOV DPTR,#0xE2EA      ; unblank                        [likely]
032E: 74 01         MOV A,#0x01
0330: F0            MOVX @DPTR,A          ; E2EA = 1
0331: E4            CLR A
0332: 90 EC 01      MOV DPTR,#0xEC01
0335: F0            MOVX @DPTR,A          ; EC01 = 0
0336: 22            RET

; =============================================================================
; 0337  F213 - F212 → A                                      [confirmed as code]
; =============================================================================
0337: 90 F2 12      MOV DPTR,#0xF212
033A: E0            MOVX A,@DPTR
033B: FF            MOV R7,A              ; R7 = F212
033C: A3            INC DPTR              ; F213
033D: E0            MOVX A,@DPTR
033E: C3            CLR C
033F: 9F            SUBB A,R7             ; A = F213 - F212
0340: 22            RET

; =============================================================================
; 0341  stash R7 and call ROM 0x1E48                         [guess: OSD/string]
; =============================================================================
0341: 90 EC 05      MOV DPTR,#0xEC05
0344: EF            MOV A,R7
0345: F0            MOVX @DPTR,A          ; EC05 = R7
0346: 12 1E 48      LCALL 0x1E48          ; low ROM helper
0349: 22            RET

; =============================================================================
; 034A–034F  DATA / Keil tail, not executed as logic
;   bytes: 41 EC 00 C8 00 22
; =============================================================================
034A: 41 EC         AJMP 0x02EC           ; DATA
034C: 00            NOP
034D: C8            XCH A,R0
034E: 00            NOP
034F: 22            RET
