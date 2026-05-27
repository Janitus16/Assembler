; *************************************************************************
; Our data section. Here we declare our strings for our console message
; *************************************************************************

SGROUP      GROUP   CODE_SEG, DATA_SEG
            ASSUME  CS:SGROUP, DS:SGROUP, SS:SGROUP

    TRUE  EQU 1
    FALSE EQU 0

    ASCII_SPECIAL_KEY EQU 00
    ASCII_LEFT        EQU 04Bh
    ASCII_RIGHT       EQU 04Dh
    ASCII_UP          EQU 048h
    ASCII_QUIT        EQU 071h ; 'q'

    ASCII_PLAYER      EQU 02Ah ; *
    ATTR_PLAYER       EQU 00Fh ; white

    ASCII_WALL        EQU 0DBh 

    ASCII_CAR         EQU 0DBh 

    CURSOR_SIZE_HIDE  EQU 02607h ; BIT 5 OF CH = 1 MEANS HIDE CURSOR
    CURSOR_SIZE_SHOW  EQU 00607h

    SCREEN_MAX_ROWS   EQU 25
    SCREEN_MAX_COLS   EQU 80

    FIELD_C1 EQU 25
    FIELD_C2 EQU 55

    COLOR_GREEN EQU 02h 
    COLOR_ROAD  EQU 08h 
    COLOR_WATER EQU 03h 

    MAX_CARS      EQU 40

    CAR_DIV_SPEED EQU 3

; *************************************************************************
; Our executable assembly code starts here in the .code section
; *************************************************************************
CODE_SEG    SEGMENT PUBLIC
            ORG 100h

MAIN    PROC    NEAR

    MOV AX, CS
    MOV DS, AX

    CALL REGISTER_TIMER_INTERRUPT
    CALL INIT_GAME
    CALL INIT_SCREEN
    CALL HIDE_CURSOR
    CALL DRAW_INITIAL_MAP
    CALL DRAW_SCORE

    MOV BYTE PTR [POS_ROW], 20
    MOV BYTE PTR [POS_COL], 40

MAIN_LOOP:
    CMP BYTE PTR [END_GAME], TRUE
    JE GAME_OVER_SCREEN

    MOV AH, 0Bh
    INT 21h
    CMP AL, 0
    JE MAIN_LOOP

    CALL READ_CHAR

    CMP AL, ASCII_QUIT
    JE JUMP_TO_END

    CMP AL, ASCII_SPECIAL_KEY
    JNE MAIN_LOOP

    CALL READ_CHAR

    CMP AL, ASCII_LEFT
    JE LEFT_KEY
    CMP AL, ASCII_RIGHT
    JE RIGHT_KEY
    CMP AL, ASCII_UP
    JE UP_KEY
    JMP MAIN_LOOP

JUMP_TO_END: 
    JMP END_PROG

LEFT_KEY:
    MOV BYTE PTR [INC_COL], -1
    MOV BYTE PTR [INC_ROW], 0
    JMP MAIN_LOOP

RIGHT_KEY:
    MOV BYTE PTR [INC_COL], 1
    MOV BYTE PTR [INC_ROW], 0
    JMP MAIN_LOOP

UP_KEY:
    MOV BYTE PTR [INC_COL], 0
    MOV BYTE PTR [INC_ROW], -1
    JMP MAIN_LOOP

GAME_OVER_SCREEN:
    CALL DRAW_SCORE

    MOV AX, 0003h
    INT 10h
    CALL SHOW_CURSOR

    MOV DH, 10
    MOV DL, 29
    CALL MOVE_CURSOR
    MOV AH, 09h
    LEA DX, MSG_GAME_OVER
    INT 21h

    MOV DH, 12
    MOV DL, 27
    CALL MOVE_CURSOR
    MOV AH, 09h
    LEA DX, MSG_FINAL_SCORE
    INT 21h
    
    LEA DX, SCORE_STR
    MOV AH, 09h
    INT 21h

    MOV DH, 15
    MOV DL, 25
    CALL MOVE_CURSOR
    MOV AH, 09h
    LEA DX, MSG_REPLAY
    INT 21h

WAIT_REPLAY_KEY:
    CALL READ_CHAR
    CMP AL, 'Y'
    JE RESTART_GAME
    CMP AL, 'y'
    JE RESTART_GAME
    CMP AL, 'N'
    JE END_PROG
    CMP AL, 'n'
    JE END_PROG
    JMP WAIT_REPLAY_KEY

