; =============================================================================
; graficos.asm  -  Rotinas graficas do Jogo de Luta (modo 12h, 640x480x16)
; -----------------------------------------------------------------------------
; desenha_jogador : desenha um lutador completo (generica para P1 e P2)
; cursor, caracter, plot_xy, circle, full_circle, line, linha_grossa
; escreve_texto, apaga_texto, limpa_tela
; Coordenadas no sistema de plot_xy: Y = 0 embaixo, Y = 479 em cima.
; A variavel publica "cor" define a cor usada por todas as primitivas.
; =============================================================================

global  desenha_jogador
global  cursor
global  caracter
global  plot_xy
global  circle
global  full_circle
global  line
global  linha_grossa
global  escreve_texto
global  apaga_texto
global  limpa_tela
global  cor

segment code public class=CODE

;-----------------------------------------------------------------------------
; desenha_jogador  (esqueleto dinamico, 40 bytes por frame)
; Entrada:
;   AL = cor (use preto para APAGAR)
;   AH = indice do frame dentro da animacao do estado
;   BH = estado da animacao (0 = parado, 1 = andando, 2 = soco,
;        3 = chute/rasteira, 4 = abaixado); escolhe a tabela em
;        tabela_animacoes
;   BL = espelho: 0 = olha para a direita, 1 = olha para a esquerda
;        (com espelho, os offsets X do frame tem o sinal invertido)
;   CX = X base (centro do tronco)
;   DX = Y base (altura dos ombros)
; Preserva todos os registradores e flags.
;
; Formato de um frame: 10 pares (X,Y) de words = 40 bytes
;   par 0     : ombro, relativo a base (CX, DX)
;   par 1     : quadril, relativo ao ombro
;   pares 2-3 : braco esquerdo  (cotovelo, mao), relativos ao ombro
;   pares 4-5 : braco direito   (cotovelo, mao), relativos ao ombro
;   pares 6-7 : perna esquerda  (joelho, pe),    relativos ao quadril
;   pares 8-9 : perna direita   (joelho, pe),    relativos ao quadril
; A cabeca e um circulo cheio de raio 10, com centro 10 px acima do ombro.
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
        
        PUSH    AX
        PUSH    BX

        ; 1. Encontra a animacao correta
        MOV     AL, BH
        XOR     AH, AH
        SHL     AX, 1
        MOV     SI, AX
        MOV     BX, [tabela_animacoes + SI]

        ; 2. Calcula offset do Frame (AH * 40 bytes = AH*8 + AH*32)
        POP     DX
        POP     AX
        
        PUSH    AX
        MOV     AL, AH
        XOR     AH, AH
        MOV     DI, AX
        SHL     DI, 1                   ; (deslocamentos de 1 bit:
        SHL     DI, 1                   ;  SHL reg,imm > 1 nao existe no 8086)
        SHL     DI, 1                   ; DI = frame * 8
        MOV     CX, DI
        SHL     DI, 1
        SHL     DI, 1                   ; DI = frame * 32
        ADD     DI, CX                  ; DI = frame * 40
        ADD     DI, BX                  ; DI aponta para o frame correto
        POP     AX

        ; 3. Le o par 0: ombro (relativo a base JX, JY)
        CALL    le_ponto_ombro
        MOV     [ombro_x], AX
        MOV     [ombro_y], BX

        ; 4. Le o par 1: quadril (relativo ao ombro)
        CALL    le_ponto_quadril
        MOV     [quadril_x], AX
        MOV     [quadril_y], BX

        ; ---- Cabeca: Raio 10, centro 10px acima do Ombro ----
        MOV     AX, [ombro_x]
        PUSH    AX
        MOV     AX, [ombro_y]
        ADD     AX, 10
        PUSH    AX
        MOV     AX, 10
        PUSH    AX
        CALL    full_circle

        ; ---- Tronco: Linha do Ombro ao Quadril ----
        MOV     AX, [ombro_x]
        PUSH    AX
        MOV     AX, [ombro_y]
        PUSH    AX
        MOV     AX, [quadril_x]
        PUSH    AX
        MOV     AX, [quadril_y]
        PUSH    AX
        CALL    linha_grossa

        ; ---- 4 Membros (2 Bracos saem do Ombro, 2 Pernas saem do Quadril) ----
        MOV     CX, 4
