; --- CONFIGURACIÓN DE SEGMENTOS ---
SGROUP      GROUP   CODE_SEG, DATA_SEG ; Agrupa código y datos en un solo grupo (típico de archivos .COM)
            ASSUME  CS:SGROUP, DS:SGROUP, SS:SGROUP

    ; Constantes lógicas
    TRUE  EQU 1
    FALSE EQU 0

    ; Códigos ASCII y Scan Codes de teclado
    ASCII_SPECIAL_KEY EQU 00    ; Indica que la siguiente tecla es una "tecla extendida" (flechas)
    ASCII_LEFT        EQU 04Bh ; Código para flecha izquierda
    ASCII_RIGHT       EQU 04Dh ; Código para flecha derecha
    ASCII_UP          EQU 048h ; Código para flecha arriba
    ASCII_QUIT        EQU 071h ; Tecla 'q' para salir

    ; Definición de elementos visuales
    ASCII_PLAYER      EQU 02Ah ; El asterisco '*' que representa al jugador
    ATTR_PLAYER       EQU 00Fh ; Color blanco brillante para el jugador
    ASCII_WALL        EQU 0DBh ; Carácter de bloque sólido para las paredes
    
    ; Configuración de pantalla
    CURSOR_SIZE_HIDE  EQU 02607h ; Valor para ocultar el cursor
    SCREEN_MAX_ROWS   EQU 25
    SCREEN_MAX_COLS   EQU 80

    ; Límites laterales del "campo de juego"
    FIELD_C1 EQU 25
    FIELD_C2 EQU 55

CODE_SEG    SEGMENT PUBLIC
            ORG 100h ; Punto de entrada estándar para ejecutables .COM

MAIN    PROC    NEAR
    MOV AX, CS      ; Inicializa el Data Segment para que apunte al código
    MOV DS, AX

    ; --- INICIALIZACIÓN ---
    CALL REGISTER_TIMER_INTERRUPT ; "Secuestra" la interrupción del reloj (08h)
    CALL INIT_GAME                ; Resetea variables del juego
    CALL INIT_SCREEN              ; Limpia pantalla y pone modo texto 80x25
    CALL HIDE_CURSOR              ; Quita el cursor parpadeante

    ; Posición inicial del jugador (abajo y centrado)
    MOV BYTE PTR [POS_R], SCREEN_MAX_ROWS - 5
    MOV BYTE PTR [POS_C], (FIELD_C1 + FIELD_C2) / 2
        
; --- BUCLE PRINCIPAL (Entrada de teclado) ---
MAIN_LOOP:
    CMP BYTE PTR [END_GAME], TRUE ; ¿Ha terminado la partida?
    JE JUMP_TO_END
    
    ; Verificar si hay una tecla pulsada (Servicio 0Bh de DOS)
    MOV AH, 0Bh
    INT 21h
    CMP AL, 0
    JE MAIN_LOOP ; Si no hay tecla, seguir esperando

    CALL READ_CHAR      ; Leer la tecla pulsada
    CMP AL, ASCII_QUIT  ; ¿Es 'q'?
    JE JUMP_TO_END
    
    CMP AL, ASCII_SPECIAL_KEY ; ¿Es una tecla especial (como las flechas)?
    JNE MAIN_LOOP
    
    CALL READ_CHAR      ; Leer el segundo código de la tecla especial
    
    ; Cambiar dirección según la flecha pulsada
    CMP AL, ASCII_LEFT
    JE LEFT_KEY
    CMP AL, ASCII_RIGHT
    JE RIGHT_KEY
    CMP AL, ASCII_UP
    JE UP_KEY
    JMP MAIN_LOOP

JUMP_TO_END: JMP END_PROG

LEFT_KEY:
    MOV BYTE PTR [INC_COL], -1 ; Mover a la izquierda
    JMP MAIN_LOOP
RIGHT_KEY:
    MOV BYTE PTR [INC_COL], 1  ; Mover a la derecha
    JMP MAIN_LOOP
UP_KEY:
    MOV BYTE PTR [INC_ROW], -1 ; Mover arriba
    JMP MAIN_LOOP

END_PROG:
    CALL RESTORE_TIMER_INTERRUPT ; Devolver el control del reloj al sistema
    MOV AX, 0003h  ; Restaurar modo de video estándar
    INT 10h
    INT 20h        ; Finalizar programa
MAIN    ENDP    

; --- RUTINA DE SERVICIO DE INTERRUPCIÓN (ISR) ---
; Se ejecuta automáticamente 18.2 veces por segundo
NEW_TIMER_INTERRUPT PROC NEAR
    PUSHF                          ; Guarda los flags
    CALL DWORD PTR [OLD_INTERRUPT_BASE] ; Llama a la interrupción original del sistema
    
    ; Guardar registros para no corromper el resto del programa
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DS

    MOV AX, CS
    MOV DS, AX

    ; Control de velocidad (solo actúa cada X pulsos de reloj)
    INC BYTE PTR [INT_COUNT]
    MOV AL, BYTE PTR [INT_COUNT]
    CMP AL, BYTE PTR [DIV_SPEED]
    JE DO_LOGIC
    JMP EXIT_ISR 