RESTART_GAME:
    CALL INIT_GAME
    CALL INIT_SCREEN
    CALL HIDE_CURSOR
    CALL DRAW_INITIAL_MAP
    CALL DRAW_SCORE

    MOV BYTE PTR [POS_ROW], 20
    MOV BYTE PTR [POS_COL], 40
    MOV BYTE PTR [INC_ROW], 0
    MOV BYTE PTR [INC_COL], 0

    JMP MAIN_LOOP

END_PROG:
    CALL RESTORE_TIMER_INTERRUPT
    CALL SHOW_CURSOR
    MOV AX, 0003h
    INT 10h
    INT 20h

MAIN    ENDP

; ****************************************
; Game timer interrupt service routine
; Called 18.2 times per second by the operating system
; Calls previous ISR
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   OLD_INTERRUPT_BASE memory variable
;   END_GAME memory variable
;   CAR_INT_COUNT memory variable
;   INT_COUNT memory variable
;   DIV_SPEED memory variable
; ****************************************
PUBLIC NEW_TIMER_INTERRUPT
NEW_TIMER_INTERRUPT PROC NEAR

    PUSHF
    CALL DWORD PTR [OLD_INTERRUPT_BASE]

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH DS
    MOV AX, CS
    MOV DS, AX

    CMP BYTE PTR [END_GAME], TRUE
    JNE NOT_END_GAME
    JMP EXIT_ISR_DIRECT

NOT_END_GAME:
    INC BYTE PTR [CAR_INT_COUNT]
    MOV AL, BYTE PTR [CAR_INT_COUNT]
    CMP AL, CAR_DIV_SPEED
    JNE SKIP_CAR_MOVE
    MOV BYTE PTR [CAR_INT_COUNT], 0
    CALL ERASE_CARS
    CALL MOVE_CARS
    CALL DRAW_CARS

SKIP_CAR_MOVE:
    INC BYTE PTR [INT_COUNT]
    MOV AL, BYTE PTR [INT_COUNT]
    CMP AL, BYTE PTR [DIV_SPEED]
    JE DO_LOGIC
    JMP EXIT_ISR

DO_LOGIC:
    MOV BYTE PTR [INT_COUNT], 0

    MOV DH, BYTE PTR [POS_ROW]
    MOV DL, BYTE PTR [POS_COL]
    CALL MOVE_CURSOR
    CALL RESTORE_TRAIL_COLOR

    CMP BYTE PTR [INC_ROW], -1
    JNE SKIP_SCORE_INC
    INC WORD PTR [SCORE]
SKIP_SCORE_INC:

    MOV AL, BYTE PTR [INC_COL]
    ADD BYTE PTR [POS_COL], AL
    MOV AL, BYTE PTR [INC_ROW]
    ADD BYTE PTR [POS_ROW], AL
    MOV BYTE PTR [INC_COL], 0
    MOV BYTE PTR [INC_ROW], 0

    CMP BYTE PTR [POS_ROW], 5
    JB DO_SCROLL
    JMP SKIP_SCROLL

DO_SCROLL:
    MOV AX, 0701h
    MOV BH, 07h
    XOR CX, CX
    MOV DX, 184Fh
    INT 10h
    MOV BYTE PTR [POS_ROW], 6

    CALL SHIFT_CARS_DOWN

    MOV SI, 23
SHIFT_ARRAY:
    MOV AL, [LINE_TYPES + SI]
    MOV [LINE_TYPES + SI + 1], AL
    DEC SI
    CMP SI, -1
    JNESHIFT_ARRAY

    MOV DH, 1               
    MOV DL, 0               
    CALL MOVE_CURSOR
    XOR BX, BX
    MOV BL, [LINE_TYPES + 1] 
    MOV AL, ASCII_WALL
    MOV CX, 4               
    CALL PRINT_MULTIPLE_CHAR

    INC BYTE PTR [MAP_LINE_COUNT]
    CALL UPDATE_MAP_COLOR
    MOV AL, BYTE PTR [CURRENT_COLOR]
    MOV [LINE_TYPES], AL

    MOV BL, AL
    MOV AL, ASCII_WALL
    CMP BL, COLOR_GREEN
    JE DRAW_GREEN_ROW

    MOV DH, 0
    MOV DL, 0
    CALL MOVE_CURSOR
    MOV CX, 80
    CALL PRINT_MULTIPLE_CHAR

    CMP BL, COLOR_ROAD
    JE DO_SPAWN
    CMP BL, COLOR_WATER
    JNE SKIP_SPAWN
