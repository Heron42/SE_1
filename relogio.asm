; Programa que deve fazer um relógio de contagem no formato (hh:mm:ss) com opção de alterar o horário atual a partir da interrupção de teclado int 9

segment code
..start:
		MOV 	AX,data					; Inicializa o registrador de Segmento de Dados DS
		MOV 	DS,AX
		MOV 	AX,stack				; Inicializa o registrador de Segmento de Pilha SS
		MOV 	SS,AX
		MOV 	SP,stacktop				; Inicializa o apontador de Pilha SP

		CLI								; Deshabilita INTerrupções por hardware - pin INTR NÃO atende INTerrupções externas	
        
        XOR     AX, AX					; Limpa o registrador AX, é equivalente a fazer "MOV AX,0"
        MOV     ES, AX					; Inicializa o registrador de Segmento Extra ES para acessar à região de vetores de INTerrupção (posição zero de memoria)
        MOV     AX, [ES:INT9*4]			; Carrega em AX o valor do IP do vector de INTerrupção 9 
        MOV     [offset_tec], AX    	; Salva na variável offset_dos o valor do IP do vector de INTerrupção 9
        MOV     AX, [ES:INT9*4+2]   	; Carrega em AX o valor do CS do vector de INTerrupção 9
        MOV     [cs_tec], AX			; Salva na variável cs_dos o valor do CS do vector de INTerrupção 9     
        MOV     [ES:INT9*4+2], CS		; Atualiza o valor do CS do vector de INTerrupção 9 com o CS do programa atual 
        MOV     WORD [ES:INT9*4],keyINT	; Atualiza o valor do IP do vector de INTerrupção 9 com o offset "keyINT" do programa atual

        XOR 	AX, AX						; Limpa o registrador AX, é equivALente a fazer "MOV AX,0"
		MOV 	ES, AX						; Inicializa o registrador de Segmento Extra ES para acessar à região de vetores de INTerrupção (posição zero de memoria)
		MOV     AX, [ES:INTr*4]				; Carrega em AX o vALor do IP do vector de INTerrupção 8
		MOV     [offset_clk], AX    		; Salva na variável offset_dos o vALor do IP do vector de INTerrupção 8
		MOV     AX, [ES:INTr*4+2]   		; Carrega em AX o vALor do CS do vector de INTerrupção 8
		MOV     [cs_clk], AX  				; Salva na variável cs_dos o vALor do CS do vector de INTerrupção 8   
		MOV     [ES:INTr*4+2], CS			; Atualiza o valor do CS do vector de INTerrupção 8 com o CS do programa atuAL
		MOV     WORD [ES:INTr*4],ClockINT	; Atualiza o valor do IP do vector de INTerrupção 8 com o offset "ClockINT" do programa atuAL

        STI								; Habilita INTerrupções por hardware - pin INTR SIM atende INTerrupções externas
                
L1:
        CMP byte [tique],0
        JNE ab
        CALL converte
ab:
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
        ;MOV     AH, 9 					; Imprimir string DOS, ou seja, imprime o valor em ascii da tecla pulsada. Por exemplo, se for tecla #2 ('1') imprime 02 (Make) ou 82 (Break)
        ;INT     21h						; Chama INTerrupção por software para imprimir o valor!
		
        CMP     BYTE [tecla_u], 81h		; Se for pulsada a tecla ESC gera o código Break = 0x81, 
        JE      fim						; Então pula para sair do programa!
        CMP     byte [tecla_u], 2Fh     ; tecla == V, muda o formato para 24h
        JE      forma24
        CMP     byte [tecla_u], 20h     ; tecla == D, muda o formato para 12h
        JE      forma12
        JMP     L1						; Se não, pula para L1 e começa tudo de novo!

forma24:
        XOR AX, AX

        MOV byte [hctrl], 24h
		MOV 	AH, 09h						
		MOV 	dx, limpa
		INT 	21h
		
        JMP L1

forma12:
        XOR AX, AX
        MOV byte [hctrl], 12h
        JMP L1

