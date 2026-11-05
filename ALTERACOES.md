# Alterações no projeto: Jogo de Luta em Assembly 8086

Nada foi commitado. Os arquivos desta pasta substituem ou complementam os do repositório.

## Como aplicar

1. Copie para a raiz do projeto todos os arquivos `.asm`, o `const.inc`, o `Makefile` e o `MONTA.BAT`.
2. O novo `trabalho.asm` **substitui** o antigo. Ele virou só o módulo principal; o restante do código foi distribuído pelos outros módulos.
3. O `graficos.asm` foi **editado** (veja `graficos.diff`). Ganhou a variável `cor` e três rotinas de texto e tela.
4. Monte com `make`. Se não houver `make` no DOS, use `MONTA.BAT`, que executa os mesmos passos.
5. O `TRABALHO.EXE` incluído já foi gerado com o `NASM16.EXE` e o `FREELINK.EXE` do próprio repositório, para testes rápidos.

## Organização dos módulos (requisito 10)

Os nomes têm no máximo 8 caracteres, por causa do limite do DOS.

| Arquivo | Conteúdo |
|---|---|
| `trabalho.asm` | Inicialização, máquina de estados (seleção, rounds, Game Over), laço principal e saída |
| `teclado.asm` | ISR da INT 9h, tabela de estado, fila de eventos, instalação e restauração do vetor |
| `tempo.asm` | ISR da INT 8h, tique do jogo, cronômetro do round, instalação e restauração do vetor |
| `jogador.asm` | Controles, movimento, pulo, animação, desenho e dados dos lutadores |
| `colisao.asm` | Detecção de golpes válidos (soco e chute) |
| `logica.asm` | Fim de round e de partida, critério de desempate, pausa (P) e saída (Q) |
| `hud.asm` | Arena, barras de energia, marcadores de rounds, cronômetro e mensagens |
| `telas.asm` | Seleção de lutadores, avisos de round e tela de Game Over |
| `graficos.asm` | Primitivas gráficas do modo 12h e desenho do boneco |
| `const.inc` | Constantes compartilhadas (portas, scan codes, cores, regras, estrutura do jogador) |

## Requisitos implementados

* **Seleção de lutadores.** O J1 escolhe com W/S, o J2 com as setas ↑/↓, e Enter inicia a luta. São 8 cores, e cada lutador aparece em prévia. A cor já escolhida pelo adversário é pulada automaticamente, então os dois nunca ficam com a mesma cor.
* **Game Over (requisito 5).** A tela mostra "GAME OVER", o vencedor na sua cor, o placar final e "Nova partida? (Y/N)". Y volta à seleção de lutadores e N encerra o programa.
* **Encerramento manual (requisito 6).** Q (e também ESC) abre "Deseja realmente sair? (Y/N)" em qualquer momento: na seleção, na luta, na pausa, nos avisos entre rounds e no Game Over. Y encerra. N apaga a pergunta e volta ao estado anterior, com o cronômetro congelado enquanto a pergunta está na tela.
* **Pausa (requisito 7).** P alterna entre pausa e execução e mostra "PAUSED". O tempo da pausa não é contado no round, porque a ISR da INT 8h só conta segundos quando `relogio_ativo = 1`.
* **Makefile (requisito 11).** Tem as dependências de cada `.obj` (seu `.asm` e o `const.inc`), a montagem, a ligação e o alvo `clean`.
* **Avisos entre rounds.** "ROUND n" e "LUTEM!" antes de cada round; "NOCAUTE!" ou "TEMPO ESGOTADO!" e o vencedor ao final, já com o último golpe desenhado na tela.

## Correções no código que já existia

* **Cronômetro preciso.** O round agora dura 3 minutos reais. Antes eram cerca de 178 s, porque o código considerava 18 tiques por segundo, quando o 8253 gera 18,2065. A correção usa um acumulador fracionário de 91 tiques para cada 5 segundos.
* **Cronômetro em M:SS.** O tempo agora aparece como 3:00, 2:59, e assim por diante.
* **Golpes simultâneos do J2.** Com M e N apertados juntos, o soco do J2 era substituído pelo chute. Agora o soco tem prioridade, como já acontecia com o J1. O código de controle passou a ser único para os dois jogadores (`controla_jogador`).
* **Estrutura do jogador.** Agora ocupa 20 bytes de fato. Antes eram 21, e `JESTADOANT` estava no byte marcado como reserva.
* **Fila de eventos.** Foi ampliada para 16 posições. Quando está cheia, descarta o código novo, em vez de corromper a fila.
* **Instruções do 8086.** `SHL DI,3` e `SHL DI,2` em `graficos.asm` não existem no 8086 (são instruções do 80186). Foram trocadas por deslocamentos de 1 bit.
* **Espera sem laço de software.** Os laços de espera usam `HLT` até a próxima interrupção.
* **Defeito encontrado nos testes.** Ao responder N no menu de saída, o J2 chutava ao voltar, porque N também é a tecla de chute dele. Agora o menu espera a tecla ser solta.

## Critério de desempate (documentado em `logica.asm`)

O vencedor do round é decidido nesta ordem:

1. mais energia (inclui o nocaute);
2. com energia igual, quem acertou o último golpe válido;
3. se ninguém acertou nenhum golpe, quem estiver mais perto do centro da arena (o critério original da equipe);
4. persistindo o empate, o Jogador 1.

## Testes realizados

Montagem com o `NASM16.EXE` (0.98) e ligação com o `FREELINK.EXE` do repositório, dentro de um DOSBox emulado. Também testei a jogabilidade no próprio DOSBox:

* seleção de cores, incluindo o pulo da cor ocupada;
* socos e chutes causando dano;
* defesa abaixado (o soco erra);
* pulo;
* pausa, com o tempo parado durante 4 s;
* Q seguido de N, voltando sem efeitos colaterais;
* partida 2 x 0 por nocaute;
* rounds por tempo (com uma montagem de teste de 6 s): vitória por energia, por centro da arena e por último golpe;
* Game Over, Y para nova partida, e Q seguido de Y para sair;
* volta ao DOS em modo texto, com o teclado funcionando (o comando `dir` foi executado).

O Makefile foi validado com o GNU make. **Ele não foi testado com um `make` de DOS** (Borland ou NMAKE), porque não há nenhum no repositório. Ele usa só regras explícitas e macros, para ser compatível com eles. Confirmem com o professor qual `make` será usado.

## Ainda pendente (não feito)

* Limpar do repositório os arquivos gerados (`.OBJ`, `.LST`, `.EXE`) e os arquivos que não fazem parte do projeto (`Linec.asm`, `relogio.asm`, `Tecbuf_Com.asm`, `GRAFICOS.EXE`, arquivos de distribuição do FREELINK), e criar um `.gitignore`.
* Revisar os comentários com acentos do `graficos.asm`, que podem aparecer corrompidos em editores de DOS.