DO_SPAWN:
    CALL SPAWN_CARS_ON_ROW_ZERO
    JMP SKIP_SCROLL

DRAW_GREEN_ROW:
    MOV DH, 0
    MOV DL, 0
    CALL MOVE_CURSOR
    MOV CX, FIELD_C1
    CALL PRINT_MULTIPLE_CHAR
    MOV DL, FIELD_C2
    CALL MOVE_CURSOR
    MOV CX, 25
    CALL PRINT_MULTIPLE_CHAR

SKIP_SPAWN:
SKIP_SCROLL:
    CALL CHECK_CAR_COLLISION
    CMP BYTE PTR [END_GAME], TRUE
    JE EXIT_ISR

    XOR BX, BX
    MOV BL, BYTE PTR [POS_ROW]
    MOV AL, [LINE_TYPES + BX]

    CMP AL, COLOR_GREEN
    JNE DRAW_PLAYER

    MOV AL, BYTE PTR [POS_COL]
    CMP AL, FIELD_C1
    JB TRIGGER_COLLISION
    CMP AL, FIELD_C2
    JAE TRIGGER_COLLISION

DRAW_PLAYER:
    MOV DH, BYTE PTR [POS_ROW]
    MOV DL, BYTE PTR [POS_COL]
    CALL MOVE_CURSOR
    MOV AL, ASCII_PLAYER
    MOV BL, ATTR_PLAYER
    CALL PRINT_CHAR_ATTR
    JMP EXIT_ISR

TRIGGER_COLLISION:
    MOV BYTE PTR [END_GAME], TRUE

EXIT_ISR:
    CALL DRAW_SCORE 
EXIT_ISR_DIRECT:
    POP DS
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    IRET

NEW_TIMER_INTERRUPT ENDP

; ****************************************
; Converts score to string and prints it at top-left corner
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   SCORE memory variable
;   SCORE_STR memory variable
; Calls:
;   MOVE_CURSOR
;   PRINT_CHAR_ATTR
; ****************************************
PUBLIC DRAW_SCORE
DRAW_SCORE  PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV AX, WORD PTR [SCORE]
    MOV BX, 10
    MOV CX, 4
    LEA SI, [SCORE_STR + 3] 

CONVERT_SCORE_LOOP:
    XOR DX, DX
    DIV BX                  
    ADD DL, '0'             
    MOV [SI], DL
    DEC SI
    LOOP CONVERT_SCORE_LOOP

    MOV DH, 0               
    MOV DL, 0               
    XOR SI, SI              

PRINT_SCORE_LOOP:
    CALL MOVE_CURSOR
    MOV AL, BYTE PTR [SCORE_STR + SI]
    MOV BL, 00Fh            
    CALL PRINT_CHAR_ATTR
    INC DL                  
    INC SI
    CMP SI, 4
    JNE PRINT_SCORE_LOOP

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

DRAW_SCORE  ENDP

; ****************************************
; Erases all active objects from the screen dynamically
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   NUM_CARS memory variable
;   CARS_ROW memory variable
;   CARS_COL memory variable
;   LINE_TYPES memory variable
; Calls:
;   MOVE_CURSOR
;   PRINT_CHAR_ATTR
; ****************************************
PUBLIC ERASE_CARS
ERASE_CARS  PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    XOR SI, SI
    MOV CL, BYTE PTR [NUM_CARS]
    XOR CH, CH
    CMP CX, 0
    JE ERASE_CARS_END

ERASE_CARS_LOOP:
    MOV DH, BYTE PTR [CARS_ROW + SI]
    MOV DL, BYTE PTR [CARS_COL + SI]
    CALL MOVE_CURSOR
    
    XOR BX, BX
    MOV BL, DH
    MOV BL, BYTE PTR [LINE_TYPES + BX] 
    
    MOV AL, ASCII_WALL
    CALL PRINT_CHAR_ATTR
    INC SI
    LOOP ERASE_CARS_LOOP

ERASE_CARS_END:
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

ERASE_CARS  ENDP