DO_LOGIC:
    MOV BYTE PTR [INT_COUNT], 0

    ; 1. Borrar la posición anterior del jugador (escribir un espacio)
    MOV DH, BYTE PTR [POS_R]
    MOV DL, BYTE PTR [POS_C]
    CALL MOVE_CURSOR
    MOV AL, ' '
    MOV BL, 0
    CALL PRINT_CHAR_ATTR

    ; 2. Actualizar posición física según los incrementos
    MOV AL, BYTE PTR [INC_COL]
    ADD BYTE PTR [POS_C], AL
    MOV AL, BYTE PTR [INC_ROW]
    ADD BYTE PTR [POS_R], AL
    
    ; Resetear incrementos (movimiento paso a paso)
    MOV BYTE PTR [INC_COL], 0
    MOV BYTE PTR [INC_ROW], 0

    ; 3. Lógica de "Scroll" y Dibujo de paredes
    CMP BYTE PTR [POS_R], 5 ; Si el jugador llega arriba...
    JAE DRAW_PLAYER
    
    ; Scroll de pantalla hacia abajo
    MOV AX, 0701h 
    MOV BH, 07h 
    XOR CX, CX
    MOV DX, 184Fh 
    INT 10h
    
    MOV BYTE PTR [POS_R], 6 ; Mantener al jugador en la fila 6

    ; Cambiar color de las paredes cada vez que subimos
    INC BYTE PTR [WALL_COLOR]
    MOV AL, BYTE PTR [WALL_COLOR]
    AND AL, 0Fh 
    JNZ DRAW_WALLS
    MOV BYTE PTR [WALL_COLOR], 1 

DRAW_WALLS:
    ; Dibujar las paredes laterales en la fila 0
    MOV AL, ASCII_WALL
    MOV BL, BYTE PTR [WALL_COLOR]
    MOV DH, 0
    MOV DL, FIELD_C1
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR
    MOV DL, FIELD_C2
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR

DRAW_PLAYER:
    ; 4. Detección de colisiones (si sale de los límites de las paredes)
    MOV AL, BYTE PTR [POS_C]
    CMP AL, FIELD_C1
    JBE TRIGGER_COLLISION ; Colisión izquierda
    CMP AL, FIELD_C2
    JAE TRIGGER_COLLISION ; Colisión derecha

    ; 5. Dibujar al jugador en la nueva posición
    MOV DH, BYTE PTR [POS_R]
    MOV DL, BYTE PTR [POS_C]
    CALL MOVE_CURSOR
    MOV AL, ASCII_PLAYER
    MOV BL, ATTR_PLAYER
    CALL PRINT_CHAR_ATTR
    JMP EXIT_ISR

TRIGGER_COLLISION:
    MOV BYTE PTR [END_GAME], TRUE

EXIT_ISR:
    ; Restaurar registros y volver
    POP DS
    POP DX
    POP CX
    POP BX
    POP AX
    IRET
NEW_TIMER_INTERRUPT ENDP

; --- FUNCIONES AUXILIARES (BIOS/DOS) ---

INIT_GAME PROC NEAR
    MOV BYTE PTR [INC_COL], 0
    MOV BYTE PTR [INC_ROW], 0
    MOV BYTE PTR [DIV_SPEED], 2  ; A menor número, más rápido el juego
    MOV BYTE PTR [END_GAME], FALSE
    MOV BYTE PTR [WALL_COLOR], 1
    RET
INIT_GAME ENDP

INIT_SCREEN PROC NEAR
    MOV AX, 0003h  ; Limpiar pantalla (Modo 80x25 texto)
    INT 10h
    RET
INIT_SCREEN ENDP

HIDE_CURSOR PROC NEAR
    MOV AH, 01h
    MOV CX, CURSOR_SIZE_HIDE
    INT 10h
    RET
HIDE_CURSOR ENDP

MOVE_CURSOR PROC NEAR
    MOV AH, 02h    ; Servicio BIOS para posicionar cursor
    XOR BX, BX
    INT 10h
    RET
MOVE_CURSOR ENDP

PRINT_CHAR_ATTR PROC NEAR
    MOV AH, 09h    ; Servicio BIOS para escribir carácter con atributo (color)
    XOR BH, BH
    MOV CX, 0001h
    INT 10h
    RET
PRINT_CHAR_ATTR ENDP

READ_CHAR PROC NEAR
    MOV AH, 08h    ; Leer carácter sin eco (espera teclado)
    INT 21h
    RET
READ_CHAR ENDP

REGISTER_TIMER_INTERRUPT PROC NEAR
    ; Guardar el vector de interrupción original 08h
    MOV AX, 3508h  
    INT 21h
    MOV WORD PTR [OLD_INTERRUPT_BASE + 2], ES
    MOV WORD PTR [OLD_INTERRUPT_BASE], BX
    ; Poner nuestra propia rutina en el vector 08h
    MOV AX, 2508h  
    MOV DX, OFFSET NEW_TIMER_INTERRUPT
    INT 21h
    RET
REGISTER_TIMER_INTERRUPT ENDP

RESTORE_TIMER_INTERRUPT PROC NEAR
    ; Restaurar el vector original para no colgar el ordenador al salir
    PUSH DS
    MOV DX, WORD PTR [OLD_INTERRUPT_BASE]
    MOV DS, WORD PTR [OLD_INTERRUPT_BASE + 2]
    MOV AX, 2508h
    INT 21h
    POP DS
    RET
RESTORE_TIMER_INTERRUPT ENDP

CODE_SEG ENDS

; --- SEGMENTO DE DATOS ---
DATA_SEG SEGMENT PUBLIC
    OLD_INTERRUPT_BASE DW 0, 0 ; Almacena el puntero a la interrupción original
    INC_COL    DB 0  ; Incremento de columna (movimiento horizontal)
    INC_ROW    DB 0  ; Incremento de fila (movimiento vertical)
    POS_R      DB 0  ; Fila actual del jugador
    POS_C      DB 0  ; Columna actual del jugador
    DIV_SPEED  DB 0  ; Divisor para la velocidad del juego
    INT_COUNT  DB 0  ; Contador de pulsos de reloj
    END_GAME   DB 0  ; Flag de fin de juego
    WALL_COLOR DB 1  ; Color actual de la pared
DATA_SEG ENDS

END MAIN