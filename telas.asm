; =============================================================================
; telas.asm  -  Telas do jogo: selecao de lutadores, avisos de round e Game Over
; -----------------------------------------------------------------------------
; tela_selecao      : cada jogador escolhe a cor do seu lutador
;                     (J1: W/S, J2: setas cima/baixo, ENTER inicia a luta).
;                     Os dois nao podem ficar com a mesma cor: a cor ja
;                     escolhida pelo adversario e pulada automaticamente.
; anuncia_round     : "ROUND n" / "LUTEM!" antes de cada round
; anuncia_fim_round : motivo do fim (nocaute ou tempo) e vencedor do round
; tela_game_over    : "GAME OVER", vencedor, placar e menu Y/N
;
; Em todas as telas, Q/ESC pede confirmacao de saida (Y/N).
; =============================================================================

; ------------------------------- Constantes (EQU) -----------------------------
; Constantes usadas por este modulo. Um EQU nao ocupa memoria: o montador
; troca o nome pelo valor. As que aparecem em mais de um modulo (estrutura do
; jogador, cores, scan codes, regras) precisam ter o MESMO valor em todos.

; ------------------------------- Scan codes (make) ----------------------------
TEC_ESC         EQU     01h
TEC_Q           EQU     10h
TEC_W           EQU     11h
TEC_Y           EQU     15h
TEC_ENTER       EQU     1Ch
TEC_S           EQU     1Fh
TEC_N           EQU     31h
TEC_CIMA        EQU     48h         ; seta para cima   (chega apos o prefixo E0h)
TEC_BAIXO       EQU     50h         ; seta para baixo  (apos E0h)

; ------------------------------- Cores (paleta padrao VGA) --------------------
vermelho        EQU     4           ; 0 1 0 0
marrom          EQU     6           ; 0 1 1 0
branco          EQU     7           ; 0 1 1 1
cinza           EQU     8           ; 1 0 0 0
azul_claro      EQU     9           ; 1 0 0 1
verde_claro     EQU     10          ; 1 0 1 0
cyan_claro      EQU     11          ; 1 0 1 1
magenta_claro   EQU     13          ; 1 1 0 1
amarelo         EQU     14          ; 1 1 1 0
branco_intenso  EQU     15          ; 1 1 1 1

; ------------------------------- Arena e HUD ----------------------------------
LIN_MSG         EQU     6           ; mensagens no centro da arena (acima do pulo)

; ------------------------------- Regras do jogo -------------------------------
MOTIVO_TEMPO    EQU     2           ; round terminou por tempo esgotado

; ------------------------------- Colisao --------------------------------------
FRAME_IMPACTO_SOCO  EQU 2           ; frame da animacao em que o soco "pega"

; ------------------------------- Estados de animacao --------------------------
EST_IDLE        EQU     0
EST_SOCO        EQU     2

; ------------------------------- Estrutura de um jogador (20 bytes) -----------
JCOR            EQU     12          ; db  cor do lutador (escolhida na selecao)

global  tela_selecao
global  anuncia_round
global  anuncia_fim_round
global  tela_game_over

extern  espera_evento               ; teclado.asm
extern  limpa_eventos
extern  desenha_jogador             ; graficos.asm
extern  escreve_texto
extern  limpa_tela
extern  line
extern  cor
extern  msg_centro                  ; hud.asm
extern  apaga_linha
extern  jogador1                    ; jogador.asm
extern  jogador2
extern  confirma_saida              ; logica.asm
extern  aguarda
extern  sair_flag
extern  rounds_p1
extern  rounds_p2
extern  vencedor
extern  vencedor_round
extern  motivo_fim

NUM_CORES       EQU     8           ; potencia de 2 (indice mascarado)
LIN_TITULO      EQU     2
LIN_CABECALHO   EQU     5
LIN_LISTA       EQU     7           ; primeira linha da lista de cores
COL_MARCA_J1    EQU     5
COL_MARCA_J2    EQU     59
X_PREVIA_J1     EQU     260
X_PREVIA_J2     EQU     380
Y_PREVIA        EQU     225         ; ombros do boneco de previa
LIN_CTRL        EQU     23

TIQUES_ROUND    EQU     27          ; ~1,5 s mostrando "ROUND n"
TIQUES_LUTEM    EQU     11          ; ~0,6 s mostrando "LUTEM!"
TIQUES_FIM      EQU     45          ; ~2,5 s mostrando o vencedor do round

segment code public class=CODE

