
#include P16C84.inc
	__CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC
        __IDLOCS H'6969'

;	��� ��室���� ���뢠⥫�
TMPort		equ	PORTA
TMPin		equ	4
TMMask		equ	0x10
;	��� ��頫��
BzPort		equ	PORTB
BzPin		equ	2
;BzPin		equ	1
;	��� ������� ���䨣��樨
JPort		equ	PORTB
JPin		equ	4
;	��� �����
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

Beginning
	CLRF	INTCON
        BSF     STATUS, RP0     ;       ��࠭�� #2
        MOVLW   0xC8            ;       ����ன��:
                                ;       - �।���⥫� 1:1
                                ;       - ����㧪� �⪫�祭�
                                ;       - �।���⥫� � WDT
                                ;       - RTCC � ��������
        MOVWF   OPTION_REG
	BCF	TRISA, TMPin    ;       ���뢠⥫� - �� �뢮�
	BCF	TRISB, 1	;	�⫠���� �������� - �� �뢮�
	BCF	TRISB, BzPin	;	��頫�� - �� �뢮�
	BCF	TRISB, LockPin	;	����� - �� �뢮�
	BSF	TRISB, JPin	;	������� - �� ����
        BCF     STATUS, RP0     ;       ��࠭�� #1

	BCF	LockPort, LockPin	;��������� ������� �����!
	BCF	BzPort, BzPin

	BSF	TMPort, TMPin	;	�⠢�� ������� �� ���뢠⥫�.
	BCF	PORTB, 1

;---	�஢�ਬ, ������� �� ������� ���䨣��樨
	BTFSC	JPort, JPin
	GOTO	NoConfig	;	��� ����� ���䨣��樨 - ���� �����

;-------------------------------------------------
;	����� ���䨣��樨 ����஫���
;-------------------------------------------------
	CALL	BeepOnce	;	���� ����� - ��騬
;---	���⨬ ��� ������ ���祩 (�� 3Fh)
	MOVLW	0x3F
	MOVWF	LoopReg
 	CLRF	EEADR
	CLRF	EEDATA
	COMF	EEDATA

CLRL
        BSF     STATUS, RP0     ;       ��࠭�� #2
	BSF	EECON1, WREN
	MOVLW	0x55
	MOVWF	EECON2
	MOVLW	0xAA
	MOVWF	EECON2
	BSF	EECON1, WR
	BTFSS	EECON1, EEIF
	GOTO	$-1
	BCF	EECON1, EEIF
        BCF     STATUS, RP0     ;       ��࠭�� #1
	INCF	EEADR
	DECFSZ	LoopReg, F
	GOTO	CLRL
	CALL	BeepOnce	;	����� ��騬

 	CLRF	EEADR		;	��稭��� ������ ᭠砫�

WaitForKey
	CALL	PresenceCheck	;	�஢��塞, ���� �� ����
	ANDLW	0xFF		;	�᫨ ��� ��� - ������㥬
	BTFSS	STATUS, Z
	GOTO	NoKeyConfig	;	��� ����

	CALL	ReadKeySID	;	����� ������ �訡�� �� fID != 1
	ANDLW	0xFF		;	�᫨ �訡�� - ������㥬
	BTFSS	STATUS, Z
	GOTO	NoKeyConfig	;	��� ����

;---	�����뢠�� ���� � ������
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
	CALL	BeepOnce	;	��騬, ���⢥ত�� ������
	
;---	������ ����, ���� ���� 㡥���
KeyPresent
	CALL	PresenceCheck	;	�஢��塞, ���� �� ����
	ANDLW	0xFF
	BTFSC	STATUS, Z
	GOTO	KeyPresent

NoKeyConfig
	CALL	SetToOutput	;	���� ���� - �뢮��� ������� � ����
	BSF	TMPort, TMPin
	CALL	SleepDelay
	GOTO	WaitForKey

