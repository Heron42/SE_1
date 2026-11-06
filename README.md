# Jogo de Luta em Assembly 8086

Jogo de luta para dois jogadores, inspirado em *Karateka*, escrito em Assembly 8086 para DOS (modo gráfico VGA 12h, 640x480, 16 cores). Dois lutadores se enfrentam numa arena com socos, chutes, pulos e defesa abaixada, em partidas de melhor de três rounds.

## Como montar e rodar

Ferramentas, todas na raiz do repositório:

* `NASM16.EXE`: montador NASM 0.98 para DOS;
* `NASM.BAT`: chama o `NASM16.EXE` para um módulo (`nasm modulo`);
* `FREELINK.EXE`: ligador.

No DOSBox, monte a pasta do projeto como drive C:

```
mount c caminho\da\pasta
c:
cycles max
```

O `cycles max` acelera o emulador; o desenho é feito pela BIOS, ponto a ponto, e fica lento com a configuração padrão.

Monte e ligue o programa com o `MAKE.BAT`, no mesmo formato do exemplo da disciplina:

```
make
```

Ele chama o `NASM.BAT` para cada um dos 9 módulos e depois liga todos com o FREELINK, gerando o `TRABALHO.EXE`.

O `Makefile` faz o mesmo para quem tiver um programa `make` instalado (no DOS, chame-o pelo nome do executável, por exemplo `gmake`, porque `make` aciona o `MAKE.BAT`).

Rode o jogo:

```
trabalho
```

Os arquivos gerados na montagem (`.obj` e `.lst`) não são versionados (ver `.gitignore`). Para apagá-los: `del *.obj` e `del *.lst`. O `TRABALHO.EXE` é mantido no repositório, para que o jogo possa ser executado sem montar.

## Como jogar

1. **Seleção de lutadores.** O J1 escolhe a cor com **W/S** e o J2 com **↑/↓**. **Enter** inicia a luta. Há 4 cores (azul, vermelho, verde e amarelo); a cor já escolhida pelo adversário é pulada automaticamente. A tela não mostra esses comandos; eles estão descritos aqui.
2. **Luta.** Os controles são:

   | Ação | Jogador 1 | Jogador 2 |
   |---|---|---|
   | Esquerda | A | ← |
   | Direita | D | → |
   | Pular | W | ↑ |
   | Abaixar | S | ↓ |
   | Chute (rasteira) | R | N |
   | Soco | T | M |

3. **Comandos a qualquer momento:**
   * **P** pausa e retoma; a tela mostra "PAUSED" e o tempo de pausa não conta no round;
   * **Q** (ou ESC) pergunta "Sair? (Y/N)"; Y encerra e N volta exatamente ao ponto anterior.
4. **Game Over.** A tela mostra o vencedor e o placar. **Y** começa uma nova partida e **N** encerra o programa.

## Regras

* Cada lutador começa o round com **10 pontos de energia**. Cada golpe válido tira 1 ponto.
* **Soco:** acerta se o adversário estiver perto e na mesma altura. **Defesa:** abaixar ou pular.
* **Chute (rasteira):** acerta se o adversário estiver perto e no chão. **Defesa:** pular.
* Cada golpe só causa dano uma vez, no frame de impacto da animação.
* O round termina quando um lutador chega a energia 0 ou quando o tempo de **3 minutos** acaba. O tempo restante aparece no centro do HUD, em segundos (de 180 a 0).
* A partida é em **melhor de três**: vence quem ganhar 2 rounds. No HUD, cada jogador tem dois quadrados amarelos: o contorno indica round ainda não vencido, e o quadrado cheio, round vencido.

### Critério de vencedor do round

Aplicado em ordem (rotina `verifica_fim_round`, em `logica.asm`):

