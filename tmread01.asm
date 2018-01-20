
#include P16F84A.inc
	__CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC
        __IDLOCS H'6969'

;	iButton reader (1-wire bus) pin
TMPort		equ	PORTA
TMPin		equ	4
TMMask		equ	0x10
;	Buzzer pin
BzPort		equ	PORTB
BzPin		equ	2
;BzPin		equ	1
;	Config button
JPort		equ	PORTB
JPin		equ	4
;	Door lock output
LockPort	equ	PORTB
LockPin		equ	7



LoopReg		equ	0x0C
ComReg		equ	0x0D
RDByte		equ	0x0E
RDLoop		equ	0x0F
BTM1		equ	0x10
BTM2		equ	0x11
BTM3		equ	0x12
BTM4		equ	0x13

RESET CODE 0x0000
    GOTO Beginning

MAIN CODE

Beginning
	CLRF	INTCON
        BSF     STATUS, RP0     ;       Page #2
        MOVLW   0xC8            ;       Settings:
                                ;       - divider 1:1
                                ;       - pullups off
                                ;       - divider to WDT
                                ;       - clock RTCC
        MOVWF   OPTION_REG
	BCF	TRISA, TMPin    ;       iButton readet - out
	BCF	TRISB, 1	;	debug LED - out
	BCF	TRISB, BzPin	;	buzzer - out
	BCF	TRISB, LockPin	;	door lock - out
	BSF	TRISB, JPin	;	config button - in
        BCF     STATUS, RP0     ;       Page #1

	BCF	LockPort, LockPin      ;Lock the door
	BCF	BzPort, BzPin           

	BSF	TMPort, TMPin	;	High level to 1-wire bus
	BCF	PORTB, 1

;---	Testing the Setup button
	BTFSC	JPort, JPin
	GOTO	NoConfig	;	Jump to main loop if not pressed

;-------------------------------------------------
;	Configuration mode
;-------------------------------------------------
	CALL	BeepOnce	;	Beeping to indicate entering config mode
;---	Erasing the whole key memory (up to 3Fh)
	MOVLW	0x3F
	MOVWF	LoopReg
 	CLRF	EEADR
	CLRF	EEDATA
	COMF	EEDATA

CLRL
        BSF     STATUS, RP0     ;       Page #2
	BSF	EECON1, WREN
	MOVLW	0x55
	MOVWF	EECON2
	MOVLW	0xAA
	MOVWF	EECON2
	BSF	EECON1, WR
	BTFSS	EECON1, EEIF
	GOTO	$-1
	BCF	EECON1, EEIF
        BCF     STATUS, RP0     ;       Page #1
	INCF	EEADR
	DECFSZ	LoopReg, F
	GOTO	CLRL
	CALL	BeepOnce	;	Beep again

 	CLRF	EEADR		;	Starting write from the beginning

WaitForKey
	CALL	PresenceCheck	;	Check if something is present on 1-wire bus
	ANDLW	0xFF		;	If not - ignore
	BTFSS	STATUS, Z
	GOTO	NoKeyConfig	;	Nothing is here

	CALL	ReadKeySID	;	May be an error if fID != 1
	ANDLW	0xFF		;	Ignore key if there's an error
	BTFSS	STATUS, Z
	GOTO	NoKeyConfig	;	Nothing is here

;---	Write a key to EEPROM
	MOVF	BTM1, W
	CALL	EEWrite
	INCF	EEADR
	MOVF	BTM2, W
	CALL	EEWrite
	INCF	EEADR
	MOVF	BTM3, W
	CALL	EEWrite
	INCF	EEADR
	MOVF	BTM4, W
	CALL	EEWrite
	INCF	EEADR
	CALL	BeepOnce	;	Confirming beep
	
;---	Wait till key will be removed
KeyPresent
	CALL	PresenceCheck	;	If it's still here
	ANDLW	0xFF
	BTFSC	STATUS, Z
	GOTO	KeyPresent