; =============================================================================
; tela_selecao
; Saida: sair_flag = 1 se o usuario confirmou a saida pela tecla Q/ESC.
;        Caso contrario, [jogador1+JCOR] e [jogador2+JCOR] recebem as cores
;        escolhidas.
; =============================================================================
tela_selecao:
        PUSH    AX
        PUSH    BX
        PUSH    DX
        PUSH    SI
        PUSH    DI

        CALL    limpa_tela
        CALL    limpa_eventos

        ; ---- textos fixos
        MOV     byte [cor], amarelo
        MOV     SI, str_titulo
        MOV     DH, LIN_TITULO
        CALL    msg_centro

        MOV     byte [cor], branco_intenso
        MOV     SI, str_cab_j1
        MOV     DH, LIN_CABECALHO
        MOV     DL, COL_MARCA_J1 - 1
        CALL    escreve_texto
        MOV     SI, str_cab_j2
        MOV     DL, COL_MARCA_J2 - 1
        CALL    escreve_texto

        MOV     byte [cor], branco
        MOV     SI, str_ctrl_j1
        MOV     DH, LIN_CTRL
        CALL    msg_centro
        MOV     SI, str_ctrl_j2
        MOV     DH, LIN_CTRL + 1
        CALL    msg_centro
        MOV     byte [cor], amarelo
        MOV     SI, str_iniciar
        MOV     DH, LIN_CTRL + 2
        CALL    msg_centro

        ; ---- "chao" sob as previas
        MOV     byte [cor], cinza
        MOV     AX, X_PREVIA_J1 - 60
        PUSH    AX
        MOV     AX, Y_PREVIA - 88
        PUSH    AX
        MOV     AX, X_PREVIA_J2 + 60
        PUSH    AX
        MOV     AX, Y_PREVIA - 88
        PUSH    AX
        CALL    line

        CALL    redesenha_j1
        CALL    redesenha_j2

        ; ---- laco de selecao
ts_espera:
        CALL    espera_evento               ; AL = scan code MAKE
        CMP     AL, TEC_W
        JE      ts_j1_sobe
        CMP     AL, TEC_S
        JE      ts_j1_desce
        CMP     AL, TEC_CIMA
        JE      ts_j2_sobe
        CMP     AL, TEC_BAIXO
        JE      ts_j2_desce
        CMP     AL, TEC_ENTER
        JE      ts_inicia
        CMP     AL, TEC_Q
        JE      ts_sair
        CMP     AL, TEC_ESC
        JE      ts_sair
        JMP     ts_espera

ts_j1_sobe:
        MOV     AL, -1
        JMP     ts_muda_j1
ts_j1_desce:
        MOV     AL, 1
ts_muda_j1:
        MOV     SI, idx_j1
        MOV     DI, idx_j2
        CALL    muda_cor
        CALL    redesenha_j1
        JMP     ts_espera

ts_j2_sobe:
        MOV     AL, -1
        JMP     ts_muda_j2
ts_j2_desce:
        MOV     AL, 1
ts_muda_j2:
        MOV     SI, idx_j2
        MOV     DI, idx_j1
        CALL    muda_cor
        CALL    redesenha_j2
        JMP     ts_espera

ts_sair:
        CALL    confirma_saida
        CMP     AL, 1
        JNE     ts_espera
        MOV     byte [sair_flag], 1
        JMP     ts_fim

ts_inicia:
        MOV     BL, [idx_j1]                ; grava as cores escolhidas
        XOR     BH, BH
        MOV     AL, [tabela_cores+BX]
        MOV     [jogador1+JCOR], AL
        MOV     BL, [idx_j2]
        MOV     AL, [tabela_cores+BX]
        MOV     [jogador2+JCOR], AL

ts_fim:
        POP     DI
        POP     SI
        POP     DX
        POP     BX
        POP     AX
        RET

; -----------------------------------------------------------------------------
; muda_cor
; Entrada: SI -> indice da cor do jogador, DI -> indice da cor do adversario,
;          AL = +1 (desce na lista) ou -1 (sobe na lista).
; Avanca circularmente e pula a cor ja escolhida pelo adversario.
; -----------------------------------------------------------------------------
muda_cor:
        PUSH    BX
        MOV     BL, [SI]
mc_avanca:
        ADD     BL, AL
        AND     BL, NUM_CORES - 1           ; volta ao inicio/fim da lista
        CMP     BL, [DI]
        JE      mc_avanca                   ; cor do adversario: pula
        MOV     [SI], BL
        POP     BX
        RET

