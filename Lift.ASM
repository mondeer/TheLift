; ----- CSC1024 Coursework: The Lift --------------------------

	JMP	Start 		; Skip past the data table (will store letters for screen output)
	
	; Timer Interrupt Vector
	DB	21		; When this accessed, the TimerHandler procedure will be called

	; This value is never accessed
	DB	00		; Blank so Keypad Interrupt Vector is at RAM location [4]

	; Keypad Interrupt Vector
	DB 	77		; When this accessed, the EnterCheck procedure will be called

	; Store VDU outputs to data table. After every output, 00 is stored. These are used to signify the end of the word and are used in the OutputVDU procedure.
	DB	"UP    "
	DB	01
	DB	"TOP   "
	DB	01
	DB	"DOWN  "
	DB	01
	DB	"BOTTOM"
	DB	01
	
TimerHandler:
	; This procedure is called when a hardware interrupt occurs
	ORG	21		; Code starts from address [21]
	IRET			; Return from interrupt	

Start:
	; Tutorial has line [CLO] here, but as this is not necessary I have removed this to free up memory
	; Tutorial has line [MOV AL, 00] here, but as this is overwritten in the following procedure I have removed this to free up memory
	OUT	06		; Display lift window
	OUT	08		; Display numeric keypad peripheral
	; Follow through to DownCheck

DownCheck:
	; This procedure checks if the down button is pressed and if so, starts DownMotor
	STI			; Set/re-enable (I) flag (will need re-enabling if the DownCheck procedure is returned to post enter being pressed).
	IN	06		; Read lift status
	AND	AL, 10		; Isolate DOWN button bit
	JZ	UpCheck		; If DOWN button not pressed, jump to UpCheck
	CALL	56		; Call first section of DownMotor if DOWN button pressed (first ORG statement)
	
UpCheck:
	; This procedure checks if the up button is pressed and if so, starts UpMotor
	IN	06		; Read lift status
	AND	AL, 20		; Isolate UP button bit
	JZ	DownCheck	; Loop if neither button pressed
	CALL	3B		; Call UpMotor
	JMP	DownCheck	; Loop after UpMotor

UpMotor:	
	; This procedure starts the clears the up button and starts the up motor movement procedures
	ORG	3B		; Code starts from address [3B]
	MOV	DL, 05		; Copy starting position of word UP in data table to BL register
	CALL	9B		; Call the SetOutputVDU proecudure
	
	IN	06		; Read lift status
	AND	AL, DF		; Clear UP button bit
	OUT	06		; De-select UP button
	
	MOV 	CL, 04		; Masking needed for top sensor
	CALL	82		; Call CheckExtreme
	MOV	BL, 01		; Masking needed to set UP motor bit
	MOV	DL, 0C		; Copy starting position of word TOP in data table to DL register
	JZ	ContinueDirection	; If not at top of lift (found in CheckExtreme), jump to ContinueDirection
	JMP	OutputExtreme	; If at top of lift, jump to OutputExtreme (will output "TOP" to VDU)

DownMotor:
	; This procedure starts the clears the down button and starts the down motor movement procedures
	ORG	56		; Code starts from address [56]
	MOV	DL, 13		; Copy starting position of word DOWN in data table to BL register
	CALL	9B		; Call the SetOutputVDU proecudure
	
	; This section of the procedure starts the movement of the lift
	ORG	5B		; Code starts from address [5B]
	
	IN	06		; Read lift status
	AND	AL, EE		; Clear DOWN button and UP motor bit (UP motor bit will be on if enter pressed whilst moving up. Both motor bits cannot be on else the lift will crash so this is a precautionary measure.)
	OUT	06		; De-select DOWN button and start UP motor

	MOV	CL, 08		; Masking needed for bottom sensor
	CALL	82		; CheckExtreme
	MOV	BL, 02		; Masking needed to set DOWN motor bit
	MOV	DL, 1A		; Copy starting position of word BOTTOM in data table to DL register
	JNZ	OutputExtreme	; If at bottom of lift, jump to OutputExtreme (will output "BOTTOM" to VDU)
	
ContinueDirection:
	; This procedure starts up/down motor depending on the calling procedure
	OR	AL, BL		; Set specified motor bit
	OUT	06		; Turn on specified motor
	CALL	88		; Call StopCrash
	RET			; Return to previous procedure
	
EnterCheck:
	; This procedure checks if the clicked button on the keypad was enter
	ORG	77		; Code starts from address [77]
	CLI			; Clear (I) flag
	IN	08		; Read in pressed key
	CMP	AL, 0D		; Check if key pressed was the enter key
	JNZ	ReturnToPrevious	; If the key pressed was not the enter key, jump to ReturnToPrevious
	; Else follow through to EnterProcess

EnterProcess:
	; This procedure calls the DownMotor procedure
	CALL 	5B		; Call second section of DownMotor (second ORG statement)
	RET		 	; Return to previous procedure
				; Note: I have assumed that the coursework instruction that says the lift must operate normally after enter does not mean that the previously called procedure must be returned to, just that all functions must work normally.
				; Also note that I have assumed that output of the word down does not need to be executed after enter is pressed, as the specification says return to the bottom of the shaft immediatly, not anything out outputting data.	

CheckExtreme:
	; This procedure checks if the lift is at the top/bottom of the shaft
	ORG	82		; Code starts from address [82]
	
	IN	06		; Read lift status
	AND	AL, CL		; Isolate specified sensor bit
	; Follow through to ReturnToPrevious

ReturnToPrevious:
	; This procedure allows me to essentially jump to a RET command. This functionality is not provided by the assembler so I have provided an alternative.	
	RET			; Return to previous procedure
	
StopCrash:
	; This procedure clears the motor bits
	ORG	88		; Code starts from address [88]
	CALL 	82		; Call CheckExtreme
	JZ	StopCrash	; Loop if the lift is not near bottom of shaft
	
	IN	06		; Read lift status again (thereby keeping the status of the pressed buttons as pressed/not pressed, which would have been changed after the first AND operation.)
	AND	AL, FC		; Clear motor bits
	OUT	06		; Stop lift motor	
	
	CMP	BL, C6		; Does BL contain C6? (C6 is used as this is will be in CL if returned from enter key).
	JZ	ReturnToPrevious	; If so, jump to ReturnToPrevious
	
OutputExtreme:
	; This procedure starts the outputting of top/bottom
	CALL	9B		; Call the SetOutputVDU procedure
	RET			; Return to previous procedure
	
SetOutputVDU:
	; This procedure will place the first RAM location for VDU output in reigster CL
	
	ORG	9B		; Code starts from address [9B]
	;PUSH	CL		; Push the value in CL to the stack. If this did not happen the if statement would not complete and an infinite loop would enter
	MOV	BL, C0		; Copies the value C0 to DL
	; Follow through to OutputVDU

OutputVDU:
	; This procedure will output the correct information to the VDU.
	MOV	AL, [DL]	; Copy contents of RAM location in BL (in data table) to CL 
	MOV	[BL], AL	; Output AL to VDU display
	
	INC	DL		; Which in data table
	INC	BL		; Where in display
	
	MOV	AL, [DL] 	; Copy next item in data table to AL
	CMP	AL, 01 		; Is this 1 (delimiter inserted in data table by me at start)?
	JNZ	OutputVDU	; If not, carry on output
	
	;POP	CL		; Restore the value of CL from the stack (pushed in SetOutputVDU)

	RET			; Return to previous procedure
				
	END
; --------------------------------------------------------------