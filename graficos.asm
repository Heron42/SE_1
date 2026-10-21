segment code

global idle
global perso1
global linha_grossa
global line
global full_circle
global circle

idle:
		push ax
		push BX
		push CX
		push dx

		mov al, [p1_cor]
		mov byte[cor], al

		MOV     AX, [p1_pos_x]
        MOV     BX, [p1_pos_y]

		;CMP byte[p1_frame], 0
		;JE idle0
		;cmp byte[p1_frame], 1
		;je idle1
		;cmp byte[p1_frame], 2
		;je idle2
		;cmp byte[p1_frame], 3
		;je idle3
		;cmp byte[p1_frame], 4
		;je idle4
	idle0:
	;braço esquerdo
		mov cx, ax
		sub cx, 20
		push cx
		mov dx, BX
		sub dx, 20
		push dx

		add cx, 23
		push cx
		add dx, 3
		push dx
	;braço direito
		mov cx, ax
		add cx, 15
		push cx
		mov dx, BX
		sub dx, 15
		push dx

		add cx, 12
		push cx
		add dx, 19
		push dx
	;perna esquerda
		sub bx, [p1_tam_corpo]

		mov cx, ax
		sub cx, 15
		push cx
		mov dx, BX
		sub dx, 21
		push dx

		sub cx, 7
		push cx
		sub dx, 13
		push dx
	;perna direita
		mov cx, ax
		add cx, 15
		push cx
		mov dx, BX
		sub dx, 21
		push dx

		add cx, 7
		push cx
		sub dx, 13
		push dx

		CALL perso1

		pop dx
		pop cx
		pop BX
		pop ax

		RET
;-----------------------------------------------------------------------------
;função perso1
; Parâmetros:
; push xbe1 (+34), push ybe1, push xbe2, push ybe2, push xbd1, push ybd1, push xbd2, push ybd2
; push xpe1, push ype1, push xpe2, push ype2, push xpd1, push ypd1 (+8), push xpd2 (+6), push ypd2 (+4)
; RET 8
; altura do personagem = 160 parece ideal
perso1:
		PUSH 	BP
		MOV 	BP, SP
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX

        MOV     AX, [p1_pos_x]
        MOV     BX, [p1_pos_y]
cabeca1:
        ADD     BX, 10
        MOV     CX, 10
        PUSH    AX
        PUSH    BX
        PUSH    CX
        CALL    full_circle
corpo1:
        MOV     AX, [p1_pos_x]
        MOV     BX, [p1_pos_y]
        MOV     CX, BX
        SUB     CX, [p1_tam_corpo]
        MOV     DX, AX
        PUSH    AX
        PUSH    BX
        PUSH    DX
        PUSH    CX
        CALL    linha_grossa
pernas1:
    esquerda1:
        MOV     AX, [p1_pos_x]
        MOV     BX, [p1_pos_y]
        SUB     BX, [p1_tam_corpo]
        MOV     CX, [bp + 18]
        MOV     DX, [bp + 16]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa

		MOV     AX, cx
        MOV     BX, dx
        MOV     CX, [bp + 14]
        MOV     DX, [bp + 12]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa

    direita1:
        MOV     AX, [p1_pos_x]
        MOV     BX, [p1_pos_y]
		SUB 	BX, [p1_tam_corpo]
        MOV     CX, [bp + 10]
        MOV     DX, [bp + 8]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa

		MOV     AX, cx
        MOV     BX, dx
        MOV     CX, [bp + 6]
        MOV     DX, [bp + 4]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa
bracos1:
    esquerdo1:
        MOV     AX, [p1_pos_x]
        MOV     BX, [p1_pos_y]
        MOV     CX, [bp + 34]
        MOV     DX, [bp + 32]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa

		MOV     AX, CX
        MOV     BX, DX
        MOV     CX, [bp + 30]
        MOV     DX, [bp + 28]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa

    direito1:
        MOV     AX, [p1_pos_x]
        MOV     BX, [p1_pos_y]
        MOV     CX, [bp + 26]
        MOV     DX, [bp + 24]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa

		MOV     AX, CX
        MOV     BX, DX
        MOV     CX, [bp + 22]
        MOV     DX, [bp + 20]
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CALL    linha_grossa
fim_perso1:
        POP     DX
        POP     CX
        POP     BX
        POP     AX
		POP 	BP
        RET		32
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

segment data

extern cor
extern modo_anterior
extern linha
extern coluna
extern deltAX
extern deltay
extern mens

extern p1_pos_x
extern p1_pos_y
extern p1_tam_corpo
extern p1_estado
extern p1_frame
extern p1_cor

extern p2_pos_x
extern p2_pos_y
extern p2_tam_corpo
extern p2_estado
extern p2_frame
extern p2_cor
