; *************************************************************************
; Our data section. Here we declare our strings for our console message
; *************************************************************************

SGROUP      GROUP   CODE_SEG, DATA_SEG
            ASSUME  CS:SGROUP, DS:SGROUP, SS:SGROUP

    ; LOGICAL CONSTANTS
    TRUE  EQU 1
    FALSE EQU 0

    ; ASCII CODES FOR SPECIAL KEYS 
    ASCII_SPECIAL_KEY EQU 00
    ASCII_LEFT        EQU 04Bh
    ASCII_RIGHT       EQU 04Dh
    ASCII_UP          EQU 048h
    ASCII_QUIT        EQU 071h ; 'q'

    ; PLAYER ASCII / ATTR
    ASCII_PLAYER      EQU 02Ah ; *
    ATTR_PLAYER       EQU 00Fh ; white

    ; PATH WALL ASCII / ATTR
    ASCII_WALL        EQU 0DBh 

    ; CURSOR
    CURSOR_SIZE_HIDE  EQU 02607h ; BIT 5 OF CH = 1 MEANS HIDE CURSOR
    CURSOR_SIZE_SHOW  EQU 00607h

    ; SCREEN DIMENSIONS
    SCREEN_MAX_ROWS   EQU 25
    SCREEN_MAX_COLS   EQU 80

    ; FIELD BOUNDARIES
    FIELD_C1 EQU 25
    FIELD_C2 EQU 55

    ; TERRAIN COLORS 
    COLOR_GREEN EQU 02h ; Green 
    COLOR_ROAD  EQU 08h ; Gray
    COLOR_WATER EQU 03h ; Cyan 

    ; BACKGROUND ATTR FOR TRAIL RESTORE 
    ATTR_BG_GREEN EQU 020h 
    ATTR_BG_ROAD  EQU 080h  
    ATTR_BG_WATER EQU 030h  

; *************************************************************************
; Our executable assembly code starts here in the .code section
; *************************************************************************
CODE_SEG    SEGMENT PUBLIC
            ORG 100h

; ****************************************
; Main entry point of the program.
; Initializes the game, screen and map,
; then enters the main keyboard-reading loop.
; Entry:
;  
; Returns:
;  
; Modifies:
;   
; Uses:
;   END_GAME, POS_ROW, POS_COL
; Calls:
;   REGISTER_TIMER_INTERRUPT, INIT_GAME, INIT_SCREEN,
;   HIDE_CURSOR, DRAW_INITIAL_MAP, READ_CHAR
; ****************************************
MAIN    PROC    NEAR

    MOV AX, CS
    MOV DS, AX

    CALL REGISTER_TIMER_INTERRUPT
    CALL INIT_GAME
    CALL INIT_SCREEN
    CALL HIDE_CURSOR
    CALL DRAW_INITIAL_MAP

    ; Initial player position
    MOV BYTE PTR [POS_ROW], 20
    MOV BYTE PTR [POS_COL], 40

MAIN_LOOP:
    CMP BYTE PTR [END_GAME], TRUE
    JE JUMP_TO_END

    ; Check for a key
    MOV AH, 0Bh
    INT 21h
    CMP AL, 0
    JE MAIN_LOOP

    ; Read available key
    CALL READ_CHAR

    CMP AL, ASCII_QUIT
    JE JUMP_TO_END

    ; Is it a special key?
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

JUMP_TO_END: JMP END_PROG

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

END_PROG:
    CALL RESTORE_TIMER_INTERRUPT
    CALL SHOW_CURSOR
    MOV AX, 0003h
    INT 10h
    INT 20h

MAIN    ENDP

; ****************************************
; Game timer service routine.
; Called ~18.2 times/second by the OS.
; Handles: trail erasing with terrain color,
; movement, scroll, collision and player drawing.
; Entry:
; 
; Returns:
; 
; Modifies:
; 
; Uses:
;   OLD_INTERRUPT_BASE, INT_COUNT, DIV_SPEED,
;   POS_ROW, POS_COL, INC_ROW, INC_COL,
;   LINE_TYPES, END_GAME
; Calls:
;   MOVE_CURSOR, PRINT_CHAR_ATTR, RESTORE_TRAIL_COLOR,
;   UPDATE_MAP_COLOR, PRINT_MULTIPLE_CHAR
; ****************************************
            PUBLIC NEW_TIMER_INTERRUPT
