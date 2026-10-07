; Teclado IBM com porta DIN (descontinuado mas o mecanismo de comunicação continua!)
; https://www.xataka.com/perifericos/clac-cataclac-clac-el-legendario-teclado-ibm-model-f-vuelve-a-la-vida-por-360-dolares-puede-ser-tuyo

; Tecla 1 (Esc) gera código Make 1, Teclar 2 (1) código Make 2, Teclar 3 (2) código Make 3 ... ~~ 88 teclas

; Break (liverar a tecla) faz 80h + código Make da tecla, -> Por exemplo a tecla 2 -> Códimo Make = 3, e Código Break = 80h+3 = 83h

; Cada dado do teclado é transferido de forma serial do 8048. A trama é composta por 10 bits, sendo 2 de sincronização (74LS175) com o clock do porcessador PCLK 
; e 8 bits do código Make ou Break da tecla, ou seja, 11XXXXXXXX, dois pusos de sincronização "11" e o código da tecla "XXXXXXXX"

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
        MOV     [offset_dos], AX    	; Salva na variável offset_dos o valor do IP do vector de INTerrupção 9
        MOV     AX, [ES:INT9*4+2]   	; Carrega em AX o valor do CS do vector de INTerrupção 9
        MOV     [cs_dos], AX			; Salva na variável cs_dos o valor do CS do vector de INTerrupção 9     
        MOV     [ES:INT9*4+2], CS		; Atualiza o valor do CS do vector de INTerrupção 9 com o CS do programa atual 
        MOV     WORD [ES:INT9*4],keyINT	; Atualiza o valor do IP do vector de INTerrupção 9 com o offset "keyINT" do programa atual
        STI								; Habilita INTerrupções por hardware - pin INTR SIM atende INTerrupções externas
                
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

segment data
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

segment stack stack						; Segmento da pilha -> SS
    resb 256							; Reserva 256 bytes para a pilha
stacktop:								; Define ponteiro do topo da pilha -> SP