;-------------------------------------------------
;	�᭮���� ०�� ����஫���
;-------------------------------------------------
NoConfig
;---	����� �஢��塞, ���� �� � ����� ��� ���� ����
	CLRF	EEADR
	MOVLW	0x40
	MOVWF	LoopReg
CheckL
	CALL	EERead
	MOVWF	RDByte
	INCF	EEADR
	INCFSZ	RDByte, F	;	�᫨ ���⠭� �� FFh - ��室��
	GOTO	MainKey
	DECFSZ	LoopReg, F
	GOTO	CheckL
	BSF	BzPort, BzPin	;	�᫨ ��諮 � - ������ ���㫥�a
	GOTO	$		;	��騬 � ��ᨬ...
	

;---	������ 横� �������� � �ᯮ�������� ����	
MainKey	
	CALL	PresenceCheck	;	�஢��塞, ���� �� ����
	ANDLW	0xFF		;	�᫨ ��� ��� - ������㥬
	BTFSS	STATUS, Z
	GOTO	NoKey

	CALL	ReadKeySID	;	��⠥� ���� � ����� �����
	ANDLW	0xFF		;	�᫨ �訡�� - ������㥬
	BTFSS	STATUS, Z
	GOTO	NoKey

;---	������ ᥪ�� �ᯮ�������� ����
	CLRF	EEADR
	MOVLW	0x0A
	MOVWF	LoopReg

ReadAgain
	CLRF	ComReg		;	������� �ࠢ�����

	CALL	EERead		;	��⠥� ����� �� �����
	XORWF	BTM1, W		;	� �஢��塞 �� �� �����筮���
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

;---	�᫨ ���� ᮢ����� - �� �㤥� �� ������ ���६���, comreg=0
	MOVLW	0xFF
	ANDWF	ComReg, F
	BTFSS	STATUS, Z
	GOTO	IncorrectKey
	GOTO	KeyFound	;	�᫨ �� ��襫 - ���� ᮢ���

IncorrectKey
	DECFSZ	LoopReg
	GOTO	ReadAgain
	GOTO	NoKey

KeyFound
;	BSF	PORTB, 1	;	����砥� �⫠���� �������� � ��
;	GOTO	$
	CALL	ReleaseLock	;	������ ����� ������ �����

NoKey
	CALL	SetToOutput	;	���� ���� - �뢮��� ������� � ����
	BSF	TMPort, TMPin

	CALL	SleepDelay	;	������ ������� ���� ��� "����"
	GOTO	MainKey		;	"� ���� �뫠 ᮡ���..."


;	���뫪� ������� �⥭�� �਩���� �����
;	� �⥭�� SID ���� � ���� � �����⮬ 0FF �� �訡��, ���� - 0
ReadKeySID
	CALL	SetToOutput

;--	���뫪� ������� �⥭�� (33h)
;	��।��� 

	MOVLW	0x33
	MOVWF	RDByte
	MOVLW	0x08
	MOVWF	LoopReg

Nbl1
	CALL	Relaxation
	BCF	TMPort, TMPin	;	�����㥬 ���� ��९����
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


	BSF	TMPort, TMPin	;	"�������" ���� - ���� ���� ᫥�. ��९��

;--	������ ��⠥��� ⮫쪮 ������ �����
;	��⠥� 1 ���� family code. �᫨ �� 01h - �����頥� �訡��

	CALL	ReadKeyByte
	MOVF	RDByte, W
	XORLW	0x01
	BTFSS	STATUS, Z
	RETLW	0xFF		;	Family code != 01h

;--	��⠥� � ��࠭塞 4 ���� ������ ����
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

