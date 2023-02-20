;Blinky
;SBC65 test program
;V1.0	17.02.23		original version
;V1.1	17.02.23		version for SBC65 V1.1	

START	= $130

OUT	= $5000

VIA	= $6000		;6522 VIA
PORTB	= VIA
DDRB	= VIA+2
PORTA	= VIA+15
DDRA	= VIA+3

;ROM calls
ROM	= $F800
DELAY	= ROM+12

LEDon	= $FE
LEDoff	= $FF

	ORG START

INIT	LDA DDRB
	ORA $01
	STA DDRB	;PA0 is output

LOOP	LDA #LEDoff	;LED off
	STA OUT
	LDA #$01
	STA PORTB
	LDY #5
	JSR DELAY	;wait 500 ms
	LDA #LEDon	;LED on
	STA OUT
	LDA #$00
	STA PORTB
	LDY #5
	JSR DELAY	;wait 500 ms
	JMP LOOP

	END 