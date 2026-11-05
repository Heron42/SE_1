nasm16 -f obj -o trabalho.obj -l trabalho.lst trabalho.asm
nasm16 -f obj -o teclado.obj  -l teclado.lst  teclado.asm
nasm16 -f obj -o tempo.obj    -l tempo.lst    tempo.asm
nasm16 -f obj -o jogador.obj  -l jogador.lst  jogador.asm
nasm16 -f obj -o colisao.obj  -l colisao.lst  colisao.asm
nasm16 -f obj -o logica.obj   -l logica.lst   logica.asm
nasm16 -f obj -o hud.obj      -l hud.lst      hud.asm
nasm16 -f obj -o telas.obj    -l telas.lst    telas.asm
nasm16 -f obj -o graficos.obj -l graficos.lst graficos.asm
freelink trabalho+teclado+tempo+jogador+colisao+logica+hud+telas+graficos,trabalho.exe;
