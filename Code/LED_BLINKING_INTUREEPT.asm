; ---------------- Single-segment .COM-safe version ----------------
CSEG SEGMENT PARA 'CODE'
    ASSUME CS:CSEG, DS:CSEG, ES:CSEG, SS:CSEG
    ORG 0100h

; --- Reserve stack area inside the same segment (COM requirement) ---
STACK_AREA  DW 100 DUP(?)      ; 200 bytes stack space (100 words)

; ---------------- EQU DEFINITIONS ----------------
TMR_C0       EQU 040h      ; Counter 0 data port
CTRL_8253    EQU 046h      ; Control word register
PIC_CMD      EQU 020h
PIC_DATA     EQU 022h
PORT_A       EQU 080h
CTRL_8255    EQU 086h
TIMER_VECTOR EQU 08h

LED_STATE DB 00h

; ---------------- INTERRUPT SERVICE ROUTINE ----------------
TIMER_ISR PROC NEAR
    PUSH AX
    PUSH DX

    XOR BYTE PTR LED_STATE, 01h
    MOV AL, LED_STATE
    MOV DX, PORT_A
    OUT DX, AL

    MOV DX, PIC_CMD
    MOV AL, 20h           ; EOI command
    OUT DX, AL

    POP DX
    POP AX
    IRET
TIMER_ISR ENDP


; ---------------- MAIN PROGRAM ----------------
START:
    ; DS = CS
    MOV AX, CS
    MOV DS, AX

    CLI                    ; disable interrupts

    ; Initialize SS:SP to the reserved stack area (COM: SS must = CS)
    MOV SS, AX             ; SS = CS (same segment for .COM)
    ; compute SP = OFFSET(STACK_AREA) + SIZE_IN_BYTES
    MOV BX, OFFSET STACK_AREA
    ADD BX, 200            ; 100 words * 2 = 200 bytes -> top of reserved stack
    MOV SP, BX

    ; --- IVT entry for vector 08h (Proteus-safe version) ---
    PUSH DS
    PUSH AX
    PUSH BX
    PUSH ES

    MOV AX, 0000h
    MOV ES, AX
    MOV BX, TIMER_VECTOR
    SHL BX, 1
    SHL BX, 1               ; BX = TIMER_VECTOR * 4

    MOV WORD PTR ES:[BX], OFFSET TIMER_ISR
    MOV AX, CS
    MOV WORD PTR ES:[BX+2], AX

    POP ES
    POP BX
    POP AX
    POP DS


    ; --- 8255: Port A OUT, B/C IN (Mode 0) ---
    MOV DX, CTRL_8255
    MOV AL, 10001011B      ; Port A=OUT, Port B/C=IN
    OUT DX, AL

    ; --- 8253: Counter0 Mode 2, LSB+MSB, binary ---
    MOV DX, CTRL_8253
    MOV AL, 00100100B      ; counter0, LSB+MSB, mode2, binary
    OUT DX, AL

    MOV DX, TMR_C0
    MOV AL, 050h           ; LSB of 0xC350
    OUT DX, AL
    MOV AL, 0C3h           ; MSB of 0xC350
    OUT DX, AL

    ; --- PIC init (single PIC, base 08h, 8086 mode, IRQ0 enabled) ---
    MOV DX, PIC_CMD
    MOV AL, 13h             ; ICW1: edge triggered, single PIC, ICW4 follows
    OUT DX, AL

    MOV DX, PIC_DATA
    MOV AL, TIMER_VECTOR    ; ICW2: base vector 08h
    OUT DX, AL

    MOV AL, 01h             ; ICW4: 8086/88 mode
    OUT DX, AL

    MOV AL, 11111110b       ; OCW1: unmask IRQ0 only
    OUT DX, AL

    STI                     ; enable interrupts

MAIN_LOOP:
    JMP MAIN_LOOP

CSEG ENDS
END START