; ****************************************
; Generates a random column between 0 and 79
; Entry: 
;   -
; Returns:
;   AL: random column index
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 21h, service AH=2Ch
; ****************************************
PUBLIC GET_RANDOM_COL
GET_RANDOM_COL PROC NEAR
    PUSH CX
    PUSH DX

    MOV AH, 2Ch
    INT 21h

    IN AL, 40h
    XOR AL, DL

    XOR AH, AH
    MOV CL, 80
    DIV CL
    MOV AL, AH      

    POP DX
    POP CX
    RET
GET_RANDOM_COL ENDP

; ****************************************
; Moves active cars/logs with wrap-around behavior
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   NUM_CARS memory variable
;   CARS_COL memory variable
;   CARS_DIR memory variable
; ****************************************
PUBLIC MOVE_CARS
MOVE_CARS   PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    MOV CL, BYTE PTR [NUM_CARS]
    XOR CH, CH
    CMP CX, 0
    JE MOVE_CARS_END

    XOR SI, SI          
    XOR DI, DI          

MOVE_CARS_LOOP:
    MOV AL, BYTE PTR [CARS_DIR + SI]
    ADD BYTE PTR [CARS_COL + SI], AL

    MOV BL, BYTE PTR [CARS_COL + SI]
    CMP BL, 80
    JB KEEP_CAR         

    MOV AL, BYTE PTR [CARS_DIR + SI]
    CMP AL, 1
    JE WRAP_RIGHT
    MOV BYTE PTR [CARS_COL + SI], 79
    JMP KEEP_CAR
WRAP_RIGHT:
    MOV BYTE PTR [CARS_COL + SI], 0

KEEP_CAR:
    MOV AL, BYTE PTR [CARS_ROW + SI]
    MOV BYTE PTR [CARS_ROW + DI], AL
    MOV AL, BYTE PTR [CARS_COL + SI]
    MOV BYTE PTR [CARS_COL + DI], AL
    MOV AL, BYTE PTR [CARS_DIR + SI]
    MOV BYTE PTR [CARS_DIR + DI], AL
    MOV AL, BYTE PTR [CARS_ATTR + SI]
    MOV BYTE PTR [CARS_ATTR + DI], AL
    INC DI

    INC SI
    LOOP MOVE_CARS_LOOP

    PUSH DI
    POP AX
    MOV BYTE PTR [NUM_CARS], AL

MOVE_CARS_END:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

MOVE_CARS   ENDP

; ****************************************
; Draws all active objects using their color attribute
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   NUM_CARS memory variable
;   CARS_ROW memory variable
;   CARS_COL memory variable
;   CARS_ATTR memory variable
; Calls:
;   MOVE_CURSOR
;   PRINT_CHAR_ATTR
; ****************************************
PUBLIC DRAW_CARS
DRAW_CARS   PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    XOR SI, SI
    MOV CL, BYTE PTR [NUM_CARS]
    XOR CH, CH
    CMP CX, 0
    JE DRAW_CARS_END

DRAW_CARS_LOOP:
    MOV DH, BYTE PTR [CARS_ROW + SI]
    MOV DL, BYTE PTR [CARS_COL + SI]
    CALL MOVE_CURSOR
    MOV AL, ASCII_CAR
    MOV BL, BYTE PTR [CARS_ATTR + SI] 
    CALL PRINT_CHAR_ATTR
    INC SI
    LOOP DRAW_CARS_LOOP

DRAW_CARS_END:
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

DRAW_CARS   ENDP

; ****************************************
; Checks if any object occupies the same cell as the player
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   NUM_CARS memory variable
;   POS_ROW memory variable
;   POS_COL memory variable
;   END_GAME memory variable
; ****************************************
PUBLIC CHECK_CAR_COLLISION
CHECK_CAR_COLLISION PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    XOR SI, SI
    MOV CL, BYTE PTR [NUM_CARS]
    XOR CH, CH
    CMP CX, 0
    JE CHECK_CAR_END

CHECK_CAR_LOOP:
    MOV AL, BYTE PTR [CARS_ROW + SI]
    CMP AL, BYTE PTR [POS_ROW]
    JNE CHECK_CAR_NEXT
    MOV AL, BYTE PTR [CARS_COL + SI]
    CMP AL, BYTE PTR [POS_COL]
    JNE CHECK_CAR_NEXT
    MOV BYTE PTR [END_GAME], TRUE
    JMP CHECK_CAR_END

CHECK_CAR_NEXT:
    INC SI
    LOOP CHECK_CAR_LOOP