fim:										; Ao sair do programa temos que restaurar o CS:IP da INTerrupção 9, que incialmente alteramos nas linhas 26 e 27
        CLI								; Deshabilita INTerrupções por hardware - pin INTR NÃO atende INTerrupções externas

        XOR     AX, AX					; Limpa o registrador AX, é equivalente a fazer "MOV AX,0"				
        MOV     ES, AX					; Inicializa o registrador de Segmento Extra ES para acessar à região de vetores de INTerrupção (posição zero de memoria)
        MOV     AX, [cs_tec]			; Carrega em AX o valor do CS do vector de INTerrupção 9 que foi salvo na variável cs_dos -> linha 25
        MOV     [ES:INT9*4+2], AX		; Atualiza o valor do CS do vector de INTerrupção 9 que foi salvo na variável cs_dos
        MOV     AX, [offset_tec]		; Carrega em AX o valor do IP do vector de INTerrupção 9 que foi salvo na variável offset_dos -> linha 23
        MOV     [ES:INT9*4], AX 		; Atualiza o valor do IP do vector de INTerrupção 9 que foi salvo na variável offset_dos

        XOR     AX, AX						; Limpa o registrador AX, é equivalente a fazer "MOV AX,0"
		MOV     ES, AX						; Inicializa o registrador de Segmento Extra ES para acessar à região de vetores de INTerrupção (posição zero de memoria)
		MOV     AX, [cs_clk]				; Carrega em AX o valor do CS do vector de INTerrupção 8 que foi salvo na variável cs_dos -> linha 16
		MOV     [ES:INTr*4+2], AX			; Atualiza o valor do CS do vector de INTerrupção 8 que foi salvo na variável cs_dos
		MOV     AX, [offset_clk]			; Carrega em AX o valor do IP do vector de INTerrupção 8 que foi salvo na variável offset_dos				
		MOV     [ES:INTr*4], AX 			; Atualiza o valor do IP do vector de INTerrupção 8 que foi salvo na variável offset_dos
		MOV     AH, 4Ch						; Carrega em AH o valor de 4Ch, parametro para INT 21h

        INT     21h						; Chama Interrupção 21h para retornar o controle ao sistema operacional -> sai de forma segura da execução do programa

converte:									; Esta função conver os valores binarios/decimais para ascii, ou seja acrecenta 0x30 a cada numero
		PUSH 	AX							; Salva contexto na pilha
		PUSH    DS
		MOV     AX, data					; Carrega em AX o endereço de "data" -> Região do código onde encontra-se o segemeto de dados "Segment data"
		MOV     DS, AX						; Atualiza registrador de segmento de dados DS, isso pode ser feito no inicio do programa!
		
        CMP     byte [hctrl], 12h
        JE      conv12
    conv24:
		XOR 	AH, AH						; Limpa AH, pois será utilizado na operação de divisão 
		MOV     BL, 10						; Carrega o operando da divisão
		MOV 	AL, byte [segundo]			; Carrega em AL o valor da variável segundo de 0 até 59
		DIV     BL							; Divide AL por BL, ou seja, AL/10. Como 10 é um byte, o cociente fica armacenado em AL e o residuo em AH 
		ADD     AL, 30h 					; Acrecenta 0x30 ao cociente para converter em ascii                                                                                          
		MOV     byte [horario_24+6], AL		; Atualiza a variável "horario_24" ná posição decenas de segundos
		ADD     AH, 30h						; Acrecenta 0x30 ao residuo para converter em ascii
		MOV 	byte [horario_24+7], AH		; Atualiza a variável "horario_24" ná posição unidades de segundos
											
		XOR 	AH, AH						; Repete o processo anterior para minutos
		MOV 	AL, byte [minuto]
		DIV     BL
		ADD     AL, 30h                                                                                          
		MOV     byte [horario_24+3], AL
		ADD     AH, 30h
		MOV 	byte [horario_24+4], AH
	
		XOR 	AH, AH						; Repete o processo anterior para horas
		MOV 	AL, byte [hora]
		DIV     BL
		ADD     AL, 30h                                                                                          
		MOV     byte [horario_24], AL
		ADD     AH, 30h
		MOV 	byte [horario_24+1], AH
		
		MOV 	AH, 09h						; Imprime o valor de horario_24 com a interrupção 21h
		MOV 	dx, horario_24
		INT 	21h
        JMP     fimconv
    conv12:
		
        XOR 	AH, AH						; Limpa AH, pois será utilizado na operação de divisão 
		MOV     BL, 10						; Carrega o operando da divisão
		MOV 	AL, byte [segundo]			; Carrega em AL o valor da variável segundo de 0 até 59
		DIV     BL							; Divide AL por BL, ou seja, AL/10. Como 10 é um byte, o cociente fica armacenado em AL e o residuo em AH 
		ADD     AL, 30h 					; Acrecenta 0x30 ao cociente para converter em ascii                                                                                          
		MOV     byte [horario_12+6], AL		; Atualiza a variável "horario_24" ná posição decenas de segundos
		ADD     AH, 30h						; Acrecenta 0x30 ao residuo para converter em ascii
		MOV 	byte [horario_12+7], AH		; Atualiza a variável "horario_24" ná posição unidades de segundos
											
		XOR 	AH, AH						; Repete o processo anterior para minutos
		MOV 	AL, byte [minuto]
		DIV     BL
		ADD     AL, 30h                                                                                          
		MOV     byte [horario_12+3], AL
		ADD     AH, 30h
		MOV 	byte [horario_12+4], AH
	
		XOR 	AH, AH						; Repete o processo anterior para horas
		MOV 	AL, byte [hora]
		DIV     BL
		ADD     AL, 30h                                                                                          
		MOV     byte [horario_12], AL
		ADD     AH, 30h
		MOV 	byte [horario_12+1], AH
		
		MOV 	AH, 09h						; Imprime o valor de horario_24 com a interrupção 21h
		MOV 	dx, horario_12
		INT 	21h
    
    fimconv:
		POP     DS							; Recupera contexto salvo nas linhas 75 e 76
		POP     AX
		RET 								; Retorna da função 

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