; -----------------------------------------------------------------------------
; redesenha_j1 / redesenha_j2: lista de cores com marcador + boneco de previa.
; -----------------------------------------------------------------------------
redesenha_j1:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     AL, [idx_j1]
        MOV     DL, COL_MARCA_J1
        CALL    desenha_lista
        MOV     BL, [idx_j1]
        XOR     BH, BH
        MOV     AL, [tabela_cores+BX]       ; cor
        MOV     AH, 0                       ; frame 0
        MOV     BL, 0                       ; olhando para a direita
        MOV     BH, EST_IDLE
        MOV     CX, X_PREVIA_J1
        MOV     DX, Y_PREVIA
        CALL    desenha_jogador
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

redesenha_j2:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     AL, [idx_j2]
        MOV     DL, COL_MARCA_J2
        CALL    desenha_lista
        MOV     BL, [idx_j2]
        XOR     BH, BH
        MOV     AL, [tabela_cores+BX]
        MOV     AH, 0
        MOV     BL, 1                       ; olhando para a esquerda
        MOV     BH, EST_IDLE
        MOV     CX, X_PREVIA_J2
        MOV     DX, Y_PREVIA
        CALL    desenha_jogador
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

; -----------------------------------------------------------------------------
; desenha_lista
; Entrada: AL = indice selecionado, DL = coluna do marcador.
; Escreve as NUM_CORES opcoes (cada nome na propria cor), com ">" na
; selecionada e " " nas demais.
; -----------------------------------------------------------------------------
desenha_lista:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI

        MOV     AH, AL                      ; AH = indice selecionado
        MOV     DH, LIN_LISTA
        XOR     CX, CX                      ; CX = indice da opcao
dl_loop:
        ; ---- marcador
        MOV     byte [cor], branco_intenso
        MOV     SI, str_marca_off
        CMP     CL, AH
        JNE     dl_marca
        MOV     SI, str_marca_on
dl_marca:
        CALL    escreve_texto

        ; ---- nome da cor, escrito na propria cor
        MOV     BX, CX
        MOV     AL, [tabela_cores+BX]
        MOV     [cor], AL
        SHL     BX, 1
        MOV     SI, [tabela_nomes+BX]
        PUSH    DX
        ADD     DL, 2
        CALL    escreve_texto
        POP     DX

        INC     DH
        INC     CX
        CMP     CX, NUM_CORES
        JB      dl_loop

        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

; =============================================================================
; anuncia_round
; Mostra "ROUND n" e "LUTEM!" no centro da arena antes do round comecar
; (com o cronometro ainda parado). Respeita Q/ESC via aguarda.
; =============================================================================
anuncia_round:
        PUSH    AX
        PUSH    CX
        PUSH    DX
        PUSH    SI

        MOV     AL, [rounds_p1]
        ADD     AL, [rounds_p2]
        ADD     AL, '1'                     ; numero do round atual
        MOV     [str_round+6], AL

        MOV     byte [cor], amarelo
        MOV     SI, str_round
        MOV     DH, LIN_MSG
        CALL    msg_centro
        MOV     CX, TIQUES_ROUND
        CALL    aguarda
        CMP     byte [sair_flag], 0
        JNE     ar_fim

        CALL    apaga_linha                 ; DH = LIN_MSG
        MOV     byte [cor], amarelo
        MOV     SI, str_lutem
        CALL    msg_centro
        MOV     CX, TIQUES_LUTEM
        CALL    aguarda
ar_fim:
        CALL    apaga_linha
        POP     SI
        POP     DX
        POP     CX
        POP     AX
        RET

; =============================================================================
; anuncia_fim_round
; Mostra o motivo do fim do round e quem venceu, por ~2,5 s.
; =============================================================================
anuncia_fim_round:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI

        MOV     byte [cor], amarelo
        MOV     SI, str_nocaute
        CMP     byte [motivo_fim], MOTIVO_TEMPO
        JNE     afr_motivo
        MOV     SI, str_tempo
afr_motivo:
        MOV     DH, LIN_MSG
        CALL    msg_centro

        MOV     AL, [vencedor_round]
        CALL    cor_do_jogador              ; [cor] = cor do vencedor
        ADD     AL, '0'
        MOV     [str_vence_round+8], AL
        MOV     SI, str_vence_round
        MOV     DH, LIN_MSG + 1
        CALL    msg_centro

        MOV     CX, TIQUES_FIM
        CALL    aguarda

        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

; -----------------------------------------------------------------------------
; cor_do_jogador
; Entrada: AL = 1 ou 2. Saida: [cor] = cor escolhida por esse jogador.
; Preserva AL.
; -----------------------------------------------------------------------------
cor_do_jogador:
        PUSH    BX
        MOV     BL, [jogador1+JCOR]
        CMP     AL, 1
        JE      cdj_grava
        MOV     BL, [jogador2+JCOR]
