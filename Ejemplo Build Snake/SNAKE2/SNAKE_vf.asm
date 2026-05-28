; * Carles Vilella, 2017 (ENTI-UB)

; *************************************************************************
; Our data section. Here we declare our strings for our console message
; *************************************************************************

SGROUP 		GROUP 	CODE_SEG, DATA_SEG
			ASSUME 	CS:SGROUP, DS:SGROUP, SS:SGROUP

    TRUE  EQU 1
    FALSE EQU 0

; EXTENDED ASCII CODES
    ASCII_SPECIAL_KEY EQU 00
    ASCII_LEFT        EQU 04Bh
    ASCII_RIGHT       EQU 04Dh
    ASCII_UP          EQU 048h
    ASCII_DOWN        EQU 050h
    ASCII_QUIT        EQU 071h ; 'q'

; ASCII / ATTR CODES TO DRAW THE SNAKE
    ASCII_SNAKE     EQU 02Ah
    ATTR_SNAKE      EQU 070h

; ASCII / ATTR CODES TO DRAW THE FIELD
    ASCII_FIELD    EQU 020h
    ATTR_FIELD     EQU 070h

    ASCII_NUMBER_ZERO EQU 030h

; CURSOR
    CURSOR_SIZE_HIDE EQU 02607h  ; BIT 5 OF CH = 1 MEANS HIDE CURSOR
    CURSOR_SIZE_SHOW EQU 00607h

; ASCII
    ASCII_YES_UPPERCASE      EQU 059h
    ASCII_YES_LOWERCASE      EQU 079h
    
; COLOR SCREEN DIMENSIONS IN NUMBER OF CHARACTERS
    SCREEN_MAX_ROWS EQU 25
    SCREEN_MAX_COLS EQU 80

; FIELD DIMENSIONS
    FIELD_R1 EQU 1
    FIELD_R2 EQU SCREEN_MAX_ROWS-2
    FIELD_C1 EQU 1
    FIELD_C2 EQU SCREEN_MAX_COLS-2

; *************************************************************************
; Our executable assembly code starts here in the .code section
; *************************************************************************
CODE_SEG	SEGMENT PUBLIC
			ORG 100h

MAIN 	PROC 	NEAR

  MAIN_GO:

      CALL REGISTER_TIMER_INTERRUPT

      CALL INIT_GAME
      CALL INIT_SCREEN
      CALL HIDE_CURSOR
      CALL DRAW_FIELD

      MOV DH, SCREEN_MAX_ROWS/2
      MOV DL, SCREEN_MAX_COLS/2
      
      CALL MOVE_CURSOR
      
  MAIN_LOOP:
      ; --- CORRECCIÓN SALTO LARGO 1 ---
      CMP [END_GAME], TRUE
      JNZ NOT_END_GAME        ; Si NO ha terminado, saltamos el JMP largo
      JMP END_PROG            ; JMP llega a cualquier distancia
  NOT_END_GAME:

      ; Check if a key is available to read
      MOV AH, 0Bh
      INT 21h
      CMP AL, 0
      JZ MAIN_LOOP

      ; A key is available -> read
      CALL READ_CHAR      

      ; End game?
      CMP AL, ASCII_QUIT
      JZ END_PROG
      
      ; Is it an special key?
      CMP AL, ASCII_SPECIAL_KEY
      JNZ MAIN_LOOP
      
      CALL READ_CHAR

      ; The game is on!
      MOV [START_GAME], TRUE

      CMP AL, ASCII_RIGHT
      JZ RIGHT_KEY
      CMP AL, ASCII_LEFT
      JZ LEFT_KEY
      CMP AL, ASCII_UP
      JZ UP_KEY
      CMP AL, ASCII_DOWN
      JZ DOWN_KEY
      
      JMP MAIN_LOOP

  RIGHT_KEY:
      MOV [INC_COL], 1
      MOV [INC_ROW], 0
      JMP END_KEY

  LEFT_KEY:
      MOV [INC_COL], -1
      MOV [INC_ROW], 0
      JMP END_KEY

  UP_KEY:
      MOV [INC_COL], 0
      MOV [INC_ROW], -1
      JMP END_KEY

  DOWN_KEY:
      MOV [INC_COL], 0
      MOV [INC_ROW], 1
      JMP END_KEY
      
  END_KEY:
      JMP MAIN_LOOP

  END_PROG:
      CALL RESTORE_TIMER_INTERRUPT
      CALL SHOW_CURSOR
      CALL PRINT_SCORE_STRING
      CALL PRINT_SCORE
      CALL PRINT_PLAY_AGAIN_STRING
      
      CALL READ_CHAR

      ; --- CORRECCIÓN SALTO LARGO 2 ---
      CMP AL, ASCII_YES_UPPERCASE
      JZ JUMP_TO_GO
      CMP AL, ASCII_YES_LOWERCASE
      JNZ EXIT_REAL           ; Si no es 'y' ni 'Y', salimos de verdad
  JUMP_TO_GO:
      JMP MAIN_GO             ; Salto largo hacia arriba
  
  EXIT_REAL:
	INT 20h		

