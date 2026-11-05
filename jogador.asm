; =============================================================================
; jogador.asm  -  Lutadores: controles, movimento, pulo, animacao e desenho
; -----------------------------------------------------------------------------
; Controles (lidos da tabela de estado mantida pela ISR do teclado):
;   Acao       Jogador 1   Jogador 2
;   Esquerda       A           <-
;   Direita        D           ->
;   Pular          W           seta cima
;   Abaixar        S           seta baixo
;   Chute          R           N
;   Soco           T           M
;
; Mecanica de orientacao:
;   - Os lutadores estao SEMPRE virados um para o outro (atualiza_direcao).
;   - No chao, um nao atravessa o outro (DIST_MIN).
;   - Pulando, o lutador pode passar por cima do adversario e trocar de lado;
;     ao pousar sobreposto, ele e empurrado para o lado em que caiu.
;
; Rotinas publicas:
;   reseta_lutadores, le_controles, fisica_jogador, atualiza_direcao,
;   atualiza_animacao, houve_mudanca, pinta_jogador, apaga_jogador
; Dados publicos:
;   jogador1, jogador2 (estrutura de TAM_JOGADOR bytes, ver const.inc)
; =============================================================================

%include "const.inc"

global  jogador1
global  jogador2
global  reseta_lutadores
global  le_controles
global  fisica_jogador
global  atualiza_direcao
global  atualiza_animacao
global  houve_mudanca
global  pinta_jogador
global  apaga_jogador

extern  teclas                      ; teclado.asm
extern  desenha_jogador             ; graficos.asm

segment code public class=CODE

; =============================================================================
; reseta_lutadores
; Coloca os dois lutadores na posicao inicial, com energia cheia, parados.
; A cor (JCOR) NAO e alterada: e a escolhida na tela de selecao.
; =============================================================================
reseta_lutadores:
        PUSH    SI
        PUSH    AX
        MOV     SI, jogador1
        MOV     AX, X_INICIAL_J1
        MOV     byte [SI+JDIR], 0           ; J1 olha para a direita
        CALL    reseta_um
        MOV     SI, jogador2
        MOV     AX, X_INICIAL_J2
        MOV     byte [SI+JDIR], 1           ; J2 olha para a esquerda
        CALL    reseta_um
        POP     AX
        POP     SI
        RET

; Entrada: SI = jogador, AX = X inicial, [SI+JDIR] ja definido.
reseta_um:
        MOV     [SI+JX], AX
        MOV     [SI+JXANT], AX
        MOV     WORD [SI+JY], Y_CHAO
        MOV     WORD [SI+JYANT], Y_CHAO
        MOV     byte [SI+JFRAME], 0
        MOV     byte [SI+JFRAMEANT], 0
        MOV     AL, [SI+JDIR]
        MOV     [SI+JDIRANT], AL
        MOV     byte [SI+JENERGIA], ENERGIA_INICIAL
        MOV     byte [SI+JESTADO], EST_IDLE
        MOV     byte [SI+JESTADOANT], EST_IDLE
        MOV     WORD [SI+JVY], 0
        MOV     byte [SI+JPULO], 0
        RET

; =============================================================================
; le_controles
; Le a tabela de estado do teclado e aplica os comandos dos dois jogadores.
; Como a tabela guarda cada tecla separadamente, os dois jogadores podem
; segurar suas teclas ao mesmo tempo sem um bloquear o outro.
; =============================================================================
le_controles:
        PUSH    SI
        PUSH    DI
        MOV     SI, jogador1
        MOV     DI, jogador2
        MOV     byte [tecla_cima], TEC_W
        MOV     byte [tecla_baixo], TEC_S
        MOV     byte [tecla_esq], TEC_A
        MOV     byte [tecla_dir], TEC_D
        MOV     byte [tecla_soco], TEC_T
        MOV     byte [tecla_chute], TEC_R
        CALL    controla_jogador

        MOV     SI, jogador2
        MOV     DI, jogador1
        MOV     byte [tecla_cima], TEC_CIMA
        MOV     byte [tecla_baixo], TEC_BAIXO
        MOV     byte [tecla_esq], TEC_ESQ
        MOV     byte [tecla_dir], TEC_DIR
        MOV     byte [tecla_soco], TEC_M
        MOV     byte [tecla_chute], TEC_N
        CALL    controla_jogador
        POP     DI
        POP     SI
        RET

