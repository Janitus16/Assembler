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

    ; CAR ASCII / ATTR
    ASCII_CAR         EQU 0DBh ; solid block same as wall
    ATTR_CAR          EQU 04Fh ; white on red

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

    ; NUMBER OF CARS (2 per road row, max 2 road segments of 20 rows = 40 cars)
    MAX_CARS      EQU 40

    ; CAR SPEED DIVIDER (cars move every CAR_DIV_SPEED timer interrupts)
    CAR_DIV_SPEED EQU 3

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
; player movement, scroll, collision, player drawing,
; car movement and car-player collision.
; Entry:
; 
; Returns:
; 
; Modifies:
; 
; Uses:
;   OLD_INTERRUPT_BASE, INT_COUNT, DIV_SPEED,
;   CAR_INT_COUNT, CAR_DIV_SPEED,
;   POS_ROW, POS_COL, INC_ROW, INC_COL,
;   LINE_TYPES, END_GAME,
;   CARS_ROW, CARS_COL, CARS_DIR, NUM_CARS
; Calls:
;   MOVE_CURSOR, PRINT_CHAR_ATTR, RESTORE_TRAIL_COLOR,
;   UPDATE_MAP_COLOR, PRINT_MULTIPLE_CHAR,
;   ERASE_CARS, MOVE_CARS, DRAW_CARS, CHECK_CAR_COLLISION
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
    PUSH SI
    PUSH DI
    PUSH DS
    MOV AX, CS
    MOV DS, AX

    ; ---- CAR MOVEMENT TICK ----
    INC BYTE PTR [CAR_INT_COUNT]
    MOV AL, BYTE PTR [CAR_INT_COUNT]
    CMP AL, CAR_DIV_SPEED
    JNE SKIP_CAR_MOVE
    MOV BYTE PTR [CAR_INT_COUNT], 0
    CALL ERASE_CARS
    CALL MOVE_CARS
    CALL DRAW_CARS

SKIP_CAR_MOVE:

    ; ---- PLAYER MOVEMENT TICK ----
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

    ; Shifts all car rows one position downward to follow the scroll
    CALL SHIFT_CARS_DOWN

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

    ; Full solid row for road or water
    MOV DH, 0
    MOV DL, 0
    CALL MOVE_CURSOR
    MOV CX, 80
    CALL PRINT_MULTIPLE_CHAR

    ; If the new row is road, spawn 2 cars on it
    CMP BL, COLOR_ROAD
    JNE SKIP_SPAWN
    CALL SPAWN_CARS_ON_ROW_ZERO
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

SKIP_SPAWN:
SKIP_SCROLL:
    ; Check car-player collision before drawing player
    CALL CHECK_CAR_COLLISION
    CMP BYTE PTR [END_GAME], TRUE
    JE EXIT_ISR

    ; Collision logic based on terrain type of the current row 
    XOR BX, BX
    MOV BL, BYTE PTR [POS_ROW]
    MOV AL, [LINE_TYPES + BX]

    CMP AL, COLOR_GREEN
    JNE DRAW_PLAYER

    ; Green zone: check if player is inside the gap
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
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    IRET

NEW_TIMER_INTERRUPT ENDP

; ****************************************
; Erases all active cars from the screen,
; restoring the road color underneath.
; Entry:
;   NUM_CARS: number of active cars
;   CARS_ROW, CARS_COL: car positions
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   NUM_CARS, CARS_ROW, CARS_COL
; Calls:
;   MOVE_CURSOR, PRINT_CHAR_ATTR
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
    MOV AL, ASCII_WALL
    MOV BL, COLOR_ROAD
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
; Moves all active cars one column in their direction.
; Cars that go off screen are removed from the array.
; Entry:
;   NUM_CARS, CARS_ROW, CARS_COL, CARS_DIR
; Returns:
;   -
; Modifies:
;   NUM_CARS, CARS_COL
; Uses:
;   CARS_ROW, CARS_COL, CARS_DIR, NUM_CARS
; Calls:
;   -
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

    XOR SI, SI          ; current index
    XOR DI, DI          ; write index (for compaction)

MOVE_CARS_LOOP:
    MOV AL, BYTE PTR [CARS_DIR + SI]
    ADD BYTE PTR [CARS_COL + SI], AL

    ; Check bounds: col < 0 or col >= 80
    MOV BL, BYTE PTR [CARS_COL + SI]
    CMP BL, 80
    JAE SKIP_CAR        ; off screen, drop it (>=80 also catches wrap of -1 -> 255)

    ; Keep car: copy to write index
    MOV AL, BYTE PTR [CARS_ROW + SI]
    MOV BYTE PTR [CARS_ROW + DI], AL
    MOV AL, BYTE PTR [CARS_COL + SI]
    MOV BYTE PTR [CARS_COL + DI], AL
    MOV AL, BYTE PTR [CARS_DIR + SI]
    MOV BYTE PTR [CARS_DIR + DI], AL
    INC DI

