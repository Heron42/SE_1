; Teclado IBM com porta DIN (descontinuado mas o mecanismo de comunicação continua!)
; https://www.xataka.com/perifericos/clac-cataclac-clac-el-legendario-teclado-ibm-model-f-vuelve-a-la-vida-por-360-dolares-puede-ser-tuyo

; Tecla 1 (Esc) gera código Make 1, Teclar 2 (1) código Make 2, Teclar 3 (2) código Make 3 ... ~~ 88 teclas

; Break (liverar a tecla) faz 80h + código Make da tecla, -> Por exemplo a tecla 2 -> Códimo Make = 3, e Código Break = 80h+3 = 83h

; Cada dado do teclado é transferido de forma serial do 8048. A trama é composta por 10 bits, sendo 2 de sincronização (74LS175) com o clock do porcessador PCLK 
; e 8 bits do código Make ou Break da tecla, ou seja, 11XXXXXXXX, dois pusos de sincronização "11" e o código da tecla "XXXXXXXX"

segment code
..start:
; ---------------------------------------------- Inicialização dos registradores --------------------------------------------;
		MOV 	AX,data					; Inicializa o registrador de Segmento de Dados DS
		MOV 	DS,AX
		MOV 	AX,stack				; Inicializa o registrador de Segmento de Pilha SS
		MOV 	SS,AX
		MOV 	SP,stacktop				; Inicializa o apontador de Pilha SP
; ---------------------------------------------------------------------------------------------------------------------------;

; ---------------------------------------------- Alocação da Interrupção do Teclado --------------------------------------------;

		CLI								; Deshabilita INTerrupções por hardware - pin INTR NÃO atende INTerrupções externas	
        XOR     AX, AX					; Limpa o registrador AX, é equivalente a fazer "MOV AX,0"
        MOV     ES, AX					; Inicializa o registrador de Segmento Extra ES para acessar à região de vetores de INTerrupção (posição zero de memoria)
        MOV     AX, [ES:INT9*4]			; Carrega em AX o valor do IP do vector de INTerrupção 9 
        MOV     [offset_dos], AX    	; Salva na variável offset_dos o valor do IP do vector de INTerrupção 9
        MOV     AX, [ES:INT9*4+2]   	; Carrega em AX o valor do CS do vector de INTerrupção 9
        MOV     [cs_dos], AX			; Salva na variável cs_dos o valor do CS do vector de INTerrupção 9     
        MOV     [ES:INT9*4+2], CS		; Atualiza o valor do CS do vector de INTerrupção 9 com o CS do programa atual 
        MOV     WORD [ES:INT9*4],keyINT	; Atualiza o valor do IP do vector de INTerrupção 9 com o offset "keyINT" do programa atual
        STI								; Habilita INTerrupções por hardware - pin INTR SIM atende INTerrupções externas
; -----------------------------------------------------------------------------------------------------------------------------;

; ---------------------------------------------- Inicialização do Modo Gráfico --------------------------------------------;
;Salvar modo corrente de video(vendo como está o modo de video da maquina)
        MOV  	AH,0Fh
    	INT  	10h
    	MOV  	[modo_anterior],AL   

;Alterar modo de video para gráfico 640x480 16 cores
    	MOV     	AL,12h
   		MOV     	AH,0
    	INT     	10h
; -------------------------------------------------------------------------------------------------------------------------;
                
L1:
        MOV     AX,[p_i]				; loop - se não tem tecla pulsada, não faz nada! p_i só é atualizado (p_i = p_i + 1) na Rotina de Serviço de INTerrupção (ISR) "keyINT" 
        CMP     AX,[p_t]
        JE      L1
        INC     word[p_t]				; p_t - se atualiza (p_t = p_t + 1) só se p_i foi atualizado, ou seja, se teve tecla pulsada
        AND     word[p_t],7				
        MOV     BX,[p_t]				; Carrega em BX o valor de p_t
        XOR     AX, AX
        MOV     AL, [BX+tecla]			; Carrega em AL o valor da variável tecla (variável atualizada durante a ISR) mais o offset BX, AL <- [BX+tecla]  
        MOV     [tecla_u],AL			; Transfere o valor de AL (no caso o valor da tecla - Código Make/Break) para variável "tecla_u"
        
		MOV     BL, 16					; Como AL contem o valor do código Make da tecla pulsada ou código Break da tecla liverada carrega BL com 16
        DIV     BL						; para dividir por 16 e representar em Hexa o valor do código Make/Break - "Lembrar que Cociente fical em AL e residuo em AH"
        ADD     AL, 30h					; Acrecenta 0x30 a AL para converter em ascii, por exemplo se for Make = 1, o ascii de 1 é 0x31			
        CMP     AL, 3Ah                 ; Se a tecla pulsada for differente de número, ou seja, se for uma letra o valor é superior a 0x3A. Ver tabela ascii
										; 
        JB      continua				; Se for numero de 0 até 9, daria 0x30 até 0x39, então pula para "continua"
        ADD     AL, 07h					; Se não for numero, acrescenta 7 para pular os carateres - ver tabela ascii

