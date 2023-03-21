;ERA24c32.ASM -  erase AT24c32 chip
;requires 4k EPROM Monitor SBC4K

;V1.0	20.03.23	initial version

VERSION	= $10

	;SYSTEM CONFIGURATION

RAM	= $0000		;SYSTEM RAM
ZPVAR	= RAM+132
INBUF	= $C0		;Input buffer
STACKV	= $12F
BUFFER	= $130		;to squeeze out more user RAM
HIMEM	= $400

OUT	= $5000		;8-BIT LATCH

VIA	= $6000		;6522 VIA

PORTB	= VIA
DDRB	= VIA+2
PORTA	= VIA+15
DDRA	= VIA+3

ACR	= VIA+11
PCR	= VIA+12
IFR	= VIA+13
IER	= VIA+14

EPROM	= $F000		;2732	4 KBYTE EPROM

START	= EPROM
CHRIN	= EPROM+3	;BIOS routine CHR input
CHROUT	= EPROM+6	;BIOS routine CHR output
PRTSTR	= EPROM+9	;print STRINGZ in A/Y L/H
DELAY	= EPROM+12	;100 ms * Y delay
I2CCLR	= EPROM+15	;clear I2C
I2CADEV	= EPROM+18	;send 7 bit dev adr to write
I2CRDEV	= EPROM+21	;send 7 bit dev adr to read
I2CRBYTE = EPROM+24	;read byte from dev
I2CWBYTE = EPROM+27	;write byte in A to dev
I2CRLB	= EPROM+30	;read last byte from dev
RDBLK	= EPROM+33	;read block from 16 bit device
			;I2CDEV, PNT16, LENGTH, CURAD
W16BYTE	= EPROM+36	;write byte in A to 16 bit device
			;I2CDEV, PNT16
W16PAGE	= EPROM+39	;write block to 16 bit device
			;I2CDEV, PNT16, LENGTH, CURAD

;CONTROL CODES

EOT	= $00
BREAK	= $03
BS	= $08
BL	= $20
CR	= $0D		; carriage return
LF	= $0A		; line feed


	;SYSTEM CONSTANTS

DEFACR	= %00000000	;LATCH DISABLE
DEFPCR	= %11101111	;CB1/CB2 Tx
			;CA1 CONT/ CA2 SCK
CB2L	= %11011111	;set CB2 low via AND PCR
CB2H	= %00100000	;set CB2 high via ORA PCR

	;memory cells

RBUFF	= $00 		;132 byte receive buffer (page aligned)
CHR	= ZPVAR+$00	;chr from CON
CMDVEC	= ZPVAR+$01	;pointer for command line
IN	= ZPVAR+$02	;pointer for GETSTR
PNT	= ZPVAR+$04	;pointer for PRTSTR
CURAD	= ZPVAR+$06	;current adr
ENDAD	= ZPVAR+$08	;last adr
HEX	= ZPVAR+$0A	;buffer for GETHEX

ACCU	= ZPVAR+$0C
XREG	= ZPVAR+$0D
YREG	= ZPVAR+$0E
STACK	= ZPVAR+$0F
STATUS	= ZPVAR+$10
PC	= ZPVAR+$11
BRKADR	= ZPVAR+$13
BRKBYT	= ZPVAR+$15
YBUF	= ZPVAR+$16	;Y buffer for CHRIN & CHROUT
BLKNO	= ZPVAR+$17	;block number
ABUF	= ZPVAR+$17	;A buffer in I2CINFO
BYTE	= ZPVAR+$18	;BYTE buffer in I2CWBYTE
CRC	= ZPVAR+$18	;CRC

IRQV	= ZPVAR+$1A	;User IRQ vector
NMIV	= ZPVAR+$1C	;User NMI vector

I2CDEV	= ZPVAR+$1E	;I2C device nr 7 Bit
ID	= ZPVAR+$1F	;I2C memory data set ID
PNT16	= ZPVAR+$21	;I2C 16 bit register
LENGTH	= ZPVAR+$23	;I2C block length
I2C_DAT = ZPVAR+$25	;I2C decive data

;I2C adresses
RTC	= $68
24C32	= $57

CLK_H	= %00001111	;CLK=1 set CA2 high via ORA PCR
CLK_L	= %11111101	;CLK=0 set CA2 low via AND PCR

	ORG BUFFER

ERASE	LDA #TITLE
	LDY #TITLE/256
	JSR PRTSTR
	LDA #24C32	;setup parameters
	STA I2CDEV
	LDA #0
	STA PNT16
	STA PNT16+1
	STA LENGTH+1
	LDA #4096/32	;# pages in 24C32
	STA I2C_DAT
ERASE1	LDA #32		;1 page
	STA LENGTH
	LDA #FFDATA
	STA CURAD
	LDA #FFDATA/256
	STA CURAD+1
	JSR W16PAGE	;delete 1 page with $FF
	BCS ERROR
	DEC I2C_DAT	;dec # pages
	BNE ERASE1	;last page?
	JMP START	;return to Monitor

ERROR	LDA #ERRM
	LDY #ERRM/256
	JSR PRTSTR
	JMP START	;return to Monitor


FFDATA	DS 32,$FF

TITLE	DB CR,LF,'deleting 24C32', CR,LF,EOT
ERRM	DB CR,LF,'* Error *',CR,LF,EOT

	END