CHECK_CAR_END:
    POP SI
    POP CX
    POP BX
    POP AX
    RET

CHECK_CAR_COLLISION ENDP

; ****************************************
; Spawns active objects on row zero according to terrain type
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   NUM_CARS memory variable
;   CURRENT_COLOR memory variable
;   MAP_LINE_COUNT memory variable
; Calls:
;   GET_RANDOM_COL
; ****************************************
PUBLIC SPAWN_CARS_ON_ROW_ZERO
SPAWN_CARS_ON_ROW_ZERO PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV BL, BYTE PTR [NUM_CARS]
    XOR BH, BH

    MOV DH, BYTE PTR [CURRENT_COLOR]

    MOV AL, BYTE PTR [MAP_LINE_COUNT]
    AND AL, 01h         
    
    JNZ DIR_RIGHT_TO_LEFT
    JMP DIR_LEFT_TO_RIGHT

DIR_RIGHT_TO_LEFT:
    CALL GET_RANDOM_COL
    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], AL
    MOV BYTE PTR [CARS_DIR + SI], -1
    
    PUSH AX
    CMP DH, COLOR_WATER
    JE L_LOG1
    XOR AH, AH
    MOV CL, 3
    DIV CL
    CMP AH, 0
    JE L_CAR1_W
    CMP AH, 1
    JE L_CAR1_R
    MOV AL, 0Eh         
    JMP L_SAVE1
L_CAR1_W:
    MOV AL, 0Fh         
    JMP L_SAVE1
L_CAR1_R:
    MOV AL, 0Ch         
    JMP L_SAVE1
L_LOG1:
    MOV AL, 06h         
L_SAVE1:
    MOV BYTE PTR [CARS_ATTR + SI], AL
    POP AX
    INC BL

    ADD AL, 40
    CMP AL, 80
    JB SET_OBJ2_L
    SUB AL, 80
SET_OBJ2_L:
    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], AL
    MOV BYTE PTR [CARS_DIR + SI], -1
    
    PUSH AX
    CMP DH, COLOR_WATER
    JE L_LOG2
    XOR AH, AH
    MOV CL, 3
    DIV CL
    CMP AH, 0
    JE L_CAR2_W
    CMP AH, 1
    JE L_CAR2_R
    MOV AL, 0Eh
    JMP L_SAVE2
L_CAR2_W:
    MOV AL, 0Fh
    JMP L_SAVE2
L_CAR2_R:
    MOV AL, 0Ch
    JMP L_SAVE2
L_LOG2:
    MOV AL, 06h
L_SAVE2:
    MOV BYTE PTR [CARS_ATTR + SI], AL
    POP AX
    INC BL
    JMP SPAWN_DONE

DIR_LEFT_TO_RIGHT:
    CALL GET_RANDOM_COL
    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], AL
    MOV BYTE PTR [CARS_DIR + SI], 1
    
    PUSH AX
    CMP DH, COLOR_WATER
    JE R_LOG1
    XOR AH, AH
    MOV CL, 3
    DIV CL
    CMP AH, 0
    JE R_CAR1_W
    CMP AH, 1
    JE R_CAR1_R
    MOV AL, 0Eh
    JMP R_SAVE1
R_CAR1_W:
    MOV AL, 0Fh
    JMP R_SAVE1
R_CAR1_R:
    MOV AL, 0Ch
    JMP R_SAVE1
R_LOG1:
    MOV AL, 06h
R_SAVE1:
    MOV BYTE PTR [CARS_ATTR + SI], AL
    POP AX
    INC BL

    ADD AL, 40
    CMP AL, 80
    JB SET_OBJ2_R
    SUB AL, 80
SET_OBJ2_R:
    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], AL
    MOV BYTE PTR [CARS_DIR + SI], 1
    
    PUSH AX
    CMP DH, COLOR_WATER
    JE R_LOG2
    XOR AH, AH
    MOV CL, 3
    DIV CL
    CMP AH, 0
    JE R_CAR2_W
    CMP AH, 1
    JE R_CAR2_R
    MOV AL, 0Eh
    JMP R_SAVE2
R_CAR2_W:
    MOV AL, 0Fh
    JMP R_SAVE2
R_CAR2_R:
    MOV AL, 0Ch
    JMP R_SAVE2
R_LOG2:
    MOV AL, 06h
