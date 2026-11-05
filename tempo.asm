; tempo.asm  -  Temporizacao pela interrupcao de hardware INT 8h (8253, IRQ0)

; Hardware
INT_CLK         EQU     08h         

global  instala_relogio
global  restaura_relogio
global  zera_cronometro
global  tique_jogo
global  segundos
global  relogio_ativo

FRAC_POR_TIQUE  EQU     5           
FRAC_POR_SEG    EQU     91

segment code public class=CODE

; instala_relogio: salva o vetor da INT 8h e instala ClockINT.
instala_relogio:
        PUSH    AX
        PUSH    ES
        CLI
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [ES:INT_CLK*4]          ; IP original
        MOV     [offset_clk], AX
        MOV     AX, [ES:INT_CLK*4+2]        ; CS original
        MOV     [cs_clk], AX
        MOV     [ES:INT_CLK*4+2], CS
        MOV     WORD [ES:INT_CLK*4], ClockINT
        STI
        POP     ES
        POP     AX
        RET

; restaura_relogio: devolve o vetor original da INT 8h.
restaura_relogio:
        PUSH    AX
        PUSH    ES
        CLI
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [cs_clk]
        MOV     [ES:INT_CLK*4+2], AX
        MOV     AX, [offset_clk]
        MOV     [ES:INT_CLK*4], AX
        STI
        POP     ES
        POP     AX
        RET

; zera_cronometro: zera os segundos do round (inicio de cada round).
; Feito com interrupcoes desabilitadas para nao competir com a ISR.
zera_cronometro:
        CLI
        MOV     WORD [segundos], 0
        MOV     byte [fracao], 0
        STI
        RET

; ClockINT  -  ISR do relogio (INT 8h)
ClockINT:
        PUSH    AX
        PUSH    DS
        MOV     AX, data
        MOV     DS, AX

        INC     WORD [tique_jogo]           ; um "frame" do jogo

        CMP     byte [relogio_ativo], 0     
        JE      ck_chain
        ADD     byte [fracao], FRAC_POR_TIQUE
        CMP     byte [fracao], FRAC_POR_SEG
        JB      ck_chain
        SUB     byte [fracao], FRAC_POR_SEG
        INC     WORD [segundos]             

ck_chain:
        PUSHF                              
        CALL    FAR [offset_clk]          

        POP     DS
        POP     AX
        IRET

; =============================================================================
segment data public class=DATA

offset_clk      DW      0           ; IP original da INT 8h (offset ANTES do
cs_clk          DW      0           ; CS original da INT 8h  segmento: far ptr)
tique_jogo      DW      0           ; incrementado a cada tique (~55 ms)
segundos        DW      0           ; segundos de round decorridos
fracao          DB      0           ; acumulador fracionario (0..90)
relogio_ativo   DB      0           ; 1 = round em andamento (conta segundos)