; -----------------------------------------------------------------------------
; tecla_ativa
; Entrada: BL = scan code. Saida: ZF = 0 se a tecla esta pressionada.
; -----------------------------------------------------------------------------
tecla_ativa:
        PUSH    BX
        XOR     BH, BH
        CMP     byte [teclas+BX], 0
        POP     BX
        RET

; -----------------------------------------------------------------------------
; controla_jogador
; Entrada: SI = jogador, DI = adversario, tecla_* = mapa de teclas dele.
; Regras:
;   - durante um soco ou chute os comandos ficam bloqueados ate o fim do golpe;
;   - abaixado o lutador nao anda, mas pode atacar;
;   - se nenhuma tecla for usada, volta ao estado parado (idle);
;   - segurar a tecla de soco/chute repete o golpe ao fim de cada animacao.
; Preserva todos os registradores.
; -----------------------------------------------------------------------------
controla_jogador:
        PUSH    AX
        PUSH    BX
        PUSH    CX

        CMP     byte [SI+JESTADO], EST_SOCO ; golpe em andamento: bloqueia tudo
        JE      cj_fim_jmp
        CMP     byte [SI+JESTADO], EST_CHUTE
        JNE     cj_livre
cj_fim_jmp:
        JMP     cj_fim

cj_livre:
        XOR     CL, CL                      ; CL = teclas usadas neste tique

        ; ---- pular
        MOV     BL, [tecla_cima]
        CALL    tecla_ativa
        JZ      cj_abaixa
        INC     CL
        CALL    inicia_pulo

        ; ---- abaixar (so no chao; abaixado nao anda)
cj_abaixa:
        MOV     BL, [tecla_baixo]
        CALL    tecla_ativa
        JZ      cj_esq
        CMP     byte [SI+JPULO], 0
        JNE     cj_esq
        INC     CL
        CMP     byte [SI+JESTADO], EST_ABAIXA
        JE      cj_soco                     ; ja abaixado: mantem o frame atual
        MOV     byte [SI+JESTADO], EST_ABAIXA
        MOV     byte [SI+JFRAME], 0
        JMP     cj_soco

        ; ---- esquerda
cj_esq:
        MOV     BL, [tecla_esq]
        CALL    tecla_ativa
        JZ      cj_dir
        INC     CL
        MOV     AX, -VELOCIDADE
        MOV     byte [SI+JESTADO], EST_ANDA
        CALL    mover_jogador

        ; ---- direita
cj_dir:
        MOV     BL, [tecla_dir]
        CALL    tecla_ativa
        JZ      cj_soco
        INC     CL
        MOV     AX, VELOCIDADE
        MOV     byte [SI+JESTADO], EST_ANDA
        CALL    mover_jogador

        ; ---- soco (tem prioridade sobre o chute se os dois forem apertados)
cj_soco:
        MOV     BL, [tecla_soco]
        CALL    tecla_ativa
        JZ      cj_chute
        MOV     byte [SI+JESTADO], EST_SOCO
        MOV     byte [SI+JFRAME], 0
        JMP     cj_fim

        ; ---- chute
cj_chute:
        MOV     BL, [tecla_chute]
        CALL    tecla_ativa
        JZ      cj_idle
        MOV     byte [SI+JESTADO], EST_CHUTE
        MOV     byte [SI+JFRAME], 0
        JMP     cj_fim

        ; ---- nenhuma tecla de acao: volta a ficar parado
cj_idle:
        CMP     CL, 0
        JNE     cj_fim
        MOV     byte [SI+JESTADO], EST_IDLE
        MOV     byte [SI+JFRAME], 0

cj_fim:
        POP     CX
        POP     BX
        POP     AX
        RET

