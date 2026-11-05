; teclado.asm  -  Tratamento do teclado pela interrupcao de hardware INT 9h

; Hardware
KB_DATA         EQU     60h         ; porta de dados do teclado (8042)
KB_CTL          EQU     61h         ; porta de controle do teclado (8255 PB)
PICTRL          EQU     20h         ; porta de comando do PIC 8259
EOI             EQU     20h         ; comando End Of Interrupt
INT_TEC         EQU     09h         ; interrupcao de hardware do teclado (IRQ1)

global  instala_teclado
global  restaura_teclado
global  le_evento
global  espera_evento
global  limpa_eventos
global  teclas

TAM_BUFFER      EQU     16          ; potencia de 2 (indice mascarado)
MASCARA_BUFFER  EQU     TAM_BUFFER - 1

segment code public class=CODE

; instala_teclado
instala_teclado:
        PUSH    AX
        PUSH    ES
        CLI                            
        XOR     AX, AX
        MOV     ES, AX                   
        MOV     AX, [ES:INT_TEC*4]       
        MOV     [offset_tec], AX
        MOV     AX, [ES:INT_TEC*4+2]    
        MOV     [cs_tec], AX
        MOV     [ES:INT_TEC*4+2], CS    
        MOV     WORD [ES:INT_TEC*4], keyINT
        STI
        POP     ES
        POP     AX
        RET

; restaura_teclado: devolve o vetor original da INT 9h (retorno seguro ao DOS).
restaura_teclado:
        PUSH    AX
        PUSH    ES
        CLI
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [cs_tec]
        MOV     [ES:INT_TEC*4+2], AX
        MOV     AX, [offset_tec]
        MOV     [ES:INT_TEC*4], AX
        STI
        POP     ES
        POP     AX
        RET

; le_evento
; Saida: CF = 0 e AL = scan code MAKE da proxima tecla pressionada, ou
;        CF = 1 se a fila nao tiver nenhum codigo MAKE pendente.
le_evento:
        PUSH    BX
le_prox:
        MOV     BX, [p_t]
        CMP     BX, [p_i]
        JE      le_vazio                    ; fila vazia
        INC     BX
        AND     BX, MASCARA_BUFFER
        MOV     [p_t], BX
        MOV     AL, [buffer+BX]
        TEST    AL, 80h
        JNZ     le_prox                     ; BREAK: ignora e tenta o proximo
        CLC
        POP     BX
        RET
le_vazio:
        STC
        POP     BX
        RET

; espera_evento
; Saida: AL = scan code MAKE. Enquanto a fila estiver vazia o processador
espera_evento:
        CALL    le_evento
        JNC     ee_fim
        HLT
        JMP     espera_evento
ee_fim:
        RET

; limpa_eventos: descarta os codigos pendentes (usado ao trocar de tela).
limpa_eventos:
        PUSH    AX
        CLI
        MOV     AX, [p_i]
        MOV     [p_t], AX
        STI
        POP     AX
        RET

; keyINT  -  ISR do teclado (INT 9h)
keyINT:
        PUSH    AX
        PUSH    BX
        PUSH    DS
        MOV     AX, data                    ; garante DS correto dentro da ISR
        MOV     DS, AX

        IN      AL, KB_DATA                 ; le o codigo make/break (porta 60h)
        CMP     AL, 0E0h                    ; prefixo de tecla estendida
        JE      ki_ack
        CMP     AL, 0E1h                    ; prefixo da tecla Pause
        JE      ki_ack

        ; grava na fila circular
        MOV     BX, [p_i]
        INC     BX
        AND     BX, MASCARA_BUFFER
        CMP     BX, [p_t]           
        JE      ki_estado                  
        MOV     [p_i], BX
        MOV     [buffer+BX], AL

ki_estado:
        ; atualiza a tabela de estado (movimento)
        MOV     BL, AL
        AND     BX, 007Fh                   ; BX = codigo sem o bit 7 (e BH = 0)
        TEST    AL, 80h                     ; bit 7 = 1 -> break (soltou)
        JNZ     ki_solta
        MOV     byte [teclas+BX], 1
        JMP     ki_ack
ki_solta:
        MOV     byte [teclas+BX], 0

ki_ack:
        IN      AL, KB_CTL                  ; reconhece o dado (pulso no bit 7
        OR      AL, 80h                     ;  da porta 61h, como no Tecbuf)
        OUT     KB_CTL, AL
        AND     AL, 7Fh
        OUT     KB_CTL, AL
        MOV     AL, EOI                     ; fim de interrupcao para o PIC
        OUT     PICTRL, AL

        POP     DS
        POP     BX
        POP     AX
        IRET

; =============================================================================
segment data public class=DATA

cs_tec          DW      0                   ; CS original da INT 9h
offset_tec      DW      0                   ; IP original da INT 9h
buffer          TIMES TAM_BUFFER DB 0       ; fila circular de scan codes
p_i             DW      0                   ; indice de escrita (ISR)
p_t             DW      0                   ; indice de leitura (programa)
teclas          TIMES 128 DB 0              ; tabela de estado: 1 = pressionada
