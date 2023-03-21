;SBC4K.ASM - 4k monitor for the SBC65 with I2C support

;V1.0	17.02.23	initial version

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

;CONTROL CODES

EOT	= $00
BREAK	= $03
BS	= $08
BL	= $20

; XMODEM Control Character Constants
SOH	= $01		; Start block
XEOT	= $04		; end of text marker
ACK	= $06		; good block acknowledged
NAK	= $15		; bad block acknowledged
CAN	= $18		; cancel (not standard, not supported)
CR	= $0D		; carriage return
LF	= $0A		; line feed
ESC	= $1B		; ESC to exit

	;SYSTEM CONSTANTS

DEFACR	= %00000000	;LATCH DISABLE
DEFPCR	= %11101111	;CB1/CB2 Tx
			;CA1 CONT/ CA2 SCK
CB2L	= %11011111	;set CB2 low via AND PCR
CB2H	= %00100000	;set CB2 high via ORA PCR

MAXLEN	= $40		;max. 64 input chr's

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

	ORG EPROM

RESET	JMP START
	JMP CHRIN	;BIOS routine CHR input
	JMP CHROUT	;BIOS routine CHR output
	JMP PRTSTR	;print STRINGZ in A/Y L/H
	JMP DELAY	;100 ms * Y delay
	JMP I2CCLR	;clear I2C
	JMP I2CADEV	;send 7 bit dev adr to write
	JMP I2CRDEV	;send 7 bit dev adr to read
	JMP I2CRBYTE	;read byte from dev
	JMP I2CWBYTE	;write byte in A to dev
	JMP I2CRLB	;read last byte from dev
	JMP RDBLK	;read block from 16 bit device
			;I2CDEV, PNT16, LENGTH, CURAD
	JMP W16BYTE	;write byte in A to 16 bit device
			;I2CDEV, PNT16
	JMP W16PAGE	;write block to 16 bit device
			;I2CDEV, PNT16, LENGTH, CURAD

START			;SBC-MON begins here
	LDX #STACKV	;INITIALISE SYSTEM
	TXS		;SET STACKPOINTER
	CLD
	CLI
	LDY #20		;2 s delay
	JSR DELAY
	JSR INITCON	;initialize CON
	JSR I2CCLR	;clear I2C bus
	JSR INITVAR	;initialize variables

	LDY #INITM/256	;print initial blurp
	LDA #INITM
	JSR PRTSTR

LOOP	LDY #PROMPTM/256	;print prompt
	LDA #PROMPTM
	JSR PRTSTR
	JSR GETSTR	;read 1 line
	LDA #0
	STA CMDVEC
	JSR DECODE
	BCC LOOP
LPERR	LDA #ERROR
	LDY #ERROR/256
	JSR PRTSTR
	JSR I2CCLR	;clear I2C bus
	JMP LOOP


DECODE	JSR GNCHR	;Decode & exec command
	BCS DECODX
	CMP #'A		;Check for letter
	BCC DECOD2
	AND #%01011111	;upper case
	STA CHR
	LDY #0
DECOD1	LDA CMDTAB,Y
	BEQ DECOD2	;COMMAND NOT FOUND
	CMP CHR
	BEQ DECOD3	;FOUND
	INY
	INY
	INY
	BNE DECOD1

DECOD3	INY
	LDA CMDTAB,Y
	PHA
	INY
	LDA CMDTAB,Y
	PHA
	RTS		;EXEC

DECOD2	SEC
DECODX	RTS	

;-------  Monitor commands  -------

DUMP	JSR GCURAD	;Dump memory to CON
	BCS DUMPX
	LDA CURAD
	AND #$F0	;STARTS always at $xxx0
	STA CURAD
	JSR GNHEX
	BCS DUMP2	;2. argument missing or wrong
	LDA HEX
	STA ENDAD
	LDA HEX+1
	STA ENDAD+1
DUMP1	JSR DUMPHE	;PRINT HEADER
DUMP3	JSR DUMPL	;PRINT LINE
	BCS DUMP4
	LDA CURAD	;print adr header every $80 bytes
	AND #%01111111
	BNE DUMP3
	JSR DUMPHE
	JMP DUMP3

DUMP2	LDA CURAD	;default 8 lines
	CLC
	ADC #$80
	STA ENDAD
	LDA CURAD+1
	ADC #0
	STA ENDAD+1
	BCC DUMP1

DUMP4	CLC
DUMPX	RTS

DUMP6	SEC
	RTS


GO	JSR GCURAD	;START PROGRAM
	BCS GOX
	LDA CURAD+1
	PHA		;push CURAD+1
	LDA CURAD
	PHA
	LDA STATUS	;restore registers from BRK
	PHA
	LDA ACCU
	LDX XREG
	LDY YREG
UIRQ	RTI		;JMP (CURAD)

GOX	RTS


ENTER	JSR GCURAD	;enter bytes to memory
	BCS ENTERX
ENTER4	JSR GNHEX	;get byte to enter
	BCS ENTER1	;argument missing
	JSR DUMPHE
	LDY #0
	LDA (CURAD),Y	;display old byte
	JSR DISHEX
	LDA HEX
	STA (CURAD),Y	;store new byt
	JSR PRTHEX
	JSR ICURAD	;INC CURAD
	BNE ENTER4
ENTER1	CLC
ENTERX	RTS


