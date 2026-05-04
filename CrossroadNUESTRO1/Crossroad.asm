; * CROSSROAD INFINITO - ARCOÍRIS
; * El jugador solo sube con UP, se mueve a los lados con LEFT/RIGHT.
; * Las paredes cambian de color creando un efecto arcoíris.

SGROUP      GROUP   CODE_SEG, DATA_SEG
            ASSUME  CS:SGROUP, DS:SGROUP, SS:SGROUP

    TRUE  EQU 1
    FALSE EQU 0

    ASCII_SPECIAL_KEY EQU 00
    ASCII_LEFT        EQU 04Bh
    ASCII_RIGHT       EQU 04Dh
    ASCII_UP          EQU 048h
    ASCII_QUIT        EQU 071h

    ASCII_PLAYER      EQU 02Ah ; '*'
    ATTR_PLAYER       EQU 00Fh ; Blanco
    ASCII_WALL        EQU 0DBh ; Bloque sólido
    
    SCREEN_MAX_ROWS EQU 25
    SCREEN_MAX_COLS EQU 80

    ; Límites de las paredes
    FIELD_C1 EQU 25
    FIELD_C2 EQU 55

CODE_SEG    SEGMENT PUBLIC
            ORG 100h

MAIN    PROC    NEAR
    MAIN_GO:
        CALL REGISTER_TIMER_INTERRUPT
        CALL INIT_GAME
        CALL INIT_SCREEN
        CALL HIDE_CURSOR

        ; Posición inicial del jugador
        MOV [POS_R], SCREEN_MAX_ROWS - 5
        MOV [POS_C], (FIELD_C1 + FIELD_C2) / 2
        
    MAIN_LOOP:
        CMP [END_GAME], TRUE
        JZ END_PROG

        ; Leer teclado
        MOV AH, 0Bh
        INT 21h
        CMP AL, 0
        JZ MAIN_LOOP

        CALL READ_CHAR      
        CMP AL, ASCII_QUIT
        JZ END_PROG
        
        CMP AL, ASCII_SPECIAL_KEY
        JNZ MAIN_LOOP
        
        CALL READ_CHAR ; Leer código extendido
        
        CMP AL, ASCII_LEFT
        JZ LEFT_KEY
        CMP AL, ASCII_RIGHT
        JZ RIGHT_KEY
        CMP AL, ASCII_UP
        JZ UP_KEY
        JMP MAIN_LOOP

    LEFT_KEY:
        MOV [INC_COL], -1
        MOV [INC_ROW], 0
        JMP MAIN_LOOP
    RIGHT_KEY:
        MOV [INC_COL], 1
        MOV [INC_ROW], 0
        JMP MAIN_LOOP
    UP_KEY:
        MOV [INC_COL], 0
        MOV [INC_ROW], -1
        JMP MAIN_LOOP

    END_PROG:
        CALL RESTORE_TIMER_INTERRUPT
        INT 20h     
MAIN    ENDP    

; --- LÓGICA DE MOVIMIENTO E INFINITO (ISR) ---
NEW_TIMER_INTERRUPT PROC NEAR
    PUSHF
    CALL DWORD PTR [OLD_INTERRUPT_BASE]
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Control de velocidad
    INC [INT_COUNT]
    MOV AL, [INT_COUNT]
    CMP [DIV_SPEED], AL
    JNZ EXIT_ISR
    MOV [INT_COUNT], 0

    ; 1. BORRAR POSICIÓN ANTERIOR DEL JUGADOR
    MOV DH, [POS_R]
    MOV DL, [POS_C]
    CALL MOVE_CURSOR
    MOV AL, ' '
    MOV BL, 0
    CALL PRINT_CHAR_ATTR

    ; 2. ACTUALIZAR POSICIÓN
    MOV AL, [INC_COL]
    ADD [POS_C], AL
    MOV AL, [INC_ROW]
    ADD [POS_R], AL

    ; Reset de incrementos (para que no se mueva solo)
    MOV [INC_COL], 0
    MOV [INC_ROW], 0

    ; 3. LÓGICA DE MAPA INFINITO (Scroll)
    ; Si el jugador sube demasiado, movemos "el mundo" hacia abajo
    CMP [POS_R], 5
    JAE DRAW_PLAYER
    
    ; Hacer SCROLL de la pantalla 1 línea hacia abajo
    MOV AH, 07h ; Scroll down
    MOV AL, 1   ; 1 línea
    MOV BH, 07h ; Atributo fondo
    MOV CH, 0   ; Fila superior
    MOV CL, 0   ; Columna izq
    MOV DH, SCREEN_MAX_ROWS - 1
    MOV DL, SCREEN_MAX_COLS - 1
    INT 10h
    
    MOV [POS_R], 6 ; Mantener al jugador en una posición fija visualmente

    ; 4. DIBUJAR NUEVAS PAREDES (EFECTO ARCOÍRIS)
    ; Incrementar color (evitando negros o colores de fondo)
    INC [WALL_COLOR]
    MOV AL, [WALL_COLOR]
    AND AL, 0Fh ; Solo 16 colores
    JZ  RESET_COLOR
    JMP DRAW_WALLS
