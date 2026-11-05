; =============================================================================
; logica.asm  -  Regras da partida, pausa e encerramento manual
; -----------------------------------------------------------------------------
; Rounds e partida:
;   - o round termina quando um lutador chega a energia 0 ou quando o tempo
;     de TEMPO_ROUND segundos se esgota;
;   - partida em melhor de tres: vence quem conquistar ROUNDS_VITORIA rounds.
;
; CRITERIO DE VENCEDOR DO ROUND (aplicado em ordem):
;   1. Quem tiver MAIS ENERGIA (inclui o nocaute: energia 0 perde).
;   2. Empate de energia: vence quem acertou o ULTIMO GOLPE VALIDO do round.
;      (Se os dois zerarem a energia no mesmo tique, vale o golpe processado
;      por ultimo nesse tique.)
;   3. Nenhum golpe no round: vence quem estiver mais perto do CENTRO da
;      arena (dominio do ringue, X = 320).
;   4. Mesma distancia ao centro: vence o Jogador 1.
;
; Teclas de comando (tratadas pelo buffer de eventos):
;   P     : alterna pausa / execucao. Na pausa o cronometro do round fica
;           congelado e e exibido "PAUSED".
;   Q/ESC : pede confirmacao "Deseja sair? (Y/N)". Y encerra o programa,
;           N retorna exatamente ao estado anterior.
;
; Rotinas publicas:
;   inicia_partida, verifica_fim_round, trata_eventos, pausa,
;   confirma_saida, aguarda
; Variaveis publicas:
;   rounds_p1, rounds_p2, round_acabou, vencedor, vencedor_round,
;   motivo_fim, ultimo_golpe, sair_flag
; =============================================================================

%include "const.inc"

global  inicia_partida
global  verifica_fim_round
global  trata_eventos
global  pausa
global  confirma_saida
global  aguarda
global  rounds_p1
global  rounds_p2
global  round_acabou
global  vencedor
global  vencedor_round
global  motivo_fim
global  ultimo_golpe
global  sair_flag

extern  le_evento                   ; teclado.asm
extern  espera_evento
extern  limpa_eventos
extern  teclas
extern  tique_jogo                  ; tempo.asm
extern  segundos
extern  relogio_ativo
extern  jogador1                    ; jogador.asm
extern  jogador2
extern  msg_centro                  ; hud.asm
extern  apaga_linha
extern  cor                         ; graficos.asm

segment code public class=CODE

; =============================================================================
; inicia_partida: zera o placar no inicio de uma nova partida.
; =============================================================================
inicia_partida:
        MOV     byte [rounds_p1], 0
        MOV     byte [rounds_p2], 0
        MOV     byte [vencedor], 0
        MOV     byte [sair_flag], 0
        RET

; =============================================================================
; verifica_fim_round
; Chamada uma vez por tique. Se o round terminou, define:
;   round_acabou = 1, vencedor_round = 1 ou 2, motivo_fim = KO ou TEMPO,
;   incrementa os rounds do vencedor e, se ele chegou a ROUNDS_VITORIA,
;   define vencedor = 1 ou 2 (fim da partida).
; Antes do inicio de cada round, round_acabou e ultimo_golpe devem ser 0.
; =============================================================================
verifica_fim_round:
        PUSH    AX
        PUSH    BX

        MOV     byte [motivo_fim], MOTIVO_KO
        CMP     byte [jogador1+JENERGIA], 0
        JE      vfr_compara
        CMP     byte [jogador2+JENERGIA], 0
        JE      vfr_compara
        CMP     WORD [segundos], TEMPO_ROUND
        JL      vfr_fim                     ; round continua
        MOV     byte [motivo_fim], MOTIVO_TEMPO

vfr_compara:
        ; ---- 1. energia
        MOV     AL, [jogador1+JENERGIA]
        CMP     AL, [jogador2+JENERGIA]
        JA      vfr_p1
        JB      vfr_p2

        ; ---- 2. ultimo golpe valido
        CMP     byte [ultimo_golpe], 1
        JE      vfr_p1
        CMP     byte [ultimo_golpe], 2
        JE      vfr_p2

        ; ---- 3. dominio do centro da arena
        MOV     AX, [jogador1+JX]
        SUB     AX, 320
        JNS     vfr_a1
        NEG     AX
