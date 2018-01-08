
#include P16C84.inc
	__CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC
        __IDLOCS H'6969'

;	Где находится считыватель
TMPort		equ	PORTA
TMPin		equ	4
TMMask		equ	0x10
;	Где пищалка
BzPort		equ	PORTB
BzPin		equ	2
;BzPin		equ	1
;	Где джампер конфигурации
JPort		equ	PORTB
JPin		equ	4
;	Где замок
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
        BSF     STATUS, RP0     ;       Страница #2
        MOVLW   0xC8            ;       Настройка:
                                ;       - пределитель 1:1
                                ;       - нагрузки отключены
                                ;       - пределитель к WDT
                                ;       - RTCC к генератору
        MOVWF   OPTION_REG
	BCF	TRISA, TMPin    ;       Считыватель - на вывод
	BCF	TRISB, 1	;	Отладочный индикатор - на вывод
	BCF	TRISB, BzPin	;	Пищалка - на вывод
	BCF	TRISB, LockPin	;	Замок - на вывод
	BSF	TRISB, JPin	;	Джампер - на ввод
        BCF     STATUS, RP0     ;       Страница #1

	BCF	LockPort, LockPin	;Немедлено закрыть дверь!
	BCF	BzPort, BzPin

	BSF	TMPort, TMPin	;	Ставим единицу на считыватель.
	BCF	PORTB, 1

;---	Проверим, замкнут ли джампер конфигурации
	BTFSC	JPort, JPin
	GOTO	NoConfig	;	Нет запроса конфигурации - идем дальше

;-------------------------------------------------
;	Режим конфигурации контроллера
;-------------------------------------------------
	CALL	BeepOnce	;	Есть запрос - пищим
;---	Чистим всю память ключей (до 3Fh)
	MOVLW	0x3F
	MOVWF	LoopReg
 	CLRF	EEADR
	CLRF	EEDATA
	COMF	EEDATA

CLRL
        BSF     STATUS, RP0     ;       Страница #2
	BSF	EECON1, WREN
	MOVLW	0x55
	MOVWF	EECON2
	MOVLW	0xAA
	MOVWF	EECON2
	BSF	EECON1, WR
	BTFSS	EECON1, EEIF
	GOTO	$-1
	BCF	EECON1, EEIF
        BCF     STATUS, RP0     ;       Страница #1
	INCF	EEADR
	DECFSZ	LoopReg, F
	GOTO	CLRL
	CALL	BeepOnce	;	Снова пищим

 	CLRF	EEADR		;	Начинаем запись сначала

WaitForKey
	CALL	PresenceCheck	;	Проверяем, есть ли ключ
	ANDLW	0xFF		;	Если его нет - игнорируем
	BTFSS	STATUS, Z
	GOTO	NoKeyConfig	;	Нет ключа

	CALL	ReadKeySID	;	Может давать ошибку при fID != 1
	ANDLW	0xFF		;	Если ошибка - игнорируем
	BTFSS	STATUS, Z
	GOTO	NoKeyConfig	;	Нет ключа

;---	Записываем ключ в память
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
	CALL	BeepOnce	;	Пищим, подтверждая запись
	
;---	Теперь ждем, пока ключ уберут
KeyPresent
	CALL	PresenceCheck	;	Проверяем, есть ли ключ
	ANDLW	0xFF
	BTFSC	STATUS, Z
	GOTO	KeyPresent

NoKeyConfig
	CALL	SetToOutput	;	Пока ждем - выводим единицу в порт
	BSF	TMPort, TMPin
	CALL	SleepDelay
	GOTO	WaitForKey

;-------------------------------------------------
;	Основной режим контроллера
;-------------------------------------------------
NoConfig
;---	Здесь проверяем, есть ли в памяти хоть один ключ
	CLRF	EEADR
	MOVLW	0x40
	MOVWF	LoopReg
CheckL
	CALL	EERead
	MOVWF	RDByte
	INCF	EEADR
	INCFSZ	RDByte, F	;	Если прочитано не FFh - выходим
	GOTO	MainKey
	DECFSZ	LoopReg, F
	GOTO	CheckL
	BSF	BzPort, BzPin	;	Если дошло сюда - память обнуленa
	GOTO	$		;	Пищим и висим...
	

;---	Главный цикл ожидания и распознавания ключа	
MainKey	
	CALL	PresenceCheck	;	Проверяем, есть ли ключ
	ANDLW	0xFF		;	Если его нет - игнорируем
	BTFSS	STATUS, Z
	GOTO	NoKey

	CALL	ReadKeySID	;	Читаем ключ в буферные байты
	ANDLW	0xFF		;	Если ошибка - игнорируем
	BTFSS	STATUS, Z
	GOTO	NoKey

