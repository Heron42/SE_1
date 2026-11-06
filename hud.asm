; hud.asm - interface grafica



;  Cores
                                    ; I R G B
preto           EQU     0           ; 0 0 0 0
amarelo         EQU     14          ; 1 1 1 0
branco_intenso  EQU     15          ; 1 1 1 1

; Arena e HUD
ARENA_ESQ       EQU     10
ARENA_DIR       EQU     629
ARENA_BAIXO     EQU     70          ; chao
ARENA_TOPO      EQU     420         ; acima disso fica o HUD
BARRA_Y_BAIXO   EQU     440         ; barras de energia
BARRA_Y_TOPO    EQU     460
BARRA_P1_X      EQU     20          ; J1
BARRA_P2_X      EQU     420         ; J2
LARG_BLOCO      EQU     20          ; 1 ponto de energia = 20 px de barra

MARCA_MEIO      EQU     6           ; meio lado do quadrado de round (13 px)
MARCA_Y_BAIXO   EQU     444         ; Y da base do quadrado (centro em 450)
MARCA_Y_TOPO    EQU     456         ; Y do topo do quadrado

TEMPO_ROUND     EQU     180         ; 3 minutos, em segundos

; Estrutura dos jogadores
JCOR            EQU     12          ; db  cor do lutador
JENERGIA        EQU     13          ; db  energia 

global  desenha_cenario
global  atualiza_barra
global  desenha_rounds
global  desenha_tempo
global  msg_centro
global  apaga_linha

extern  line                        ; graficos.asm
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

; desenha_cenario

desenha_cenario:
        CALL    limpa_tela
        CALL    desenha_arena
        CALL    desenha_barras
        CALL    desenha_rounds
        MOV     WORD [ultimo_seg], 0FFFFh   ; forca o redesenho do tempo
        CALL    desenha_tempo
        RET

; desenha_arena

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

; desenha_barras
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

; faixa_vertical
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

; atualiza_barra
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

; desenha_rounds
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
; Desenha um quadrado de 13 x 13 px centrado em (BX, 450):
;   cheio (round vencido)        se AL >= CL
;   so o contorno (nao vencido)  caso contrario
marcador:
        PUSH    AX
        PUSH    DX
        PUSH    SI
        MOV     byte [cor], amarelo
        MOV     SI, BX
        SUB     SI, MARCA_MEIO              ; SI = X da borda esquerda
        MOV     DX, BX
        ADD     DX, MARCA_MEIO              ; DX = X da borda direita
        CMP     AL, CL
        JAE     mc_cheio

        ; ---- contorno: os 4 lados do quadrado
        MOV     AX, MARCA_Y_TOPO            ; lado de cima
        PUSH    SI
        PUSH    AX
        PUSH    DX
        PUSH    AX
        CALL    line
        MOV     AX, MARCA_Y_BAIXO           ; lado de baixo
        PUSH    SI
        PUSH    AX
        PUSH    DX
        PUSH    AX
        CALL    line
        PUSH    SI                          ; lado esquerdo
        MOV     AX, MARCA_Y_BAIXO
        PUSH    AX
        PUSH    SI
        MOV     AX, MARCA_Y_TOPO
        PUSH    AX
        CALL    line
        PUSH    DX                          ; lado direito
        MOV     AX, MARCA_Y_BAIXO
        PUSH    AX
        PUSH    DX
        MOV     AX, MARCA_Y_TOPO
        PUSH    AX
        CALL    line
        JMP     mc_fim

        ; ---- cheio: uma linha vertical para cada coluna X
mc_cheio:
        PUSH    SI                          ; x1
        MOV     AX, MARCA_Y_BAIXO
        PUSH    AX                          ; y1
        PUSH    SI                          ; x2
        MOV     AX, MARCA_Y_TOPO
        PUSH    AX                          ; y2
        CALL    line
        INC     SI
        CMP     SI, DX
        JLE     mc_cheio

mc_fim:
        POP     SI
        POP     DX
        POP     AX
        RET

; desenha_tempo
desenha_tempo:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX

        MOV     AX, [segundos]
        CMP     AX, [ultimo_seg]
        JE      dt_fim
        MOV     [ultimo_seg], AX

        ; Limpa fundo dos 3 digitos (X=304-327, Y=448-463)
        MOV     byte [cor], preto
        MOV     CX, 304
dt_limpa:
        PUSH    CX
        MOV     AX, 448
        PUSH    AX
        PUSH    CX
        MOV     AX, 463
        PUSH    AX
        CALL    line
        INC     CX
        CMP     CX, 328
        JL      dt_limpa

        MOV     AX, TEMPO_ROUND
        SUB     AX, [segundos]
        JNS     dt_pos
        XOR     AX, AX
dt_pos:
        MOV     BL, 100
        DIV     BL                          ; AL = centena, AH = resto
        MOV     BH, AH

        MOV     byte [cor], branco_intenso
        MOV     DH, 1
        MOV     DL, 38
        CALL    cursor
        ADD     AL, '0'
        CALL    caracter

        MOV     AL, BH
        XOR     AH, AH
        MOV     BL, 10
        DIV     BL

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
        POP     CX
        POP     BX
        POP     AX
        RET

; msg_centro
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

; apaga_linha
apaga_linha:
        PUSH    CX
        PUSH    DX
        MOV     DL, 2
        MOV     CX, 76
        CALL    apaga_texto
        POP     DX
        POP     CX
        RET

segment data public class=DATA

ultimo_seg      DW      0FFFFh      ; ultimo valor de segundos desenhado