dj_membro:
        CMP     CX, 2
        JA      dj_origem_ombro
        ; Pernas (CX = 2, 1) saem do Quadril
        MOV     AX, [quadril_x]
        MOV     BX, [quadril_y]
        JMP     dj_origem_ok
dj_origem_ombro:
        ; Bracos (CX = 4, 3) saem do Ombro
        MOV     AX, [ombro_x]
        MOV     BX, [ombro_y]
dj_origem_ok:
        MOV     [membro_base_x], AX
        MOV     [membro_base_y], BX

        PUSH    AX                      ; x1 = origem
        PUSH    BX                      ; y1
        CALL    le_ponto_membro         ; AX,BX = articulacao
        PUSH    AX                      ; x2
        PUSH    BX                      ; y2
        CALL    linha_grossa

        PUSH    AX                      ; x1 = articulacao
        PUSH    BX                      ; y1
        CALL    le_ponto_membro         ; AX,BX = extremidade
        PUSH    AX                      ; x2
        PUSH    BX                      ; y2
        CALL    linha_grossa

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
; Auxiliares de desenha_jogador: leem um par (offX, offY) em [DI], aplicam o
; espelho (negam X) e somam a origem correspondente.
; Saida: AX = X absoluto, BX = Y absoluto, DI avancado 4 bytes.
;   le_ponto_ombro   : origem = base (base_x, base_y)
;   le_ponto_quadril : origem = ombro
;   le_ponto_membro  : origem = inicio do membro (ombro ou quadril)
;-----------------------------------------------------------------------------
le_ponto_ombro:
        MOV     AX, [DI]
        CMP     byte [espelho], 0
        JE      lpo_sem
        NEG     AX
lpo_sem:
        ADD     AX, [base_x]
        MOV     BX, [DI+2]
        ADD     BX, [base_y]
        ADD     DI, 4
        RET

le_ponto_quadril:
        MOV     AX, [DI]
        CMP     byte [espelho], 0
        JE      lpq_sem
        NEG     AX
lpq_sem:
        ADD     AX, [ombro_x]
        MOV     BX, [DI+2]
        ADD     BX, [ombro_y]
        ADD     DI, 4
        RET

le_ponto_membro:
        MOV     AX, [DI]
        CMP     byte [espelho], 0
        JE      lpm_sem
        NEG     AX
lpm_sem:
        ADD     AX, [membro_base_x]
        MOV     BX, [DI+2]
        ADD     BX, [membro_base_y]
        ADD     DI, 4
        RET

;-----------------------------------------------------------------------------
;funcao cursor
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
;funcao caracter escrito na posicao do cursor
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
; escreve_texto
; Entrada: DS:SI = texto terminado em 0, DH = linha (0-29), DL = coluna (0-79)
;          cor definida na variavel cor
; Preserva todos os registradores.
;-----------------------------------------------------------------------------
escreve_texto:
        PUSHF
        PUSH    AX
        PUSH    DX
        PUSH    SI
        CLD
et_loop:
        LODSB
        CMP     AL, 0
        JE      et_fim
        CALL    cursor
        CALL    caracter
        INC     DL
        JMP     et_loop
et_fim:
        POP     SI
        POP     DX
        POP     AX
        POPF
        RET

;-----------------------------------------------------------------------------
; apaga_texto
; Entrada: DH = linha, DL = coluna inicial, CX = numero de caracteres.
; Escreve espacos (a BIOS preenche a celula 8x16 com o fundo preto).
; Preserva todos os registradores.
;-----------------------------------------------------------------------------
apaga_texto:
        PUSHF
        PUSH    AX
        PUSH    CX
        PUSH    DX
        JCXZ    at_fim
        MOV     AL, ' '
at_loop:
        CALL    cursor
        CALL    caracter
        INC     DL
        LOOP    at_loop
at_fim:
        POP     DX
        POP     CX
        POP     AX
        POPF
        RET