ClockINT:									; Este segmento de código só será executado se um pulso de relojio está ativo, ou seja, se a INT 8h for acionada!
		PUSH	AX							; Salva contexto na pilha							
		PUSH	DS
		MOV     AX,data						; Carrega em AX o endereço de "data" -> Região do código onde encontra-se o segemeto de dados "Segment data"
		MOV     DS,AX						; Atualiza registrador de segmento de dados DS, isso pode ser feito no inicio do programa!	

		INC		byte [tique]				; Incremente variável tique toda vez que entra na interrupção
		CMP		byte[tique], 18				; Compara variável "teique" com 18, isso para alterar os valores do relogio a cada segundo -> 18/18.2 ~1 segundo!
		JB		Fimrel						; Se for menor que 18 pula para Fimrel
		MOV 	byte [tique], 0				; Se não, limpa variável tique e  
		INC 	byte [segundo]				; Incrementa variável segundo
		CMP 	byte [segundo], 60			; Compara variável "segundo" com 60
		JB   	Fimrel						; Se segundo for menor do que 60, pula para Fimrel
		MOV 	byte [segundo], 0			; Se não, limpa segundo e
		INC 	byte [minuto]				; Incrementa variável minuto
		CMP 	byte [minuto], 60			; Compara variável "minuto" com 60
		JB   	Fimrel						; Se minuto for menor do que 60, pula para Fimrel
		MOV 	byte [minuto], 0			; Se não, limpa minuto e
		INC 	byte [hora]					; Incrementa variável hora

		CMP     byte [hctrl], 12h
        JE      clk12
	
	clk24:
		CMP 	byte [hora], 24				; Compara variável "hora" com 24
		JB   	Fimrel						; Se hora for menor do que 24, pula para Fimrel
		MOV 	byte [hora], 0				; Se não, limpa hora
        JMP     Fimrel

    clk12:
		CMP 	byte [hora], 12				; Compara variável "hora" com 24
		JB   	Fimrel						; Se hora for menor do que 12, pula para Fimrel
		MOV 	byte [hora], 0				; Se não, limpa hora
		CMP 	byte [horario_12+9], 'A'
		JE 		estadoM
		MOV 	byte [horario_12+9], 'P'
		JMP 	Fimrel
	
	estadoM:
		MOV 	byte [horario_12+9], 'A'
Fimrel:
		MOV		AL,eoi						; Carrega o AL com a byte de End of Interruption, -> 20h por default						
		OUT		20h,AL						; Livera o PIC que está na porta 20h
		POP		DS							; Reestablece os registradores salvos na pilha na linha 46
		POP		AX
		IRET								; Retorna da interrupção
        
segment data
        kb_data EQU 60h  				; PORTA DE LEITURA DE TECLADO
        kb_ctl  EQU 61h  				; PORTA DE RESET PARA PEDIR NOVA INTERRUPCAO
        pictrl  EQU 20h					; PORTA DO PIC DE TECLADO
        eoi     EQU 20h					; Byte de final de interrupção PIC - resgistrador
        INT9    EQU 9h					; Interrupção por hardware do teclado
        cs_tec  DW  1					; Variável de 2 bytes para armacenar o CS da INT 9
        offset_tec  DW 1				; Variável de 2 bytes para armacenar o IP da INT 9
        tecla_u db 0
        tecla   resb  8					; Variável de 8 bytes para armacenar a tecla presionada. Só precisa de 2 bytes!	 
        p_i     dw  0   				; Indice p/ Interrupcao (Incrementa na ISR quando pressiona/solta qualquer tecla)  
        p_t     dw  0   				; Indice p/ Interrupcao (Incrementa após retornar da ISR quando pressiona/solta qualquer tecla)    
        teclasc DB  0,0,13,10,'$'		; Variável tipo char para printar o código Make/Break em hexadecimal

		INTr	   	EQU 08h					; Interrupção por hardware do tick
		char		DB	0
		offset_clk	DW	0					; Variável de 2 bytes para armacenar o IP da INT 8
		cs_clk		DW	0					; Variável de 2 bytes para armacenar o CS da INT 8
		tique		DB  0					; Variável de 2 bytes que é incrementada a cada tick do clock ~54.9 ms 
		segundo		DB  30					; Variável para os segundos
		minuto 		DB  59					; Variável para os minutos
		hora 		DB  11					; Variável para as horas
		horario_24		DB  0,0,':',0,0,':',0,0,' ', 13,'$' ; Variável typo string para printar o relogio
        horario_12      DB  0,0,':',0,0,':',0,0,' ','A','M',13,'$'
		limpa			DB  ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',13,'$'
        hctrl       DB  12

segment stack stack						; Segmento da pilha -> SS
    resb 512							; Reserva 256 bytes para a pilha
stacktop:								; Define ponteiro do topo da pilha -> SP