READ	JSR GCURAD	;Read file to nnnn
	BCS READX
	JSR CRLF
	JMP XMODEM

READX	RTS


LIST	JSR GCURAD	;list 14 commands from adr
	BCS LISTX
	LDA #14
	STA ACCU
LIST1	JSR DASM	;print command
	DEC ACCU
	BNE LIST1
	CLC
LISTX	RTS


SETBRK	JSR GCURAD	;set Breakpoint at nnnn
	BCS SETBRKX
	LDA CURAD
	STA BRKADR	;save adr
	LDY CURAD+1
	STY BRKADR+1
	LDY #0
	LDA (BRKADR),Y
	STA BRKBYT	;save opcode
	TYA
	STA (BRKADR),Y	;store BRK opcode
SETBRKX	RTS

	;--- XMODEM ---

XModem	LDA #1		; store file to CURAD
	STA BLKNO	; block nr = 1
	LDA #10		; max. 10 errors
	STA CMDVEC
	SEI		; no IRQ from here	
StartCrc
	LDA #'C		; C STArt transmission CRC option
	JSR D_CHROUT	; send it
	JSR D_CHRIN	; wait for input
	BCC GotByte	; byte received, process it
	BCS StartCrc	; resend 'C

StartBlk
	JSR D_CHROUT	; Send ACK or NAK
	JSR D_CHRIN	; get first byte of block
GotByte	CMP #SOH	; Start of block?
	BEQ BegBlk
	CMP #CAN	; quitting?
        BEQ BADBLK
	CMP #XEOT	; XMODEN EOT Byte
	BNE BadCrc	; Not SOH or EOT, so flush buffer & send NAK
Done	CLI		; END OF CRITICAL PHASE
	LDA #ACK	; last block, send ACK and exit.
	JSR CHROUT	; END OF CRITICAL PHASE
FLUSH	JSR D_CHRIN	; flush receive buffer
	BCC FLUSH
	CLC
	RTS

BegBlk	LDX #$00
GetBlk	JSR D_CHRIN	; get next character
			; if no chr -> save $00 -> CRC errror
	STA RBUFF,X	; good char, save it in the rcv buffer
	INX		; inc buffer pointer	
	CPX #$84	; <01> <FE> <128 bytes> <CRCH> <CRCL>
	BNE GetBlk	; get 130 characters
	LDX #$00
	LDA RBUFF,X	; get block # from buffer
	CMP BLKNO	; compare to expected block #	
	BNE BadBlk
GoodBlk1
	EOR #$FF	; 1's comp of block #
	INX
	CMP RBUFF,X	; compare with expected 1's comp of block #
	BEQ GoodBlk2 	; matched!
BadBlk	JSR FLUSH	; mismatched - flush buffer
	LDA #CAN	; end transfer
	JSR CHROUT	;END OF CRITICAL PHASE
	SEC
	RTS
	
GoodBlk2
	JSR CalcCRC
	LDA RBUFF,X	; get hi CRC from buffer
	CMP CRC+1	; compare to calculated hi CRC
	BNE BadCrc	; bad CRC, send NAK
	INX
	LDA RBUFF,X	; get lo CRC from buffer
	CMP CRC		; compare to calculated lo CRC
	BEQ CopyBlk	; good CRC
BadCrc	JSR FLUSH	; flush the input port
	DEC CMDVEC
	BEQ BADBLK	;too manx errors
	LDA #NAK
	JMP StartBlk	; Start over, get the block again		
	
CopyBlk	LDX #$02	; data STARTS at pos $02
	LDY #$00	; set offset to zero
CopyBlk3
	LDA RBUFF,X	; get data byte from buffer
	STA (CURAD),Y	; save to target
	INY
CopyBlk4
	INX		; point to next data byte
	CPX #$82	; is it the last byte
	BNE CopyBlk3	; no, get the next one
IncBlk	INC BLKNO	; done.  Inc the block #
	CLC
	LDA CURAD	; CURAD = CURAD +$80
	ADC #$80
	STA CURAD
	BCC INCBLK1
	INC CURAD+1
INCBLK1	LDA #ACK	; send ACK
	JMP StartBlk	; get next block

	;--- CRC subroutines ---

CalcCRC	LDA #$00	; yes, calculate the CRC for the 128 bytes
	STA CRC
	STA CRC+1
	LDX #$02
CalcCRC1
	LDA RBUFF,X
	EOR CRC+1 	; Quick CRC computation with lookup tables
       	TAY		; updates the two bytes at CRC & CRC+1
       	LDA CRC		; with the byte send in Accu
       	EOR CRCHI,Y
       	STA CRC+1
      	LDA CRCLO,Y
       	STA CRC
	INX
	CPX #$82	; done yet?
	BNE CalcCRC1	; no, get next
	RTS		; x=82 on exit

	;--- Subroutines ----

GCURAD	JSR GETHEX	;get CURAD from INBUF
	BCC GCURA1
	CMP #0		;missing argument
	BEQ GCURA2
	RTS

GCURA1	LDA HEX
	STA CURAD
	LDY HEX+1
	STY CURAD+1
GCURA2	CLC
	RTS


GNHEX	JSR GNCHR
	BCS GNHEXX	;argument missing
	CMP #',
	BNE GNHEX1
	JSR GETHEX
GNHEXX	RTS

GNHEX1	SEC
	RTS