MAIN	ENDP	

; ****************************************
; Reset internal variables
; ****************************************
                  PUBLIC  INIT_GAME
INIT_GAME          PROC    NEAR

    MOV [INC_ROW], 0
    MOV [INC_COL], 0
    MOV [DIV_SPEED], 10
    MOV [NUM_TILES], 0
    MOV [START_GAME], FALSE
    MOV [END_GAME], FALSE

    RET
INIT_GAME	ENDP	

; ****************************************
; Reads char from keyboard
; ****************************************
PUBLIC  READ_CHAR
READ_CHAR PROC NEAR
    MOV AH, 8
    INT 21h
    RET
READ_CHAR ENDP

; ****************************************
; Read character and attribute at cursor position
; ****************************************
PUBLIC READ_SCREEN_CHAR                 
READ_SCREEN_CHAR PROC NEAR
    PUSH BX
    MOV AH, 8
    XOR BH, BH
    INT 10h
    POP BX
    RET
READ_SCREEN_CHAR  ENDP

; ****************************************
; Draws the rectangular field
; ****************************************
PUBLIC DRAW_FIELD
DRAW_FIELD PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    MOV AL, ASCII_FIELD
    MOV BL, ATTR_FIELD
    MOV DL, FIELD_C2
  UP_DOWN_SCREEN_LIMIT:
    MOV DH, FIELD_R1
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR
    MOV DH, FIELD_R2
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR
    DEC DL
    CMP DL, FIELD_C1
    JNS UP_DOWN_SCREEN_LIMIT
    MOV DH, FIELD_R2
  LEFT_RIGHT_SCREEN_LIMIT:
    MOV DL, FIELD_C1
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR
    MOV DL, FIELD_C2
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR
    DEC DH
    CMP DH, FIELD_R1
    JNS LEFT_RIGHT_SCREEN_LIMIT
    POP DX
    POP BX
    POP AX
    RET
DRAW_FIELD       ENDP

PUBLIC PRINT_SNAKE
PRINT_SNAKE PROC NEAR
    PUSH AX
    PUSH BX
    MOV AL, ASCII_SNAKE
    MOV BL, ATTR_SNAKE
    CALL PRINT_CHAR_ATTR
    POP BX
    POP AX
    RET
PRINT_SNAKE        ENDP     

PUBLIC PRINT_CHAR_ATTR
PRINT_CHAR_ATTR PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    MOV AH, 9
    MOV BH, 0
    MOV CX, 1
    INT 10h
    POP CX
    POP BX
    POP AX
    RET
PRINT_CHAR_ATTR        ENDP     

PUBLIC PRINT_CHAR
PRINT_CHAR PROC NEAR
    PUSH AX
    PUSH DX
    MOV AH, 2
    MOV DL, AL
    INT 21h
    POP DX
    POP AX
    RET
PRINT_CHAR        ENDP     

PUBLIC INIT_SCREEN
INIT_SCREEN	PROC NEAR
      PUSH AX
      PUSH BX
      PUSH CX
      PUSH DX
      MOV AL,3
      MOV AH,0
      INT 10h
      XOR AL, AL
      XOR CX, CX
      MOV DH, SCREEN_MAX_ROWS
      MOV DL, SCREEN_MAX_COLS
      MOV BH, 7
      MOV AH, 6
      INT 10h
      POP DX      
      POP CX      
      POP BX      
      POP AX      
	RET
INIT_SCREEN		ENDP

PUBLIC  HIDE_CURSOR
HIDE_CURSOR PROC NEAR
      PUSH AX
      PUSH CX
      MOV AH, 1
      MOV CX, CURSOR_SIZE_HIDE
      INT 10h
      POP CX
      POP AX
      RET
HIDE_CURSOR       ENDP

PUBLIC SHOW_CURSOR
SHOW_CURSOR PROC NEAR
    PUSH AX
    PUSH CX
    MOV AH, 1
    MOV CX, CURSOR_SIZE_SHOW
    INT 10h
    POP CX
    POP AX
    RET
SHOW_CURSOR       ENDP

PUBLIC GET_CURSOR_PROP
GET_CURSOR_PROP PROC NEAR
      PUSH AX
      PUSH BX
      MOV AH, 3
      XOR BX, BX
      INT 10h
      POP BX
      POP AX
      RET
GET_CURSOR_PROP       ENDP

PUBLIC SET_CURSOR_PROP
SET_CURSOR_PROP PROC NEAR
      PUSH AX
      PUSH BX
      MOV AH, 2
      XOR BX, BX
      INT 10h
      POP BX
      POP AX
      RET
SET_CURSOR_PROP       ENDP

PUBLIC MOVE_CURSOR
MOVE_CURSOR PROC NEAR
      PUSH DX
      CALL GET_CURSOR_PROP  
      POP DX
      CALL SET_CURSOR_PROP
      RET
MOVE_CURSOR       ENDP