; =============================================================================
; mover_jogador
; Entrada: SI = jogador que se move, DI = adversario, AX = deslocamento em X
; So aplica o movimento se:
;   - o jogador continuar dentro dos limites da arena, e
;   - a distancia ate o adversario continuar >= DIST_MIN (nao atravessa).
; Se QUALQUER um dos dois estiver no ar, a distancia nao e verificada:
; e assim que um lutador passa por cima do outro e troca de lado.
; =============================================================================
mover_jogador:
        PUSH    AX
        PUSH    BX
        ADD     AX, [SI+JX]                 ; AX = nova posicao X
        CMP     AX, LIM_ESQ
        JL      mj_fim                      ; passaria da parede esquerda
        CMP     AX, LIM_DIR
        JG      mj_fim                      ; passaria da parede direita
        CMP     byte [SI+JPULO], 0          ; quem anda esta no ar?
        JNE     mj_aceita
        CMP     byte [DI+JPULO], 0          ; o adversario esta no ar?
        JNE     mj_aceita
        MOV     BX, AX
        SUB     BX, [DI+JX]                 ; BX = nova_x - x_adversario
        JNS     mj_abs
        NEG     BX                          ; BX = |distancia|
mj_abs:
        CMP     BX, DIST_MIN
        JL      mj_fim                      ; encostaria/atravessaria o adversario
mj_aceita:
        MOV     [SI+JX], AX                 ; movimento aceito
mj_fim:
        POP     BX
        POP     AX
        RET

; =============================================================================
; inicia_pulo
; Entrada: SI = jogador. So pula se estiver no chao.
; =============================================================================
inicia_pulo:
        CMP     byte [SI+JPULO], 0
        JNE     ip_fim                      ; ja esta no ar: ignora
        MOV     byte [SI+JPULO], 1
        MOV     WORD [SI+JVY], VEL_PULO     ; velocidade vertical inicial (para cima)
ip_fim:
        RET

; =============================================================================
; fisica_jogador
; Entrada: SI = jogador, DI = adversario. Executada uma vez por tique.
;   Y  <- Y + VY
;   VY <- VY - 



; Ao tocar o chao (Y <= Y_CHAO): fixa Y no chao, zera VY, encerra o pulo
; e resolve uma eventual sobreposicao com o adversario.
; Com VEL_PULO = 22 e GRAVIDADE = 2 o pulo sobe 132 px e dura ~1,3 s
; (os pes passam cerca de 30 px acima da cabeca do adversario).
; =============================================================================
fisica_jogador:
        PUSH    AX
        CMP     byte [SI+JPULO], 0
        JE      fj_fim                      ; no chao: nada a fazer
        MOV     AX, [SI+JVY]
        ADD     [SI+JY], AX                 ; move na vertical
        SUB     WORD [SI+JVY], GRAVIDADE    ; gravidade
        CMP     WORD [SI+JY], Y_CHAO
        JG      fj_fim                      ; ainda no ar
        MOV     WORD [SI+JY], Y_CHAO        ; pousou
        MOV     WORD [SI+JVY], 0
        MOV     byte [SI+JPULO], 0
        CALL    separa_ao_pousar
fj_fim:
        POP     AX
        RET

; =============================================================================
; separa_ao_pousar
; Entrada: SI = jogador que acabou de pousar, DI = adversario.
; Se pousou a menos de DIST_MIN do adversario (que esta no chao), empurra
; quem pousou para o lado em que caiu. Se a parede impedir, empurra o
; adversario para o outro lado. Se o adversario ainda estiver no ar, a
; separacao sera feita quando ELE pousar.
; =============================================================================
separa_ao_pousar:
        PUSH    AX
        PUSH    BX
        CMP     byte [DI+JPULO], 0
        JNE     sp_fim                      ; adversario no ar: resolve depois
        MOV     AX, [SI+JX]
        SUB     AX, [DI+JX]                 ; AX = x_pousou - x_adversario
        MOV     BX, AX
        JNS     sp_abs
        NEG     BX