;-----------------------------------------------------------------------------
; limpa_tela
; Reprograma o modo 12h (VGA 640x480, 16 cores), o que tambem apaga a tela.
; Preserva todos os registradores.
;-----------------------------------------------------------------------------
limpa_tela:
        PUSH    AX
        MOV     AX, 0012h
        INT     10h
        POP     AX
        RET

;-----------------------------------------------------------------------------
;funcao plot_xy
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
;funcao circle
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
	MOV		DX,0  					;DX sera a variavel x. CX e a variavel y
	
;Aqui em cima a logica foi invertida, 1-r => r-1 e as comparacoes passaram a 
; ser JL => JG, assim garante valores positivos para d

stay:								;LOOP
	MOV		SI,DI
	CMP		SI,0
	JG		inf       				;caso d for menor que 0, seleciona pixel superior (nao  SALta)
	MOV		SI,DX					;o JL e importante porque trata-se de conta com sinal
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
	CALL plot_xy					;toma conta do setimo octante
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
	JB		fim_circle  			;se CX (y) esta abaixo de DX (x), termina     
	JMP		stay					;se CX (y) esta acima de DX (x), continua no LOOP
	
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
;funcao full_circle
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
	MOV		DX,0  				;DX sera a variavel x. CX e a variavel y
	
;aqui em cima a logica foi invertida, 1-r => r-1 e as comparacoes passaram a ser
;JL => JG, assimm garante valores positivos para d

stay_full:						;LOOP
	MOV		SI,DI
	CMP		SI,0
	JG		inf_full       		;caso d for menor que 0, seleciona pixel superior (nao  salta)
	MOV		SI,DX				;o JL e importante porque trata-se de conta com sinal
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
	JB		fim_full_circle  	;se CX (y) esta abaixo de DX (x), termina     
	JMP		stay_full			;se CX (y) esta acima de DX (x), continua no LOOP
	
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
;funcao linha
; Parametros:
;	PUSH x1; PUSH y1; PUSH x2; PUSH y2; CALL line;  (x<639, y<479)
; Funcao linha_grossa
; Parametros:
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
        ; 1o Traco: A linha central (coordenadas originais)
        ; ----------------------------------------------------
        PUSH    AX              ; x1
        PUSH    BX              ; y1
        PUSH    CX              ; x2
        PUSH    DX              ; y2
        CALL    line            ; A funcao line consome esses 4 PUSHes

        ; ----------------------------------------------------
        ; 2o Traco: Linha deslocada 1 pixel para a direita (+1 no X)
        ; ----------------------------------------------------
        INC     AX              ; x1 + 1
        INC     CX              ; x2 + 1
        
        PUSH    AX              ; x1 + 1
        PUSH    BX              ; y1 (mantido)
        PUSH    CX              ; x2 + 1
        PUSH    DX              ; y2 (mantido)
        CALL    line            ; Consome os PUSHes

        ; ----------------------------------------------------
        ; 3o Traco: Linha deslocada 1 pixel para a esquerda (-1 do original)
        ; ----------------------------------------------------
        SUB     AX, 2           ; (x1 + 1) - 2 = x1 - 1
        SUB     CX, 2           ; (x2 + 1) - 2 = x2 - 1
        
        PUSH    AX              ; x1 - 1
        PUSH    BX              ; y1 (mantido)
        PUSH    CX              ; x2 - 1
        PUSH    DX              ; y2 (mantido)
        CALL    line            ; Consome os PUSHes

        ; Restaura os registradores originais da funcao chamadora
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        POP     BP
        RET     8               ; Limpa os 8 bytes empilhados ao chamar linha_grossa

;-----------------------------------------------------------------------------
;funcao line
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
;Comparar modulos de deltax e deltay sabendo que CX>AX
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

cor             DB      15          ; cor corrente das primitivas (branco intenso)
deltAX          DW      0           ; variaveis de trabalho da rotina line
deltay          DW      0

base_x          DW      0           ; variaveis de trabalho de desenha_jogador
base_y          DW      0
ombro_x         DW      0
ombro_y         DW      0
quadril_x       DW      0
quadril_y       DW      0
membro_base_x   DW      0
membro_base_y   DW      0
espelho         DB      0