;---	Теперь секция распознавания ключа
	CLRF	EEADR
	MOVLW	0x0A
	MOVWF	LoopReg

ReadAgain
	CLRF	ComReg		;	Регистр сравнения

	CALL	EERead		;	Читаем байты из памяти
	XORWF	BTM1, W		;	и проверяем их на идентичность
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

;---	Если ключ совпадет - не будет ни одного инкремента, comreg=0
	MOVLW	0xFF
	ANDWF	ComReg, F
	BTFSS	STATUS, Z
	GOTO	IncorrectKey
	GOTO	KeyFound	;	Если все прошел - ключ совпал

IncorrectKey
	DECFSZ	LoopReg
	GOTO	ReadAgain
	GOTO	NoKey

KeyFound
;	BSF	PORTB, 1	;	Включаем отладочный индикатор и все
;	GOTO	$
	CALL	ReleaseLock	;	Теперь можно открыть замок

NoKey
	CALL	SetToOutput	;	Пока ждем - выводим единицу в порт
	BSF	TMPort, TMPin

	CALL	SleepDelay	;	Делаем длинную паузу для "отдыха"
	GOTO	MainKey		;	"У попа была собака..."


;	Посылка команды чтения серийного номера
;	и чтение SID ключа в буфер с возвратом 0FF при ошибке, иначе - 0
ReadKeySID
	CALL	SetToOutput

;--	Посылка команды чтения (33h)
;	Передаем 

	MOVLW	0x33
	MOVWF	RDByte
	MOVLW	0x08
	MOVWF	LoopReg

Nbl1
	CALL	Relaxation
	BCF	TMPort, TMPin	;	Тактируем ключ перепадом
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


	BSF	TMPort, TMPin	;	"Взводим" порт - ключ ждет след. перепад

;--	Теперь остается только прочитать данные
;	Читаем 1 байт family code. Если не 01h - возвращаем ошибку

	CALL	ReadKeyByte
	MOVF	RDByte, W
	XORLW	0x01
	BTFSS	STATUS, Z
	RETLW	0xFF		;	Family code != 01h

;--	Читаем и сохраняем 4 байта данных ключа
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
;       BSF     STATUS, RP0     ;       Страница #2
;	BSF	EECON1, WREN
;	MOVLW	0x55
;	MOVWF	EECON2
;	MOVLW	0xAA
;	MOVWF	EECON2
;	BSF	EECON1, WR
;	BTFSS	EECON1, EEIF
;	GOTO	$-1
;	BCF	EECON1, EEIF
;       BCF     STATUS, RP0     ;       Страница #1
;	INCF	EEADR
; 
;	DECFSZ	LoopReg, F
;	GOTO	RL
;
;	BSF	PORTB, 1	;	Включаем отладочный индикатор и все
;	GOTO	$


	RETLW	0

;	Чтение байта из ключа в RDByte
ReadKeyByte
	CLRF	RDByte
	MOVLW	0x08
	MOVWF	RDLoop
	CALL	SetToOutput
BLoop
	CALL	Relaxation
	BCF	TMPort, TMPin	;	Тактируем ключ перепадом
	NOP
	NOP
	NOP
	CALL	SetToInput
	NOP
	MOVF	PORTA, W	;	Вводим данные с ключа
	CALL	SetToOutput
	BSF	TMPort, TMPin	;	"Взводим" порт - ключ ждет след. перепад
	ANDLW	TMMask
	BTFSC	STATUS, Z	;	Если прочитали "0"
	BCF	STATUS, C
	BTFSS	STATUS, Z	;	Если прочитали "1"
	BSF	STATUS, C
	RRF	RDByte, F	;	Задвигаем очередной бит
	MOVLW	0xF5
	CALL	Delay
	DECFSZ	RDLoop, F
	GOTO	BLoop

	RETURN
;----------------------------------------------------------------------
;--	Вспомогательные подпрограммы протокола "1WireBUS"
;----------------------------------------------------------------------
;	Релаксация шины положительным фронтом
Relaxation
	BSF	TMPort, TMPin
	NOP
	NOP
	NOP
	RETURN

;	Задержка на W us
Delay
	ADDLW	0x07	;	Корректируем на 7 мкс
	MOVWF	TMR0
Lp	BTFSS   INTCON, T0IF
        GOTO    Lp
        BCF     INTCON, T0IF
	RETURN

;	Переводим порт в режим ввода (4 мкс)
SetToInput	
        BSF     STATUS, RP0     ;       Страница #2
	BSF	TRISA, TMPin    ;       Настраиваем порт на ввод
        BCF     STATUS, RP0     ;       Страница #1
	RETURN