NoKeyConfig
	CALL	SetToOutput	;	Set 1-wire but to output and high
	BSF	TMPort, TMPin
	CALL	SleepDelay
	GOTO	WaitForKey

;-------------------------------------------------
;	Main working mode
;-------------------------------------------------
NoConfig
;---	Checking if there's at least one key in EEPROM
	CLRF	EEADR
	MOVLW	0x40
	MOVWF	LoopReg
CheckL
	CALL	EERead
	MOVWF	RDByte
	INCF	EEADR
	INCFSZ	RDByte, F	;	Exit the loop if it's not 0FFh
	GOTO	MainKey
	DECFSZ	LoopReg, F
	GOTO	CheckL
	BSF	BzPort, BzPin	;	Beeping constantly...
	GOTO	$		;	... and infinitely
	

;---	The main cycle
MainKey	
	CALL	PresenceCheck	;	Check if anything present on the 1-wire bus
	ANDLW	0xFF		;	Nothing found, ignore the rest
	BTFSS	STATUS, Z
	GOTO	NoKey

	CALL	ReadKeySID	;	Reading out the key
	ANDLW	0xFF		;	Ignore it, if there was a read error
	BTFSS	STATUS, Z
	GOTO	NoKey

;---	Key recognition section
	CLRF	EEADR
	MOVLW	0x0A
	MOVWF	LoopReg

ReadAgain
	CLRF	ComReg		;	Compare register

	CALL	EERead		;	Read a byte from EEPROM key memory
	XORWF	BTM1, W		;	and compare with the received byte
	BTFSS	STATUS, Z
	INCF	ComReg
	INCF	EEADR

	CALL	EERead
	XORWF	BTM2, W
	BTFSS	STATUS, Z
	INCF	ComReg
	INCF	EEADR

	CALL	EERead
	XORWF	BTM3, W
	BTFSS	STATUS, Z
	INCF	ComReg
	INCF	EEADR

	CALL	EERead
	XORWF	BTM4, W
	BTFSS	STATUS, Z
	INCF	ComReg
	INCF	EEADR

;---	If a key will match, the comreg=0
;---    2018 UPDATE: there's a bug. The door will open a 0xFFFFFFFF fake key

	MOVLW	0xFF
	ANDWF	ComReg, F
	BTFSS	STATUS, Z
	GOTO	IncorrectKey
	GOTO	KeyFound	;	If a key matched, go further

IncorrectKey
	DECFSZ	LoopReg
	GOTO	ReadAgain
	GOTO	NoKey

KeyFound
;	BSF	PORTB, 1	;	Debug LED
;	GOTO	$
	CALL	ReleaseLock	;	Now you can open the lock

NoKey
	CALL	SetToOutput	;	Set 1-wire but to output and high
	BSF	TMPort, TMPin

	CALL	SleepDelay	;	Have some sleep
	GOTO	MainKey		;	and continue the main cycle

;-----------------------------------------------------------
;       ReadKeySID subroutine
;	1-wire bus TX a read command
;	then RX a key SID returning 0xFF on error, 0 when ok
ReadKeySID
	CALL	SetToOutput

;--	Send a read command (33h)
;	TXing

	MOVLW	0x33
	MOVWF	RDByte
	MOVLW	0x08
	MOVWF	LoopReg

Nbl1
	CALL	Relaxation
	BCF	TMPort, TMPin	;	Clock the bus
	NOP
	NOP
	NOP
	RRF	RDByte, F
	BTFSS	STATUS, C
	BCF	TMPort, TMPin
	BTFSC	STATUS, C
	BSF	TMPort, TMPin
	MOVLW	0xFF-0x25
	CALL	Delay
	DECFSZ	LoopReg, F
	GOTO	Nbl1


	BSF	TMPort, TMPin	;	Setting to high, slave waits the next edge

