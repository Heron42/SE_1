; =============================================================================
; const.inc  -  Constantes compartilhadas por todos os modulos do jogo
; -----------------------------------------------------------------------------
; Contem apenas EQUs (nao gera codigo nem dados). Incluido com
;   %include "const.inc"
; em cada modulo .asm. Qualquer alteracao aqui exige remontar todos os
; modulos (o Makefile ja declara essa dependencia).
; =============================================================================

; ------------------------------- Hardware -------------------------------------
KB_DATA         EQU     60h         ; porta de dados do teclado (8042)
KB_CTL          EQU     61h         ; porta de controle do teclado (8255 PB)
PICTRL          EQU     20h         ; porta de comando do PIC 8259
EOI             EQU     20h         ; comando End Of Interrupt
INT_TEC         EQU     09h         ; interrupcao de hardware do teclado (IRQ1)
INT_CLK         EQU     08h         ; interrupcao de hardware do 8253 (IRQ0)

; ------------------------------- Scan codes (make) ----------------------------
TEC_ESC         EQU     01h
TEC_Q           EQU     10h
TEC_W           EQU     11h
TEC_R           EQU     13h
TEC_T           EQU     14h
TEC_Y           EQU     15h
TEC_P           EQU     19h
TEC_ENTER       EQU     1Ch
TEC_A           EQU     1Eh
TEC_S           EQU     1Fh
TEC_D           EQU     20h
TEC_N           EQU     31h
TEC_M           EQU     32h
TEC_CIMA        EQU     48h         ; seta para cima   (chega apos o prefixo E0h)
TEC_ESQ         EQU     4Bh         ; seta esquerda    (apos E0h)
TEC_DIR         EQU     4Dh         ; seta direita     (apos E0h)
TEC_BAIXO       EQU     50h         ; seta para baixo  (apos E0h)

; ------------------------------- Cores (paleta padrao VGA) --------------------
                                    ; I R G B
preto           EQU     0           ; 0 0 0 0
azul            EQU     1           ; 0 0 0 1
verde           EQU     2           ; 0 0 1 0
cyan            EQU     3           ; 0 0 1 1
vermelho        EQU     4           ; 0 1 0 0
magenta         EQU     5           ; 0 1 0 1
marrom          EQU     6           ; 0 1 1 0
branco          EQU     7           ; 0 1 1 1
cinza           EQU     8           ; 1 0 0 0
azul_claro      EQU     9           ; 1 0 0 1
verde_claro     EQU     10          ; 1 0 1 0
cyan_claro      EQU     11          ; 1 0 1 1
rosa            EQU     12          ; 1 1 0 0
magenta_claro   EQU     13          ; 1 1 0 1
amarelo         EQU     14          ; 1 1 1 0
branco_intenso  EQU     15          ; 1 1 1 1

; ------------------------------- Arena e HUD ----------------------------------
; Coordenadas no sistema de plot_xy: Y = 0 embaixo, Y = 479 em cima.
ARENA_ESQ       EQU     10
ARENA_DIR       EQU     629
ARENA_BAIXO     EQU     70          ; chao
ARENA_TOPO      EQU     420         ; acima disso fica o HUD

BARRA_Y_BAIXO   EQU     440         ; barras de energia
BARRA_Y_TOPO    EQU     460
BARRA_P1_X      EQU     20          ; J1: X = 20..219
BARRA_P2_X      EQU     420         ; J2: X = 420..619
LARG_BLOCO      EQU     20          ; 1 ponto de energia = 20 px de barra

; Linhas de texto (modo 12h: 30 linhas x 80 colunas, celula 8x16)
LIN_TEMPO       EQU     1           ; cronometro (centro do HUD)
COL_TEMPO       EQU     38
LIN_MSG         EQU     6           ; mensagens no centro da arena (acima do pulo)
LIN_CONFIRMA    EQU     27          ; confirmacao de saida (abaixo do chao)

; ------------------------------- Regras do jogo -------------------------------
ENERGIA_INICIAL EQU     10          ; golpes validos para perder o round
ROUNDS_VITORIA  EQU     2           ; melhor de tres
TEMPO_ROUND     EQU     180         ; 3 minutos, em segundos
MOTIVO_KO       EQU     1           ; round terminou por falta de energia
MOTIVO_TEMPO    EQU     2           ; round terminou por tempo esgotado

; ------------------------------- Fisica dos lutadores -------------------------
VELOCIDADE      EQU     4           ; pixels por tique (~73 px/s)
LIM_ESQ         EQU     40          ; menor X permitido para o centro do boneco
LIM_DIR         EQU     598         ; maior X permitido (braco vai ate +27)
DIST_MIN        EQU     50          ; distancia minima entre os dois lutadores
Y_CHAO          EQU     156         ; Y dos ombros com o lutador no chao
VEL_PULO        EQU     22          ; velocidade vertical inicial do pulo (px/tique)
GRAVIDADE       EQU     2           ; reducao de VY a cada tique
X_INICIAL_J1    EQU     150
X_INICIAL_J2    EQU     490

; ------------------------------- Colisao --------------------------------------
ALCANCE_SOCO    EQU     68          ; distancia maxima em X para o soco acertar
ALCANCE_CHUTE   EQU     74          ; distancia maxima em X para o chute acertar
TOLERANCIA_Y    EQU     25          ; diferenca de altura maxima para o soco
FRAME_IMPACTO_SOCO  EQU 2           ; frame da animacao em que o soco "pega"
FRAME_IMPACTO_CHUTE EQU 3           ; frame da animacao em que o chute "pega"

; ------------------------------- Estados de animacao --------------------------
EST_IDLE        EQU     0
EST_ANDA        EQU     1
EST_SOCO        EQU     2
EST_CHUTE       EQU     3
EST_ABAIXA      EQU     4

; ------------------------------- Estrutura de um jogador (20 bytes) -----------
; Acesse sempre como [SI+campo] ou [jogadorN+campo].
JX              EQU     0           ; dw  posicao X atual (centro do tronco)
JY              EQU     2           ; dw  posicao Y atual (ombros)
JXANT           EQU     4           ; dw  X onde foi desenhado por ultimo
JYANT           EQU     6           ; dw  Y onde foi desenhado por ultimo
JFRAME          EQU     8           ; db  frame atual da animacao
JFRAMEANT       EQU     9           ; db  frame desenhado por ultimo
JDIR            EQU     10          ; db  0 = olha p/ direita, 1 = p/ esquerda
JDIRANT         EQU     11          ; db  direcao desenhada por ultimo
JCOR            EQU     12          ; db  cor do lutador (escolhida na selecao)
JENERGIA        EQU     13          ; db  energia (comeca em ENERGIA_INICIAL)
JESTADO         EQU     14          ; db  estado de animacao (EST_*)
JESTADOANT      EQU     15          ; db  estado desenhado por ultimo
JVY             EQU     16          ; dw  velocidade vertical (positiva = sobe)
JPULO           EQU     18          ; db  1 = no ar, 0 = no chao
                                    ; byte 19: reserva (alinhamento)
TAM_JOGADOR     EQU     20