continua:        
        MOV     [teclasc], AL			; O cociente da divisão é transferido à variável "teclasc"
        ADD     AH, 30h					; Repete o processo com o ressiduo: Acrescenta 0x30 para converter em ascii,
        CMP     AH, 3Ah					; Verifica se é maior do que 0x39, ou seja, se é letra!
        JB      continua1				; Se não, então é numero (0x30 até 0x39) e pula para "continua1"
        ADD     AH, 07h					; Se não for numero, então é letra e acrescenta 7 para pular os carateres - ver tabela ascii

continua1:
        MOV     [teclasc+1], AH			; O ressiduo da divisão é transferido à variável "teclasc+1"
        MOV     DX,teclasc				; Carrega endereço de teclasc
        MOV     AH, 9 					; Imprimir string DOS, ou seja, imprime o valor em ascii da tecla pulsada. Por exemplo, se for tecla #2 ('1') imprime 02 (Make) ou 82 (Break)
        INT     21h						; Chama INTerrupção por software para imprimir o valor!
		
        CMP     BYTE [tecla_u], 81h		; Se for pulsada a tecla ESC gera o código Break = 0x81, 
        JE      L2						; Então pula para sair do programa!
        JMP     L1						; Se não, pula para L1 e começa tudo de novo!

L2:										; Ao sair do programa temos que restaurar o CS:IP da INTerrupção 9, que incialmente alteramos nas linhas 26 e 27
        CLI								; Deshabilita INTerrupções por hardware - pin INTR NÃO atende INTerrupções externas
        XOR     AX, AX					; Limpa o registrador AX, é equivalente a fazer "MOV AX,0"				
        MOV     ES, AX					; Inicializa o registrador de Segmento Extra ES para acessar à região de vetores de INTerrupção (posição zero de memoria)
        MOV     AX, [cs_dos]			; Carrega em AX o valor do CS do vector de INTerrupção 9 que foi salvo na variável cs_dos -> linha 25
        MOV     [ES:INT9*4+2], AX		; Atualiza o valor do CS do vector de INTerrupção 9 que foi salvo na variável cs_dos
        MOV     AX, [offset_dos]		; Carrega em AX o valor do IP do vector de INTerrupção 9 que foi salvo na variável offset_dos -> linha 23
        MOV     [ES:INT9*4], AX 		; Atualiza o valor do IP do vector de INTerrupção 9 que foi salvo na variável offset_dos
        MOV     AH, 4Ch					; Carrega em AH o valor de 4Ch, parametro para INT 21h
        INT     21h						; Chama Interrupção 21h para retornar o controle ao sistema operacional -> sai de forma segura da execução do programa