;	MOVLW	0x06
;	MOVWF	LoopReg
; 	CLRF	EEADR
;
;RL
;	CALL	ReadKeyByte
;	MOVF	RDByte, W
;	MOVWF	EEDATA
;       BSF     STATUS, RP0     ;       ��࠭�� #2
;	BSF	EECON1, WREN
;	MOVLW	0x55
;	MOVWF	EECON2
;	MOVLW	0xAA
;	MOVWF	EECON2
;	BSF	EECON1, WR
;	BTFSS	EECON1, EEIF
;	GOTO	$-1
;	BCF	EECON1, EEIF
;       BCF     STATUS, RP0     ;       ��࠭�� #1
;	INCF	EEADR
; 
;	DECFSZ	LoopReg, F
;	GOTO	RL
;
;	BSF	PORTB, 1	;	����砥� �⫠���� �������� � ��
;	GOTO	$


	RETLW	0

;	�⥭�� ���� �� ���� � RDByte
ReadKeyByte
	CLRF	RDByte
	MOVLW	0x08
	MOVWF	RDLoop
	CALL	SetToOutput
BLoop
	CALL	Relaxation
	BCF	TMPort, TMPin	;	�����㥬 ���� ��९����
	NOP
	NOP
	NOP
	CALL	SetToInput
	NOP
	MOVF	PORTA, W	;	������ ����� � ����
	CALL	SetToOutput
	BSF	TMPort, TMPin	;	"�������" ���� - ���� ���� ᫥�. ��९��
	ANDLW	TMMask
	BTFSC	STATUS, Z	;	�᫨ ���⠫� "0"
	BCF	STATUS, C
	BTFSS	STATUS, Z	;	�᫨ ���⠫� "1"
	BSF	STATUS, C
	RRF	RDByte, F	;	��������� ��।��� ���
	MOVLW	0xF5
	CALL	Delay
	DECFSZ	RDLoop, F
	GOTO	BLoop

	RETURN
;----------------------------------------------------------------------
;--	�ᯮ����⥫�� ����ணࠬ�� ��⮪��� "1WireBUS"
;----------------------------------------------------------------------
;	�������� 設� ������⥫�� �஭⮬
Relaxation
	BSF	TMPort, TMPin
	NOP
	NOP
	NOP
	RETURN

;	����প� �� W us
Delay
	ADDLW	0x07	;	���४��㥬 �� 7 ���
	MOVWF	TMR0
Lp	BTFSS   INTCON, T0IF
        GOTO    Lp
        BCF     INTCON, T0IF
	RETURN

;	��ॢ���� ���� � ०�� ����� (4 ���)
SetToInput	
        BSF     STATUS, RP0     ;       ��࠭�� #2
	BSF	TRISA, TMPin    ;       ����ࠨ���� ���� �� ����
        BCF     STATUS, RP0     ;       ��࠭�� #1
	RETURN

;	��ॢ���� ���� � ०�� �뢮�� (4 ���)
SetToOutput	
        BSF     STATUS, RP0     ;       ��࠭�� #2
	BCF	TRISA, TMPin    ;       ����ࠨ���� ���� �� ����
        BCF     STATUS, RP0     ;       ��࠭�� #1
	RETURN

;----------------------------------------------------------------------
;--	��⠫�� �ᯮ����⥫�� ����ணࠬ��
;----------------------------------------------------------------------
;	������ � EEPROM. EEADR � W (EEDATA) ������ ���� ��⠭������.
EEWrite
	MOVWF	EEDATA
	BSF     STATUS, RP0     ;       ��࠭�� #2
	BSF	EECON1, WREN
	MOVLW	0x55
	MOVWF	EECON2
	MOVLW	0xAA
	MOVWF	EECON2
	BSF	EECON1, WR
	BTFSS	EECON1, EEIF
	GOTO	$-1
	BCF	EECON1, EEIF
	BCF     STATUS, RP0     ;       ��࠭�� #1

	RETURN

;	�⥭�� �� EEPROM � W. EEADR ����e� ���� ��⠭�����.
EERead
	BSF     STATUS, RP0     ;       ��࠭�� #2
	BSF	EECON1, RD	;	��⠥� ������
	BCF     STATUS, RP0     ;       ��࠭�� #1
	NOP
	NOP
	MOVF	EEDATA, W
	RETURN

