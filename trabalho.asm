; =============================================================================
; trabalho.asm  -  Jogo de Luta em Assembly 8086 (modulo principal)
; -----------------------------------------------------------------------------
; Responsabilidades deste modulo:
;   - inicializacao (segmentos, vetores de interrupcao, modo de video)
;   - ISR de teclado (INT 9h) com TABELA DE ESTADO + buffer de eventos
;   - ISR de relogio (INT 8h) gerando o "tique" do loop do jogo
;   - loop principal sincronizado com o relogio
;   - movimentacao dos dois jogadores
;   - restauracao do sistema na saida
;
; Controles implementados nesta versao:
;   Jogador 1: A = esquerda, D = direita, W = pular
;   Jogador 2: seta esquerda, seta direita, seta cima = pular
;   ESC      : sai do programa (provisorio; o Q com confirmacao vem depois)
;
; Mecanica de orientacao:
;   - Os lutadores estao SEMPRE virados um para o outro (atualiza_direcao).
;   - No chao, um nao atravessa o outro (DIST_MIN).
;   - Pulando, o lutador pode passar por cima do adversario e trocar de lado;
;     ao pousar sobreposto, ele e empurrado para o lado em que caiu.
;
; Montagem (2 modulos):
;   nasm16 -f obj -o trabalho.obj -l trabalho.lst trabalho.asm
;   nasm16 -f obj -o graficos.obj -l graficos.lst graficos.asm
;   (ligar trabalho.obj + graficos.obj com o linker usado na disciplina)
; =============================================================================

; ------------------------------- Simbolos externos / publicos -----------------
extern  desenha_jogador         ; graficos.asm
extern  line                    ; graficos.asm

global  cor
global  deltAX
global  deltay
global  tam_corpo

; =============================================================================
segment code public class=CODE
..start:
; ---------------------------------------------- Inicializacao dos registradores
        MOV     AX, data
        MOV     DS, AX
        MOV     AX, stack
        MOV     SS, AX
        MOV     SP, stacktop

; ---------------------------------------------- Instalacao das ISRs (INT 9 e INT 8)
        CLI                                 ; desabilita interrupcoes enquanto troca os vetores
        XOR     AX, AX
        MOV     ES, AX                      ; ES = 0000h -> tabela de vetores

        MOV     AX, [ES:INT9*4]             ; salva IP original da INT 9
        MOV     [offset_tec], AX
        MOV     AX, [ES:INT9*4+2]           ; salva CS original da INT 9
        MOV     [cs_tec], AX
        MOV     [ES:INT9*4+2], CS           ; instala nossa ISR de teclado
        MOV     WORD [ES:INT9*4], keyINT

        MOV     AX, [ES:INTr*4]             ; salva IP original da INT 8
        MOV     [offset_clk], AX
        MOV     AX, [ES:INTr*4+2]           ; salva CS original da INT 8
        MOV     [cs_clk], AX
        MOV     [ES:INTr*4+2], CS           ; instala nossa ISR de relogio
        MOV     WORD [ES:INTr*4], ClockINT
        STI                                 ; reabilita interrupcoes

; ---------------------------------------------- Modo grafico
        MOV     AH, 0Fh                     ; le o modo de video atual
        INT     10h
        MOV     [modo_anterior], AL

        MOV     AH, 0                       ; modo 12h: 640x480, 16 cores
        MOV     AL, 12h
        INT     10h

; ---------------------------------------------- Cena inicial
        CALL    desenha_arena
        MOV     SI, jogador1
        CALL    pinta_jogador
        MOV     SI, jogador2
        CALL    pinta_jogador

        MOV     AX, [tique_jogo]            ; sincroniza o contador do loop
        MOV     [ultimo_tique], AX

; =============================================================================
; LOOP PRINCIPAL
; Roda uma vez a cada tique da INT 8h (~55 ms, 18,2 vezes por segundo).
; Nao ha atraso por laco de software: o ritmo vem do temporizador 8253.
; =============================================================================
loop_jogo:
        MOV     AX, [tique_jogo]
        CMP     AX, [ultimo_tique]
        JE      loop_jogo                   ; ainda no mesmo tique: espera
        MOV     [ultimo_tique], AX

        ; ---- 1. Eventos pontuais (buffer circular) -------------------------
        CALL    trata_eventos
        CMP     byte [sair_flag], 1
        JE      fim

        ; ---- 2. Teclas mantidas pressionadas (tabela de estado) ------------
        CALL    le_controles

        ; ---- 3. Fisica do pulo (gravidade e pouso) -------------------------
        MOV     SI, jogador1
        MOV     DI, jogador2
        CALL    fisica_jogador
        MOV     SI, jogador2
        MOV     DI, jogador1
        CALL    fisica_jogador

        ; ---- 4. Vira os lutadores um para o outro --------------------------
        CALL    atualiza_direcao

        ; ---- 5. Redesenha apenas se algo mudou -----------------------------
        CALL    houve_mudanca               ; retorna AL = 1 se precisa redesenhar
        CMP     AL, 0
        JE      loop_jogo

        MOV     SI, jogador1                ; apaga os dois na posicao antiga...
        CALL    apaga_jogador
        MOV     SI, jogador2
        CALL    apaga_jogador
        MOV     SI, jogador1                ; ...e redesenha os dois na nova
        CALL    pinta_jogador               ; (redesenhar ambos evita que um
        MOV     SI, jogador2                ;  apague um pedaco do outro)
        CALL    pinta_jogador

        JMP     loop_jogo