; ---------------------------------------------- ISR de Teclado --------------------------------------------;
keyINT:									; Este segmento de código só será executado se uma tecla for presionada, ou seja, se a INT 9h for acionada!
        PUSH    AX						; Salva contexto na pilha
        PUSH    BX
        PUSH    DS
 ;       MOV     AX,data					; Carrega em AX o endereço de "data" -> Região do código onde encontra-se o segemeto de dados "Segment data" 			
 ;       MOV     DS,AX					; Atualiza registrador de segmento de dados DS, isso pode ser feito no inicio do programa!
        IN      AL, kb_data				; Le a porta 60h, que é onde está o byte do Make/Break da tecla. Esse valor é fornecido pelo chip "8255 PPI"
        INC     WORD [p_i]				; Incrementa p_i para indicar no loop principal que uma tecla foi acionada!
        AND     WORD [p_i],7			
        MOV     BX,[p_i]				; Carrega p_i em BX
        MOV     [BX+tecla],al			; Transfere o valor Make/Break da tecla armacenado em AL "linha 84" para o segmento de dados com offset DX, na variável "tecla"
        IN      AL, kb_ctl				; Le porta 61h, pois o bit mais significativo "bit 7" 
        OR      AL, 80h					; Faz operação lógica OR com o bit mais significativo do registrador AL (1XXXXXXX) -> Valor lido da porta 61h 
        OUT     kb_ctl, AL				; Seta o bit mais significativo da porta 61h
        AND     AL, 7Fh					; Restablece o valor do bit mais significativo do registrador AL (0XXXXXXX), alterado na linha 90 	
        OUT     kb_ctl, AL				; Reinicia o registrador de dislocamento 74LS322 e Livera a interrupção "CLR do flip-flop 7474". O 8255 - Programmable Peripheral Interface (PPI) fica pronto para recever um outro código da tecla https://es.wikipedia.org/wiki/INTel_8255
        MOV     AL, eoi					; Carrega o AL com a byte de End of Interruption, -> 20h por default
        OUT     pictrl, AL				; Livera o PIC
        
		POP     DS						; Reestablece os registradores salvos na linha 79 
        POP     BX
        POP     AX
        IRET							; Retorna da interrupção
; ----------------------------------------------------------------------------------------------------------;


; ---------------------------------------------- Funções Gráficas --------------------------------------------;
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
; ---------------------------------------------- Variáveis de Interrupção do Teclado --------------------------------------------;
        kb_data EQU 60h  				; PORTA DE LEITURA DE TECLADO
        kb_ctl  EQU 61h  				; PORTA DE RESET PARA PEDIR NOVA INTERRUPCAO
        pictrl  EQU 20h					; PORTA DO PIC DE TECLADO
        eoi     EQU 20h					; Byte de final de interrupção PIC - resgistrador
        INT9    EQU 9h					; Interrupção por hardware do teclado
        cs_dos  DW  1					; Variável de 2 bytes para armacenar o CS da INT 9
        offset_dos  DW 1				; Variável de 2 bytes para armacenar o IP da INT 9
        tecla_u db 0
        tecla   resb  8					; Variável de 8 bytes para armacenar a tecla presionada. Só precisa de 2 bytes!	 
        p_i     dw  0   				; Indice p/ Interrupcao (Incrementa na ISR quando pressiona/solta qualquer tecla)  
        p_t     dw  0   				; Indice p/ Interrupcao (Incrementa após retornar da ISR quando pressiona/solta qualquer tecla)    
        teclasc DB  0,0,13,10,'$'		; Variável tipo char para printar o código Make/Break em hexadecimal
; ------------------------------------------------------------------------------------------------------------------------------;

; ---------------------------------------------- Variáveis do Modo Gráfico --------------------------------------------;
        cor		db		branco_intenso
                                    ; I R G B COR
        pRETo			equ		0	; 0 0 0 0 pRETo
        azul			equ		1	; 0 0 0 1 azul
        verde			equ		2	; 0 0 1 0 verde
        cyan			equ		3	; 0 0 1 1 cyan
        vermelho		equ		4	; 0 1 0 0 vermelho
        magenta			equ		5	; 0 1 0 1 magenta
        marrom			equ		6	; 0 1 1 0 marrom
        branco			equ		7	; 0 1 1 1 branco
        cinza			equ		8	; 1 0 0 0 cinza
        azul_claro		equ		9	; 1 0 0 1 azul claro
        verde_claro		equ		10	; 1 0 1 0 verde claro
        cyan_claro		equ		11	; 1 0 1 1 cyan claro
        rosa			equ		12	; 1 1 0 0 rosa
        magenta_claro	equ		13	; 1 1 0 1 magenta claro
        amarelo			equ		14	; 1 1 1 0 amarelo
        branco_intenso	equ		15	; 1 1 1 1 branco INTenso

        modo_anterior	db		0
        linha   		dw  	0
        coluna  		dw  	0
        deltAX			dw		0
        deltay			dw		0	
        mens    		db  	'Funcao Grafica'
; ---------------------------------------------------------------------------------------------------------------------;

segment stack stack						; Segmento da pilha -> SS
    resb 1024							; Reserva 1024 bytes para a pilha
stacktop:								; Define ponteiro do topo da pilha -> SP