vfr_a1:
        MOV     BX, [jogador2+JX]
        SUB     BX, 320
        JNS     vfr_a2
        NEG     BX
vfr_a2:
        CMP     AX, BX
        JA      vfr_p2                      ; J2 mais perto do centro
        ; ---- 4. persistindo o empate, J1 (cai em vfr_p1)

vfr_p1:
        MOV     byte [vencedor_round], 1
        INC     byte [rounds_p1]
        CMP     byte [rounds_p1], ROUNDS_VITORIA
        JB      vfr_acabou
        MOV     byte [vencedor], 1
        JMP     vfr_acabou

vfr_p2:
        MOV     byte [vencedor_round], 2
        INC     byte [rounds_p2]
        CMP     byte [rounds_p2], ROUNDS_VITORIA
        JB      vfr_acabou
        MOV     byte [vencedor], 2

vfr_acabou:
        MOV     byte [round_acabou], 1
vfr_fim:
        POP     BX
        POP     AX
        RET

; =============================================================================
; trata_eventos
; Consome a fila de eventos do teclado durante a luta:
;   P     -> pausa (bloqueia ate novo P)
;   Q/ESC -> confirmacao de saida (Y define sair_flag = 1)
; As demais teclas sao ignoradas aqui (o movimento usa a tabela de estado).
; =============================================================================
trata_eventos:
        PUSH    AX
te_prox:
        CMP     byte [sair_flag], 0
        JNE     te_fim
        CALL    le_evento
        JC      te_fim                      ; fila vazia
        CMP     AL, TEC_P
        JE      te_pausa
        CMP     AL, TEC_Q
        JE      te_sair
        CMP     AL, TEC_ESC
        JE      te_sair
        JMP     te_prox
te_pausa:
        CALL    pausa
        JMP     te_prox
te_sair:
        CALL    confirma_saida
        CMP     AL, 1
        JNE     te_prox
        MOV     byte [sair_flag], 1
te_fim:
        POP     AX
        RET

; =============================================================================
; pausa
; Congela o cronometro do round, mostra "PAUSED" e espera um novo P.
; Q/ESC continuam funcionando durante a pausa (com confirmacao).
; Ao retomar, apaga o aviso e devolve o cronometro ao estado anterior; como
; o laco principal so processa um tique por vez, o jogo continua exatamente
; do ponto em que parou.
; =============================================================================
pausa:
        PUSH    AX
        PUSH    DX
        PUSH    SI

        MOV     AL, [relogio_ativo]
        PUSH    AX                          ; guarda o estado do cronometro
        MOV     byte [relogio_ativo], 0     ; tempo de pausa nao conta

        MOV     byte [cor], amarelo
        MOV     SI, str_pausado
        MOV     DH, LIN_MSG
        CALL    msg_centro
        MOV     byte [cor], branco
        MOV     SI, str_continuar
        MOV     DH, LIN_MSG + 1
        CALL    msg_centro

pa_espera:
        CALL    espera_evento               ; AL = tecla (HLT enquanto nada chega)
        CMP     AL, TEC_P
        JE      pa_retoma
        CMP     AL, TEC_Q
        JE      pa_sair
        CMP     AL, TEC_ESC
        JNE     pa_espera
pa_sair:
        CALL    confirma_saida
        CMP     AL, 1
        JNE     pa_espera                   ; N: continua pausado
        MOV     byte [sair_flag], 1

pa_retoma:
        MOV     DH, LIN_MSG
        CALL    apaga_linha
        MOV     DH, LIN_MSG + 1
        CALL    apaga_linha

        POP     AX
        MOV     [relogio_ativo], AL         ; restaura o cronometro
        POP     SI
        POP     DX
        POP     AX
        RET