;--	Reading data from 1-wire bus
;	A family code byte. If it's not 01h we can't handle it

	CALL	ReadKeyByte
	MOVF	RDByte, W
	XORLW	0x01
	BTFSS	STATUS, Z
	RETLW	0xFF		;	Family code != 01h

;--	Reading the next 4 bytes
	CALL	ReadKeyByte
	MOVF	RDByte, W
	MOVWF	BTM1
	CALL	ReadKeyByte
	MOVF	RDByte, W
	MOVWF	BTM2
	CALL	ReadKeyByte
	MOVF	RDByte, W
	MOVWF	BTM3
	CALL	ReadKeyByte
	MOVF	RDByte, W
	MOVWF	BTM4
	
;---    Some old debug code
;	MOVLW	0x06
;	MOVWF	LoopReg
; 	CLRF	EEADR
;
;RL
;	CALL	ReadKeyByte
;	MOVF	RDByte, W
;	MOVWF	EEDATA
;       BSF     STATUS, RP0     ;       Page #2
;	BSF	EECON1, WREN
;	MOVLW	0x55
;	MOVWF	EECON2
;	MOVLW	0xAA
;	MOVWF	EECON2
;	BSF	EECON1, WR
;	BTFSS	EECON1, EEIF
;	GOTO	$-1
;	BCF	EECON1, EEIF
;       BCF     STATUS, RP0     ;       Page #1
;	INCF	EEADR
; 
;	DECFSZ	LoopReg, F
;	GOTO	RL
;
;	BSF	PORTB, 1	;	Debug LED on
;	GOTO	$


	RETLW	0

;-----------------------------------------------------------
;       ReadKeyByte subroutine
;	RX a byte from 1-wire bus to RDByte
ReadKeyByte
	CLRF	RDByte
	MOVLW	0x08
	MOVWF	RDLoop
	CALL	SetToOutput
BLoop
	CALL	Relaxation
	BCF	TMPort, TMPin	;	Clock a slave
	NOP
	NOP
	NOP
	CALL	SetToInput
	NOP
	MOVF	PORTA, W	;	Receiving data
	CALL	SetToOutput
	BSF	TMPort, TMPin	;	Setting the bus to high
	ANDLW	TMMask
	BTFSC	STATUS, Z	;	If it's "0"
	BCF	STATUS, C
	BTFSS	STATUS, Z	;	If it's "1"
	BSF	STATUS, C
	RRF	RDByte, F	;	Pushing the bit
	MOVLW	0xF5
	CALL	Delay
	DECFSZ	RDLoop, F
	GOTO	BLoop

	RETURN
;----------------------------------------------------------------------
;--	1-Wire BUS subroutines
;----------------------------------------------------------------------
;	Relaxing the bus with a positive edge
Relaxation
	BSF	TMPort, TMPin
	NOP
	NOP
	NOP
	RETURN

;	Delay for W us
Delay
	ADDLW	0x07	;	7us correction
	MOVWF	TMR0
Lp	BTFSS   INTCON, T0IF
        GOTO    Lp
        BCF     INTCON, T0IF
	RETURN

;	Setting port to input (4 us)
SetToInput	
        BSF     STATUS, RP0     ;       Page #2
	BSF	TRISA, TMPin    ;       Setting to input   
        BCF     STATUS, RP0     ;       Page #1
	RETURN

;	Setting port to output (4 us)
SetToOutput	
        BSF     STATUS, RP0     ;       Page #2
	BCF	TRISA, TMPin    ;       Setting to output
        BCF     STATUS, RP0     ;       Page #1
	RETURN

;----------------------------------------------------------------------
;--	Misc. subroutines
;----------------------------------------------------------------------
;	Write W to EEPROM. EEADR should be set.
EEWrite
	MOVWF	EEDATA
	BSF     STATUS, RP0     ;       Page #2
	BSF	EECON1, WREN
	MOVLW	0x55
	MOVWF	EECON2
	MOVLW	0xAA
	MOVWF	EECON2
	BSF	EECON1, WR
	BTFSS	EECON1, EEIF
	GOTO	$-1
	BCF	EECON1, EEIF
	BCF     STATUS, RP0     ;       Page #1

	RETURN