sp_abs:
        CMP     BX, DIST_MIN
        JGE     sp_fim                      ; ja estao afastados o suficiente

        MOV     BX, [DI+JX]
        CMP     AX, 0
        JL      sp_esquerda
        ; ---- caiu a direita (ou exatamente em cima): vai para a direita
        ADD     BX, DIST_MIN
        CMP     BX, LIM_DIR
        JLE     sp_grava
        MOV     BX, LIM_DIR                 ; parede direita: encosta nela...
        MOV     AX, LIM_DIR - DIST_MIN
        MOV     [DI+JX], AX                 ; ...e empurra o adversario
        JMP     sp_grava
sp_esquerda:
        ; ---- caiu a esquerda: vai para a esquerda
        SUB     BX, DIST_MIN
        CMP     BX, LIM_ESQ
        JGE     sp_grava
        MOV     BX, LIM_ESQ                 ; parede esquerda: encosta nela...
        MOV     AX, LIM_ESQ + DIST_MIN
        MOV     [DI+JX], AX                 ; ...e empurra o adversario
sp_grava:
        MOV     [SI+JX], BX
sp_fim:
        POP     BX
        POP     AX
        RET

; =============================================================================
; atualiza_direcao
; Mantem os lutadores sempre virados um para o outro:
;   x1 < x2 -> J1 olha para a direita (0) e J2 para a esquerda (1)
;   x1 > x2 -> J1 olha para a esquerda (1) e J2 para a direita (0)
;   x1 = x2 -> (um sobre o outro, no pulo) mantem a direcao atual
; =============================================================================
atualiza_direcao:
        PUSH    AX
        MOV     AX, [jogador1+JX]
        CMP     AX, [jogador2+JX]
        JE      ad_fim
        JG      ad_invertido
        MOV     byte [jogador1+JDIR], 0
        MOV     byte [jogador2+JDIR], 1
        JMP     ad_fim
ad_invertido:
        MOV     byte [jogador1+JDIR], 1
        MOV     byte [jogador2+JDIR], 0
ad_fim:
        POP     AX
        RET

; =============================================================================
; atualiza_animacao
; Entrada: SI = jogador.
; Avanca o frame da animacao do estado atual:
;   - abaixado: trava no ultimo frame enquanto a tecla estiver pressionada;
;   - soco/chute: ao terminar a animacao, volta ao estado parado;
;   - demais estados: animacao ciclica.
; =============================================================================
atualiza_animacao:
        PUSH    AX
        PUSH    BX

        MOV     BL, [SI+JESTADO]
        XOR     BH, BH
        MOV     AL, [limite_frames+BX]      ; numero de frames deste estado

        INC     byte [SI+JFRAME]
        CMP     [SI+JFRAME], AL
        JL      aa_fim                      ; ainda dentro da animacao

        CMP     byte [SI+JESTADO], EST_ABAIXA
        JNE     aa_ciclo
        DEC     AL                          ; abaixado: trava no ultimo frame
        MOV     [SI+JFRAME], AL
        JMP     aa_fim

aa_ciclo:
        MOV     byte [SI+JFRAME], 0         ; recomeca a animacao
        CMP     byte [SI+JESTADO], EST_SOCO
        JE      aa_reseta_idle
        CMP     byte [SI+JESTADO], EST_CHUTE
        JNE     aa_fim
aa_reseta_idle:
        MOV     byte [SI+JESTADO], EST_IDLE ; golpe terminou

aa_fim:
        POP     BX
        POP     AX
        RET

; =============================================================================
; houve_mudanca
; Saida: AL = 1 se algum jogador mudou de posicao/frame/estado/direcao desde
;        o ultimo desenho; AL = 0 caso contrario.
; =============================================================================
houve_mudanca:
        PUSH    SI
        MOV     SI, jogador1
        CALL    jogador_mudou
        CMP     AL, 1
        JE      hm_fim
        MOV     SI, jogador2
        CALL    jogador_mudou
hm_fim:
        POP     SI
        RET