; =============================================================================
; fim: restaura vetores e modo de video e devolve o controle ao DOS
; =============================================================================
fim:
        CLI
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [cs_tec]                ; restaura INT 9
        MOV     [ES:INT9*4+2], AX
        MOV     AX, [offset_tec]
        MOV     [ES:INT9*4], AX
        MOV     AX, [cs_clk]                ; restaura INT 8
        MOV     [ES:INTr*4+2], AX
        MOV     AX, [offset_clk]
        MOV     [ES:INTr*4], AX
        STI

        MOV     AH, 0                       ; restaura o modo de video original
        MOV     AL, [modo_anterior]
        INT     10h

        MOV     AX, 4C00h                   ; retorna ao DOS
        INT     21h

; =============================================================================
; trata_eventos
; Consome o buffer circular de codigos (eventos de "pressionou uma vez").
; Usado para teclas de comando (ESC agora; P, Q, Y, N, Enter depois).
; =============================================================================
trata_eventos:
        PUSH    AX
        PUSH    BX
te_prox:
        MOV     AX, [p_i]
        CMP     AX, [p_t]
        JE      te_fim                      ; buffer vazio
        INC     WORD [p_t]
        AND     WORD [p_t], 7
        MOV     BX, [p_t]
        MOV     AL, [BX+tecla]
        MOV     [tecla_u], AL

        CMP     AL, TEC_ESC                 ; ESC pressionado (make 01h)
        JNE     te_prox
        MOV     byte [sair_flag], 1
te_fim:
        POP     BX
        POP     AX
        RET

; =============================================================================
; le_controles
; Le a tabela de estado do teclado e move os jogadores.
; Como a tabela guarda cada tecla separadamente, os dois jogadores podem
; segurar suas teclas ao mesmo tempo sem um bloquear o outro.
; =============================================================================
le_controles:
        PUSH    AX
        PUSH    SI
        PUSH    DI

        ; ------------------------- Jogador 1 (W / A / D)
        MOV     SI, jogador1
        MOV     DI, jogador2
        CMP     byte [teclas+TEC_W], 0
        JE      lc_p1_esq
        CALL    inicia_pulo
lc_p1_esq:
        CMP     byte [teclas+TEC_A], 0
        JE      lc_p1_dir
        MOV     AX, -VELOCIDADE
        CALL    mover_jogador
lc_p1_dir:
        CMP     byte [teclas+TEC_D], 0
        JE      lc_p2
        MOV     AX, VELOCIDADE
        CALL    mover_jogador

        ; ------------------------- Jogador 2 (setas)
lc_p2:
        MOV     SI, jogador2
        MOV     DI, jogador1
        CMP     byte [teclas+TEC_CIMA], 0
        JE      lc_p2_esq
        CALL    inicia_pulo
lc_p2_esq:
        CMP     byte [teclas+TEC_ESQ], 0
        JE      lc_p2_dir
        MOV     AX, -VELOCIDADE
        CALL    mover_jogador
lc_p2_dir:
        CMP     byte [teclas+TEC_DIR], 0
        JE      lc_fim
        MOV     AX, VELOCIDADE
        CALL    mover_jogador
lc_fim:
        POP     DI
        POP     SI
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
;   VY <- VY - GRAVIDADE
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
; A troca de direcao e detectada por houve_mudanca (JDIR x JDIRANT) e o
; boneco e redesenhado espelhado automaticamente.
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
; houve_mudanca
; Saida: AL = 1 se algum jogador mudou de posicao/frame/direcao desde o
;        ultimo desenho; AL = 0 caso contrario.
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
; guarda essa posicao/frame/direcao como "anterior" (para poder apagar depois).
; =============================================================================
pinta_jogador:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     AL, [SI+JCOR]
        MOV     AH, [SI+JFRAME]
        MOV     BL, [SI+JDIR]
        MOV     CX, [SI+JX]
        MOV     DX, [SI+JY]
        CALL    desenha_jogador             ; preserva todos os registradores
        MOV     [SI+JXANT], CX
        MOV     [SI+JYANT], DX
        MOV     [SI+JFRAMEANT], AH
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
        MOV     CX, [SI+JXANT]
        MOV     DX, [SI+JYANT]
        CALL    desenha_jogador
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

