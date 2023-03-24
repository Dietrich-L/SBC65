SBC65
===========
Dietrich Lausberg <lausbergd@gmail.com>
https://github.com/dietrich-l

This repository contains hardware and software of my SBC65, a simple 6502 based single board computer, which I use as testbed and standalone controller for not too complicated applications.

System Description
--------------------------
6502 processor
1 kByte RAM
2 kByte or 4 kByte EPROM (2716/28c16 or 2732) 
6522 I/O chip 
8-Bit Latch for digital output
Serial-I/O 38400 Baud bitbanged in system ROM
I2C bus support (4k version only)
Wireles serial interface via NRF24L01
Monitor for debugging and XMODEM file transfer

The system was developed originally in 1985 as Centronice interface for a Brother CE60 electronic flying wheel typewriter. The CE60 is long gone, but the description is in the repository, if somebody is interested. In 2022 I converted the SBC65 to its curent use as development platform for a family of 6502 based SBCs.

Memory Map
---------------------
RAM	= $0000		;SYSTEM RAM
INBUF	= $C0		;Input buffer
STACKV	= $12F
BUFFER	= $130		;to squeeze out more user RAM
HIMEM	= $400

OUT	= $5000		;8-BIT LATCH
VIA	= $6000		;6522 VIA
EPROM	= $F800		;2716	2 KBYTE EPROM
EPROM	= $F000		;2732	4 KBYTE EPROM

Software List
---------------------
Name		Version
SBC65		1.1	System ROM 2kByte version
SBC4K		1.1	System ROM 4kByte version
BLINKY		1.1	blinking LED for testing
CPUTYPE		1.0	identify 6502 type (NMOS or CMOS)
AT28UTIL	1.0	Tool to read and write an AT28c16 EEPROM
ERA24C32	1.0	Erase I2C AT24C32 EEPROM
TEMP		1.0	Display temperature from RTC

All software is supplied as assembler files to be assembled with the CPM-65 assembler. In case you wish to use a different assembler, the syntax has to be adapted accordingly.

Documentation
--------------------
Currently the documentation of SBC65 is sparse and only for my personal needs. I plan to write appropriate docs over time. If there are any whishes, please open a DISCUSSION

Errors
--------------------
The SBC65 system software is in an early development stage. So expect errors. The V0 hardware has seen now more than 35 years of service and is proven stable. However be warned: the adressing of the 8-Bit Latch 74LS273 is a bit out of spec and can cause issues with some CPUs due to tolerances in timing. It should be changed.



Redistribution
--------------
Source code, and all documents, are freely redistributable in
any form. Please see the the COPYRIGHT file included in this
Repository.