; Tabela de ponteiros para as animacoes (cada endereco ocupa 1 word / 2 bytes)
tabela_animacoes:
        dw      v_idle      ; Estado 0
        dw      v_anda      ; Estado 1
        dw      v_soco      ; Estado 2
        dw      v_chute     ; Estado 3
        dw      v_abaixa    ; Estado 4

; =============================================================================
; Animacao parada (estado 0) - 2 frames definidos
; Cada frame: 10 pares (X,Y) = 40 bytes (formato em desenha_jogador).
; Obs.: limite_frames (jogador.asm) usa so o frame 0; o frame 1 ("respirando")
; esta pronto, mas nao e exibido.
; =============================================================================
v_idle:
    ; --- Frame 0 ---
    dw   0,   0,   0, -46     ; Ombro na base, Quadril 46px abaixo (reto)
    dw -20, -20,   3, -17     ; Braco Esq
    dw  15, -15,  27,   4     ; Braco Dir
    dw -15, -25, -22, -38     ; Perna Esq (relativa ao quadril)
    dw  15, -25,  22, -38     ; Perna Dir (relativa ao quadril)

    ; --- Frame 1 ---
    dw   0,  -1,   0, -45     ; Ombro e quadril afundam 1px (respirando)
    dw -20, -22,   3, -19
    dw  15, -15,  27,   4
    dw -15, -24, -22, -37
    dw  15, -24,  22, -38

; =============================================================================
; Animacao de caminhada (estado 1) - 10 frames, ciclica
; =============================================================================
v_anda:
    ; --- Frame 0 (Perna Dir frente, Perna Esq esticada atras) ---
    dw   0,   0,   0, -46     ; Ombro na base, Quadril 46px abaixo
    dw -20, -20,   3, -17     ; Braco Esq 
    dw  15, -15,  27,   4     ; Braco Dir 
    dw -15, -18, -24, -38     ; Perna Esq
    dw  15, -18,  24, -38     ; Perna Dir

    ; --- Frame 1 (Transicao) ---
    dw   0,   0,   0, -46
    dw -19, -21,   4, -18
    dw  14, -16,  26,   3
    dw -10, -16, -10, -29
    dw  10, -20,  12, -38

    ; --- Frame 2 (Cruzamento - Perna do ar passa pela perna do chao) ---
    dw   0,   0,   0, -46
    dw -18, -22,   5, -19
    dw  13, -17,  25,   2
    dw  10, -12,   5, -24
    dw   5, -21,   0, -38

    ; --- Frame 3 (Alcancando a frente) ---
    dw   0,   0,   0, -46
    dw -19, -21,   4, -18
    dw  14, -16,  26,   3
    dw  18, -16,  15, -29
    dw  -5, -20, -12, -38

    ; --- Frame 4 (Pre-contato) ---
    dw   0,   0,   0, -46
    dw -20, -20,   3, -17
    dw  15, -15,  27,   4
    dw  17, -17,  22, -34
    dw -15, -18, -24, -38

    ; --- Frame 5 (Inversao de Passo - Perna Esq frente, Perna Dir atras) ---
    dw   0,   0,   0, -46
    dw -21, -19,   2, -16
    dw  16, -14,  28,   5
    dw  15, -18,  24, -38
    dw -15, -18, -24, -38

    ; --- Frame 6 (Transicao 2) ---
    dw   0,   0,   0, -46
    dw -22, -18,   1, -15
    dw  17, -13,  29,   6
    dw  10, -20,  12, -38
    dw -10, -16, -10, -29

    ; --- Frame 7 (Cruzamento 2) ---
    dw   0,   0,   0, -46
    dw -23, -17,   0, -14
    dw  18, -12,  30,   7
    dw   5, -21,   0, -38
    dw  10, -12,   5, -24

    ; --- Frame 8 (Alcancando a frente 2) ---
    dw   0,   0,   0, -46
    dw -22, -18,   1, -15
    dw  17, -13,  29,   6
    dw  -5, -20, -12, -38
    dw  18, -16,  15, -29

    ; --- Frame 9 (Pre-contato 2) ---
    dw   0,   0,   0, -46
    dw -21, -19,   2, -16
    dw  16, -14,  28,   5
    dw -15, -18, -24, -38
    dw  17, -17,  22, -34