GETHEX	LDA #0 		;GET HEX NUMBER FROM LINE
	STA HEX		;RESET HEX
	STA HEX+1
	TAX
GETHE2	JSR GETNIB	;GET NIBBLE TO HEX
	BCS GETHE1
	INX
	CPX #4
	BCC GETHE2	;max 4 bytes
GETHE4	CLC
	RTS

GETHE1	CMP #EOT
	BNE GETHE3
	CPX #0		;A=EOT & X=0 -> missing argument
	BNE GETHE4
GETHE3	SEC
	RTS


GETNIB	JSR GNCHR	;GET NIBBLE TO HEX
	BCS GETNI1	;EOT?
	CMP #',
	BEQ GETNIX
	EOR #$30
	CMP #10
	BCC GETNI2	;0..9
	ORA #$20	;convert to upper case
	ADC #$88	;map to $FA..$FF
	CMP #$FA
	BCS GETNI2	;A..F
	LDA #$FF	;invalid chr
	SEC
GETNI1	RTS

GETNIX	DEC CMDVEC	;CMDVEC back to ,
	CLC
	RTS

GETNI2	ASL A		;shift to MSNIB
	ASL A
	ASL A
	ASL A
	LDY #4
GETNI4	ASL A
	ROL HEX
	ROL HEX+1
	DEY
	BNE GETNI4
	CLC
	RTS


GNCHR	LDY CMDVEC
	LDA (IN),Y	;get chr
	BEQ GNCHRX
	INC CMDVEC	;inc pointer
	CLC
	RTS

GNCHRX	SEC		;EOT met
	RTS


ICURAD	INC CURAD	;inc CURAD
	BNE ICURADX
	INC CURAD+1
ICURADX	RTS


CRLF	LDA #CR
	JSR CHROUT
	LDA #LF
	JMP CHROUT

PRTSP	LDA #BL
	JMP CHROUT


DUMPHE	JSR PRTCUR	;PRINT CURAD
	LDA #':
	JSR CHROUT
	JMP PRTSP


PRTCUR	JSR CRLF
	LDA CURAD+1
	JSR PRTHEX
	LDA CURAD
	JMP PRTHEX


DUMPL	JSR CRLF	;print 16 memory bytes hex & ASCII
	LDY #0
DUMPL1	LDA (CURAD),Y	;print hex bytes
	JSR DISHEX
	INY
	CPY #8
	BNE DUMPL3
	LDA #BS		;1 bs after 8 bytes
	JSR CHROUT
DUMPL3	CPY #$10
	BCC DUMPL1
	LDY #0
DUMPL2	LDA (CURAD),Y	;print ASCII bytes
	JSR DISASC
	INY
	CPY #$10
	BCC DUMPL2
	TYA
	LDY CURAD+1	;CURAD = CURAD + $10
	CLC
	ADC CURAD
	STA CURAD
	BCC DUMPL4
	INY
	STY CURAD+1	;ENDAD reached?
DUMPL4	CPY ENDAD+1
	BCC DUMPLX
	CMP ENDAD
DUMPLX	RTS


PRTSTR	STA PNT		;PRINT MESSAGE in A/Y
	STY PNT+1
PRTSTR1	LDY #0
	LDA (PNT),Y	;check for EOT
	BEQ PRTSTRX
	JSR CHROUT
	INC PNT
	BNE PRTSTR1
	INC PNT+1
	BNE PRTSTR1
PRTSTRX	RTS


PRTHEX	PHA		;print HEX byte
	LSR A
	LSR A
	LSR A
	LSR A
	JSR PRTNIB
	PLA
	AND #$0F
PRTNIB	CMP #$0A	;print Nibble
	BCC PRTNI1
	ADC #6
PRTNI1	ADC #$30
	JMP CHROUT


DISREG	LDX #0		;display registers and flags
DISRE1	JSR PRTREG
	INX
	CPX #4		;4 REGISTERS
	BCC DISRE1
DISFLAGS		;display CPU flags
	LDX #7
	LDA STATUS
	STA BRKBYT
DISFL1	LDA FTAB,X
	BEQ DISFL3
	JSR CHROUT
	ROL BRKBYT	
	LDA #%00011000
	ROL A
	JSR CHROUT
DISFL2	DEX
	BPL DISFL1
	RTS

DISFL3	ROL BRKBYT
	JMP DISFL2


PRTREG	LDA RTAB,X	;PRINT CPU REGISTER indexed by X
	JSR CHROUT
	LDA #'=
	JSR CHROUT
	LDA ACCU,X

DISHEX	JSR PRTHEX	;prints HEX & SP
	JMP PRTSP


DISASC	AND #$7F	;prints 1 ASCII
	CMP #$20
	BCC DISAS1
	CMP #$7F
	BCC DISAS2
DISAS1	LDA #'.
DISAS2	JMP CHROUT



GETSTR	LDY #0		;reads string from CON to INBUF	
GETSTRL	JSR CHRIN	;Format ASCIIZ
	BCS GETSTRL	;if no chr, try again
	CMP #CR
	BEQ GETSTR2
	CMP #BS
	BEQ GETSTR1
	CMP #ESC
	BEQ GETSTR3
	CMP #BREAK
	BEQ GETSTR3
	AND #$7F	;7 Bit ASCII only
	CMP #$20	;TEST CHR
	BCC GETSTRL	;ignore control chr's
	STA (IN),Y
	JSR CHROUT	;echo CHR
	INY
	CPY #MAXLEN-1
	BCC GETSTRL