NEW_TIMER_INTERRUPT PROC NEAR

    ; Call the previous ISR
    PUSHF
    CALL DWORD PTR [OLD_INTERRUPT_BASE]

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DS
    MOV AX, CS
    MOV DS, AX

    ; Increment counter and check if it is time to act
    INC BYTE PTR [INT_COUNT]
    MOV AL, BYTE PTR [INT_COUNT]
    CMP AL, BYTE PTR [DIV_SPEED]
    JE DO_LOGIC
    JMP EXIT_ISR

DO_LOGIC:
    MOV BYTE PTR [INT_COUNT], 0

    ; Erase trail by restoring terrain color 
    MOV DH, BYTE PTR [POS_ROW]
    MOV DL, BYTE PTR [POS_COL]
    CALL MOVE_CURSOR
    CALL RESTORE_TRAIL_COLOR

    ; Update position 
    MOV AL, BYTE PTR [INC_COL]
    ADD BYTE PTR [POS_COL], AL
    MOV AL, BYTE PTR [INC_ROW]
    ADD BYTE PTR [POS_ROW], AL
    MOV BYTE PTR [INC_COL], 0
    MOV BYTE PTR [INC_ROW], 0

    ; Physical and logical scroll when player reaches the top 
    CMP BYTE PTR [POS_ROW], 5
    JAE SKIP_SCROLL

    ; Shifts the screen one line downward
    MOV AX, 0701h
    MOV BH, 07h
    XOR CX, CX
    MOV DX, 184Fh
    INT 10h
    MOV BYTE PTR [POS_ROW], 6

    ; Shifts the LINE_TYPES array one position downward
    MOV SI, 23
SHIFT_ARRAY:
    MOV AL, [LINE_TYPES + SI]
    MOV [LINE_TYPES + SI + 1], AL
    DEC SI
    CMP SI, -1
    JNE SHIFT_ARRAY

    ; Generate new top line according to terrain sequence
    INC BYTE PTR [MAP_LINE_COUNT]
    CALL UPDATE_MAP_COLOR
    MOV AL, BYTE PTR [CURRENT_COLOR]
    MOV [LINE_TYPES], AL

    ; Draw new row 0 according to terrain type
    MOV BL, AL
    MOV AL, ASCII_WALL
    CMP BL, COLOR_GREEN
    JE DRAW_GREEN_ROW

    ; Full solid row of water
    MOV DH, 0
    MOV DL, 0
    CALL MOVE_CURSOR
    MOV CX, 80
    CALL PRINT_MULTIPLE_CHAR
    JMP SKIP_SCROLL

DRAW_GREEN_ROW:
    ; Green side walls with a gap in the center
    MOV DH, 0
    MOV DL, 0
    CALL MOVE_CURSOR
    MOV CX, FIELD_C1
    CALL PRINT_MULTIPLE_CHAR
    MOV DL, FIELD_C2
    CALL MOVE_CURSOR
    MOV CX, 25
    CALL PRINT_MULTIPLE_CHAR

SKIP_SCROLL:
    ; Collision logic based on terrain type of the current row 
    XOR BX, BX
    MOV BL, BYTE PTR [POS_ROW]
    MOV AL, [LINE_TYPES + BX] ; Ground type where the player is standing

    CMP AL, COLOR_GREEN
    JNE DRAW_PLAYER ; Road/Water, no side walls

    ; Green zone check if player is inside the gap
    MOV AL, BYTE PTR [POS_COL]
    CMP AL, FIELD_C1
    JB TRIGGER_COLLISION
    CMP AL, FIELD_C2
    JAE TRIGGER_COLLISION

DRAW_PLAYER:
    ; Draw player at the new position
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
    POP DS
    POP DX
    POP CX
    POP BX
    POP AX
    IRET

NEW_TIMER_INTERRUPT ENDP

; ****************************************
; Restores the terrain color at the current cursor position.
; Green interior: does nothing (leaves the gap empty)
; Green wall (col < FIELD_C1 or col >= FIELD_C2): repaints ASCII_WALL with COLOR_GREEN
; Road solid block with gray color
; Water solid block with cyan color
; Entry:
;   Cursor already positioned at (POS_ROW, POS_COL)
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   POS_ROW, POS_COL, LINE_TYPES
;   ASCII_WALL, COLOR_GREEN
;   ATTR_BG_ROAD, ATTR_BG_WATER
; Calls:
;   PRINT_CHAR_ATTR
; ****************************************
            PUBLIC RESTORE_TRAIL_COLOR