R_SAVE2:
    MOV BYTE PTR [CARS_ATTR + SI], AL
    POP AX
    INC BL

SPAWN_DONE:
    CMP BL, MAX_CARS
    JBE STORE_COUNT
    MOV BL, MAX_CARS
STORE_COUNT:
    MOV BYTE PTR [NUM_CARS], BL

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

SPAWN_CARS_ON_ROW_ZERO ENDP

; ****************************************
; Shifts all active object row positions down by 1
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   NUM_CARS memory variable
;   CARS_ROW memory variable
; ****************************************
PUBLIC SHIFT_CARS_DOWN
SHIFT_CARS_DOWN PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI

    MOV CL, BYTE PTR [NUM_CARS]
    XOR CH, CH
    CMP CX, 0
    JE SHIFT_CARS_END

    XOR SI, SI
    XOR DI, DI

SHIFT_CARS_LOOP:
    INC BYTE PTR [CARS_ROW + SI]
    MOV AL, BYTE PTR [CARS_ROW + SI]
    CMP AL, 25
    JAE SHIFT_SKIP

    MOV AL, BYTE PTR [CARS_ROW + SI]
    MOV BYTE PTR [CARS_ROW + DI], AL
    MOV AL, BYTE PTR [CARS_COL + SI]
    MOV BYTE PTR [CARS_COL + DI], AL
    MOV AL, BYTE PTR [CARS_DIR + SI]
    MOV BYTE PTR [CARS_DIR + DI], AL
    MOV AL, BYTE PTR [CARS_ATTR + SI]
    MOV BYTE PTR [CARS_ATTR + DI], AL
    INC DI

SHIFT_SKIP:
    INC SI
    LOOP SHIFT_CARS_DOWN

    PUSH DI
    POP AX
    MOV BYTE PTR [NUM_CARS], AL

SHIFT_CARS_END:
    POP DI
    POP SI
    POP CX
    POP BX
    POP AX
    RET

SHIFT_CARS_DOWN ENDP

; ****************************************
; Restores the background terrain color at current cell
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   POS_ROW memory variable
;   POS_COL memory variable
;   LINE_TYPES memory variable
; Calls:
;   PRINT_CHAR_ATTR
; ****************************************
PUBLIC RESTORE_TRAIL_COLOR
RESTORE_TRAIL_COLOR PROC NEAR

    PUSH AX
    PUSH BX

    XOR BX, BX
    MOV BL, BYTE PTR [POS_ROW]
    MOV AL, [LINE_TYPES + BX]

    CMP AL, COLOR_GREEN
    JE  TRAIL_GREEN
    CMP AL, COLOR_ROAD
    JE  TRAIL_ROAD

    MOV BL, COLOR_WATER
    MOV AL, ASCII_WALL
    CALL PRINT_CHAR_ATTR
    JMP RESTORE_END

TRAIL_ROAD:
    MOV BL, COLOR_ROAD
    MOV AL, ASCII_WALL
    CALL PRINT_CHAR_ATTR
    JMP RESTORE_END

TRAIL_GREEN:
    MOV AL, BYTE PTR [POS_COL]
    CMP AL, FIELD_C1
    JB  TRAIL_GREEN_WALL
    CMP AL, FIELD_C2
    JAE TRAIL_GREEN_WALL

    MOV BL, 000h
    MOV AL, ' '
    CALL PRINT_CHAR_ATTR
    JMP RESTORE_END

TRAIL_GREEN_WALL:
    MOV BL, COLOR_GREEN
    MOV AL, ASCII_WALL
    CALL PRINT_CHAR_ATTR

RESTORE_END:
    POP BX
    POP AX
    RET

RESTORE_TRAIL_COLOR ENDP

; ****************************************
; Updates CURRENT_COLOR sequence limits
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   MAP_LINE_COUNT memory variable
;   CURRENT_COLOR memory variable
; ****************************************
PUBLIC UPDATE_MAP_COLOR
UPDATE_MAP_COLOR PROC NEAR

    PUSH AX

    MOV AL, BYTE PTR [MAP_LINE_COUNT]
    CMP AL, 10
    JB  SET_GREEN
    CMP AL, 30
    JB  SET_ROAD
    CMP AL, 40
    JB  SET_GREEN
    CMP AL, 60
    JB  SET_ROAD
    CMP AL, 70
    JB  SET_GREEN
    CMP AL, 90
    JB  SET_WATER

    MOV BYTE PTR [MAP_LINE_COUNT], 0