GETSTR2	LDA #EOT
	STA (IN),Y
	RTS

GETSTR3	LDY #0		;clear input
	BEQ GETSTR2

GETSTR1	DEY		;do BS
	BMI GETSTR
	JSR CHROUT	;print BS
	JMP GETSTRL

		
DASM	JSR DUMPHE	;print ASM command as hex 
	LDY #0		;print CURAD:
	LDA (CURAD),Y
	JSR OPLEN	;calculate opcode length
	TAX
DASM1	LDY #0
	LDA (CURAD),Y	;print command & operand
	JSR DISHEX
	JSR ICURAD	;INC CURAD
DASM2	DEX
	BNE DASM1	
	RTS


OPLEN	LDX #1		;calculate opcode length
	CMP #0
	BEQ OPLENX
	CMP #$40
	BEQ OPLENX
	CMP #$60
	BEQ OPLENX
	LDX #3
	CMP #$20
	BEQ OPLENX
	AND #$1F
	CMP #$19
	BEQ OPLENX
	AND #$0F
	TAX
	LDA LENTAB,X
	RTS

OPLENX	TXA
	RTS


DELAY	PHA		;100 ms delay * Y
DELAY1	TYA		;saves A,X
	PHA
	LDY #56
DELAY2	SEC		;7*256*56 uS = 100 ms delay
	SBC #1
	BCS DELAY2
	DEY
	BNE DELAY2
	PLA
	TAY
	DEY
	BNE DELAY1
	PLA
	RTS


; --- I2C functions ---

SET	JSR GHEAD	;set I2CDEV, reg, byte, byte, ...
	BCS SETX
SET1	LDA I2CDEV
	JSR I2CADEV	;select dev for Write
	BCS SETX
	LDA ID
	JSR I2CWByte	;set register to write
	BCS SETX
	LDA PNT16
SET2	JSR I2CWBYTE	;write byte to reg
	BCS SETX
	JSR GNHEX
	LDA HEX
	BCC SET2	;next byte
	CLC
SETX	JSR I2CSTOP
	RTS

SETXX	SEC
	BCS SETX


FETCH	JSR GHEAD	;fetch devadr, reg, nn, adr
	BCS FETCHX
	JSR GNHEX
	BCS FETCHX
FETCH0	LDA I2CDEV	;X pointer, ID nr of bytes-1
	JSR I2CADEV
	BCS FETCHX
	LDA ID		;reg
FETCH3	JSR I2CWByte
	BCS FETCHX
	LDA I2CDEV	;read command
	JSR I2CRDEV
	BCS FETCHX
FETCH1	JSR I2CRBYTE	;Read byte
	BCS FETCHX
	LDY #0
	STA (HEX),Y
	INC HEX
	BNE FETCH2
	INC HEX+1
FETCH2	DEC PNT16
	BMI FETCHXX
	BNE FETCH1	;next byte
	JSR I2CRLB
FETCHX	RTS

FETCHXX	SEC
	RTS


ADDID	JSR GHEAD	;add to devadr, ID, nnnn, data adr
	BCS ADDIDXX	;nnnn #bytes
	JSR GNHEX
	BCS ADDIDXX
	JSR FINDID	;find ID
	BCC ADDID1	;found
	CMP #$FF
	BNE ADDIDX
ADDID1	LDA ENDAD	;LENGTH = ENDAD
	STA LENGTH
	LDA ENDAD+1
	STA LENGTH+1
	LDA HEX		;CURAD = HEX
	STA CURAD
	LDA HEX+1
	STA CURAD+1
	LDA ID		;write ID
	JSR W16BYTE
	BCS ADDIDXX
	LDA ID+1
	JSR W16BYTE
	BCS ADDIDXX
	LDA LENGTH	;Write LENGTH
	JSR W16BYTE
	BCS ADDIDXX
	LDA LENGTH+1
	JSR W16BYTE
	BCS ADDIDXX
	JMP W16PAGE	;write ID data

ADDIDX	SEC
ADDIDXX	RTS


PULLID	JSR GHEAD	;pull data from devadr, ID to adr
	BCS PULLIDX
	JSR FINDID
	BCS PULLIDX
	LDA ENDAD	;CURAD = ENDAD
	STA CURAD
	LDA ENDAD+1
	STA CURAD+1
	LDA I2C_DAT+2	;LENGTH = I2C_DAT+3
	STA LENGTH
	LDA I2C_DAT+3
	STA LENGTH+1
	CLC		;PNT = PNT +4
	LDA PNT16
	ADC #4
	STA PNT16
	BCC PULLID1
	INC PNT16+1
PULLID1	JSR RDBLK	;read block
PULLIDX	RTS


TIME	LDA #RTC	;show time from RTC
	STA I2CDEV
	LDA #0		;reg 0 ff
	STA ID
	STA HEX		;store in $0000
	STA HEX+1
	LDA #3
	STA PNT16	;get sec, min, hour
	JSR FETCH0
	BCS TIMEX
	JSR CRLF
	LDA 2		;hour
	AND #$3F	;clear 12/24h & AM/PM bits
	JSR PRTHEX
	LDA #':
	JSR CHROUT
	LDA 1
	JSR PRTHEX
	LDA #':
	JSR CHROUT
	LDA 0
	JSR PRTHEX
	JSR CRLF
	CLC