PUBLIC  MOVE_CURSOR_RIGHT
MOVE_CURSOR_RIGHT PROC NEAR
    PUSH CX
    PUSH DX
    CALL GET_CURSOR_PROP
    ADD DL, 1
    CMP DL, SCREEN_MAX_COLS
    JZ MOVE_CURSOR_RIGHT_END
    CALL SET_CURSOR_PROP
  MOVE_CURSOR_RIGHT_END:
    POP DX
    POP CX
    RET
MOVE_CURSOR_RIGHT       ENDP

PUBLIC PRINT_STRING
PRINT_STRING PROC NEAR
    PUSH DX
    MOV AH,9
    INT 21h
    POP DX
    RET
PRINT_STRING       ENDP

PUBLIC PRINT_SCORE_STRING
PRINT_SCORE_STRING PROC NEAR
    PUSH CX
    PUSH DX
    CALL GET_CURSOR_PROP  
    MOV DH, FIELD_R2+1
    MOV DL, FIELD_C1
    CALL SET_CURSOR_PROP
    LEA DX, SCORE_STR
    CALL PRINT_STRING
    POP DX
    POP CX
    RET
PRINT_SCORE_STRING       ENDP

PUBLIC PRINT_PLAY_AGAIN_STRING
PRINT_PLAY_AGAIN_STRING PROC NEAR
    PUSH DX
    LEA DX, PLAY_AGAIN_STR
    CALL PRINT_STRING
    POP DX
    RET
PRINT_PLAY_AGAIN_STRING       ENDP

PUBLIC PRINT_SCORE
PRINT_SCORE PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV AX, [NUM_TILES]
    XOR DX, DX
    MOV BX, 1000
    DIV BX            
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR
    MOV AX, DX        
    XOR DX, DX
    MOV BX, 100
    DIV BX            
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR
    MOV AX, DX          
    XOR DX, DX
    MOV BX, 10
    DIV BX            
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR
    MOV AX, DX
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR
    POP DX
    POP CX
    POP BX
    POP AX
    RET   
PRINT_SCORE        ENDP

PUBLIC NEW_TIMER_INTERRUPT
NEW_TIMER_INTERRUPT PROC NEAR
    PUSHF
    CALL DWORD PTR [OLD_INTERRUPT_BASE]
    PUSH AX
    CMP [START_GAME], TRUE
    JNZ END_ISR
    INC [INT_COUNT]
    MOV AL, [INT_COUNT]
    CMP [DIV_SPEED], AL
    JNZ END_ISR
    MOV [INT_COUNT], 0
    ADD DL, [INC_COL]
    ADD DH, [INC_ROW]
    CALL MOVE_CURSOR
    CALL READ_SCREEN_CHAR
    CMP AH, ATTR_SNAKE
    JZ END_SNAKES
    INC [NUM_TILES]
    CALL PRINT_SNAKE
    CMP [DIV_SPEED], 1
    JZ END_ISR
    MOV AX, [NUM_TILES]
    XOR DX, DX
    MOV BL, [NUM_TILES_INC_SPEED]
    XOR BH, BH
    DIV BX
    CMP DX, 0                 
    JNZ END_ISR
    DEC [DIV_SPEED]
    JMP END_ISR
END_SNAKES:
      MOV [END_GAME], TRUE
END_ISR:
      POP AX
      IRET
NEW_TIMER_INTERRUPT ENDP
                 
PUBLIC REGISTER_TIMER_INTERRUPT
REGISTER_TIMER_INTERRUPT PROC NEAR
        PUSH AX
        PUSH BX
        PUSH DS
        PUSH ES 
        CLI                                 
        MOV  AX, 3508h                      
        INT  21h                            
        MOV  WORD PTR OLD_INTERRUPT_BASE+02h, ES  
        MOV  WORD PTR OLD_INTERRUPT_BASE, BX  
        MOV  AX, 2508h                      
        MOV  DX, offset NEW_TIMER_INTERRUPT 
        INT  21h                            
        STI                                 
        POP  ES                             
        POP  DS
        POP  BX
        POP  AX
        RET      
REGISTER_TIMER_INTERRUPT ENDP

PUBLIC RESTORE_TIMER_INTERRUPT
RESTORE_TIMER_INTERRUPT PROC NEAR
      PUSH AX                               
      PUSH DS
      PUSH DX 
      CLI                                 
      MOV  AX, 2508h                      
      MOV  DX, WORD PTR OLD_INTERRUPT_BASE
      MOV  DS, WORD PTR OLD_INTERRUPT_BASE+02h
      INT  21h                            
      STI                                 
      POP  DX                               
      POP  DS
      POP  AX
      RET    
RESTORE_TIMER_INTERRUPT ENDP

CODE_SEG 	ENDS

DATA_SEG	SEGMENT	PUBLIC
    OLD_INTERRUPT_BASE    DW  0, 0  
    INC_ROW DB 0    
    INC_COL DB 0
    NUM_TILES DW 0               
    NUM_TILES_INC_SPEED DB 20    
    DIV_SPEED DB 10               
    INT_COUNT DB 0               
    START_GAME DB 0               
    END_GAME DB 0                
    SCORE_STR           DB "Your score is $"
    PLAY_AGAIN_STR      DB ". Do you want to play again? (Y/N)$"
DATA_SEG	ENDS

		END MAIN