SKIP_CAR:
    INC SI
    LOOP MOVE_CARS_LOOP

    ; DI holds the new count of surviving cars
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
; Draws all active cars on the screen.
; Entry:
;   NUM_CARS, CARS_ROW, CARS_COL
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   NUM_CARS, CARS_ROW, CARS_COL
; Calls:
;   MOVE_CURSOR, PRINT_CHAR_ATTR
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
    MOV BL, ATTR_CAR
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
; Checks if any car occupies the same cell as the player.
; If so, sets END_GAME = TRUE.
; Entry:
;   POS_ROW, POS_COL, NUM_CARS, CARS_ROW, CARS_COL
; Returns:
;   END_GAME = TRUE if collision detected
; Modifies:
;   -
; Uses:
;   POS_ROW, POS_COL, NUM_CARS, CARS_ROW, CARS_COL
; Calls:
;   -
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
; Spawns 2 cars on row 0 (just scrolled in).
; Alternates direction based on MAP_LINE_COUNT parity.
; Car 1 starts at col 0, Car 2 at col 40.
; Entry:
;   MAP_LINE_COUNT used to determine direction
;   NUM_CARS: current count (will be incremented by 2)
; Returns:
;   NUM_CARS updated
;   CARS_ROW, CARS_COL, CARS_DIR updated
; Modifies:
;   -
; Uses:
;   NUM_CARS, CARS_ROW, CARS_COL, CARS_DIR, MAP_LINE_COUNT
; Calls:
;   -
; ****************************************
            PUBLIC SPAWN_CARS_ON_ROW_ZERO
SPAWN_CARS_ON_ROW_ZERO PROC NEAR

    PUSH AX
    PUSH BX
    PUSH SI

    MOV BL, BYTE PTR [NUM_CARS]
    XOR BH, BH

    ; Determine direction from MAP_LINE_COUNT parity
    MOV AL, BYTE PTR [MAP_LINE_COUNT]
    AND AL, 01h         ; odd/even
    JZ DIR_LEFT_TO_RIGHT

    ; Direction: right to left (-1), start cols 79 and 39
    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], 79
    MOV BYTE PTR [CARS_DIR + SI], -1
    INC BL

    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], 39
    MOV BYTE PTR [CARS_DIR + SI], -1
    INC BL
    JMP SPAWN_DONE

DIR_LEFT_TO_RIGHT:
    ; Direction: left to right (+1), start cols 0 and 40
    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], 0
    MOV BYTE PTR [CARS_DIR + SI], 1
    INC BL

    MOV SI, BX
    MOV BYTE PTR [CARS_ROW + SI], 0
    MOV BYTE PTR [CARS_COL + SI], 40
    MOV BYTE PTR [CARS_DIR + SI], 1
    INC BL

SPAWN_DONE:
    ; Clamp to MAX_CARS
    CMP BL, MAX_CARS
    JBE STORE_COUNT
    MOV BL, MAX_CARS
STORE_COUNT:
    MOV BYTE PTR [NUM_CARS], BL

    POP SI
    POP BX
    POP AX
    RET

SPAWN_CARS_ON_ROW_ZERO ENDP

; ****************************************
; Shifts all car row positions down by 1
; after a screen scroll. Cars that fall off row 24
; are removed from the array.
; Entry:
;   NUM_CARS, CARS_ROW
; Returns:
;   NUM_CARS, CARS_ROW updated
; Modifies:
;   -
; Uses:
;   NUM_CARS, CARS_ROW, CARS_COL, CARS_DIR
; Calls:
;   -
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
    INC DI

SHIFT_SKIP:
    INC SI
    LOOP SHIFT_CARS_LOOP

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
; Restores the terrain color at the current cursor position.
; Green interior: erases with black space
; Green wall: repaints ASCII_WALL with COLOR_GREEN
; Road: solid block gray
; Water: solid block cyan
; Entry:
;   Cursor already positioned at (POS_ROW, POS_COL)
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   POS_ROW, POS_COL, LINE_TYPES
;   ASCII_WALL, COLOR_GREEN
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

    ; Water
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
; Updates CURRENT_COLOR according to the cyclic terrain sequence:
; Green -> Road -> Green -> Road -> Green -> Water -> reset
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
; Draws the initial map: all rows green
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
; Resets internal game variables.
; Entry:
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses:
;   MAP_LINE_COUNT, CURRENT_COLOR, DIV_SPEED,
;   INT_COUNT, END_GAME, NUM_CARS, CAR_INT_COUNT
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
    MOV BYTE PTR [NUM_CARS], 0
    MOV BYTE PTR [CAR_INT_COUNT], 0

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

; *************************************************************************
; Data section: game variables
; *************************************************************************
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

    ; Car subsystem
    CAR_INT_COUNT  DB 0                  ; Interrupt counter for car movement
    NUM_CARS       DB 0                  ; Number of active cars
    CARS_ROW       DB MAX_CARS DUP(0)    ; Row of each car
    CARS_COL       DB MAX_CARS DUP(0)    ; Column of each car
    CARS_DIR       DB MAX_CARS DUP(0)    ; Direction of each car (+1 or -1)

DATA_SEG ENDS

END MAIN