TIMEX	RTS


DATE	LDA #RTC	;show time from RTC
	STA I2CDEV
	LDA #0		;reg 0 ff
	STA HEX		;store in $0000
	STA HEX+1
	LDA #4		;reg 4 ff
	STA ID
	STA PNT16	;get dd, mm, yy
	JSR FETCH0
	BCS DATEX
	JSR CRLF
	LDA 0
	JSR PRTHEX
	LDA #'.
	JSR CHROUT
	LDA 1
	AND #$7F	;clear century bit
	JSR PRTHEX
	LDA #'.
	JSR CHROUT
	LDA #$20
	JSR PRTHEX
	LDA 2
	JSR PRTHEX
	JSR CRLF
	CLC
DATEX	RTS


I2CINFO	JSR I2CCLR 	;list devices on I2C bus
	LDA #INFO_M
	LDY #INFO_M/256
	JSR PRTSTR
	LDA #0
	STA ABUF	;start with dev = 0
INFO3	JSR PRTSP	;print dev adress
	LDA ABUF
	JSR PRTHEX	
	LDA ABUF
	JSR I2CADEV	;check dev present?
	BCC INFO1
	LDA #CR
	JSR CHROUT
INFO2	INC ABUF
	BPL INFO3
	LDY #3
INFO4	JSR PRTSP	;all adr scanned, delete last try
	DEY
	BPL INFO4
	CLC
INFOX	RTS

INFO1	JSR PRTSP	;print dev
	LDA ABUF
	ASL A
	JSR PRTHEX
	JSR PRTSP
	LDA ABUF
	SEC
	ROL A
	JSR PRTHEX
	JSR I2CSTOP
	JSR CRLF
	JMP INFO2

; --- I2C subroutines ---

GHEAD	JSR GETHEX	;get I2CDEV, reg, value
	BCS GHEADX	;argument missing or wrong
	LDA HEX
	AND #$7F	;bits 7 must be 0
	STA I2CDEV	;devadr
	JSR GNHEX
	BCS GHEADX	;argument missing or wrong
	LDA HEX		;reg
	STA ID
	LDA HEX+1
	STA ID+1
	JSR GNHEX
	BCS GHEADX	;argument missing or wrong
	LDA HEX		;value
	STA PNT16
	LDA HEX+1
	STA PNT16+1
GHEADX	RTS


FINDID	LDA PNT16	;find ID in I2CDEV
	STA ENDAD	;copy nnnn to ENDAD
	LDA PNT16+1
	STA ENDAD+1
	LDA #0
	STA PNT16	;PNT16=$0000
	STA PNT16+1
	STA LENGTH+1
FINDI1	LDA #4		;read ID header
	STA LENGTH
	LDA #I2C_DAT	;4 header bytes to I2C_DAT
	STA CURAD
	LDA #I2C_DAT/256
	STA CURAD+1
	JSR RDBLK	;read ID header
	BCS FINDIDX
	LDY I2C_DAT	;check ID field = $FF
	LDA I2C_DAT+1
	CPY #$FF
	BNE FINDI4
	CMP #$FF
	BEQ FINDIDX	;ID not found
FINDI4	CPY ID		;Check ID field = ID
	BNE FINDI2
	CMP ID+1
	BNE FINDI2
	CLC		;ID found
	RTS

FINDI2	CLC		;PNT16 = PNT16 + 4
	LDA PNT16
	ADC #4
	BCC FINDI3
	INC PNT16+1
	CLC
FINDI3	ADC I2C_DAT+2	;PNT16 = PNT16 + ID length
	STA PNT16
	LDA PNT16+1
	ADC I2C_DAT+3
	STA PNT16+1
	BCC FINDI1	;read next ID header

FINDIDX	RTS	


RDBLK	JSR SET16W	;Read Block from DEV(PNT16) to CURAD
	BCS RDBLKX	;read LENGTH bytes
	LDA I2CDEV
	JSR I2CRDEV
	BCS RDBLKX
RDBLK1	JSR DECLEN	;dec LENGTH
	BCS RDBLK2	;finished?
	JSR I2CRBYTE	;read next byte
	BCS RDBLKX
	LDY #0
	STA (CURAD),Y
	JSR ICURAD	;inc CURAD
	BNE RDBLK1

RDBLK2	JSR I2CRLB	;dummy read last byte
RDBLKX	RTS


W16BYTE	PHA		;write A to 16 bit device
	JSR SET16W
	PLA
	BCS W16BYTX
	JSR I2CWByte
	BCS W16BYTX
	JSR IPNT16
	JSR W16POLL
W16BYTX	RTS


W16PAGE	JSR SET16W	;write pages to 16 bit device
	BCS W16PAGX	;I2CDEV, PNT16, LENGTH, CURAD
W16PAG2	JSR DECLEN	;dec LENGTH
	BCS W16PAG1
	LDY #0
	LDA (CURAD),Y	;write byte
	JSR I2CWByte
	BCS W16PAGX
	JSR ICURAD	;inc CURAD
	JSR IPNT16	;inc PNT16
	LDA PNT16	;check for page boundary
	AND #$1F
	BNE W16PAG2
	JSR W16POLL	;wait for device ready
	BCC W16PAGE
