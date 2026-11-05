; =============================================================================
; hud.asm  -  Interface grafica da luta: arena, energia, tempo, rounds, avisos
; -----------------------------------------------------------------------------
; Layout (coordenadas de plot_xy, Y = 0 embaixo):
;   Y 440..460 : barras de energia (J1 a esquerda, J2 a direita), marcadores
;                de rounds vencidos e cronometro M:SS no centro
;   Y 70..420  : arena (delimitadores inferior, superior, esquerdo e direito)
;   linha de texto LIN_MSG      : avisos (ROUND n, PAUSED, vencedor do round)
;   linha de texto LIN_CONFIRMA : confirmacao de saida (abaixo do chao)
;
; Rotinas publicas:
;   desenha_cenario : limpa a tela e desenha arena + HUD completo
;   atualiza_barra  : apaga 1 bloco da barra de energia (DI = jogador atingido)
;   desenha_rounds  : marcadores de rounds vencidos
;   desenha_tempo   : cronometro (so redesenha quando o segundo muda)
;   msg_centro      : escreve um texto centralizado numa linha
;   apaga_linha     : apaga uma linha de texto dentro da arena
; =============================================================================

%include "const.inc"

global  desenha_cenario
global  atualiza_barra
global  desenha_rounds
global  desenha_tempo
global  msg_centro
global  apaga_linha

extern  line                        ; graficos.asm
extern  circle
extern  full_circle
extern  cursor
extern  caracter
extern  escreve_texto
extern  apaga_texto
extern  limpa_tela
extern  cor
extern  jogador1                    ; jogador.asm
extern  jogador2
extern  segundos                    ; tempo.asm
extern  rounds_p1                   ; logica.asm
extern  rounds_p2

segment code public class=CODE

; =============================================================================
; desenha_cenario
; Limpa a tela e desenha a arena, as barras, os rounds e o cronometro.
; Chamado no inicio de cada round.
; =============================================================================
desenha_cenario:
        CALL    limpa_tela
        CALL    desenha_arena
        CALL    desenha_barras
        CALL    desenha_rounds
        MOV     WORD [ultimo_seg], 0FFFFh   ; forca o redesenho do tempo
        CALL    desenha_tempo
        RET

; =============================================================================
; desenha_arena
; Retangulo da arena: chao em Y = ARENA_BAIXO, teto em Y = ARENA_TOPO,
; paredes em X = ARENA_ESQ e X = ARENA_DIR.
; =============================================================================
desenha_arena:
        PUSH    AX
        MOV     byte [cor], branco_intenso

        MOV     AX, ARENA_ESQ               ; chao
        PUSH    AX
        MOV     AX, ARENA_BAIXO
        PUSH    AX
        MOV     AX, ARENA_DIR
        PUSH    AX
        MOV     AX, ARENA_BAIXO
        PUSH    AX
        CALL    line

        MOV     AX, ARENA_ESQ               ; teto
        PUSH    AX
        MOV     AX, ARENA_TOPO
        PUSH    AX
        MOV     AX, ARENA_DIR
        PUSH    AX
        MOV     AX, ARENA_TOPO
        PUSH    AX
        CALL    line

        MOV     AX, ARENA_ESQ               ; parede esquerda
        PUSH    AX
        MOV     AX, ARENA_BAIXO
        PUSH    AX
        MOV     AX, ARENA_ESQ
        PUSH    AX
        MOV     AX, ARENA_TOPO
        PUSH    AX
        CALL    line

        MOV     AX, ARENA_DIR               ; parede direita
        PUSH    AX
        MOV     AX, ARENA_BAIXO
        PUSH    AX
        MOV     AX, ARENA_DIR
        PUSH    AX
        MOV     AX, ARENA_TOPO
        PUSH    AX
        CALL    line

        POP     AX
        RET

; =============================================================================
; desenha_barras
; Desenha as duas barras de energia, cada uma com JENERGIA * LARG_BLOCO px,
; na cor escolhida pelo jogador:
;   Jogador 1 (esquerda): X = 20..219
;   Jogador 2 (direita) : X = 420..619
; =============================================================================
desenha_barras:
        PUSH    AX
        PUSH    BX
        PUSH    SI

        MOV     SI, jogador1
        MOV     BX, BARRA_P1_X
        CALL    barra_cheia
        MOV     SI, jogador2
        MOV     BX, BARRA_P2_X
        CALL    barra_cheia

        POP     SI
        POP     BX
        POP     AX
        RET

; Entrada: SI = jogador, BX = X inicial da barra.
barra_cheia:
        PUSH    AX
        PUSH    CX
        PUSH    DX
        MOV     AL, [SI+JCOR]
        MOV     [cor], AL
        MOV     AL, [SI+JENERGIA]
        XOR     AH, AH
        MOV     DL, LARG_BLOCO
        MUL     DL                          ; AX = largura em pixels
        MOV     DX, BX
        ADD     DX, AX                      ; DX = X final (exclusivo)
        MOV     CX, BX
        CALL    faixa_vertical
        POP     DX
        POP     CX
        POP     AX
        RET

; -----------------------------------------------------------------------------
; faixa_vertical
; Preenche, na cor [cor], as colunas X = CX .. DX-1 entre BARRA_Y_BAIXO e
; BARRA_Y_TOPO (uma linha vertical por coluna).
; -----------------------------------------------------------------------------
faixa_vertical:
        PUSH    AX
        PUSH    CX