cdj_grava:
        MOV     [cor], BL
        POP     BX
        RET

; =============================================================================
; tela_game_over
; Mostra "GAME OVER", o vencedor da partida, o placar e pergunta se os
; jogadores querem uma nova partida.
; Saida: AL = 1 -> Y (nova partida), AL = 0 -> N ou saida confirmada (Q).
; =============================================================================
tela_game_over:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI

        CALL    limpa_tela
        CALL    limpa_eventos

        MOV     byte [cor], amarelo
        MOV     SI, str_game_over
        MOV     DH, 4
        CALL    msg_centro

        MOV     AL, [vencedor]
        CALL    cor_do_jogador
        ADD     AL, '0'
        MOV     [str_campeao+8], AL
        MOV     SI, str_campeao
        MOV     DH, 7
        CALL    msg_centro

        MOV     AL, [rounds_p1]             ; "Placar final: J1 x - y J2"
        ADD     AL, '0'
        MOV     [str_placar+17], AL
        MOV     AL, [rounds_p2]
        ADD     AL, '0'
        MOV     [str_placar+21], AL
        MOV     byte [cor], branco_intenso
        MOV     SI, str_placar
        MOV     DH, 9
        CALL    msg_centro

        ; ---- o campeao, em pose de soco
        MOV     SI, jogador1
        CMP     byte [vencedor], 1
        JE      go_boneco
        MOV     SI, jogador2
go_boneco:
        MOV     AL, [SI+JCOR]
        MOV     AH, FRAME_IMPACTO_SOCO
        MOV     BL, 0
        MOV     BH, EST_SOCO
        MOV     CX, 320
        MOV     DX, Y_PREVIA
        CALL    desenha_jogador

        MOV     byte [cor], amarelo
        MOV     SI, str_nova
        MOV     DH, 24
        CALL    msg_centro

go_espera:
        CALL    espera_evento
        CMP     AL, TEC_Y
        JE      go_sim
        CMP     AL, TEC_N
        JE      go_nao
        CMP     AL, TEC_Q
        JE      go_sair
        CMP     AL, TEC_ESC
        JNE     go_espera
go_sair:
        CALL    confirma_saida
        CMP     AL, 1
        JNE     go_espera
go_nao:
        MOV     AL, 0
        JMP     go_fim
go_sim:
        MOV     AL, 1
go_fim:
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        RET

; =============================================================================
segment data public class=DATA

idx_j1          DB      0           ; cor atual do J1 (indice em tabela_cores)
idx_j2          DB      1           ; cor atual do J2

tabela_cores    DB      azul_claro, vermelho, verde_claro, amarelo
                DB      magenta_claro, cyan_claro, branco_intenso, marrom

tabela_nomes    DW      nome_0, nome_1, nome_2, nome_3
                DW      nome_4, nome_5, nome_6, nome_7

nome_0          DB      'AZUL    ', 0
nome_1          DB      'VERMELHO', 0
nome_2          DB      'VERDE   ', 0
nome_3          DB      'AMARELO ', 0
nome_4          DB      'MAGENTA ', 0
nome_5          DB      'CIANO   ', 0
nome_6          DB      'BRANCO  ', 0
nome_7          DB      'MARROM  ', 0

str_marca_on    DB      '>', 0
str_marca_off   DB      ' ', 0

str_titulo      DB      'SELECAO DE LUTADORES', 0
str_cab_j1      DB      'JOGADOR 1', 0
str_cab_j2      DB      'JOGADOR 2', 0
str_ctrl_j1     DB      '', 0
str_ctrl_j2     DB      '', 0
str_iniciar     DB      '', 0

; Nos textos abaixo, o "n" (e o "x"/"y" do placar) e substituido em tempo de
; execucao pelo digito correspondente; o indice usado esta indicado ao lado.
str_round       DB      'ROUND n', 0                    ; n = indice 6
str_lutem       DB      'LUTEM!', 0
str_nocaute     DB      'KO', 0
str_tempo       DB      'TEMPO ESGOTADO!', 0
str_vence_round DB      'JOGADOR n VENCEU O ROUND', 0   ; n = indice 8

str_game_over   DB      'GAME OVER', 0
str_campeao     DB      'JOGADOR n VENCEU A PARTIDA!', 0 ; n = indice 8
str_placar      DB      'Placar final: J1 x - y J2', 0  ; x = 17, y = 21
str_nova        DB      'Nova partida? (Y/N)', 0