; =============================================================================
; desenha_arena
; Retangulo da arena: chao em Y = ARENA_BAIXO, teto em Y = ARENA_TOPO,
; paredes em X = ARENA_ESQ e X = ARENA_DIR. A faixa acima do teto fica
; reservada para o HUD (energia, tempo, rounds).
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
; ISR de teclado (INT 9h)
; Mantem duas estruturas:
;   teclas[128] : 1 = tecla pressionada, 0 = solta (para movimento continuo)
;   tecla[8]    : buffer circular de codigos (para comandos pontuais)
; As setas chegam como E0h + codigo; o prefixo E0h e simplesmente ignorado,
; de modo que seta esquerda = 4Bh, seta direita = 4Dh etc.
; =============================================================================
keyINT:
        PUSH    AX
        PUSH    BX
        PUSH    DS
        MOV     AX, data                    ; garante DS correto dentro da ISR
        MOV     DS, AX

        IN      AL, kb_data                 ; le o codigo make/break (porta 60h)
        CMP     AL, 0E0h                    ; prefixo de tecla estendida
        JE      ki_ack
        CMP     AL, 0E1h                    ; prefixo da tecla Pause
        JE      ki_ack

        ; ---- grava no buffer circular (comandos)
        INC     WORD [p_i]
        AND     WORD [p_i], 7
        MOV     BX, [p_i]
        MOV     [BX+tecla], AL

        ; ---- atualiza a tabela de estado (movimento)
        MOV     BL, AL
        AND     BX, 007Fh                   ; BX = codigo sem o bit 7 (e BH = 0)
        TEST    AL, 80h                     ; bit 7 = 1 -> break (soltou)
        JNZ     ki_solta
        MOV     byte [teclas+BX], 1
        JMP     ki_ack
ki_solta:
        MOV     byte [teclas+BX], 0

ki_ack:
        IN      AL, kb_ctl                  ; reconhece o dado na porta 61h
        OR      AL, 80h
        OUT     kb_ctl, AL
        AND     AL, 7Fh
        OUT     kb_ctl, AL
        MOV     AL, eoi                     ; fim de interrupcao para o PIC
        OUT     pictrl, AL

        POP     DS
        POP     BX
        POP     AX
        IRET

; =============================================================================
; ISR de relogio (INT 8h) - 18,2 Hz
; Incrementa tique_jogo (ritmo do loop) e conta segundos (base para o
; cronometro de 3 minutos do round). Ao final ENCADEIA a ISR original do
; BIOS, que mantem o relogio do sistema e envia o EOI ao PIC.
; =============================================================================
ClockINT:
        PUSH    AX
        PUSH    DS
        MOV     AX, data
        MOV     DS, AX

        INC     WORD [tique_jogo]           ; um "frame" do jogo

        INC     byte [tique]                ; contagem de segundos
        CMP     byte [tique], 18
        JB      ck_chain
        MOV     byte [tique], 0
        INC     WORD [segundos]

ck_chain:
        PUSHF                               ; simula um INT para a ISR original
        CALL    FAR [offset_clk]            ; (ela faz o EOI e termina em IRET)

        POP     DS
        POP     AX
        IRET

; =============================================================================
segment data public class=DATA

; ------------------------------- Teclado --------------------------------------
kb_data         EQU     60h         ; porta de dados do teclado
kb_ctl          EQU     61h         ; porta de controle do teclado
pictrl          EQU     20h         ; porta de comando do PIC
eoi             EQU     20h         ; comando End Of Interrupt
INT9            EQU     09h         ; interrupcao de hardware do teclado

; Scan codes (make)
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
TEC_CIMA        EQU     48h         ; seta para cima   (apos E0h)
TEC_ESQ         EQU     4Bh         ; seta esquerda    (apos E0h)
TEC_DIR         EQU     4Dh         ; seta direita     (apos E0h)
TEC_BAIXO       EQU     50h         ; seta para baixo  (apos E0h)