;	Переводим порт в режим вывода (4 мкс)
SetToOutput	
        BSF     STATUS, RP0     ;       Страница #2
	BCF	TRISA, TMPin    ;       Настраиваем порт на ввод
        BCF     STATUS, RP0     ;       Страница #1
	RETURN

;----------------------------------------------------------------------
;--	Остальные вспомогательные подпрограммы
;----------------------------------------------------------------------
;	Запись в EEPROM. EEADR и W (EEDATA) должны быть установлены.
EEWrite
	MOVWF	EEDATA
	BSF     STATUS, RP0     ;       Страница #2
	BSF	EECON1, WREN
	MOVLW	0x55
	MOVWF	EECON2
	MOVLW	0xAA
	MOVWF	EECON2
	BSF	EECON1, WR
	BTFSS	EECON1, EEIF
	GOTO	$-1
	BCF	EECON1, EEIF
	BCF     STATUS, RP0     ;       Страница #1

	RETURN

;	Чтение из EEPROM в W. EEADR должeн быть установлен.
EERead
	BSF     STATUS, RP0     ;       Страница #2
	BSF	EECON1, RD	;	Читаем память
	BCF     STATUS, RP0     ;       Страница #1
	NOP
	NOP
	MOVF	EEDATA, W
	RETURN

;	Проверка присутствия ключа. Если нет - возвращаем 0FFh
PresenceCheck

;---	Проверка присутствия ключа - "просаживание" питания на 480 мкс.
	BCF	TMPort, TMPin	;	Ставим ноль на считыватель.
	CLRF	TMR0
        BCF     INTCON, T0IF
Lpk1    BTFSS   INTCON, T0IF	;	Ждем ~256 мкс
        GOTO    Lpk1
        BCF     INTCON, T0IF
	MOVLW	0x30
	MOVWF	TMR0
Lpk2    BTFSS   INTCON, T0IF	;	Ждем еще ~224 мкс
        GOTO    Lpk2
        BCF     INTCON, T0IF

	BSF	TMPort, TMPin	;	Ставим единицу на считыватель.

	CALL	SetToInput

;---	Сразу после ресета должны прочитать единицу.
	MOVF	PORTA, W	;	Вводим данные с ключа и выделяем их
	ANDLW	TMMask
	BTFSC	STATUS, Z	;	Если в акк. ненулевое значение - переходим
	RETLW	0xFF		;	Ключа нет - уходим.



	MOVLW	0xBF
	MOVWF	TMR0
Lpk3    BTFSS   INTCON, T0IF	;	Ждем импульса присутствия ~35 мкс
        GOTO    Lpk3
        BCF     INTCON, T0IF
	MOVF	PORTA, W	;	Вводим данные с ключа и выделяем их
	ANDLW	TMMask

	BTFSS	STATUS, Z	;	Если в акк. ненулевое значение - не перемычка
	RETLW	0xFF		;	Ключа нет - уходим.

	CALL	SetToOutput
	BSF	TMPort, TMPin

;---	Теперь ждем 480 мкс для восстановления ключа после ресета
	CLRF	TMR0
        BCF     INTCON, T0IF
Lpw1    BTFSS   INTCON, T0IF	;	Ждем ~256 мкс
        GOTO    Lpw1
        BCF     INTCON, T0IF
	MOVLW	0x30
	MOVWF	TMR0
Lpw2    BTFSS   INTCON, T0IF	;	Ждем еще ~224 мкс
        GOTO    Lpw2
        BCF     INTCON, T0IF

	RETLW	0

;	Общая пауза между опросами ключа
SleepDelay

;	Настраиваем заново для выдержки паузы
        BSF     STATUS, RP0     ;       Страница #2
        MOVLW   0xC7            ;       Настройка:
                                ;       - пределитель 1:256
                                ;       - нагрузки отключены
                                ;       - пределитель к RTCC
                                ;       - RTCC к генератору
        MOVWF   OPTION_REG
        BCF     STATUS, RP0     ;       Страница #1
	CLRF	TMR0
	CLRW
	CALL	Delay
	CLRW
	CALL	Delay
        BSF     STATUS, RP0     ;       Страница #2
        MOVLW   0xC8            ;       Настройка:
                                ;       - пределитель 1:1
                                ;       - нагрузки отключены
                                ;       - пределитель к WDT
                                ;       - RTCC к генератору
        MOVWF   OPTION_REG
        BCF     STATUS, RP0     ;       Страница #1

	RETURN

;	Пищим один раз 
BeepOnce

	BSF	BzPort, BzPin	;	Включаем пищалку
	CALL	SleepDelay
	BCF	BzPort, BzPin	;	Выключаем пищалку
	RETURN

;	Открываем замок и пищим пищалкой
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