W16PAGX	RTS

W16PAG1	JMP W16POLL	;wait for ready and finished


SET16W	LDA I2CDEV	;Set for 16 bit write
	JSR I2CADEV	;select dev
	BCS SET16WX
	JSR I2CR16	;set 16 bit reg
SET16WX	RTS


W16POLL	JSR I2CSTOP	;STOP condition
	LDA I2CDEV
	JMP I2CADEV	;wait for device ready


DECLEN	LDA LENGTH	;LENGTH = 0?
	BNE DECLEN1
	LDA LENGTH+1
	BEQ DECLEN2	;if yes then finished
	DEC LENGTH+1	;dec LENGTH
DECLEN1	DEC LENGTH
	CLC
	RTS

DECLEN2	SEC		;finished
	RTS


IPNT16	INC PNT16	;inc PNT16
	BNE IPNT16X
	INC PNT16+1
IPNT16X	RTS

;--------- I2C Commands ------------------------------

I2CCLR	JSR I2CStop	;clear I2C-Bus
	JSR I2CStart
	JSR DUP
	LDX #9		;dummy read 9 bits
CLR1	JSR CLK
	DEX
	BNE CLR1
	JSR I2CStart
	JMP I2CStop


I2CADEV	ASL A		;send 7 bit dev adr to write
	LDY #100	;try 100x = 30 ms
	STA BYTE+1
I2CWT2	JSR I2CStart
	LDA BYTE+1	;poll dev
	JSR I2CWByte
	BCC I2CWT1
	DEY
	BNE I2CWT2
I2CWT1	RTS		;C=1  I2C_BRK


I2CR16	LDA PNT16+1	;send PNT16 to dev
	JSR I2CWByte	;send high byte
	BCS R16X
	LDA PNT16
	JSR I2CWByte	;send low byte
R16X	RTS


I2CRDEV			;send 7 bit dev adr to read
	SEC
	ROL A		;set for read
	TAY
	JSR I2CSTART
	TYA
	JSR I2CWByte
	RTS

I2CWByte		;write byte in A to dev
	STA BYTE	;save A
	JSR DDN
	JSR CLKDN
	LDX #8		;send 8 bit
WByte2	JSR DUP
	ASL BYTE	;bit in C
	BCS WByte1
	JSR DDN		;if C=0
WBYTE1	JSR CLK
	DEX
	BNE WByte2
	JMP IS_ACK

I2CRBYTE		;read byte from dev
	JSR I2CRB	;read 1 byte
	JSR I2CACK
	TYA
	CLC		;Byte in A
	RTS

I2CRLB			;read last byte from dev
	JSR I2CRB	;read 1 byte
	JSR I2CNAK	;send NAK to terminate
	JSR I2CSTOP	
	TYA
	CLC		;Byte in A
	RTS


; I2C subroutines

I2CRB	LDY #0		; Y=0 to save byte
	JSR DUP
	LDX #8		;read 8 Bit
RByte1	JSR CLKUP	;SCL = 1
	JSR DIN		;Bit in C
	TYA
	ROL A
	TAY
	JSR CLKDN	;SCL = 0
	DEX
	BNE RBYTE1
	RTS		;byte in Y

; basic I2C states

I2CStart		;I2C start condition
	JSR DUP
	JSR CLKUP
	JSR DDN
	JSR CLKDN
	RTS

I2CStop			; I2C stop condition
	JSR DDN
	JSR CLKUP
	JSR DUP
	RTS

I2CACK	JSR DDN		; Master sends ACK
	JSR CLK
	JSR DUP		; release SDA
	RTS

I2CNAK	JSR DUP		; Master sends NAK
	JSR CLK
	RTS

IS_ACK	JSR DUP		;Check for ACK from dev
	JSR CLKUP
	JSR DIN		;ACK bit in C
	JSR CLKDN
	RTS		; C=0 is ACK


; Bit I/O for I2C  PB6 = SDA, PA0 = SCL

DUP	LDA DDRB	;SDA = 1
	AND #%10111111	;PB6 is Input
	STA DDRB
	RTS

DDN	LDA PORTB		;SDA = 0
	AND #%10111111	; PB6 = 0
	STA PORTB
	LDA DDRB
	ORA #%01000000	; PB6 is Output
	STA DDRB
	RTS

DIN	LDA PORTB		; read 1 bit in C
	ASL A
	ASL A		; now bit 6 is in C
	RTS

CLK	LDA PCR		; SCL = 1
	ORA #CLK_H	; PA0 is Output
	STA PCR
	AND #CLK_L		; SCL = 0
	STA PCR
	RTS

CLKUP	LDA PCR		; SCL = 1
	ORA #CLK_H	; CA2 is Output
	STA PCR
	RTS

CLKDN	LDA PCR		; SCL = 0
	AND #CLK_L
	STA PCR
	RTS


; --- non-zero page variables and buffers (page aligned) ---

MEM
	DS MEM/256+1*256-MEM,$FF	;page alignment

; The following tables are used to calculate the CRC for the 128 bytes
; in the xmodem data blocks. 

; low byte CRC lookup table (should be page aligned)