; =============================================================================
; Animacao de soco (estado 2) - 10 frames
; O dano e verificado no frame 2 (FRAME_IMPACTO_SOCO em const.inc), primeiro
; frame do braco totalmente estendido (mao em X = +52).
; =============================================================================
v_soco:
    ; --- Frame 0: Startup 1 ---
    dw   0,   0,   0, -46
    dw -20, -18,  -2, -15
    dw  10, -12,  20, -10
    dw -15, -25, -22, -38
    dw  15, -25,  22, -38

    ; --- Frame 1: Startup 2 ---
    dw   0,   0,   0, -46
    dw -22, -18,  -5, -15
    dw  18,  -5,  36,  -3
    dw -18, -25, -25, -38
    dw  18, -25,  25, -38

    ; --- Frames 2 a 5: LOCKOUT TOTAL (X=+52, Y=0) ---
    ; Frame 2
    dw   0,   0,   0, -46,  -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -25, -30, -38,   22, -25,  30, -38
    ; Frame 3
    dw   0,   0,   0, -46,  -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -25, -30, -38,   22, -25,  30, -38
    ; Frame 4
    dw   0,   0,   0, -46,  -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -25, -30, -38,   22, -25,  30, -38
    ; Frame 5
    dw   0,   0,   0, -46,  -20, -18,  -2, -15,   26,   0,  52,   0,  -22, -25, -30, -38,   22, -25,  30, -38

    ; --- Frame 6: Recovery 1 ---
    dw   0,   0,   0, -46
    dw -20, -18,  -2, -15
    dw  20,  -6,  38,  -4
    dw -20, -25, -27, -38
    dw  20, -25,  27, -38

    ; --- Frame 7: Recovery 2 ---
    dw   0,   0,   0, -46
    dw -20, -19,   0, -16
    dw  14, -10,  26,  -8
    dw -18, -25, -25, -38
    dw  18, -25,  25, -38

    ; --- Frame 8: Recovery 3 ---
    dw   0,   0,   0, -46
    dw -20, -20,   3, -17
    dw  10, -14,  18, -12
    dw -16, -25, -23, -38
    dw  16, -25,  23, -38

    ; --- Frame 9: Retorno a guarda ---
    dw   0,   0,   0, -46
    dw -20, -20,   3, -17
    dw  12, -15,  24,  -2
    dw -15, -25, -22, -38
    dw  15, -25,  22, -38