SET_GREEN:
    MOV BYTE PTR [CURRENT_COLOR], COLOR_GREEN
    JMP UPDATE_MAP_COLOR_END

SET_ROAD:
    MOV BYTE PTR [CURRENT_COLOR], COLOR_ROAD
    JMP UPDATE_MAP_COLOR_END

SET_WATER:
    MOV BYTE PTR [CURRENT_COLOR], COLOR_WATER

UPDATE_MAP_COLOR_END:
    POP AX
    RET

UPDATE_MAP_COLOR ENDP

; ****************************************
; Prints a character multiple times
; Entry: 
;   AL: ASCII character
;   BL: attribute
;   CX: count
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=09h
; ****************************************
PUBLIC PRINT_MULTIPLE_CHAR
PRINT_MULTIPLE_CHAR PROC NEAR

    PUSH AX
    PUSH BX

    MOV AH, 09h
    XOR BH, BH
    INT 10h

    POP BX
    POP AX
    RET

PRINT_MULTIPLE_CHAR ENDP

; ****************************************
; Draws the initial green map matrix
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   TEMP_ROW memory variable
;   LINE_TYPES memory variable
; Calls:
;   MOVE_CURSOR
;   PRINT_MULTIPLE_CHAR
; ****************************************
PUBLIC DRAW_INITIAL_MAP
DRAW_INITIAL_MAP PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV BYTE PTR [TEMP_ROW], 0

LOOP_DRAW_MAP:
    XOR AX, AX
    MOV AL, BYTE PTR [TEMP_ROW]
    MOV DI, AX
    MOV BYTE PTR [LINE_TYPES + DI], COLOR_GREEN

    MOV DH, BYTE PTR [TEMP_ROW]
    MOV DL, 0
    CALL MOVE_CURSOR
    MOV AL, ASCII_WALL
    MOV BL, COLOR_GREEN
    MOV CX, FIELD_C1
    CALL PRINT_MULTIPLE_CHAR

    MOV DL, FIELD_C2
    CALL MOVE_CURSOR
    MOV CX, 25
    CALL PRINT_MULTIPLE_CHAR

    INC BYTE PTR [TEMP_ROW]
    CMP BYTE PTR [TEMP_ROW], 25
    JNE LOOP_DRAW_MAP

    POP DX
    POP CX
    POP BX
    POP AX
    RET

DRAW_INITIAL_MAP ENDP

; ****************************************
; Reset internal game variables
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   MAP_LINE_COUNT memory variable
;   CURRENT_COLOR memory variable
;   DIV_SPEED memory variable
;   INT_COUNT memory variable
;   END_GAME memory variable
;   NUM_CARS memory variable
;   CAR_INT_COUNT memory variable
;   SCORE memory variable
; ****************************************
PUBLIC INIT_GAME
INIT_GAME PROC NEAR

    MOV BYTE PTR [MAP_LINE_COUNT], 0
    MOV BYTE PTR [CURRENT_COLOR], COLOR_GREEN
    MOV BYTE PTR [DIV_SPEED], 2
    MOV BYTE PTR [INT_COUNT], 0
    MOV BYTE PTR [END_GAME], FALSE
    MOV BYTE PTR [NUM_CARS], 0
    MOV BYTE PTR [CAR_INT_COUNT], 0
    MOV WORD PTR [SCORE], 0

    RET

INIT_GAME ENDP

; ****************************************
; Set screen to mode 3
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=00h
; ****************************************
PUBLIC INIT_SCREEN
INIT_SCREEN PROC NEAR

    PUSH AX

    MOV AX, 0003h
    INT 10h

    POP AX
    RET

INIT_SCREEN ENDP

; ****************************************
; Hides text cursor
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   CURSOR_SIZE_HIDE constant
; Calls:
;   int 10h, service AH=01h
; ****************************************
PUBLIC HIDE_CURSOR
HIDE_CURSOR PROC NEAR

    PUSH AX
    PUSH CX

    MOV AH, 01h
    MOV CX, CURSOR_SIZE_HIDE
    INT 10h

    POP CX
    POP AX
    RET

HIDE_CURSOR ENDP