1. quem tiver **mais energia** (inclui o nocaute);
2. com energia igual, quem acertou o **último golpe válido** do round (se os dois zerarem a energia no mesmo tique, vale o golpe processado por último);
3. se ninguém acertou nenhum golpe, quem estiver **mais perto do centro** da arena;
4. persistindo o empate, o **Jogador 1**.

## Organização do código

| Arquivo | Conteúdo |
|---|---|
| `trabalho.asm` | Módulo principal: inicialização, máquina de estados (seleção, rounds, Game Over), laço principal e saída |
| `teclado.asm` | ISR da INT 9h, tabela de estado das teclas, fila de eventos, instalação e restauração do vetor |
| `tempo.asm` | ISR da INT 8h, tique do jogo, cronômetro do round, instalação e restauração do vetor |
| `jogador.asm` | Controles, movimento, pulo, animação, desenho e dados dos lutadores |
| `colisao.asm` | Detecção de golpes válidos |
| `logica.asm` | Fim de round e de partida, critério de desempate, pausa e confirmação de saída |
| `hud.asm` | Arena, barras de energia, marcadores de rounds, cronômetro e mensagens |
| `telas.asm` | Seleção de lutadores, avisos de round e tela de Game Over |
| `graficos.asm` | Primitivas gráficas do modo 12h (ponto, linha, círculo, texto) e desenho do boneco |
| `MAKE.BAT` / `NASM.BAT` | Montagem dos módulos e ligação (padrão da disciplina) |
| `MONTA.BAT` | Alternativa equivalente ao `MAKE.BAT`, com os comandos do `nasm16` escritos por extenso |
| `Makefile` | Mesma montagem, para uso com um programa `make` |
| `NASM16.EXE` / `FREELINK.EXE` | Montador e ligador usados na montagem |
| `.gitignore` | Impede que os arquivos gerados (`.obj`, `.lst`) sejam versionados |

Não há arquivo de constantes compartilhado: cada módulo declara no início, com `EQU`, as constantes que usa (portas, scan codes, cores, regras e os deslocamentos dos campos do lutador). Uma constante que aparece em mais de um módulo, como `JENERGIA` ou `Y_CHAO`, precisa ter o mesmo valor em todos eles; ao mudar uma regra, procure o nome em todos os `.asm`.

## Detalhes técnicos

* **Teclado (INT 9h).** A ISR, baseada no programa *Tecbuf*, lê o scan code direto da porta 60h e alimenta duas estruturas:
  * uma **tabela de estado** com 128 posições (tecla pressionada ou solta), usada no movimento, para que os dois jogadores possam segurar teclas ao mesmo tempo;
  * uma **fila circular** de 16 posições, usada nos comandos pontuais (P, Q, Y, N, Enter e seleção de cores).

  Nenhuma leitura de teclado usa a INT 21h.
* **Temporização (INT 8h).** O 8253 gera 18,2065 interrupções por segundo.
  * Cada interrupção é um "tique" do jogo, e o laço principal processa um tique por vez.
  * Entre tiques, o processador fica em `HLT`: não há laço de atraso por software.
  * O cronômetro soma 5 a um acumulador a cada tique e conta 1 segundo a cada 91 (18,2 tiques por segundo).
  * Os segundos só são contados durante a luta; ficam parados na pausa, no menu de saída e entre rounds.
  * A ISR encadeia a rotina original do BIOS, que mantém a hora do sistema.
* **Vídeo.** O jogo usa o modo 12h, com desenho pela BIOS (INT 10h). Os lutadores são esqueletos com animação quadro a quadro (formato descrito em `desenha_jogador`). São apagados e redesenhados apenas quando algo muda.
* **Restauração do sistema.** A saída é única (rótulo `fim`, em `trabalho.asm`), tanto pelo Game Over quanto pela tecla Q. Ela restaura os vetores originais das INT 8h e 9h e o modo de vídeo que estava ativo, e devolve o controle ao DOS.
* **Compatibilidade.** O código usa só instruções do 8086. Todos os saltos condicionais são curtos, como exige o NASM 0.98.