CRClo
 DB $00,$21,$42,$63,$84,$A5,$C6,$E7,$08,$29,$4A,$6B,$8C,$AD,$CE,$EF
 DB $31,$10,$73,$52,$B5,$94,$F7,$D6,$39,$18,$7B,$5A,$BD,$9C,$FF,$DE
 DB $62,$43,$20,$01,$E6,$C7,$A4,$85,$6A,$4B,$28,$09,$EE,$CF,$AC,$8D
 DB $53,$72,$11,$30,$D7,$F6,$95,$B4,$5B,$7A,$19,$38,$DF,$FE,$9D,$BC
 DB $C4,$E5,$86,$A7,$40,$61,$02,$23,$CC,$ED,$8E,$AF,$48,$69,$0A,$2B
 DB $F5,$D4,$B7,$96,$71,$50,$33,$12,$FD,$DC,$BF,$9E,$79,$58,$3B,$1A
 DB $A6,$87,$E4,$C5,$22,$03,$60,$41,$AE,$8F,$EC,$CD,$2A,$0B,$68,$49
 DB $97,$B6,$D5,$F4,$13,$32,$51,$70,$9F,$BE,$DD,$FC,$1B,$3A,$59,$78
 DB $88,$A9,$CA,$EB,$0C,$2D,$4E,$6F,$80,$A1,$C2,$E3,$04,$25,$46,$67
 DB $B9,$98,$FB,$DA,$3D,$1C,$7F,$5E,$B1,$90,$F3,$D2,$35,$14,$77,$56
 DB $EA,$CB,$A8,$89,$6E,$4F,$2C,$0D,$E2,$C3,$A0,$81,$66,$47,$24,$05
 DB $DB,$FA,$99,$B8,$5F,$7E,$1D,$3C,$D3,$F2,$91,$B0,$57,$76,$15,$34
 DB $4C,$6D,$0E,$2F,$C8,$E9,$8A,$AB,$44,$65,$06,$27,$C0,$E1,$82,$A3
 DB $7D,$5C,$3F,$1E,$F9,$D8,$BB,$9A,$75,$54,$37,$16,$F1,$D0,$B3,$92
 DB $2E,$0F,$6C,$4D,$AA,$8B,$E8,$C9,$26,$07,$64,$45,$A2,$83,$E0,$C1
 DB $1F,$3E,$5D,$7C,$9B,$BA,$D9,$F8,$17,$36,$55,$74,$93,$B2,$D1,$F0 

; hi byte CRC lookup table (should be page aligned)
		
CRChi
 DB $00,$10,$20,$30,$40,$50,$60,$70,$81,$91,$A1,$B1,$C1,$D1,$E1,$F1
 DB $12,$02,$32,$22,$52,$42,$72,$62,$93,$83,$B3,$A3,$D3,$C3,$F3,$E3
 DB $24,$34,$04,$14,$64,$74,$44,$54,$A5,$B5,$85,$95,$E5,$F5,$C5,$D5
 DB $36,$26,$16,$06,$76,$66,$56,$46,$B7,$A7,$97,$87,$F7,$E7,$D7,$C7
 DB $48,$58,$68,$78,$08,$18,$28,$38,$C9,$D9,$E9,$F9,$89,$99,$A9,$B9
 DB $5A,$4A,$7A,$6A,$1A,$0A,$3A,$2A,$DB,$CB,$FB,$EB,$9B,$8B,$BB,$AB
 DB $6C,$7C,$4C,$5C,$2C,$3C,$0C,$1C,$ED,$FD,$CD,$DD,$AD,$BD,$8D,$9D
 DB $7E,$6E,$5E,$4E,$3E,$2E,$1E,$0E,$FF,$EF,$DF,$CF,$BF,$AF,$9F,$8F
 DB $91,$81,$B1,$A1,$D1,$C1,$F1,$E1,$10,$00,$30,$20,$50,$40,$70,$60
 DB $83,$93,$A3,$B3,$C3,$D3,$E3,$F3,$02,$12,$22,$32,$42,$52,$62,$72
 DB $B5,$A5,$95,$85,$F5,$E5,$D5,$C5,$34,$24,$14,$04,$74,$64,$54,$44
 DB $A7,$B7,$87,$97,$E7,$F7,$C7,$D7,$26,$36,$06,$16,$66,$76,$46,$56
 DB $D9,$C9,$F9,$E9,$99,$89,$B9,$A9,$58,$48,$78,$68,$18,$08,$38,$28
 DB $CB,$DB,$EB,$FB,$8B,$9B,$AB,$BB,$4A,$5A,$6A,$7A,$0A,$1A,$2A,$3A
 DB $FD,$ED,$DD,$CD,$BD,$AD,$9D,$8D,$7C,$6C,$5C,$4C,$3C,$2C,$1C,$0C
 DB $EF,$FF,$CF,$DF,$AF,$BF,$8F,$9F,$6E,$7E,$4E,$5E,$2E,$3E,$0E,$1E

	;---- Tables ----

CMDTAB	DB 'B'
	DD SETBRK-1
	DB 'D'
	DD DUMP-1
	DB 'E'
	DD ENTER-1
	DB 'G'
	DD GO-1
	DB 'L'
	DD LIST-1
	DB 'R'
	DD READ-1
	DB 'S'
	DD SET-1
	DB 'F'
	DD FETCH-1
	DB 'A'
	DD ADDID-1
	DB 'P'
	DD PULLID-1
	DB 'T'
	DD TIME-1
	DB 'K'
	DD DATE-1
	DB 'I'
	DD I2CINFO-1

	DB $00