;	Read from EEPROM into W. EEADR should be set.
EERead
	BSF     STATUS, RP0     ;       Page #2
	BSF	EECON1, RD	;	Reading the memory
	BCF     STATUS, RP0     ;       Page #1
	NOP
	NOP
	MOVF	EEDATA, W
	RETURN

;	Probing if a key is present on a bus. Returning 0FFh if not
PresenceCheck

;---	Resetting a whole 1-wire bus: dropping to 0 for 480us.
	BCF	TMPort, TMPin	;	Dropping low.
	CLRF	TMR0
        BCF     INTCON, T0IF
Lpk1    BTFSS   INTCON, T0IF	;	Waiting for ~256 us
        GOTO    Lpk1
        BCF     INTCON, T0IF
	MOVLW	0x30
	MOVWF	TMR0
Lpk2    BTFSS   INTCON, T0IF	;	And ~224 us
        GOTO    Lpk2
        BCF     INTCON, T0IF

	BSF	TMPort, TMPin	;	Setting back high.

	CALL	SetToInput

;---	There should be 1 immediately after reset.
	MOVF	PORTA, W	;	Bus data input
	ANDLW	TMMask
	BTFSC	STATUS, Z	;	Testing for a zero
	RETLW	0xFF		;	This is not a key, returning.



	MOVLW	0xBF
	MOVWF	TMR0
Lpk3    BTFSS   INTCON, T0IF	;	Wait for a presence pulse ~35 us
        GOTO    Lpk3
        BCF     INTCON, T0IF
	MOVF	PORTA, W	;	Bus data input
	ANDLW	TMMask

	BTFSS	STATUS, Z	;	Testing for a 1
	RETLW	0xFF		;	This is not a key, returning.

	CALL	SetToOutput
	BSF	TMPort, TMPin

;---	Waiting 480us for the key recovering after a reset
	CLRF	TMR0
        BCF     INTCON, T0IF
Lpw1    BTFSS   INTCON, T0IF	;	Delay ~256us
        GOTO    Lpw1
        BCF     INTCON, T0IF
	MOVLW	0x30
	MOVWF	TMR0
Lpw2    BTFSS   INTCON, T0IF	;	Delay ~224us
        GOTO    Lpw2
        BCF     INTCON, T0IF

	RETLW	0

;	A sleep subroutine for the main cycle
SleepDelay

;	Making sure the timer is set up correctly for the delay counting
        BSF     STATUS, RP0     ;       Page #2
        MOVLW   0xC7            ;       Setup:
                                ;       - prescaler 1:256
                                ;       - pullups off
                                ;       - prescaler to RTCC
                                ;       - RTCC to the main clock
        MOVWF   OPTION_REG
        BCF     STATUS, RP0     ;       Page #1
	CLRF	TMR0
	CLRW
	CALL	Delay
	CLRW
	CALL	Delay
        BSF     STATUS, RP0     ;       Page #2
        MOVLW   0xC8            ;       Setup:
                                ;       - prescaler 1:1
                                ;       - pullups off
                                ;       - prescaler to WDT
                                ;       - RTCC to the main clock
        MOVWF   OPTION_REG
        BCF     STATUS, RP0     ;       Page #1

	RETURN

;	Beep just once
BeepOnce

	BSF	BzPort, BzPin	;	Buzzer on
	CALL	SleepDelay
	BCF	BzPort, BzPin	;	Buzzer off
	RETURN

;	Open the lock and beep
ReleaseLock

	BSF	BzPort, BzPin
	BSF	LockPort, LockPin
	MOVLW	0x06
	MOVWF	LoopReg
BeepL	CALL	SleepDelay
	DECFSZ	LoopReg, F
	GOTO	BeepL

	BCF	BzPort, BzPin
	BCF	LockPort, LockPin

	RETURN

	END