cs_tec          DW      0           ; CS original da INT 9
offset_tec      DW      0           ; IP original da INT 9
tecla_u         DB      0           ; ultimo codigo retirado do buffer
tecla           TIMES 8 DB 0        ; buffer circular de codigos
p_i             DW      0           ; indice de escrita (ISR)
p_t             DW      0           ; indice de leitura (programa)
teclas          TIMES 128 DB 0      ; tabela de estado: 1 = pressionada

; ------------------------------- Relogio --------------------------------------
INTr            EQU     08h         ; interrupcao de hardware do temporizador
offset_clk      DW      0           ; IP original da INT 8  (offset ANTES do
cs_clk          DW      0           ; CS original da INT 8   segmento: far ptr)
tique           DB      0           ; tiques dentro do segundo atual
segundos        DW      0           ; segundos decorridos
tique_jogo      DW      0           ; incrementado a cada tique (~55 ms)
ultimo_tique    DW      0           ; ultimo tique processado pelo loop

; ------------------------------- Video ----------------------------------------
cor             DB      branco_intenso
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

modo_anterior   DB      0
deltAX          DW      0           ; variaveis de trabalho da rotina line
deltay          DW      0

; ------------------------------- Arena ----------------------------------------
; Coordenadas no sistema de plot_xy: Y = 0 embaixo, Y = 479 em cima.
ARENA_ESQ       EQU     10
ARENA_DIR       EQU     629
ARENA_BAIXO     EQU     70          ; chao
ARENA_TOPO      EQU     420         ; acima disso fica o HUD

; ------------------------------- Jogo -----------------------------------------
VELOCIDADE      EQU     4           ; pixels por tique (~73 px/s)
LIM_ESQ         EQU     40          ; menor X permitido para o centro do boneco
LIM_DIR         EQU     598         ; maior X permitido (braco vai ate +27)
DIST_MIN        EQU     50          ; distancia minima entre os dois lutadores
Y_CHAO          EQU     156         ; Y dos ombros com o lutador no chao
VEL_PULO        EQU     22          ; velocidade vertical inicial do pulo (px/tique)
GRAVIDADE       EQU     2           ; reducao de VY a cada tique
sair_flag       DB      0

tam_corpo       DW      46
tam_braco       DW      28
tam_perna       DW      30

; ----------------------------------------------------------------------------
; Estrutura de um jogador (20 bytes). Acesse sempre como [SI+campo].
; ----------------------------------------------------------------------------
JX              EQU     0           ; dw  posicao X atual (centro do tronco)
JY              EQU     2           ; dw  posicao Y atual (ombros)
JXANT           EQU     4           ; dw  X onde foi desenhado por ultimo
JYANT           EQU     6           ; dw  Y onde foi desenhado por ultimo
JFRAME          EQU     8           ; db  frame atual da animacao
JFRAMEANT       EQU     9           ; db  frame desenhado por ultimo
JDIR            EQU     10          ; db  0 = olha p/ direita, 1 = p/ esquerda
JDIRANT         EQU     11          ; db  direcao desenhada por ultimo
JCOR            EQU     12          ; db  cor do lutador
JENERGIA        EQU     13          ; db  energia (comeca em 10)
JESTADO         EQU     14          ; db  0 idle, 1 dir, 2 esq, 3 soco, 4 chute...
                                    ; byte 15: reserva (alinhamento)
JVY             EQU     16          ; dw  velocidade vertical (positiva = sobe)
JPULO           EQU     18          ; db  1 = no ar, 0 = no chao
                                    ; byte 19: reserva (alinhamento)

; Y_CHAO = 156 deixa os pes (offset -84 do frame) logo acima do chao (Y = 70)
jogador1:
        DW      150, Y_CHAO         ; JX, JY
        DW      150, Y_CHAO         ; JXANT, JYANT
        DB      0, 0                ; JFRAME, JFRAMEANT
        DB      0, 0                ; JDIR, JDIRANT   (olha para a direita)
        DB      azul_claro          ; JCOR
        DB      10                  ; JENERGIA
        DB      0                   ; JESTADO
        DB      0                   ; reserva
        DW      0                   ; JVY
        DB      0                   ; JPULO
        DB      0                   ; reserva

jogador2:
        DW      490, Y_CHAO         ; JX, JY
        DW      490, Y_CHAO         ; JXANT, JYANT
        DB      0, 0                ; JFRAME, JFRAMEANT
        DB      1, 1                ; JDIR, JDIRANT   (olha para a esquerda)
        DB      vermelho            ; JCOR
        DB      10                  ; JENERGIA
        DB      0                   ; JESTADO
        DB      0                   ; reserva
        DW      0                   ; JVY
        DB      0                   ; JPULO
        DB      0                   ; reserva

; =============================================================================
segment stack stack
        resb    1024
stacktop: