; =============================================================================
; graficos.asm  -  Rotinas graficas do Jogo de Luta (modo 12h, 640x480x16)
; -----------------------------------------------------------------------------
; desenha_jogador : desenha um lutador completo (generica para P1 e P2)
; cursor, caracter, plot_xy, circle, full_circle, line, linha_grossa
; Coordenadas no sistema de plot_xy: Y = 0 embaixo, Y = 479 em cima.
; =============================================================================

global  desenha_jogador
global  cursor
global  caracter
global  plot_xy
global  circle
global  full_circle
global  line
global  linha_grossa

extern  cor                     ; trabalho.asm
extern  deltAX                  ; trabalho.asm
extern  deltay                  ; trabalho.asm
extern  tam_corpo               ; trabalho.asm

segment code public class=CODE

;-----------------------------------------------------------------------------
; desenha_jogador
; Entrada:
;   AL = cor (use preto para APAGAR)
;   AH = indice do frame da animacao (cada frame = 32 bytes em v_idle)
;	BH = estado da animação (0 = idle, 1 = andando, 2 = soco, 3 = chute)
;   BL = espelho: 0 = olha para a direita, 1 = olha para a esquerda
;        (com espelho, os offsets X do frame tem o sinal invertido)
;   CX = X base (centro do tronco)
;   DX = Y base (altura dos ombros)
; Preserva todos os registradores e flags.
;
; Formato de um frame (8 pontos X,Y relativos ao ombro):
;   braco esq: articulacao, mao   | braco dir: articulacao, mao
;   perna esq: joelho, pe         | perna dir: joelho, pe
; Bracos partem do ombro (X, Y); pernas partem do quadril (X, Y - tam_corpo).
;-----------------------------------------------------------------------------
desenha_jogador:
        PUSHF
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI

        MOV     [cor], AL
        MOV     [espelho], BL
        MOV     [base_x], CX
        MOV     [base_y], DX
        
        ; Salva o frame (AH) e o estado (BH) temporariamente
        PUSH    AX
        PUSH    BX

        ; Encontra o endereço base da animação a partir do Estado (BH)
        MOV     AL, BH
        XOR     AH, AH
        SHL     AX, 1                   ; Multiplica estado por 2 (pois cada dw tem 2 bytes)
        MOV     SI, AX
        MOV     BX, [tabela_animacoes + SI] ; BX agora guarda o endereço da animação correta

        ; Calcula o offset do Frame (antigo AH, que foi salvo na pilha)
        POP     DX                      ; Restaura estado em DH, espelho em DL
        POP     AX                      ; Restaura cor em AL, frame em AH
        
        PUSH    AX                      ; Salva AX de novo para não perder a cor
        MOV     AL, AH                  ; Move o frame para AL
        XOR     AH, AH
        MOV     DI, AX
        MOV     CL, 5
        SHL     DI, CL                  ; Multiplica frame por 32
        
        ; Soma o offset do frame com o endereço base da animação
        ADD     DI, BX                  ; Em vez de ADD DI, v_idle
        POP     AX                      ; Restaura AX original (com a cor)

        ; ---- cabeca: circulo cheio de raio 10, centro 10 px acima do ombro
        MOV     AX, [base_x]
        PUSH    AX
        MOV     AX, [base_y]
        ADD     AX, 10
        PUSH    AX
        MOV     AX, 10
        PUSH    AX
        CALL    full_circle

        ; ---- tronco: do ombro ate o quadril
        MOV     AX, [base_x]
        PUSH    AX
        MOV     AX, [base_y]
        PUSH    AX
        MOV     AX, [base_x]
        PUSH    AX
        MOV     AX, [base_y]
        SUB     AX, [tam_corpo]
        PUSH    AX
        CALL    linha_grossa

        ; ---- 4 membros, cada um com 2 segmentos
        MOV     CX, 4
dj_membro:
        MOV     AX, [base_x]            ; origem do membro
        MOV     BX, [base_y]
        CMP     CX, 2
        JA      dj_origem               ; CX = 4, 3 -> bracos (saem do ombro)
        SUB     BX, [tam_corpo]         ; CX = 2, 1 -> pernas (saem do quadril)
dj_origem:
        PUSH    AX                      ; x1 = origem
        PUSH    BX                      ; y1
        CALL    le_ponto                ; AX,BX = articulacao (cotovelo/joelho)
        PUSH    AX                      ; x2
        PUSH    BX                      ; y2
        CALL    linha_grossa            ; origem -> articulacao

        PUSH    AX                      ; x1 = articulacao (linha_grossa preserva AX/BX)
        PUSH    BX                      ; y1
        CALL    le_ponto                ; AX,BX = extremidade (mao/pe)
        PUSH    AX                      ; x2
        PUSH    BX                      ; y2
        CALL    linha_grossa            ; articulacao -> extremidade

        LOOP    dj_membro

        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        POPF
        RET

;-----------------------------------------------------------------------------
; le_ponto (uso interno de desenha_jogador)
; Le um par (offX, offY) em [DI], aplica o espelho e soma a base.
; Saida: AX = X absoluto, BX = Y absoluto, DI avancado 4 bytes.
;-----------------------------------------------------------------------------
le_ponto:
        MOV     AX, [DI]
        CMP     byte [espelho], 0
        JE      lp_sem_espelho
        NEG     AX
lp_sem_espelho:
        ADD     AX, [base_x]
        MOV     BX, [DI+2]
        ADD     BX, [base_y]
        ADD     DI, 4
        RET

;-----------------------------------------------------------------------------
;função cursor
; Parametros:
; 	DH = linha (0-29) e  DL = coluna  (0-79)
cursor:
		PUSHf
		PUSH 	AX
		PUSH 	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		MOV     AH,2
		MOV     BH,0
		INT     10h
		POP		BP
		POP		DI
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POPf
		RET
;-----------------------------------------------------------------------------
;função caracter escrito na posição do cursor
; Parametros:
; 	AL = caracter a ser escrito
; 	cor definida na variavel cor
caracter:
		PUSHf
		PUSH 	AX
		PUSH 	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
    	MOV     AH,9
    	MOV     BH,0
    	MOV     CX,1
   		MOV     bl,[cor]
    	INT     10h
		POP		BP
		POP		DI
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POPf
		RET
;-----------------------------------------------------------------------------
;função plot_xy
; Parametros:
;	PUSH x; PUSH y; CALL plot_xy;  (x<639, y<479)
; 	cor definida na variavel cor
plot_xy:
		PUSH	BP
		MOV		BP,SP
		PUSHf
		PUSH 	AX
		PUSH 	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
	    MOV     AH,0Ch
	    MOV     AL,[cor]
	    MOV     BH,0
	    MOV     DX,479
		SUB		DX,[BP+4]
	    MOV     CX,[BP+6]
	    INT     10h
		POP		DI
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POPf
		POP		BP
		RET		4
;-----------------------------------------------------------------------------
;função circle
; Parametros:
;	PUSH xc; PUSH yc; PUSH r; CALL circle;  (xc+r<639,yc+r<479)e(xc-r>0,yc-r>0)
; 	cor definida na variavel cor
circle:
	PUSH 	BP
	MOV	 	BP,SP
	PUSHf                        	;coloca os flags na pilha
	PUSH 	AX
	PUSH 	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	
	MOV		AX,[BP+8]    			;resgata xc
	MOV		BX,[BP+6]    			;resgata yc
	MOV		CX,[BP+4]    			;resgata r
	
	MOV 	DX,BX	
	ADD		DX,CX       			;ponto extremo superior
	PUSH    AX			
	PUSH	DX
	CALL plot_xy
	
	MOV		DX,BX
	SUB		DX,CX       			;ponto extremo inferior
	PUSH    AX			
	PUSH	DX
	CALL plot_xy
	
	MOV 	DX,AX	
	ADD		DX,CX       			;ponto extremo DIreita
	PUSH    DX			
	PUSH	BX
	CALL plot_xy
	
	MOV		DX,AX
	SUB		DX,CX       			;ponto extremo esquerda
	PUSH    DX			
	PUSH	BX
	CALL plot_xy
		
	MOV		DI,CX
	SUB		DI,1	 				;DI = r-1
	MOV		DX,0  					;DX será a variável x. CX é a variavel y
	
;Aqui em cima a lógica foi invertida, 1-r => r-1 e as comparações passaram a 
; ser JL => JG, assim garante valores positivos para d

stay:								;LOOP
	MOV		SI,DI
	CMP		SI,0
	JG		inf       				;caso d for menor que 0, seleciona pixel superior (não  SALta)
	MOV		SI,DX					;o JL é importante porque trata-se de conta com sinal
	SAL		SI,1					;multiplica por dois (shift arithmetic left)
	ADD		SI,3
	ADD		DI,SI     				;nesse ponto d = d+2*DX+3
	INC		DX						;Incrementa DX
	JMP		plotar
inf:	
	MOV		SI,DX
	SUB		SI,CX  					;faz x - y (DX-CX), e SALva em DI 
	SAL		SI,1
	ADD		SI,5
	ADD		DI,SI					;nesse ponto d = d+2*(DX-CX)+5
	INC		DX						;Incrementa x (DX)
	DEC		CX						;Decrementa y (CX)
	
plotar:	
	MOV		SI,DX
	ADD		SI,AX
	PUSH    SI						;coloca a abcisa x+xc na pilha
	MOV		SI,CX
	ADD		SI,BX
	PUSH    SI						;coloca a ordenada y+yc na pilha
	CALL plot_xy					;toma conta do segundo octante
	MOV		SI,AX
	ADD		SI,DX
	PUSH    SI						;coloca a abcisa xc+x na pilha
	MOV		SI,BX
	SUB		SI,CX
	PUSH    SI						;coloca a ordenada yc-y na pilha
	CALL plot_xy					;toma conta do s�timo octante
	MOV		SI,AX
	ADD		SI,CX
	PUSH    SI						;coloca a abcisa xc+y na pilha
	MOV		SI,BX
	ADD		SI,DX
	PUSH    SI						;coloca a ordenada yc+x na pilha
	CALL plot_xy					;toma conta do segundo octante
	MOV		SI,AX
	ADD		SI,CX
	PUSH    SI						;coloca a abcisa xc+y na pilha
	MOV		SI,BX
	SUB		SI,DX
	PUSH    SI						;coloca a ordenada yc-x na pilha
	CALL plot_xy					;toma conta do oitavo octante
	MOV		SI,AX
	SUB		SI,DX
	PUSH    SI						;coloca a abcisa xc-x na pilha
	MOV		SI,BX
	ADD		SI,CX
	PUSH    SI						;coloca a ordenada yc+y na pilha
	CALL plot_xy					;toma conta do terceiro octante
	MOV		SI,AX
	SUB		SI,DX
	PUSH    SI						;coloca a abcisa xc-x na pilha
	MOV		SI,BX
	SUB		SI,CX
	PUSH    SI						;coloca a ordenada yc-y na pilha
	CALL plot_xy					;toma conta do sexto octante
	MOV		SI,AX
	SUB		SI,CX
	PUSH    SI						;coloca a abcisa xc-y na pilha
	MOV		SI,BX
	SUB		SI,DX
	PUSH    SI						;coloca a ordenada yc-x na pilha
	CALL plot_xy					;toma conta do quINTo octante
	MOV		SI,AX
	SUB		SI,CX
	PUSH    SI						;coloca a abcisa xc-y na pilha
	MOV		SI,BX
	ADD		SI,DX
	PUSH    SI						;coloca a ordenada yc-x na pilha
	CALL plot_xy					;toma conta do quarto octante
	
	CMP		CX,DX
	JB		fim_circle  			;se CX (y) está abaixo de DX (x), termina     
	JMP		stay					;se CX (y) está acima de DX (x), continua no LOOP
	
fim_circle:
	POP		DI
	POP		SI
	POP		DX
	POP		CX
	POP		BX
	POP		AX
	POPf
	POP		BP
	RET		6
;-----------------------------------------------------------------------------
;função full_circle
; Parametros:
;	PUSH xc; PUSH yc; PUSH r; CALL full_circle;  (xc+r<639,yc+r<479)e(xc-r>0,yc-r>0)
; 	cor definida na variavel cor					  
full_circle:
	PUSH 	BP
	MOV	 	BP,SP
	PUSHf                        ;coloca os flags na pilha
	PUSH 	AX
	PUSH 	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI

	MOV		AX,[BP+8]    		;resgata xc
	MOV		BX,[BP+6]    		;resgata yc
	MOV		CX,[BP+4]    		;resgata r
	
	MOV		SI,BX
	SUB		SI,CX
	PUSH    AX					;coloca xc na pilha			
	PUSH	SI					;coloca yc-r na pilha
	MOV		SI,BX
	ADD		SI,CX
	PUSH	AX					;coloca xc na pilha
	PUSH	SI					;coloca yc+r na pilha
	CALL line
		
	MOV		DI,CX
	SUB		DI,1	 			;DI = r-1
	MOV		DX,0  				;DX será a variável x. CX é a variavel y
	
;aqui em cima a lógica foi invertida, 1-r => r-1 e as comparações passaram a ser
;JL => JG, assimm garante valores positivos para d

stay_full:						;LOOP
	MOV		SI,DI
	CMP		SI,0
	JG		inf_full       		;caso d for menor que 0, seleciona pixel superior (não  salta)
	MOV		SI,DX				;o JL é importante porque trata-se de conta com sinal
	SAL		SI,1				;multiplica por doi (shift arithmetic left)
	ADD		SI,3
	ADD		DI,SI     			;nesse ponto d = d+2*DX+3
	INC		DX					;Incrementa DX
	JMP		plotar_full
inf_full:	
	MOV		SI,DX
	SUB		SI,CX  				;faz x - y (DX-CX), e salva em DI 
	SAL		SI,1
	ADD		SI,5
	ADD		DI,SI				;nesse ponto d=d+2*(DX-CX)+5
	INC		DX					;Incrementa x (DX)
	DEC		CX					;Decrementa y (CX)
	
plotar_full:	
	MOV		SI,AX
	ADD		SI,CX
	PUSH	SI					;coloca a abcisa y+xc na pilha			
	MOV		SI,BX
	SUB		SI,DX
	PUSH    SI					;coloca a ordenada yc-x na pilha
	MOV		SI,AX
	ADD		SI,CX
	PUSH	SI					;coloca a abcisa y+xc na pilha	
	MOV		SI,BX
	ADD		SI,DX
	PUSH    SI					;coloca a ordenada yc+x na pilha	
	CALL 	line
	
	MOV		SI,AX
	ADD		SI,DX
	PUSH	SI					;coloca a abcisa xc+x na pilha			
	MOV		SI,BX
	SUB		SI,CX
	PUSH    SI					;coloca a ordenada yc-y na pilha
	MOV		SI,AX
	ADD		SI,DX
	PUSH	SI					;coloca a abcisa xc+x na pilha	
	MOV		SI,BX
	ADD		SI,CX
	PUSH    SI					;coloca a ordenada yc+y na pilha	
	CALL	line
	
	MOV		SI,AX
	SUB		SI,DX
	PUSH	SI					;coloca a abcisa xc-x na pilha			
	MOV		SI,BX
	SUB		SI,CX
	PUSH    SI					;coloca a ordenada yc-y na pilha
	MOV		SI,AX
	SUB		SI,DX
	PUSH	SI					;coloca a abcisa xc-x na pilha	
	MOV		SI,BX
	ADD		SI,CX
	PUSH    SI					;coloca a ordenada yc+y na pilha	
	CALL	line
	
	MOV		SI,AX
	SUB		SI,CX
	PUSH	SI					;coloca a abcisa xc-y na pilha			
	MOV		SI,BX
	SUB		SI,DX
	PUSH    SI					;coloca a ordenada yc-x na pilha
	MOV		SI,AX
	SUB		SI,CX
	PUSH	SI					;coloca a abcisa xc-y na pilha	
	MOV		SI,BX
	ADD		SI,DX
	PUSH    SI					;coloca a ordenada yc+x na pilha	
	CALL	line
	
	CMP		CX,DX
	JB		fim_full_circle  	;se CX (y) está abaixo de DX (x), termina     
	JMP		stay_full			;se CX (y) está acima de DX (x), continua no LOOP
	
fim_full_circle:
	POP		DI
	POP		SI
	POP		DX
	POP		CX
	POP		BX
	POP		AX
	POPf
	POP		BP
	RET		6

;-----------------------------------------------------------------------------
;função linha
; Parâmetros:
;	PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL line;  (x<639, y<479)
; Função linha_grossa
; Parâmetros:
;   PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL linha_grossa;
linha_grossa:
        PUSH    BP
        MOV     BP,SP
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX

        ; Resgata as coordenadas originais passadas para linha_grossa
        MOV     AX,[BP+10]      ; AX = x1
        MOV     BX,[BP+8]       ; BX = y1
        MOV     CX,[BP+6]       ; CX = x2
        MOV     DX,[BP+4]       ; DX = y2

        ; ----------------------------------------------------
        ; 1º Traço: A linha central (coordenadas originais)
        ; ----------------------------------------------------
        PUSH    AX              ; x1
        PUSH    BX              ; y1
        PUSH    CX              ; x2
        PUSH    DX              ; y2
        CALL    line            ; A função line consome esses 4 PUSHes

        ; ----------------------------------------------------
        ; 2º Traço: Linha deslocada 1 pixel para a direita (+1 no X)
        ; ----------------------------------------------------
        INC     AX              ; x1 + 1
        INC     CX              ; x2 + 1
        
        PUSH    AX              ; x1 + 1
        PUSH    BX              ; y1 (mantido)
        PUSH    CX              ; x2 + 1
        PUSH    DX              ; y2 (mantido)
        CALL    line            ; Consome os PUSHes

        ; ----------------------------------------------------
        ; 3º Traço: Linha deslocada 1 pixel para a esquerda (-1 do original)
        ; ----------------------------------------------------
        SUB     AX, 2           ; (x1 + 1) - 2 = x1 - 1
        SUB     CX, 2           ; (x2 + 1) - 2 = x2 - 1
        
        PUSH    AX              ; x1 - 1
        PUSH    BX              ; y1 (mantido)
        PUSH    CX              ; x2 - 1
        PUSH    DX              ; y2 (mantido)
        CALL    line            ; Consome os PUSHes

        ; Restaura os registradores originais da função chamadora
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        POP     BP
        RET     8               ; Limpa os 8 bytes empilhados ao chamar linha_grossa

;-----------------------------------------------------------------------------
;função line
; Parametros:
;	PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL line;  (x<639, y<479)
line:
		PUSH	BP
		MOV		BP,SP
		PUSHf             		;coloca os flags na pilha
		PUSH 	AX
		PUSH 	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		MOV		AX,[BP+10]   	;resgata os vALores das coordenadas
		MOV		BX,[BP+8]    	;resgata os vALores das coordenadas
		MOV		CX,[BP+6]    	;resgata os vALores das coordenadas
		MOV		DX,[BP+4]    	;resgata os vALores das coordenadas
		CMP		AX,CX
		JE		line2
		JB		line1
		XCHG	AX,CX
		XCHG	BX,DX
		JMP		line1
line2:							;deltax = 0
		CMP		BX,DX  			;Subtrai DX de BX
		JB		line3
		XCHG	BX,DX        	;troca os valores de BX e DX entre eles
line3:							;DX > BX
		PUSH	AX
		PUSH	BX
		CALL 	plot_xy
		CMP		BX,DX
		JNE		line31
		JMP		fim_line
line31:	INC		BX
		JMP		line3
;deltAX <>0
line1:
;Comparar módulos de deltax e deltay sabendo que CX>AX
	; CX > AX
		PUSH	CX
		SUB		CX,AX
		MOV		[deltAX],CX
		POP		CX
		PUSH	DX
		SUB		DX,BX
		JA		line32
		NEG		DX
line32:		
		MOV		[deltay],DX
		POP		DX

		PUSH	AX
		MOV		AX,[deltAX]
		CMP		AX,[deltay]
		POP		AX
		JB		line5
; CX > AX e deltAX>deltay
		PUSH	CX
		SUB		CX,AX
		MOV		[deltAX],CX
		POP		CX
		PUSH	DX
		SUB		DX,BX
		MOV		[deltay],DX
		POP		DX

		MOV		SI,AX
line4:
		PUSH	AX
		PUSH	DX
		PUSH	SI
		SUB		SI,AX	;(x-x1)
		MOV		AX,[deltay]
		IMUL	SI
		MOV		SI,[deltAX]		;arredondar
		SHR		SI,1
;Se numerador (DX)>0 soma se <0 Subtrai
		CMP		DX,0
		JL		ar1
		ADD		AX,SI
		ADC		DX,0
		JMP		arc1
ar1:	SUB		AX,SI
		SBB		DX,0
arc1:
		IDIV	word [deltAX]
		ADD		AX,BX
		POP		SI
		PUSH	SI
		PUSH	AX
		CALL	plot_xy
		POP		DX
		POP		AX
		CMP		SI,CX
		JE		fim_line
		INC		SI
		JMP		line4

line5:	CMP		BX,DX
		JB 		line7
		XCHG	AX,CX
		XCHG	BX,DX
line7:
		PUSH	CX
		SUB		CX,AX
		MOV		[deltAX],CX
		POP		CX
		PUSH	DX
		SUB		DX,BX
		MOV		[deltay],DX
		POP		DX

		MOV		SI,BX
line6:
		PUSH	DX
		PUSH	SI
		PUSH	AX
		SUB		SI,BX	;(y-y1)
		MOV		AX,[deltAX]
		IMUL	SI
		MOV		SI,[deltay]		;arredondar
		SHR		SI,1
;Se numerador (DX)>0 soma se <0 subtrai
		CMP		DX,0
		JL		ar2
		ADD		AX,SI
		ADC		DX,0
		JMP		arc2
ar2:	SUB		AX,SI
		SBB		DX,0
arc2:
		IDIV	word [deltay]
		MOV		DI,AX
		POP		AX
		ADD		DI,AX
		POP		SI
		PUSH	DI
		PUSH	SI
		CALL	plot_xy
		POP		DX
		CMP		SI,DX
		JE		fim_line
		INC		SI
		JMP		line6

fim_line:
		POP		DI
		POP		SI
		POP		DX
		POP		CX
		POP		BX
		POP		AX
		POPf
		POP		BP
		RET		8
; ------------------------------------------------------------------------------------------;

;*****************************************************************************
segment data public class=DATA

base_x          DW      0           ; variaveis de trabalho de desenha_jogador
base_y          DW      0
espelho         DB      0


; Tabela de ponteiros para as animações (cada endereço ocupa 1 word / 2 bytes)
tabela_animacoes:
        dw      v_idle      ; Estado 0
        dw      v_anda      ; Estado 1
        dw      v_soco      ; Estado 2
        dw      v_chute     ; Estado 3

; =============================================================================
; Animação Estacionária (6 Frames)
; Cada frame: 8 pares (X,Y) = 32 bytes.
; =============================================================================
v_idle:
    ; --- Frame 0 ---
    dw -20, -20,   3, -17     ; Braco Esquerdo  (articulacao, mao)
    dw  15, -15,  27,   4     ; Braco Direito
    dw -15, -71, -22, -84     ; Perna Esquerda  (joelho, pe)
    dw  15, -71,  22, -84     ; Perna Direita

    ; --- Frame 1 ---
    dw -20, -22,   3, -19     ; Braco Esquerdo
    dw  15, -15,  27,   4     ; Braco Direito
    dw -15, -71, -22, -84     ; Perna Esquerda
    dw  15, -71,  22, -85     ; Perna Direita (corrigido: joelho em +15)

; =============================================================================
; Animação de Caminhada (10 Frames)
; Cada frame: 8 pares (X,Y) = 32 bytes.
; =============================================================================
v_anda:
    ; --- Frame 0 (Perna Dir frente, Perna Esq esticada atrás) ---
    dw -20, -20,   3, -17     ; Braço Esq (Guarda, posição inicial)
    dw  15, -15,  27,   4     ; Braço Dir 
    dw -15, -64, -24, -84     ; Perna Esq (Atrás, prestes a subir)
    dw  15, -64,  24, -84     ; Perna Dir (Frente, plantada no chão)

    ; --- Frame 1 (Transição) ---
    dw -19, -21,   4, -18     ; Braço Esq (Balanço leve para cima)
    dw  14, -16,  26,   3     ; Braço Dir 
    dw -10, -62, -10, -75     ; Perna Esq (Joelho dobra, pé sai do chão)
    dw  10, -66,  12, -84     ; Perna Dir (Deslizando para trás)

    ; --- Frame 2 (Cruzamento - Perna do ar passa pela perna do chão) ---
    dw -18, -22,   5, -19     ; Braço Esq (Ponto mais alto do balanço)
    dw  13, -17,  25,   2     ; Braço Dir 
    dw  10, -58,   5, -70     ; Perna Esq (No ar, cruzando o centro)
    dw   5, -67,   0, -84     ; Perna Dir (No centro do corpo)

    ; --- Frame 3 (Alcançando a frente) ---
    dw -19, -21,   4, -18     ; Braço Esq (Descendo)
    dw  14, -16,  26,   3     ; Braço Dir 
    dw  18, -62,  15, -75     ; Perna Esq (Descendo à frente)
    dw  -5, -66, -12, -84     ; Perna Dir (Continuando para trás)

    ; --- Frame 4 (Pré-contato) ---
    dw -20, -20,   3, -17     ; Braço Esq (Volta ao centro)
    dw  15, -15,  27,   4     ; Braço Dir 
    dw  17, -63,  22, -80     ; Perna Esq (Calcanhar quase tocando o chão)
    dw -15, -64, -24, -84     ; Perna Dir (Máxima extensão atrás)

    ; --- Frame 5 (Inversão de Passo - Perna Esq frente, Perna Dir atrás) ---
    dw -21, -19,   2, -16     ; Braço Esq (Balanço leve para baixo)
    dw  16, -14,  28,   5     ; Braço Dir 
    dw  15, -64,  24, -84     ; Perna Esq (Frente, plantada no chão)
    dw -15, -64, -24, -84     ; Perna Dir (Atrás, prestes a subir)

    ; --- Frame 6 (Transição 2) ---
    dw -22, -18,   1, -15     ; Braço Esq 
    dw  17, -13,  29,   6     ; Braço Dir 
    dw  10, -66,  12, -84     ; Perna Esq (Deslizando para trás)
    dw -10, -62, -10, -75     ; Perna Dir (Joelho dobra, pé sai do chão)

    ; --- Frame 7 (Cruzamento 2) ---
    dw -23, -17,   0, -14     ; Braço Esq (Ponto mais baixo do balanço)
    dw  18, -12,  30,   7     ; Braço Dir 
    dw   5, -67,   0, -84     ; Perna Esq (No centro do corpo)
    dw  10, -58,   5, -70     ; Perna Dir (No ar, cruzando o centro)

    ; --- Frame 8 (Alcançando a frente 2) ---
    dw -22, -18,   1, -15     ; Braço Esq (Subindo)
    dw  17, -13,  29,   6     ; Braço Dir 
    dw  -5, -66, -12, -84     ; Perna Esq (Continuando para trás)
    dw  18, -62,  15, -75     ; Perna Dir (Descendo à frente)

    ; --- Frame 9 (Pré-contato 2) ---
    dw -21, -19,   2, -16     ; Braço Esq (Quase no centro)
    dw  16, -14,  28,   5     ; Braço Dir 
    dw -15, -64, -24, -84     ; Perna Esq (Máxima extensão atrás)
    dw  17, -63,  22, -80     ; Perna Dir (Calcanhar quase tocando o chão)

; =============================================================================
; Animação de Soco (20 Frames)
; Cada frame: 8 pares (X,Y) = 32 bytes.
; Estrutura:
;   - Frames 0 e 1: Startup ultrarrápido (avanço direto para o golpe)
;   - Frames 2 a 15: SUSTENTAÇÃO TOTAL (14 frames com o braço esticado em X=+52, Y=0)
;   - Frames 16 a 19: Recovery (recolhimento para a guarda)
; =============================================================================
v_soco:
    ; --- Frame 0: Startup 1 (Preparo rápido) ---
    dw -20, -18,  -2, -15     ; Braço Esq (Guarda)
    dw  10, -12,  20, -10     ; Braço Dir (Mão ganha velocidade)
    dw -15, -71, -22, -84     ; Perna Esq 
    dw  15, -71,  22, -84     ; Perna Dir 

    ; --- Frame 1: Startup 2 (Extensão quase completa) ---
    dw -22, -18,  -5, -15     ; Braço Esq 
    dw  18,  -5,  36,  -3     ; Braço Dir 
    dw -18, -71, -25, -84     ; Perna Esq 
    dw  18, -71,  25, -84     ; Perna Dir 

    ; --- Frames 2 a 5: BRAÇO TOTALMENTE EXTENDIDO (LOCKOUT EM Y=0, X=+52) ---
    ; Frame 2
    dw -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -71, -30, -84,   22, -71,  30, -84
    ; Frame 3
    dw -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -71, -30, -84,   22, -71,  30, -84
    ; Frame 4
    dw -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -71, -30, -84,   22, -71,  30, -84
    ; Frame 5
    dw -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -71, -30, -84,   22, -71,  30, -84

    ; --- Frame 6: Recovery 1 (Início do recolhimento) ---
    dw -20, -18,  -2, -15     ; Braço Esq
    dw  20,  -6,  38,  -4     ; Braço Dir (Puxando de volta)
    dw -20, -71, -27, -84     ; Perna Esq 
    dw  20, -71,  27, -84     ; Perna Dir 

    ; --- Frame 7: Recovery 2 ---
    dw -20, -19,   0, -16     ; Braço Esq
    dw  14, -10,  26,  -8     ; Braço Dir
    dw -18, -71, -25, -84     ; Perna Esq
    dw  18, -71,  25, -84     ; Perna Dir

    ; --- Frame 8: Recovery 3 ---
    dw -20, -20,   3, -17     ; Braço Esq
    dw  10, -14,  18, -12     ; Braço Dir
    dw -16, -71, -23, -84     ; Perna Esq
    dw  16, -71,  23, -84     ; Perna Dir

    ; --- Frame 9: Retorno final à guarda ---
    dw -20, -20,   3, -17     ; Braço Esq
    dw  12, -15,  24,  -2     ; Braço Dir (Volta ao idle)
    dw -15, -71, -22, -84     ; Perna Esq
    dw  15, -71,  22, -84     ; Perna Dir

; =============================================================================
; Animação de Chute / Rasteira Baixa (10 Frames)
; Cada frame: 8 pares (X,Y) = 32 bytes.
; Estrutura:
;   - Frames 0 a 2 : Preparação (Início da agachada, mão no chão p/ apoio)
;   - Frames 3 a 6 : PERMANÊNCIA / VARREDURA (4 frames com perna em X=+55, Y=-84)
;   - Frames 7 a 9 : Recuo (Recolhimento da perna e levantada do tronco)
; =============================================================================
v_chute:
    ; --- Frame 0: Startup 1 (Guarda abaixa e joelhos flexionam) ---
    dw -18, -25,  -5, -20     ; Braço Esq
    dw  12, -22,  22, -15     ; Braço Dir
    dw -15, -68, -22, -84     ; Perna Esq (Apoio atrás)
    dw  12, -68,  18, -84     ; Perna Dir (Começa a agachar)

    ; --- Frame 1: Startup 2 (Mão esquerda vai ao chão para apoio) ---
    dw -15, -35, -25, -45     ; Braço Esq (Mão plantada no chão)
    dw  10, -28,  20, -22     ; Braço Dir (Tronco inclina para frente)
    dw -15, -60, -22, -84     ; Perna Esq (Joelho de apoio dobra bastante)
    dw   5, -62,   0, -80     ; Perna Dir (Perna de ataque recolhe p/ impulso)

    ; --- Frame 2: Startup 3 (Projeção da perna rente ao chão) ---
    dw -15, -40, -25, -45     ; Braço Esq (Apoio firme)
    dw  12, -28,  24, -20     ; Braço Dir
    dw -18, -62, -25, -84     ; Perna Esq
    dw  20, -75,  38, -82     ; Perna Dir (Esticando a rasteira em X=+38)

    ; --- Frames 3 a 6: RASTEIRA EXTENDIDA TOTALMENTE (VARREDURA RENDE AO CHÃO) ---
    ; Frame 3 (Active 1)
    dw -15, -40, -25, -45,   15, -25,  28, -20,  -18, -62, -26, -84,   28, -80,  55, -84
    ; Frame 4 (Active 2)
    dw -15, -40, -25, -45,   15, -25,  28, -20,  -18, -62, -26, -84,   28, -80,  55, -84
    ; Frame 5 (Active 3)
    dw -15, -40, -25, -45,   15, -25,  28, -20,  -18, -62, -26, -84,   28, -80,  55, -84
    ; Frame 6 (Active 4)
    dw -15, -40, -25, -45,   15, -25,  28, -20,  -18, -62, -26, -84,   28, -80,  55, -84

    ; --- Frame 7: Recovery 1 (Recolhendo a perna do chute) ---
    dw -15, -38, -25, -45     ; Braço Esq
    dw  12, -26,  22, -20     ; Braço Dir
    dw -16, -65, -24, -84     ; Perna Esq
    dw  18, -70,  32, -84     ; Perna Dir (Pé descola da frente)

    ; --- Frame 8: Recovery 2 (Levantando o tronco) ---
    dw -18, -25,  -5, -20     ; Braço Esq (Mão descola do chão)
    dw  14, -20,  24, -10     ; Braço Dir
    dw -15, -68, -22, -84     ; Perna Esq
    dw  14, -70,  20, -84     ; Perna Dir

    ; --- Frame 9: Recovery 3 (Quase de volta à posição de Idle) ---
    dw -20, -20,   3, -17     ; Braço Esq
    dw  15, -15,  27,   4     ; Braço Dir
    dw -15, -71, -22, -84     ; Perna Esq
    dw  15, -71,  22, -84     ; Perna Dir
