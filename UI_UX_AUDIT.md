# Auditoria UI/UX — Dino Park Tycoon

Escopo: interface do cliente (`src/StarterPlayer/StarterPlayerScripts/DinoParkClient.client.lua`) e a lógica pura de apoio em `Logic.lua`. Economia, servidor e DataStore não foram alterados. Design brief: `design/features/ui-ux-redesign/design.md` (Status: approved).

## 1. Análise da experiência anterior

| # | Problema | Impacto |
|---|----------|---------|
| 1 | Tutorial no topo, com texto genérico e botão "X" que gravava no servidor | Objetivo some ao fechar; sem próximo passo claro depois do onboarding |
| 2 | Nenhum indicador de progressão ("o que falta para a próxima melhoria") | Jogador não sabe quanto falta nem para quê |
| 3 | Inventário em lista de linhas com rótulos apertados (raridade e renda em uma linha só) | Difícil comparar espécies; sem estado visual claro (habitat/guardado) |
| 4 | Incubação: só texto de contagem e botão "Coletar"; revelação silenciosa | Momento de maior recompensa sem celebração |
| 5 | Loja sem informar o que acontece com o tempo nem o motivo de botão desabilitado | Botão "Comprado"/"Comprar" cinza sem explicação |
| 6 | Botões cinza sem resposta ao toque ("morto") | Feedback fraco em ações que falham |
| 7 | Mensagens de falha dependem só de cor (vermelho/verde) | Não atende acessibilidade |
| 8 | Barra inferior sem sinal de atenção (ovo pronto, melhoria acessível) | Jogador não volta ao que está pronto |
| 9 | Texto de 13 px em botões e alguns rótulos pequenos; contraste de texto de cinza sobre verde fraco | Legibilidade em celular |
| 10 | Painel de tamanho fixo (460×400), sem adaptação a retrato | Overflow e área de toque pequena em celular retrato |
| 11 | Barra inferior cortada: layout usava `ViewportSize` e ignorava a barra superior do Roblox (58 px) | Botões fora da tela (achado no Studio durante esta sessão) |

## 2. Arquitetura de informação e design system

- Sempre visível: HUD de moedas, objetivo, próxima melhoria (wide), barra inferior com badges.
- Painel central único; revelação de dinossauro como sobreposição não bloqueante.
- Tokens (cores, fontes, tamanhos, estilos de botão) em `design/DESIGN.md`. Estilos de botão: `primary`, `gold`, `ghost`, `disabled`; `disabled` aceita toque e mostra o motivo.
- Lógica de orientação em `Logic.lua` (pura, testada): `Logic.currentGoal` e `Logic.nextUpgrade`.

## 3. Mudanças implementadas

- HUD: moedas em destaque, renda em texto, aviso "Progresso não é salvo nesta sessão" em texto (não só cor).
- Objetivo: primeira missão pendente (com recompensa e dica de ação). Quando as missões acabam: próximo passo de melhoria com custo.
- Próxima melhoria (tela larga): nome, custo e "Pronto" ou "Faltam N moedas".
- Barra inferior: "Coleção" (antes "Inventário"); badges "!" para ovo pronto/disponível, dinossauro sem habitat com vaga, melhoria acessível.
- Incubadora: estados vazio/sem ovos/chocando (texto + barra de progresso)/pronto. Chances de nascer com barras proporcionais e porcentagem com raridade em texto.
- Coleção: cards em grade (3 colunas em tela larga, 2 em retrato) com faixa da espécie, raridade (texto + cor), estado (No habitat / Disponível / Aguardando vaga), renda, e ação ("Colocar", "Guardar" ou "Sem vaga" com motivo).
- Revelação: pop-in, faíscas (10 pontos), som mais agudo, nome, raridade, descrição, "Colocar no habitat" ou "Guardar para depois". Só aparece para dinossauro novo na lista (não ao entrar).
- Loja: contagem regressiva da troca, aviso de que os itens são iguais para todos e só enfeites; botões mostram preço, "Faltam N" (com motivo) ou "Na coleção".
- Melhorias: barra de nível, efeito atual → próximo (ex.: "Renda: +25% → +50%"), "Faltam N" ou "Máximo".
- Missões: pílulas FEITO/PENDENTE, recompensa à direita, contagem no topo.
- Feedback: encolhimento ao tocar; avisos com prefixo "+", "!" ou nenhum; "+N" dourado sobe ao ganhar moedas.
- Layout: usa `gui.AbsoluteSize` (descontando a barra superior), recalcula ao mudar de janela; célula de barra e painel proporcionais.
- Desempenho: sem animação contínua além da barra de incubação (0,5 s); painéis reconstroem só o conteúdo aberto; faíscas e sons criados por evento e removidos com `Debris`.
- Lógica nova: `Logic.currentGoal` e `Logic.nextUpgrade`, com 2 testes em `tests/logic_test.lua`.