; =============================================================================
; confirma_saida
; Mostra "Deseja realmente sair? (Y/N)" na linha LIN_CONFIRMA e espera Y ou N.
; O cronometro fica congelado enquanto a pergunta estiver na tela.
; Saida: AL = 1 se o usuario confirmou (Y), AL = 0 se desistiu (N).
; A mensagem e apagada antes de retornar (volta ao estado anterior).
; =============================================================================
confirma_saida:
        PUSH    BX
        PUSH    DX
        PUSH    SI

        MOV     BL, [relogio_ativo]         ; guarda o estado do cronometro
        MOV     byte [relogio_ativo], 0

        MOV     BH, [cor]                   ; preserva a cor corrente
        MOV     byte [cor], amarelo
        MOV     SI, str_sair
        MOV     DH, LIN_CONFIRMA
        CALL    msg_centro

cs_espera:
        CALL    espera_evento
        CMP     AL, TEC_Y
        JE      cs_sim
        CMP     AL, TEC_N
        JNE     cs_espera
        MOV     AL, 0
        JMP     cs_solta
cs_sim:
        MOV     AL, 1

        ; ---- espera a tecla ser solta: N tambem e o chute do J2, e sem isso
        ;      o jogo voltaria com a tecla "pressionada" e o J2 chutaria.
cs_solta:
        PUSH    BX
        MOV     BX, TEC_N
        CMP     AL, 0
        JE      cs_aguarda_solta
        MOV     BX, TEC_Y
cs_aguarda_solta:
        CMP     byte [teclas+BX], 0
        JE      cs_soltou
        HLT
        JMP     cs_aguarda_solta
cs_soltou:
        POP     BX
        CALL    limpa_eventos               ; descarta o BREAK e repeticoes
cs_fim:
        MOV     DH, LIN_CONFIRMA
        CALL    apaga_linha
        MOV     [cor], BH
        MOV     [relogio_ativo], BL         ; restaura o cronometro

        POP     SI
        POP     DX
        POP     BX
        RET

; =============================================================================
; aguarda
; Entrada: CX = numero de tiques (~55 ms cada) a esperar.
; Espera usando o contador da INT 8h (HLT entre as interrupcoes), sem laco
; de atraso. Durante a espera, Q/ESC continuam pedindo confirmacao; se o
; usuario confirmar, sair_flag = 1 e a rotina retorna imediatamente.
; =============================================================================
aguarda:
        PUSH    AX
        PUSH    BX
        MOV     BX, [tique_jogo]            ; tique inicial
ag_loop:
        CALL    le_evento
        JC      ag_tempo
        CMP     AL, TEC_Q
        JE      ag_sair
        CMP     AL, TEC_ESC
        JNE     ag_tempo
ag_sair:
        CALL    confirma_saida
        CMP     AL, 1
        JNE     ag_tempo
        MOV     byte [sair_flag], 1
        JMP     ag_fim
ag_tempo:
        MOV     AX, [tique_jogo]
        SUB     AX, BX                      ; tiques decorridos
        CMP     AX, CX
        JAE     ag_fim
        HLT                                 ; dorme ate a proxima interrupcao
        JMP     ag_loop
ag_fim:
        POP     BX
        POP     AX
        RET

; =============================================================================
segment data public class=DATA

rounds_p1       DB      0           ; rounds vencidos pelo Jogador 1
rounds_p2       DB      0           ; rounds vencidos pelo Jogador 2
round_acabou    DB      0           ; 1 = o round atual terminou
vencedor        DB      0           ; 0 = partida em andamento, 1/2 = campeao
vencedor_round  DB      0           ; quem venceu o ultimo round (1/2)
motivo_fim      DB      0           ; MOTIVO_KO ou MOTIVO_TEMPO
ultimo_golpe    DB      0           ; quem acertou o ultimo golpe (0 = ninguem)
sair_flag       DB      0           ; 1 = usuario confirmou a saida

str_pausado     DB      'PAUSED', 0
str_continuar   DB      'Pressione P para continuar', 0
str_sair        DB      'Deseja realmente sair? (Y/N)', 0