; ****************************************
; Shows text cursor
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   CURSOR_SIZE_SHOW constant
; Calls:
;   int 10h, service AH=01h
; ****************************************
PUBLIC SHOW_CURSOR
SHOW_CURSOR PROC NEAR

    PUSH AX
    PUSH CX

    MOV AH, 01h
    MOV CX, CURSOR_SIZE_SHOW
    INT 10h

    POP CX
    POP AX
    RET

SHOW_CURSOR ENDP

; ****************************************
; Moves cursor to coordinate
; Entry: 
;   (DH, DL): coordinates -> (row, col)
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=02h
; ****************************************
PUBLIC MOVE_CURSOR
MOVE_CURSOR PROC NEAR

    PUSH AX
    PUSH BX

    MOV AH, 02h
    XOR BH, BH 
    INT 10h

    POP BX
    POP AX
    RET

MOVE_CURSOR ENDP

; ****************************************
; Prints a character and attribute at cursor position
; Entry: 
;   AL: ASCII code
;   BL: attribute
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=09h
; ****************************************
PUBLIC PRINT_CHAR_ATTR
PRINT_CHAR_ATTR PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX

    MOV AH, 09h
    XOR BH, BH
    MOV CX, 0001h
    INT 10h

    POP CX
    POP BX
    POP AX
    RET

PRINT_CHAR_ATTR ENDP

; ****************************************
; Reads char from keyboard without echo
; Entry: 
;   -
; Returns:
;   AL: ASCII code
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 21h, service AH=08h
; ****************************************
PUBLIC READ_CHAR
READ_CHAR PROC NEAR

    MOV AH, 08h
    INT 21h

    RET

READ_CHAR ENDP

; ****************************************
; Replaces current timer ISR with game timer ISR
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   OLD_INTERRUPT_BASE memory variable
; Calls:
;   int 21h, service AH=35h
;   int 21h, service AH=25h
; ****************************************
PUBLIC REGISTER_TIMER_INTERRUPT
REGISTER_TIMER_INTERRUPT PROC NEAR

    PUSH AX
    PUSH BX
    PUSH DS
    PUSH ES

    CLI

    MOV AX, 3508h
    INT 21h
    MOV WORD PTR [OLD_INTERRUPT_BASE + 2], ES
    MOV WORD PTR [OLD_INTERRUPT_BASE], BX

    MOV AX, 2508h
    MOV DX, OFFSET NEW_TIMER_INTERRUPT
    INT 21h

    STI

    POP ES
    POP DS
    POP BX
    POP AX
    RET

REGISTER_TIMER_INTERRUPT ENDP

; ****************************************
; Restore system timer ISR
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   OLD_INTERRUPT_BASE memory variable
; Calls:
;   int 21h, service AH=25h
; ****************************************
PUBLIC RESTORE_TIMER_INTERRUPT
RESTORE_TIMER_INTERRUPT PROC NEAR

    PUSH AX
    PUSH DS
    PUSH DX

    CLI

    MOV AX, 2508h
    MOV DX, WORD PTR [OLD_INTERRUPT_BASE]
    MOV DS, WORD PTR [OLD_INTERRUPT_BASE + 2]
    INT 21h

    STI

    POP DX
    POP DS
    POP AX
    RET

RESTORE_TIMER_INTERRUPT ENDP

CODE_SEG ENDS

DATA_SEG    SEGMENT PUBLIC

    OLD_INTERRUPT_BASE  DW 0, 0

    INC_COL    DB 0
    INC_ROW    DB 0

    POS_ROW    DB 0
    POS_COL    DB 0

    DIV_SPEED  DB 0
    INT_COUNT  DB 0

    END_GAME   DB 0

    MAP_LINE_COUNT DB 0
    CURRENT_COLOR  DB 0

    TEMP_ROW       DB 0

    LINE_TYPES     DB 26 DUP(0)

    CAR_INT_COUNT  DB 0
    NUM_CARS       DB 0
    CARS_ROW       DB MAX_CARS DUP(0)
    CARS_COL       DB MAX_CARS DUP(0)
    CARS_DIR       DB MAX_CARS DUP(0)
    CARS_ATTR      DB MAX_CARS DUP(0)

    SCORE      DW 0
    SCORE_STR  DB '0','0','0','0','$'

    MSG_GAME_OVER   DB '=== FIN DEL JUEGO ===', '$'
    MSG_FINAL_SCORE DB 'Puntuacion final: ', '$'
    MSG_REPLAY      DB 'Quieres volver a jugar? (Y/N) ', '$'

DATA_SEG ENDS

END MAIN