RESET_COLOR: MOV [WALL_COLOR], 1

DRAW_WALLS:
    MOV AL, ASCII_WALL
    MOV BL, [WALL_COLOR]
    ; Pared Izquierda
    MOV DH, 0
    MOV DL, FIELD_C1
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR
    ; Pared Derecha
    MOV DL, FIELD_C2
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR

DRAW_PLAYER:
    ; Colisión con paredes
    MOV DL, [POS_C]
    CMP DL, FIELD_C1
    JBE COLLISION
    CMP DL, FIELD_C2
    JAE COLLISION

    ; Dibujar Jugador
    MOV DH, [POS_R]
    MOV DL, [POS_C]
    CALL MOVE_CURSOR
    MOV AL, ASCII_PLAYER
    MOV BL, ATTR_PLAYER
    CALL PRINT_CHAR_ATTR
    JMP EXIT_ISR

COLLISION:
    MOV [END_GAME], TRUE

EXIT_ISR:
    POP DX
    POP CX
    POP BX
    POP AX
    IRET
NEW_TIMER_INTERRUPT ENDP

; --- FUNCIONES AUXILIARES ---

INIT_GAME PROC NEAR
    MOV [INC_COL], 0
    MOV [INC_ROW], 0
    MOV [DIV_SPEED], 2
    MOV [END_GAME], FALSE
    MOV [WALL_COLOR], 1
    RET
INIT_GAME ENDP

INIT_SCREEN PROC NEAR
    MOV AX, 3
    INT 10h
    RET
INIT_SCREEN ENDP

HIDE_CURSOR PROC NEAR
    MOV AH, 1
    MOV CX, CURSOR_SIZE_HIDE
    INT 10h
    RET
HIDE_CURSOR ENDP

MOVE_CURSOR PROC NEAR
    MOV AH, 2
    XOR BX, BX
    INT 10h
    RET
MOVE_CURSOR ENDP

PRINT_CHAR_ATTR PROC NEAR
    MOV AH, 9
    MOV BH, 0
    MOV CX, 1
    INT 10h
    RET
PRINT_CHAR_ATTR ENDP

READ_CHAR PROC NEAR
    MOV AH, 8
    INT 21h
    RET
READ_CHAR ENDP

REGISTER_TIMER_INTERRUPT PROC NEAR
    MOV AX, 3508h
    INT 21h
    MOV WORD PTR OLD_INTERRUPT_BASE+2, ES
    MOV WORD PTR OLD_INTERRUPT_BASE, BX
    MOV AX, 2508h
    MOV DX, OFFSET NEW_TIMER_INTERRUPT
    INT 21h
    RET
REGISTER_TIMER_INTERRUPT ENDP

RESTORE_TIMER_INTERRUPT PROC NEAR
    LDS DX, OLD_INTERRUPT_BASE
    MOV AX, 2508h
    INT 21h
    RET
RESTORE_TIMER_INTERRUPT ENDP

CODE_SEG ENDS

DATA_SEG SEGMENT PUBLIC
    OLD_INTERRUPT_BASE DW 0, 0
    INC_COL DB 0
    INC_ROW DB 0
    POS_R   DB 0
    POS_C   DB 0
    DIV_SPEED DB 0
    INT_COUNT DB 0
    END_GAME  DB 0
    WALL_COLOR DB 1
DATA_SEG ENDS

END MAIN