Removido: o tutorial e o uso de `dismissTutorial` pelo cliente. O handler `dismissTutorial` continua no servidor (não usado).

## 4. Testes executados

| Teste | Resultado |
|-------|-----------|
| `node tools/build.js` | OK (installer regenerado) |
| `tools/check.js` (sintaxe Lua 5.1/5.3, 12 arquivos) | OK |
| `tools/globals.js` | OK |
| `tools/xref.js` (ações e campos de estado) | OK |
| `tests/run_tests.js` (16 testes, inclui 2 novos) | 16 passaram, 0 falharam |
| Studio: Play com o client novo, captura de tela | HUD, objetivo, próxima melhoria, barra inferior e badges visíveis; barra inteira após a correção do inset |
| Studio: clique real em "Ovo" (mouse MCP) | **Não confirmado**: o clique via MCP não abriu o painel (ver TEST_REPORT.md) |

## 5. Auditoria de usabilidade (checklist, sem usuários reais)

- [x] Objetivo visível desde o spawn, com texto de ação.
- [x] Botões desabilitados explicam o motivo ao tocar.
- [x] Estados (vazio, chocando, pronto, sem vaga, máximo, comprado) têm texto próprio.
- [x] Informação por cor também tem texto (raridade, estado, missões, avisos).
- [x] Texto mínimo de 13 px.
- [ ] Teste de toque em celular real: não feito.
- [ ] Teste de contraste medido com ferramenta: não feito (valores estimados pelo token de cor).
- [ ] Teste de layout em 390×844 e 844×390: não feito no Studio (só a janela de 1511×781 foi verificada).

## 6. Comparação com os objetivos

- Primeiros 30 s: o objetivo "Choque seu primeiro ovo" está na tela desde o início, com "Abra Ovo e toque em Incubar". Falta medir o tempo real até o primeiro clique com jogadores — hipótese, não validada.
- Progressão: "Próxima melhoria" e os níveis em barra deixam claro o que falta. Hipótese: isso aumenta a compra de melhorias. Não medido.
- Loja: sem urgência falsa; a rotação aparece com o tempo. Hipótese: a clareza reduz frustração. Não medido.

## 7. Hipóteses a validar com jogadores

1. Jogadores iniciantes chegam a incubar o primeiro ovo em menos de 30 s com o objetivo visível.
2. A revelação com faíscas e som aumenta o desejo de colocar o dinossauro no habitat (medir taxa de "Colocar" logo após a revelação).
3. O indicador "Próxima melhoria" aumenta a compra de melhorias em comparação com a versão anterior.
4. Os badges "!" na barra trazem o jogador de volta ao ovo pronto (medir retorno em 5 min).

## 8. Pendências

- Verificar no Studio o clique nos botões (painéis, incubação, compra) e o layout em celular (retrato e paisagem).
- Verificar o som `rbxasset://sounds/electronicpingshort.wav` com `PlaybackSpeed` 1,4 (já usado antes, mas nunca ouvido).
- Os valores de contraste são estimativas pelos tokens, não medidos.