RESTORE_TRAIL_COLOR PROC NEAR

    PUSH AX
    PUSH BX

    ; Get terrain type for the players current row
    XOR BX, BX
    MOV BL, BYTE PTR [POS_ROW]
    MOV AL, [LINE_TYPES + BX]

    CMP AL, COLOR_GREEN
    JE  TRAIL_GREEN
    CMP AL, COLOR_ROAD
    JE  TRAIL_ROAD

    ; Water solid block with cyan color
    MOV BL, COLOR_WATER
    MOV AL, ASCII_WALL
    CALL PRINT_CHAR_ATTR
    JMP RESTORE_END

TRAIL_ROAD:
    ; Road solid block with gray color
    MOV BL, COLOR_ROAD
    MOV AL, ASCII_WALL
    CALL PRINT_CHAR_ATTR
    JMP RESTORE_END

TRAIL_GREEN:
    ; Check if column is in the side wall zone
    MOV AL, BYTE PTR [POS_COL]
    CMP AL, FIELD_C1
    JB  TRAIL_GREEN_WALL        ; col < FIELD_C1, left wall
    CMP AL, FIELD_C2
    JAE TRAIL_GREEN_WALL        ; col >= FIELD_C2, right wall

    ; Green path interior erase the * with a black space
    MOV BL, 000h
    MOV AL, ' '
    CALL PRINT_CHAR_ATTR
    JMP RESTORE_END

TRAIL_GREEN_WALL:
    ; Side wall repaint the solid block with green color
    MOV BL, COLOR_GREEN
    MOV AL, ASCII_WALL
    CALL PRINT_CHAR_ATTR

RESTORE_END:
    POP BX
    POP AX
    RET

RESTORE_TRAIL_COLOR ENDP

; ****************************************
; Updates CURRENT_COLOR according to the cyclic terrain sequence:
; Green
; Road
; Green
; Road
; Green
; Water
; Reset and Green
; Entry:
;   MAP_LINE_COUNT: counter of generated lines
; Returns:
;   CURRENT_COLOR updated
; Modifies:
;   -
; Uses:
;   MAP_LINE_COUNT, CURRENT_COLOR
; Calls:
;   -
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

    ; Cycle complete reset counter
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
; Prints character AL with attribute BL CX times
; at the current cursor position (INT 10h, service 09h).
; Entry:
;   AL: ASCII character to print
;   BL: attribute
;   CX: number of repetitions
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
; Draws the initial map: all rows in green
; with walls at columns 0..FIELD_C1 and FIELD_C2..79.
; Also initializes the LINE_TYPES array to COLOR_GREEN.
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   TEMP_ROW, LINE_TYPES, ASCII_WALL, FIELD_C1, FIELD_C2
; Calls:
;   MOVE_CURSOR, PRINT_MULTIPLE_CHAR
; ****************************************
            PUBLIC DRAW_INITIAL_MAP
DRAW_INITIAL_MAP PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV BYTE PTR [TEMP_ROW], 0

LOOP_DRAW_MAP:
    ; Mark row as green in the logical array
    XOR AX, AX
    MOV AL, BYTE PTR [TEMP_ROW]
    MOV DI, AX
    MOV BYTE PTR [LINE_TYPES + DI], COLOR_GREEN

    ; Draw left wall
    MOV DH, BYTE PTR [TEMP_ROW]
    MOV DL, 0
    CALL MOVE_CURSOR
    MOV AL, ASCII_WALL
    MOV BL, COLOR_GREEN
    MOV CX, FIELD_C1
    CALL PRINT_MULTIPLE_CHAR

    ; Draw right wall
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
; Resets internal game variables.
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   MAP_LINE_COUNT, CURRENT_COLOR, DIV_SPEED,
;   INT_COUNT, END_GAME
; Calls:
;   -
; ****************************************
            PUBLIC INIT_GAME
INIT_GAME PROC NEAR

    MOV BYTE PTR [MAP_LINE_COUNT], 0
    MOV BYTE PTR [CURRENT_COLOR], COLOR_GREEN
    MOV BYTE PTR [DIV_SPEED], 2
    MOV BYTE PTR [INT_COUNT], 0
    MOV BYTE PTR [END_GAME], FALSE

    RET

INIT_GAME ENDP

