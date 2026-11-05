# =============================================================================
# Makefile  -  Jogo de Luta em Assembly 8086
# -----------------------------------------------------------------------------
# Monta cada modulo com o NASM (formato OMF/.obj), liga todos com o FREELINK
# e gera TRABALHO.EXE. Cada .obj depende do seu .asm, de modo
# que so os modulos alterados sao remontados.
#
# Uso:
#   make          -> gera trabalho.exe
#   make clean    -> apaga .obj, .lst e o executavel
#
# Escrito so com regras explicitas e macros $(...), sem regras de padrao,
# para funcionar tanto no MAKE do DOS (Borland/Turbo, NMAKE) quanto no
# GNU make. Para outro montador/ligador, altere as macros abaixo, por ex.:
#   make ASM=nasm LINK=tlink
# =============================================================================

ASM     = nasm16
AFLAGS  = -f obj
LINK    = freelink
RM      = del
EXE     = trabalho.exe

OBJS    = trabalho.obj teclado.obj tempo.obj jogador.obj colisao.obj \
          logica.obj hud.obj telas.obj graficos.obj

# Lista de objetos no formato do FREELINK (separados por "+")
LOBJS   = trabalho+teclado+tempo+jogador+colisao+logica+hud+telas+graficos

# ------------------------------- Ligacao -------------------------------------
$(EXE): $(OBJS)
	$(LINK) $(LOBJS),$(EXE);

# ------------------------------- Montagem dos modulos ------------------------
trabalho.obj: trabalho.asm
	$(ASM) $(AFLAGS) -o trabalho.obj -l trabalho.lst trabalho.asm

teclado.obj: teclado.asm
	$(ASM) $(AFLAGS) -o teclado.obj -l teclado.lst teclado.asm

tempo.obj: tempo.asm
	$(ASM) $(AFLAGS) -o tempo.obj -l tempo.lst tempo.asm

jogador.obj: jogador.asm
	$(ASM) $(AFLAGS) -o jogador.obj -l jogador.lst jogador.asm

colisao.obj: colisao.asm
	$(ASM) $(AFLAGS) -o colisao.obj -l colisao.lst colisao.asm

logica.obj: logica.asm
	$(ASM) $(AFLAGS) -o logica.obj -l logica.lst logica.asm

hud.obj: hud.asm
	$(ASM) $(AFLAGS) -o hud.obj -l hud.lst hud.asm

telas.obj: telas.asm
	$(ASM) $(AFLAGS) -o telas.obj -l telas.lst telas.asm

graficos.obj: graficos.asm
	$(ASM) $(AFLAGS) -o graficos.obj -l graficos.lst graficos.asm

# ------------------------------- Limpeza -------------------------------------
clean:
	$(RM) *.obj
	$(RM) *.lst
	$(RM) $(EXE)
