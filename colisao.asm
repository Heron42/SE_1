; =============================================================================
; colisao.asm  -  Deteccao de golpes validos (soco e chute)
; -----------------------------------------------------------------------------
; Um golpe so causa dano no FRAME DE IMPACTO da animacao (um unico frame por
; golpe), de modo que cada soco/chute tira no maximo 1 ponto de energia.
;
; Condicoes de acerto:
;   SOCO  : |x_atacante - x_defensor| <= ALCANCE_SOCO
;           |y_atacante - y_defensor| <= TOLERANCIA_Y (mesma altura)
;           defensor NAO esta abaixado          -> defesa: abaixar ou pular
;   CHUTE : |x_atacante - x_defensor| <= ALCANCE_CHUTE
;           defensor NAO esta no ar             -> defesa: pular
;
; Rotina publica: verifica_golpe
; =============================================================================

%include "const.inc"

global  verifica_golpe

extern  atualiza_barra              ; hud.asm
extern  ultimo_golpe                ; logica.asm
extern  jogador1                    ; jogador.asm

segment code public class=CODE

; =============================================================================
; verifica_golpe
; Entrada: SI = atacante, DI = defensor.
; Se o golpe for valido, decrementa a energia do defensor, atualiza a barra
; na tela e registra quem acertou por ultimo (usado no desempate).
; =============================================================================
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

        ; ---- soco ------------------------------------------------------------
vg_testa_soco:
        CMP     AH, FRAME_IMPACTO_SOCO
        JNE     vg_fim
        CMP     byte [DI+JESTADO], EST_ABAIXA   ; defensor abaixado: soco passa por cima
        JE      vg_fim
        MOV     AX, [SI+JY]                     ; mesma altura?
        SUB     AX, [DI+JY]
        JNS     vg_soco_abs_y
        NEG     AX
vg_soco_abs_y:
        CMP     AX, TOLERANCIA_Y
        JG      vg_fim                          ; defensor no ar (ou atacante)
        MOV     BX, ALCANCE_SOCO
        JMP     vg_checa_dist_x

        ; ---- chute -----------------------------------------------------------
vg_testa_chute:
        CMP     AH, FRAME_IMPACTO_CHUTE
        JNE     vg_fim
        CMP     byte [DI+JPULO], 0              ; defensor no ar: chute passa por baixo
        JNE     vg_fim
        MOV     BX, ALCANCE_CHUTE

        ; ---- distancia horizontal -------------------------------------------
vg_checa_dist_x:
        MOV     AX, [SI+JX]
        SUB     AX, [DI+JX]
        JNS     vg_abs_x
        NEG     AX
vg_abs_x:
        CMP     AX, BX
        JG      vg_fim                          ; longe demais

        ; ---- golpe valido ----------------------------------------------------
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