; ****************************************
; Sets screen to mode 3 (80x25, color) and clears it.
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   -
; Calls:
;   int 10h, service AH=0
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
; Hides the text cursor.
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   CURSOR_SIZE_HIDE
; Calls:
;   int 10h, service AH=1
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
; Shows the text cursor (standard size).
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   CURSOR_SIZE_SHOW
; Calls:
;   int 10h, service AH=1
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
; Moves the cursor to the given coordinate (page 0).
; Entry:
;   DH: row
;   DL: column
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   -
; Calls:
;   int 10h, service AH=2
; ****************************************
            PUBLIC MOVE_CURSOR
MOVE_CURSOR PROC NEAR

    PUSH AX
    PUSH BX

    MOV AH, 02h
    XOR BX, BX
    INT 10h

    POP BX
    POP AX
    RET

MOVE_CURSOR ENDP

; ****************************************
; Prints a character and attribute at the current
; cursor position, page 0. Does not move the cursor.
; Entry:
;   AL: ASCII code to print
;   BL: attribute to apply
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   -
; Calls:
;   int 10h, service AH=9
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
; Reads a character from keyboard without displaying it.
; Blocks until a key is pressed.
; Entry:
;   -
; Returns:
;   AL: ASCII code of the key
; Modifies:
;   -
; Uses:
;   -
; Calls:
;   int 21h, service AH=8
; ****************************************
            PUBLIC READ_CHAR
READ_CHAR PROC NEAR

    MOV AH, 08h
    INT 21h

    RET

READ_CHAR ENDP

; ****************************************
; Registers the new timer ISR (INT 08h),
; saving the previous vector in OLD_INTERRUPT_BASE.
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   OLD_INTERRUPT_BASE, NEW_TIMER_INTERRUPT
; Calls:
;   int 21h, service AH=35h (get INT 08h vector)
;   int 21h, service AH=25h (set INT 08h vector)
; ****************************************
            PUBLIC REGISTER_TIMER_INTERRUPT
REGISTER_TIMER_INTERRUPT PROC NEAR

    PUSH AX
    PUSH BX
    PUSH DS
    PUSH ES

    CLI ; Disable interrupts

    ; Get current INT 08h vector
    MOV AX, 3508h
    INT 21h
    MOV WORD PTR [OLD_INTERRUPT_BASE + 2], ES ; Save segment
    MOV WORD PTR [OLD_INTERRUPT_BASE], BX ; Save offset

    ; Set new INT 08h vector
    MOV AX, 2508h
    MOV DX, OFFSET NEW_TIMER_INTERRUPT
    INT 21h

    STI ; re-enabling interrupts

    POP ES
    POP DS
    POP BX
    POP AX
    RET

REGISTER_TIMER_INTERRUPT ENDP

; ****************************************
; Restores the original timer ISR (INT 08h)
; from the value saved in OLD_INTERRUPT_BASE.
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   OLD_INTERRUPT_BASE
; Calls:
;   int 21h, service AH=25h (set INT 08h vector)
; ****************************************
            PUBLIC RESTORE_TIMER_INTERRUPT
RESTORE_TIMER_INTERRUPT PROC NEAR

    PUSH AX
    PUSH DS
    PUSH DX

    CLI ; Disable interrupts

    ; Restore original INT 08h vector
    MOV AX, 2508h
    MOV DX, WORD PTR [OLD_INTERRUPT_BASE]
    MOV DS, WORD PTR [OLD_INTERRUPT_BASE + 2]
    INT 21h

    STI ; re-enabling interrupts

    POP DX
    POP DS
    POP AX
    RET

RESTORE_TIMER_INTERRUPT ENDP

CODE_SEG ENDS

; *************************************************************************
; Data section: game variables
; *************************************************************************
DATA_SEG    SEGMENT PUBLIC

    OLD_INTERRUPT_BASE  DW 0, 0 ; Previous timer ISR address

    ; Player position increments (-1, 0, 1)
    INC_COL    DB 0
    INC_ROW    DB 0

    POS_ROW    DB 0 ; Current player row
    POS_COL    DB 0 ; Current player column

    DIV_SPEED  DB 0 ; Player moves every DIV_SPEED interrupts
    INT_COUNT  DB 0 ; Interrupt counter until next update

    END_GAME   DB 0 ; TRUE when player collides

    MAP_LINE_COUNT DB 0 ; Generated line counter (controls terrain sequence)
    CURRENT_COLOR  DB 0 ; Terrain type of the next line to generate

    TEMP_ROW       DB 0 ; Temporary variable for DRAW_INITIAL_MAP loop

    LINE_TYPES     DB 26 DUP(0) ; Terrain type of each screen row (indices 0-24)

DATA_SEG ENDS

END MAIN