fv_loop:
        CMP     CX, DX
        JGE     fv_fim
        PUSH    CX                          ; x1
        MOV     AX, BARRA_Y_BAIXO
        PUSH    AX                          ; y1
        PUSH    CX                          ; x2
        MOV     AX, BARRA_Y_TOPO
        PUSH    AX                          ; y2
        CALL    line
        INC     CX
        JMP     fv_loop
fv_fim:
        POP     CX
        POP     AX
        RET

; =============================================================================
; atualiza_barra
; Entrada: DI = jogador que acabou de perder 1 ponto de energia.
; Apaga (pinta de preto) apenas o bloco de LARG_BLOCO px correspondente ao
; novo valor de [DI+JENERGIA], sem redesenhar o resto da barra.
; =============================================================================
atualiza_barra:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX

        MOV     AL, [DI+JENERGIA]
        XOR     AH, AH
        MOV     BL, LARG_BLOCO
        MUL     BL                          ; AX = deslocamento do bloco

        CMP     DI, jogador1
        JNE     ab_jogador2
        ADD     AX, BARRA_P1_X
        JMP     ab_apaga
ab_jogador2:
        ADD     AX, BARRA_P2_X

ab_apaga:
        MOV     CX, AX
        MOV     DX, AX
        ADD     DX, LARG_BLOCO
        MOV     byte [cor], preto
        CALL    faixa_vertical

        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

; =============================================================================
; desenha_rounds
; Dois marcadores por jogador (circulo vazio = round ainda nao vencido,
; circulo cheio = round vencido). J1 em X = 235/255, J2 em X = 405/385.
; =============================================================================
desenha_rounds:
        PUSH    AX
        PUSH    BX
        PUSH    CX

        MOV     AL, [rounds_p1]
        MOV     BX, 235
        MOV     CL, 1
        CALL    marcador
        MOV     BX, 255
        MOV     CL, 2
        CALL    marcador

        MOV     AL, [rounds_p2]
        MOV     BX, 405
        MOV     CL, 1
        CALL    marcador
        MOV     BX, 385
        MOV     CL, 2
        CALL    marcador

        POP     CX
        POP     BX
        POP     AX
        RET

; Entrada: AL = rounds vencidos, CL = numero do marcador, BX = X do centro.
; Desenha circulo cheio se AL >= CL, ou vazio caso contrario.
marcador:
        PUSH    AX
        PUSH    DX
        MOV     byte [cor], amarelo
        MOV     DL, AL                      ; DL = rounds vencidos
        PUSH    BX                          ; xc
        MOV     AX, 450
        PUSH    AX                          ; yc
        MOV     AX, 6
        PUSH    AX                          ; r
        CMP     DL, CL
        JAE     mc_cheio
        CALL    circle                      ; consome xc, yc, r
        JMP     mc_fim
mc_cheio:
        CALL    full_circle
mc_fim:
        POP     DX
        POP     AX
        RET

; =============================================================================
; desenha_tempo
; Mostra o tempo restante do round no formato M:SS. So redesenha quando o
; segundo muda (evita chamadas desnecessarias a BIOS).
; =============================================================================
desenha_tempo:
        PUSH    AX
        PUSH    BX
        PUSH    DX

        MOV     AX, [segundos]
        CMP     AX, [ultimo_seg]
        JE      dt_fim
        MOV     [ultimo_seg], AX

        MOV     AX, TEMPO_ROUND
        SUB     AX, [segundos]              ; AX = segundos restantes
        JNS     dt_pos
        XOR     AX, AX
dt_pos:
        MOV     BL, 60
        DIV     BL                          ; AL = minutos, AH = segundos
        MOV     BH, AH

        MOV     byte [cor], branco_intenso
        MOV     DH, LIN_TEMPO
        MOV     DL, COL_TEMPO
        CALL    cursor
        ADD     AL, '0'
        CALL    caracter                    ; minutos

        INC     DL
        CALL    cursor
        MOV     AL, ':'
        CALL    caracter

        MOV     AL, BH
        XOR     AH, AH
        MOV     BL, 10
        DIV     BL                          ; AL = dezena, AH = unidade
        INC     DL
        CALL    cursor
        ADD     AL, '0'
        CALL    caracter

        INC     DL
        CALL    cursor
        MOV     AL, AH
        ADD     AL, '0'
        CALL    caracter

dt_fim:
        POP     DX
        POP     BX
        POP     AX
        RET

; =============================================================================
; msg_centro
; Entrada: DS:SI = texto terminado em 0, DH = linha, cor em [cor].
; Escreve o texto centralizado horizontalmente (80 colunas).
; =============================================================================
msg_centro:
        PUSH    AX
        PUSH    CX
        PUSH    DX
        PUSH    SI

        XOR     CX, CX                      ; CX = comprimento do texto
mc_conta:
        CMP     byte [SI], 0
        JE      mc_posiciona
        INC     CX
        INC     SI
        JMP     mc_conta
mc_posiciona:
        POP     SI
        PUSH    SI
        MOV     AX, 80
        SUB     AX, CX
        SHR     AX, 1                       ; coluna = (80 - comprimento) / 2
        MOV     DL, AL
        CALL    escreve_texto

        POP     SI
        POP     DX
        POP     CX
        POP     AX
        RET

; =============================================================================
; apaga_linha
; Entrada: DH = linha de texto. Apaga as colunas 2..77 (dentro das paredes
; da arena, que ficam nas colunas 1 e 78).
; =============================================================================
apaga_linha:
        PUSH    CX
        PUSH    DX
        MOV     DL, 2
        MOV     CX, 76
        CALL    apaga_texto
        POP     DX
        POP     CX
        RET

; =============================================================================
segment data public class=DATA

ultimo_seg      DW      0FFFFh      ; ultimo valor de segundos desenhado