LENTAB	DB 2,2,2,4,2,2,2,4,1,2,1,4,3,3,3,4
RTAB	DB 'AXYS'
FTAB	DB 'CZIDB',0,'VN'

	;---- Messages ----

INITM	DB CR,LF,' SBC-65 I2C MONITOR V',VERSION/16+$30,'.',VERSION*$1000/$1000+$30
	DB CR,LF,EOT
PROMPTM	DB CR,LF,'>',EOT
ERROR	DB CR,LF,'* Error *',EOT
BRKM	DB CR,LF,'BREAK',EOT
INFO_M	DB CR, LF,' I2C devices active',CR,LF
	DB 'dev W  R',CR,LF,EOT

	;----	NMI ROUTINE	----

NMI	JMP (NMIV)		;DEFAULT START

	;----	IRQ ROUTINE	----

IRQ	STA ACCU	;save ACCU
	PLA		;GET STATUS REGISTER
	PHA
	AND #%00010000	;BREAK?
	BNE UBRK
	LDA ACCU
	JMP (IRQV)	;invoke user IRQ routine
	

UBRK	STY YREG
	STX XREG
	PLA
	STA STATUS
	PLA
	STA PC
	PLA
	STA PC+1
	TSX
	STX STACK
	SEC
	LDA PC
	SBC #2		;PC=PC-2
	STA PC
	BCS UBRK1
	DEC PC+1
UBRK1	LDA #BRKM	;DISPLAY BREAK MESSAGE
	LDY #BRKM/256
	JSR PRTSTR
	LDA PC
	CMP BRKADR	;check BRK adr
	BNE UBRK5
	LDA PC+1
	CMP BRKADR+1
	BNE UBRK5
	LDY #0
	LDA BRKBYT	;restore OPCODE
	STA (PC),Y
UBRK2	LDA PC
	STA CURAD
	LDA PC+1
	STA CURAD+1
	JSR DASM	;print opcode
	JSR DISREG	;print recisters
	JMP LOOP

UBRK5	JMP LPERR	;Error

;-------  Initialisation  -------

INITVAR	LDA #INBUF	;IN = INBUF
	STA IN
	LDA #INBUF/256
	STA IN+1
	LDA #RESET	;set CURAD = RESET
	STA CURAD
	LDA #RESET/256
	STA CURAD+1
	LDA #UIRQ	;set default user IRQ vektor
	STA IRQV
	LDA #UIRQ/256
	STA IRQV+1
	LDA #START	;set default user NMI vektor
	STA NMIV
	LDA #START/256
	STA NMIV+1
	RTS

;-------  TERMINAL I/O-ROUTINES 1200 - 38400 Baud  -------

MEM1
	DS MEM1/256+1*256-MEM1,$FF	;page alignment

CHRIN	SEI		;BIOS chr input with IRQ disabled
	STY YBUF
	JSR D_CHRIN
	LDY YBUF
	CLI
	RTS


D_CHRIN			;CHR input if C=0: CHR in A, 8 bit transparent
	LDY #$FF	;	      C=1  no CHR after 0,4s
	TYA		;setup delay approx. 0.4 sec
	SEC
CHRIN3	SBC #1
	BCC CHRIN4
CHRIN5	BIT PORTB	;GET CHR FROM CON to CHR, destroys Y
	BMI CHRIN3	;WAIT FOR START BIT on PB7
	LDY #8		;SET FOR 8 BITS
	PHA		;DELAY 7 us
	PLA		;38400 BAUD
CHRIN1	JSR CHRIN6	;DELAY 12 us
	LDA PORTB	;GET ONE BIT
	ASL A		;shift BIT in C
	ROR CHR		;ROTATE BIT INTO CHR
	DEY
	BNE CHRIN1
	LDA CHR		;CHR received, stopbit ignored
	CLC
CHRIN6	RTS

CHRIN4	DEY
	SEC
	BNE CHRIN5
	SEC		;no chr received
	RTS


CHROUT	SEI		;BIOS chr output with IRQ disabled
	STY YBUF
	JSR D_CHROUT
	LDY YBUF
	CLI
	RTS


D_CHROUT		;PRINTS CHR in A TO CON, destroys Y
	STA CHR		;8 bit transparent
	LDA PCR
	ORA #CB2H	;CB2 = 1
	STA PCR
	CMP (0),Y	;delay 5 us
	AND #CB2L	;START BIT
	STA PCR
	NOP		;DELAY 2 us
	LDY #8		;SEND 8 BITS
CHROUT1	LSR CHR		;SHIFT OUT 1 BIT
	LDA PCR
	BCS CHROUT3	;symmetric timing
	AND #CB2L	;'0
	BCC CHROUT2
CHROUT3	ORA #CB2H	;'1
	BCC CHROUT2
CHROUT2	STA PCR
	NOP
	DEY
	BNE CHROUT1
	LDA PCR		;SEND 1 STOP BIT
	ORA #CB2H	;NO PARITY
	STA PCR
	RTS


INITCON			;initialize VIA for serial CON
	LDA #DEFACR
	STA ACR
	LDA #DEFPCR
	STA PCR
	RTS

;----------------------------------------

FREE
	DS $FFFA-FREE, $FF		;VEKTOREN AB $FFFA

	DW NMI
	DW RESET
	DW IRQ
	
	END