; Entrada: SI = jogador. Saida: AL = 1 se mudou, 0 se nao.
jogador_mudou:
        PUSH    BX
        MOV     AL, 1
        MOV     BX, [SI+JX]
        CMP     BX, [SI+JXANT]
        JNE     jm_fim
        MOV     BX, [SI+JY]
        CMP     BX, [SI+JYANT]
        JNE     jm_fim
        MOV     BL, [SI+JFRAME]
        CMP     BL, [SI+JFRAMEANT]
        JNE     jm_fim
        MOV     BL, [SI+JESTADO]
        CMP     BL, [SI+JESTADOANT]
        JNE     jm_fim
        MOV     BL, [SI+JDIR]
        CMP     BL, [SI+JDIRANT]
        JNE     jm_fim
        MOV     AL, 0
jm_fim:
        POP     BX
        RET

; =============================================================================
; pinta_jogador
; Entrada: SI = jogador. Desenha na posicao ATUAL, com a cor do jogador, e
; guarda essa posicao/frame/estado/direcao como "anterior" (para apagar depois).
; =============================================================================
pinta_jogador:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     AL, [SI+JCOR]
        MOV     AH, [SI+JFRAME]
        MOV     BL, [SI+JDIR]
        MOV     BH, [SI+JESTADO]
        MOV     CX, [SI+JX]
        MOV     DX, [SI+JY]
        CALL    desenha_jogador             ; preserva todos os registradores
        MOV     [SI+JXANT], CX
        MOV     [SI+JYANT], DX
        MOV     [SI+JFRAMEANT], AH
        MOV     [SI+JESTADOANT], BH
        MOV     [SI+JDIRANT], BL
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

; =============================================================================
; apaga_jogador
; Entrada: SI = jogador. Redesenha em PRETO na posicao ANTERIOR.
; =============================================================================
apaga_jogador:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     AL, preto
        MOV     AH, [SI+JFRAMEANT]
        MOV     BL, [SI+JDIRANT]
        MOV     BH, [SI+JESTADOANT]
        MOV     CX, [SI+JXANT]
        MOV     DX, [SI+JYANT]
        CALL    desenha_jogador
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

; =============================================================================
segment data public class=DATA

; Mapa de teclas do jogador sendo processado por controla_jogador
tecla_cima      DB      0
tecla_baixo     DB      0
tecla_esq       DB      0
tecla_dir       DB      0
tecla_soco      DB      0
tecla_chute     DB      0

; Numero de frames de cada estado: parado, andar, soco, chute, abaixar.
; O estado parado usa so o frame 0 (v_idle tambem tem um frame 1, nao usado).
limite_frames   DB      1, 10, 10, 10, 3

; ----------------------------------------------------------------------------
; Lutadores (TAM_JOGADOR = 20 bytes cada; offsets em const.inc).
; A cor e sobrescrita pela tela de selecao.
; ----------------------------------------------------------------------------
jogador1:
        DW      X_INICIAL_J1, Y_CHAO    ; JX, JY
        DW      X_INICIAL_J1, Y_CHAO    ; JXANT, JYANT
        DB      0, 0                    ; JFRAME, JFRAMEANT
        DB      0, 0                    ; JDIR, JDIRANT   (olha para a direita)
        DB      azul_claro              ; JCOR
        DB      ENERGIA_INICIAL         ; JENERGIA
        DB      EST_IDLE, EST_IDLE      ; JESTADO, JESTADOANT
        DW      0                       ; JVY
        DB      0                       ; JPULO
        DB      0                       ; reserva

jogador2:
        DW      X_INICIAL_J2, Y_CHAO    ; JX, JY
        DW      X_INICIAL_J2, Y_CHAO    ; JXANT, JYANT
        DB      0, 0                    ; JFRAME, JFRAMEANT
        DB      1, 1                    ; JDIR, JDIRANT   (olha para a esquerda)
        DB      vermelho                ; JCOR
        DB      ENERGIA_INICIAL         ; JENERGIA
        DB      EST_IDLE, EST_IDLE      ; JESTADO, JESTADOANT
        DW      0                       ; JVY
        DB      0                       ; JPULO
        DB      0                       ; reserva
