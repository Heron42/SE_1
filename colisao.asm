; =============================================================================
; colisao.asm  -  Deteccao de golpes validos (soco e chute)
; =============================================================================

;  Colisao 
ALCANCE_SOCO    EQU     68          ; distancia maxima em X para o soco acertar
ALCANCE_CHUTE   EQU     74          ; distancia maxima em X para o chute acertar
TOLERANCIA_Y    EQU     25          ; diferenca de altura maxima para o soco
FRAME_IMPACTO_SOCO  EQU 2           ; frame da animacao em que o soco pega
FRAME_IMPACTO_CHUTE EQU 3           ; frame da animacao em que o chute pega

;  Estados de animacao 
EST_SOCO        EQU     2
EST_CHUTE       EQU     3
EST_ABAIXA      EQU     4

;  Estrutura de um jogador 
JX              EQU     0           ; dw  posicao X atual (centro do tronco)
JY              EQU     2           ; dw  posicao Y atual (ombros)
JFRAME          EQU     8           ; db  frame atual da animacao
JENERGIA        EQU     13          ; db  energia (comeca em ENERGIA_INICIAL)
JESTADO         EQU     14          ; db  estado de animacao (EST_*)
JPULO           EQU     18          ; db  1 = no ar, 0 = no chao

global  verifica_golpe

extern  atualiza_barra              ; hud.asm
extern  ultimo_golpe                ; logica.asm
extern  jogador1                    ; jogador.asm

segment code public class=CODE

; verifica_golpe
; Entrada: SI = atacante, DI = defensor.
; Se o golpe for valido, decrementa a energia do defensor, atualiza a barra
; na tela e registra quem acertou por ultimo
verifica_golpe:
        PUSH    AX
        PUSH    BX

        MOV     AL, [SI+JESTADO]
        MOV     AH, [SI+JFRAME]

        CMP     AL, EST_SOCO
        JE      vg_testa_soco
        CMP     AL, EST_CHUTE
        JE      vg_testa_chute
        JMP     vg_fim

        ;soco 
vg_testa_soco:
        CMP     AH, FRAME_IMPACTO_SOCO
        JNE     vg_fim
        CMP     byte [DI+JESTADO], EST_ABAIXA   ; oponente abaixado
        JE      vg_fim
        MOV     AX, [SI+JY]
        SUB     AX, [DI+JY]
        JNS     vg_soco_abs_y
        NEG     AX
vg_soco_abs_y:
        CMP     AX, TOLERANCIA_Y
        JG      vg_fim                          ; oponente/jogador no ar
        MOV     BX, ALCANCE_SOCO
        JMP     vg_checa_dist_x

        ;chute 
vg_testa_chute:
        CMP     AH, FRAME_IMPACTO_CHUTE
        JNE     vg_fim
        CMP     byte [DI+JPULO], 0              ; oponente no ar
        JNE     vg_fim
        MOV     BX, ALCANCE_CHUTE

        ;distancia horizontal 
vg_checa_dist_x:
        MOV     AX, [SI+JX]
        SUB     AX, [DI+JX]
        JNS     vg_abs_x
        NEG     AX
vg_abs_x:
        CMP     AX, BX
        JG      vg_fim                          ; longe demais

        ;golpe valido 
        CMP     byte [DI+JENERGIA], 0
        JE      vg_fim
        DEC     byte [DI+JENERGIA]
        CALL    atualiza_barra
        MOV     byte [ultimo_golpe], 1          ; registra quem acertou
        CMP     SI, jogador1
        JE      vg_fim
        MOV     byte [ultimo_golpe], 2
vg_fim:
        POP     BX
        POP     AX
        RET