;	�஢�ઠ ������⢨� ����. �᫨ ��� - �����頥� 0FFh
PresenceCheck

;---	�஢�ઠ ������⢨� ���� - "��ᠦ������" ��⠭�� �� 480 ���.
	BCF	TMPort, TMPin	;	�⠢�� ���� �� ���뢠⥫�.
	CLRF	TMR0
        BCF     INTCON, T0IF
Lpk1    BTFSS   INTCON, T0IF	;	���� ~256 ���
        GOTO    Lpk1
        BCF     INTCON, T0IF
	MOVLW	0x30
	MOVWF	TMR0
Lpk2    BTFSS   INTCON, T0IF	;	���� �� ~224 ���
        GOTO    Lpk2
        BCF     INTCON, T0IF

	BSF	TMPort, TMPin	;	�⠢�� ������� �� ���뢠⥫�.

	CALL	SetToInput

;---	�ࠧ� ��᫥ ��� ������ ������ �������.
	MOVF	PORTA, W	;	������ ����� � ���� � �뤥�塞 ��
	ANDLW	TMMask
	BTFSC	STATUS, Z	;	�᫨ � ���. ���㫥��� ���祭�� - ���室��
	RETLW	0xFF		;	���� ��� - �室��.



	MOVLW	0xBF
	MOVWF	TMR0
Lpk3    BTFSS   INTCON, T0IF	;	���� ������ ������⢨� ~35 ���
        GOTO    Lpk3
        BCF     INTCON, T0IF
	MOVF	PORTA, W	;	������ ����� � ���� � �뤥�塞 ��
	ANDLW	TMMask

	BTFSS	STATUS, Z	;	�᫨ � ���. ���㫥��� ���祭�� - �� ��६�窠
	RETLW	0xFF		;	���� ��� - �室��.

	CALL	SetToOutput
	BSF	TMPort, TMPin

;---	������ ���� 480 ��� ��� ����⠭������� ���� ��᫥ ���
	CLRF	TMR0
        BCF     INTCON, T0IF
Lpw1    BTFSS   INTCON, T0IF	;	���� ~256 ���
        GOTO    Lpw1
        BCF     INTCON, T0IF
	MOVLW	0x30
	MOVWF	TMR0
Lpw2    BTFSS   INTCON, T0IF	;	���� �� ~224 ���
        GOTO    Lpw2
        BCF     INTCON, T0IF

	RETLW	0

;	���� ��㧠 ����� ���ᠬ� ����
SleepDelay

;	����ࠨ���� ������ ��� �뤥প� ����
        BSF     STATUS, RP0     ;       ��࠭�� #2
        MOVLW   0xC7            ;       ����ன��:
                                ;       - �।���⥫� 1:256
                                ;       - ����㧪� �⪫�祭�
                                ;       - �।���⥫� � RTCC
                                ;       - RTCC � ��������
        MOVWF   OPTION_REG
        BCF     STATUS, RP0     ;       ��࠭�� #1
	CLRF	TMR0
	CLRW
	CALL	Delay
	CLRW
	CALL	Delay
        BSF     STATUS, RP0     ;       ��࠭�� #2
        MOVLW   0xC8            ;       ����ன��:
                                ;       - �।���⥫� 1:1
                                ;       - ����㧪� �⪫�祭�
                                ;       - �।���⥫� � WDT
                                ;       - RTCC � ��������
        MOVWF   OPTION_REG
        BCF     STATUS, RP0     ;       ��࠭�� #1

	RETURN

;	��騬 ���� ࠧ 
BeepOnce

	BSF	BzPort, BzPin	;	����砥� ��頫��
	CALL	SleepDelay
	BCF	BzPort, BzPin	;	�몫�砥� ��頫��
	RETURN

;	���뢠�� ����� � ��騬 ��頫���
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