; =============================================================================
; Animacao de chute (estado 3): rasteira baixa - 10 frames
; O ponto mais baixo fica em Y = 74, para nao apagar o chao da arena (Y = 70).
; O dano e verificado no frame 3 (FRAME_IMPACTO_CHUTE em const.inc), primeiro
; frame da perna totalmente estendida (pe em X = +58). Por ser rasteira, a
; defesa contra o chute e pular.
; =============================================================================
v_chute:
    ; --- Frame 0: Startup 1 (Corpo desce levemente) ---
    dw   0, -12,   0, -42     ; Ombro em -12px
    dw -18, -15,  -5, -10     ; Braco Esq
    dw  12, -12,  22,  -5     ; Braco Dir
    dw -15, -18, -22, -34     ; Perna Esq
    dw  12, -18,  18, -34     ; Perna Dir

    ; --- Frame 1: Startup 2 (Queda rapida, mao busca o chao) ---
    dw   0, -30,  -5, -25     ; Ombro em -30px
    dw -15, -18, -22, -28     ; Braco Esq
    dw  10, -10,  20,  -5     ; Braco Dir
    dw -15, -12, -22, -24     ; Perna Esq
    dw   8, -10,  15, -18     ; Perna Dir

    ; --- Frame 2: Startup 3 (Prestes a atingir a rasteira) ---
    dw   0, -45,  -8, -16     ; Ombro em -45px
    dw -12, -16, -22, -30     ; Braco Esq
    dw   8, -10,  18, -14     ; Braco Dir
    dw -16, -10,  -8, -17     ; Perna Esq
    dw  20,  -6,  42, -13     ; Perna Dir

    ; --- Frames 3 a 6: PERMANENCIA (POSTURA AJUSTADA - MARGEM DE 4PX DO CHAO) ---
    ; Frame 3 (Active 1)
    dw 0,-50, -10,-14,  -12,-14,-22,-30,  8,-10,18,-16,  -18,-12,-6,-18,  28,-8,58,-17
    ; Frame 4 (Active 2)
    dw 0,-50, -10,-14,  -12,-14,-22,-30,  8,-10,18,-16,  -18,-12,-6,-18,  28,-8,58,-17
    ; Frame 5 (Active 3)
    dw 0,-50, -10,-14,  -12,-14,-22,-30,  8,-10,18,-16,  -18,-12,-6,-18,  28,-8,58,-17
    ; Frame 6 (Active 4)
    dw 0,-50, -10,-14,  -12,-14,-22,-30,  8,-10,18,-16,  -18,-12,-6,-18,  28,-8,58,-17

    ; --- Frame 7: Recovery 1 (Perna recolhe, tronco comeca a subir) ---
    dw   0, -35,  -8, -22     ; Ombro sobe para -35px
    dw -12, -15, -22, -25     ; Mao descola do chao
    dw  10, -10,  20,  -8     ; Braco Dir
    dw -16, -12, -18, -25     ; Perna Esq
    dw  20, -12,  35, -23     ; Perna Dir

    ; --- Frame 8: Recovery 2 (Subindo o corpo) ---
    dw   0, -18,  -4, -34     ; Ombro em -18px
    dw -16, -15,  -5, -10
    dw  12, -12,  22,  -5
    dw -15, -18, -22, -32
    dw  14, -18,  20, -32

    ; --- Frame 9: Recovery 3 (Retorno ao Idle) ---
    dw   0,   0,   0, -46     ; Ombro e quadril na posicao padrao
    dw -20, -20,   3, -17     ; Braco Esq
    dw  15, -15,  27,   4     ; Braco Dir
    dw -15, -25, -22, -38     ; Perna Esq
    dw  15, -25,  22, -38     ; Perna Dir

; =============================================================================
; Animacao abaixando (estado 4) - 3 frames de descida; enquanto a tecla de
; abaixar estiver pressionada, fica travada no frame 2.
; Pes sempre fixos em Y = 72 (-84 px da base Y_CHAO = 156).
; Abaixado, o lutador nao e atingido por socos.
; =============================================================================
v_abaixa:
    ; --- Frame 0: Inicio da descida (Ombro -12px, Joelhos comecam a dobrar) ---
    dw   0, -12,   0, -40     ; Ombro -12px (Y=144), Quadril -40px (Y=104)
    dw -18, -18,   3, -14     ; Braco Esq
    dw  14, -14,  25,   4     ; Braco Dir
    dw -16, -18, -21, -32     ; Perna Esq (pe em 104-32 = 72)
    dw  16, -18,  21, -32     ; Perna Dir (pe em 104-32 = 72)

    ; --- Frame 1: Meio da descida (Ombro -24px, Guarda fechando) ---
    dw   0, -24,   0, -35     ; Ombro -24px (Y=132), Quadril -35px (Y=97)
    dw -17, -16,   4, -11     ; Braco Esq
    dw  13, -13,  23,   4     ; Braco Dir
    dw -17, -12, -20, -25     ; Perna Esq (pe em 97-25 = 72)
    dw  17, -12,  20, -25     ; Perna Dir (pe em 97-25 = 72)

    ; --- Frame 2: Totalmente abaixado (Ombro -36px, permanece aqui) ---
    dw   0, -36,   0, -30     ; Ombro -36px (Y=120), Quadril -30px (Y=90)
    dw -16, -14,   4,  -8     ; Braco Esq (em guarda baixa)
    dw  12, -12,  22,   4     ; Braco Dir (protegendo o rosto)
    dw -18,  -6, -20, -18     ; Perna Esq (joelho dobrado, pe em 90-18 = 72)
    dw  18,  -6,  20, -18     ; Perna Dir (joelho dobrado, pe em 90-18 = 72)


