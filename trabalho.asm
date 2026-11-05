; trabalho.asm  -  Jogo de Luta em Assembly 8086 (modulo principal)

; Simbolos externos
extern  instala_teclado             ; teclado.asm
extern  restaura_teclado
extern  limpa_eventos
extern  instala_relogio             ; tempo.asm
extern  restaura_relogio
extern  zera_cronometro
extern  tique_jogo
extern  relogio_ativo
extern  jogador1                    ; jogador.asm
extern  jogador2
extern  reseta_lutadores
extern  le_controles
extern  fisica_jogador
extern  atualiza_direcao
extern  atualiza_animacao
extern  houve_mudanca
extern  pinta_jogador
extern  apaga_jogador
extern  verifica_golpe              ; colisao.asm
extern  inicia_partida              ; logica.asm
extern  verifica_fim_round
extern  trata_eventos
extern  round_acabou
extern  vencedor
extern  ultimo_golpe
extern  sair_flag
extern  desenha_cenario             ; hud.asm
extern  desenha_tempo
extern  desenha_rounds
extern  tela_selecao                ; telas.asm
extern  anuncia_round
extern  anuncia_fim_round
extern  tela_game_over

segment code public class=CODE
..start:
; Registradores de segmento/pilha
        MOV     AX, data
        MOV     DS, AX
        MOV     AX, stack
        MOV     SS, AX
        MOV     SP, stacktop
        CLD

; Modo de video
        MOV     AH, 0Fh                     ; le o modo de video atual
        INT     10h
        MOV     [modo_anterior], AL         ; (restaurado na saida)

; ISRs de teclado e relogio
        MOV     byte [relogio_ativo], 0
        CALL    instala_teclado
        CALL    instala_relogio

; NOVA PARTIDA: tela de selecao de lutadores
nova_partida:
        MOV     byte [relogio_ativo], 0
        MOV     byte [sair_flag], 0
        CALL    tela_selecao
        CMP     byte [sair_flag], 0
        JE      np_ok
        JMP     fim
np_ok:
        CALL    inicia_partida              ; placar 0 x 0

; NOVO ROUND
novo_round:
        MOV     byte [relogio_ativo], 0     ; cronometro parado ate o "LUTEM!"
        CALL    reseta_lutadores
        CALL    zera_cronometro
        MOV     byte [round_acabou], 0
        MOV     byte [ultimo_golpe], 0

        CALL    desenha_cenario             ; arena + HUD
        MOV     SI, jogador1
        CALL    pinta_jogador
        MOV     SI, jogador2
        CALL    pinta_jogador

        CALL    anuncia_round               ; "ROUND n" / "LUTEM!"
        CMP     byte [sair_flag], 0
        JE      nr_ok
        JMP     fim
nr_ok:
        CALL    limpa_eventos
        MOV     AX, [tique_jogo]
        MOV     [ultimo_tique], AX
        MOV     byte [relogio_ativo], 1     ; o tempo do round comeca a correr

; LACO PRINCIPAL DA LUTA
; Roda uma vez a cada tique da INT 8h
loop_jogo:
        MOV     AX, [tique_jogo]
        CMP     AX, [ultimo_tique]
        JNE     lj_tique
        HLT                                 ; espera a proxima interrupcao
        JMP     loop_jogo
lj_tique:
        MOV     [ultimo_tique], AX

        ; 1. Comandos pontuais: P (pausa) e Q/ESC (sair)
        CALL    trata_eventos
        CMP     byte [sair_flag], 0
        JE      lj_controles
        JMP     fim
lj_controles:
        ; Se houve pausa, o tique_jogo avancou durante ela: ressincroniza
        ; para retomar exatamente do mesmo ponto.
        MOV     AX, [tique_jogo]
        MOV     [ultimo_tique], AX

        ; 2. Teclas mantidas pressionadas
        CALL    le_controles

        ; 3. Fisica do pulo
        MOV     SI, jogador1
        MOV     DI, jogador2
        CALL    fisica_jogador
        MOV     SI, jogador2
        MOV     DI, jogador1
        CALL    fisica_jogador

        ; 4. Vira os lutadores um para o outro 
        CALL    atualiza_direcao

        ; 5. Avanca os frames de animacao 
        MOV     SI, jogador1
        CALL    atualiza_animacao
        MOV     SI, jogador2
        CALL    atualiza_animacao

        ; 6. Golpes validos 
        MOV     SI, jogador1                ; J1 atacando J2
        MOV     DI, jogador2
        CALL    verifica_golpe
        MOV     SI, jogador2                ; J2 atacando J1
        MOV     DI, jogador1
        CALL    verifica_golpe

        ; 7. Cronometro na tela 
        CALL    desenha_tempo

        ; 8. Redesenha os lutadores apenas se algo mudou 
        CALL    houve_mudanca               ; AL = 1 se precisa redesenhar
        CMP     AL, 0
        JE      lj_fim_round
        MOV     SI, jogador1                ; apaga os dois na posicao antiga
        CALL    apaga_jogador
        MOV     SI, jogador2
        CALL    apaga_jogador
        MOV     SI, jogador1                ; redesenha os dois na nova
        CALL    pinta_jogador               
        MOV     SI, jogador2                
        CALL    pinta_jogador

        ; 9. Fim do round?
lj_fim_round:
        CALL    verifica_fim_round
        CMP     byte [round_acabou], 0
        JNE     lj_round_acabou
        JMP     loop_jogo

lj_round_acabou:
        MOV     byte [relogio_ativo], 0
        CALL    desenha_rounds              ; marca o round vencido no HUD
        CALL    anuncia_fim_round
        CMP     byte [sair_flag], 0
        JE      lj_proximo
        JMP     fim
lj_proximo:
        CMP     byte [vencedor], 0
        JNE     game_over
        JMP     novo_round

; GAME OVER: Y = nova partida, N = encerra
game_over:
        CALL    tela_game_over              ; AL = 1 (Y) ou 0 (N / Q confirmado)
        CMP     AL, 1
        JNE     fim
        JMP     nova_partida

; fim: restaura vetores e modo de video e devolve o controle ao DOS.
fim:
        MOV     byte [relogio_ativo], 0
        CALL    restaura_relogio            ; vetor original da INT 8h
        CALL    restaura_teclado            ; vetor original da INT 9h

        MOV     AH, 0                       ; modo de video original
        MOV     AL, [modo_anterior]
        INT     10h

        MOV     AX, 4C00h                   ; retorna ao DOS
        INT     21h

segment data public class=DATA

modo_anterior   DB      0           ; modo de video ao iniciar o programa
ultimo_tique    DW      0           ; ultimo tique processado pelo laco

segment stack stack
        resb    2048
stacktop:
