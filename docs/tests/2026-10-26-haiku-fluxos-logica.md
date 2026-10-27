# Testes de fluxos da lógica — Dino Park Tycoon (2026-10-26)

**Sessão:** Haiku 5.5. Testes automatizados em Lua pura (fengari, Lua 5.3). Nada rodou no Roblox Studio (a outra sessão estava usando o Studio). Nada aqui valida comportamento dentro do Roblox.
**Arquivos:** `tests/fluxos_test.lua` (novo, 103 testes); `tests/run_tests.js` (passou a executar também este arquivo). Rodada 1: escrita dos testes, 9 falhas reproduzindo bugs. Rodada 2: correção dos 9 bugs em `src/` e ajuste de 2 expectativas em `tests/logic_test.lua`. `installer/Parte2_Scripts.lua` foi regenerado pelo `build.js`. Nenhum commit.

## Como rodar

Comando obrigatório do projeto:

```bash
node tools/build.js && (cd tools && node check.js && node globals.js && node xref.js) && node tests/run_tests.js
```

**Estado atual: a cadeia termina com código 0.**

## Placar final

| Suíte | Testes | Passam | Falham |
|---|---|---|---|
| `tests/logic_test.lua` (original) | 38 | 38 | 0 |
| `tests/fluxos_test.lua` (novo) | 103 | 103 | 0 |
| **Total** | **141** | **141** | **0** |

Fuzz de invariantes (3000 ações, sorteio fixo), na última rodada: `FUZZ: 669 ações aceitas, 2331 recusadas, moedas finais 7291`. A conta de moedas fechou em todos os passos.

Verificação obrigatória na última rodada: `build` OK; `check.js` 43/43 sem erro de sintaxe; `globals.js` OK; `xref.js` OK; `run_tests.js` código 0.

Rodada 1 (antes das correções): 131 passaram e 9 falharam, todos `BUG:`.

## Ações do cliente cobertas pela Logic

Lista do `tools/xref.js`: getState, buyEgg, incubate, collect, place, remove, buyUpgrade, buyShop, claimDaily, claimQuest, claimQuestBonus, claimGoal, track, goHome, dismissTutorial.

| Ação | Onde a regra vive | Cobertura nos testes | O que não dá para testar fora do Roblox |
|---|---|---|---|
| buyEgg | `Logic.buyEgg` | feliz, falta de moedas, limite de ovos, repetição, fim de semana, 1ª ação do dia | — |
| incubate | `Logic.startIncubate` | feliz, sem ovos, ocupada, nível 3 | — |
| collect | `Logic.collect` | antes da hora, na hora, sem incubação, inventário cheio, repetição, sorteio no limite | o sorteio real usa `Random.new()` no GameService (aqui, `rnd` é injetado) |
| place | `Logic.place` | feliz, id inexistente, tipos errados, texto enorme, nil, repetição, habitat cheio, limite de 4 | — |
| remove | `Logic.remove` | feliz, fora do habitat, id inexistente, tipos errados, texto enorme, repetição | — |
| buyUpgrade | `Logic.buyUpgrade` | feliz, falta de moedas, custo exato, máximo, chave inválida, repetição até o máximo | — |
| buyShop | `Logic.buyShop` | feliz (decoração e cerca), fora do estoque, só-recompensa, já possuído, falta de moedas, id inválido, evento, estoque real | `os.time()` e a ordem do `commit` ficam no GameService |
| claimDaily | `Logic.claimDaily` | feliz, repetição, virada do dia, sem punição, 7 dias, cerca repetida, relógio voltando | — |
| claimQuest | `Logic.claimQuest` | feliz, antes de concluir, repetição, id inválido, expirada, 1ª ação do dia, relógio voltando | — |
| claimQuestBonus | `Logic.claimQuestBonus` | antes das 3, 2 de 3, feliz, repetição, novo dia | — |
| claimGoal | `Logic.claimGoal` | antes de cumprir, feliz, repetição, id inválido, misto, cosmético repetido, sem expiração, decoração conta | — |
| track | filtro em `GameService.handlers.track`; lista em `Config.ClientEvents` | só a lista fechada (4 eventos; eventos de compra e de servidor ficam de fora) | o filtro em si está no GameService (lacuna) |
| getState | `Logic.retentionView` (o resto está no GameService/ParkService) | visão somente leitura | `buildState` e ParkService (lacuna) |
| goHome | nenhuma função de Logic (`PivotTo`, `CFrame`, `Workspace`) | nenhuma | tudo: é Roblox |
| dismissTutorial | nenhuma função de Logic: só marca `session.data.tutorialDismissed` no GameService | só indireto, via `Logic.offerEligible` | ver lacunas |

## Matriz de casos

Gerada automaticamente a partir da saída real do `node tests/run_tests.js` da última rodada. "Esperado" é o texto do nome do teste.

Contagem por ação:

| Ação / grupo | Testes | Passam | Falham (BUG) |
|---|---|---|---|
| buyEgg | 5 | 5 | 0 |
| incubate | 4 | 4 | 0 |
| collect | 6 | 6 | 0 |
| place | 8 | 8 | 0 |
| remove | 5 | 5 | 0 |
| buyUpgrade | 6 | 6 | 0 |
| buyShop | 9 | 9 | 0 |
| claimDaily | 7 | 7 | 0 |
| claimQuest | 7 | 7 | 0 |
| claimQuestBonus | 5 | 5 | 0 |
| claimGoal | 8 | 8 | 0 |
| track | 1 | 1 | 0 |
| getState | 1 | 1 | 0 |
| migrate | 15 | 15 | 0 |
| trava | 2 | 2 | 0 |
| recibos | 4 | 4 | 0 |
| passes | 1 | 1 | 0 |
| eventos | 4 | 4 | 0 |
| checkMissions | 1 | 1 | 0 |
| fluxo | 3 | 3 | 0 |
| invariante | 1 | 1 | 0 |
| **Total** | **103** | **103** | **0** |

Matriz completa:

| Ação | Caso | Esperado | Resultado | Nome do teste |
|---|---|---|---|---|
| buyEgg | feliz | cobra o preço cheio e entrega 1 ovo | passa | `buyEgg \| feliz: cobra o preço cheio e entrega 1 ovo` |
| buyEgg | falta de moedas | recusa sem debitar nem dar ovo | passa | `buyEgg \| falta de moedas: recusa sem debitar nem dar ovo` |
| buyEgg | limite de ovos | recusa com 99 ovos mesmo com moedas de sobra | passa | `buyEgg \| limite de ovos: recusa com 99 ovos mesmo com moedas de sobra` |
| buyEgg | repetição | dinheiro exato para 2 ovos; a 3ª falha e o saldo não fica negativo | passa | `buyEgg \| repetição: dinheiro exato para 2 ovos; a 3ª falha e o saldo não fica negativo` |
| buyEgg | fim de semana | preço cai 25% (38) e o débito bate | passa | `buyEgg \| fim de semana: preço cai 25% (38) e o débito bate` |
| incubate | feliz | consome 1 ovo e marca pronto em agora + 12 s | passa | `incubate \| feliz: consome 1 ovo e marca pronto em agora + 12 s` |
| incubate | sem ovos | recusa e não cria incubação | passa | `incubate \| sem ovos: recusa e não cria incubação` |
| incubate | incubadora ocupada | a 2ª tentativa falha e não consome ovo | passa | `incubate \| incubadora ocupada: a 2ª tentativa falha e não consome ovo` |
| incubate | — | incubadora nível 3 encurta para 3 s | passa | `incubate \| incubadora nível 3 encurta para 3 s` |
| collect | antes da hora | recusa e mantém o ovo na incubadora | passa | `collect \| antes da hora: recusa e mantém o ovo na incubadora` |
| collect | exatamente na hora | choca o primeiro ovo como Leafling | passa | `collect \| exatamente na hora: choca o primeiro ovo como Leafling` |
| collect | sem incubação | recusa com 'Nada para coletar.' | passa | `collect \| sem incubação: recusa com 'Nada para coletar.'` |
| collect | inventário cheio (MaxDinos) | recusa e mantém o ovo | passa | `collect \| inventário cheio (MaxDinos): recusa e mantém o ovo` |
| collect | repetição | coletar de novo não choca outro dino | passa | `collect \| repetição: coletar de novo não choca outro dino` |
| collect | — | sorteio no limite (rnd quase 1) dá a espécie mais rara após o 1º ovo | passa | `collect \| sorteio no limite (rnd quase 1) dá a espécie mais rara após o 1º ovo` |
| place | feliz | coloca o dino no habitat e conta a colocação | passa | `place \| feliz: coloca o dino no habitat e conta a colocação` |
| place | id inexistente | recusa sem tocar no habitat | passa | `place \| id inexistente: recusa sem tocar no habitat` |
| place | tipos errados (número, fracionário, negativo, NaN, infinito, booleano, tabela) | todos recusados | passa | `place \| tipos errados (número, fracionário, negativo, NaN, infinito, booleano, tabela): todos recusados` |
| place | string enorme (100 mil caracteres) | recusa sem erro | passa | `place \| string enorme (100 mil caracteres): recusa sem erro` |
| place | nil e string vazia | recusados | passa | `place \| nil e string vazia: recusados` |
| place | repetição | o mesmo dino não entra duas vezes nem conta duas colocações | passa | `place \| repetição: o mesmo dino não entra duas vezes nem conta duas colocações` |
| place | habitat cheio com 1 habitat | o 2º dino é recusado | passa | `place \| habitat cheio com 1 habitat: o 2º dino é recusado` |
| place | limite de 4 habitats | aceita 4 dinos e recusa o 5º | passa | `place \| limite de 4 habitats: aceita 4 dinos e recusa o 5º` |
| remove | feliz | tira do habitat e o dino continua no inventário | passa | `remove \| feliz: tira do habitat e o dino continua no inventário` |
| remove | dino no inventário mas fora do habitat | recusa | passa | `remove \| dino no inventário mas fora do habitat: recusa` |
| remove | id inexistente, nil e número | recusados | passa | `remove \| id inexistente, nil e número: recusados` |
| remove | string enorme | recusa sem erro | passa | `remove \| string enorme: recusa sem erro` |
| remove | repetição | remover duas vezes tira só uma vez | passa | `remove \| repetição: remover duas vezes tira só uma vez` |
| buyUpgrade | feliz | debita o custo do nível e sobe 1 nível | passa | `buyUpgrade \| feliz: debita o custo do nível e sobe 1 nível` |
| buyUpgrade | falta de moedas | custo 100 com saldo 99 não compra | passa | `buyUpgrade \| falta de moedas: custo 100 com saldo 99 não compra` |
| buyUpgrade | exatamente o custo | compra e zera o saldo | passa | `buyUpgrade \| exatamente o custo: compra e zera o saldo` |
| buyUpgrade | nível máximo | recusa sem cobrar | passa | `buyUpgrade \| nível máximo: recusa sem cobrar` |
| buyUpgrade | chave inválida (nil, número, desconhecida, vazia, campo do save, texto enorme) | recusa | passa | `buyUpgrade \| chave inválida (nil, número, desconhecida, vazia, campo do save, texto enorme): recusa` |
| buyUpgrade | — | repetição até o máximo cobra exatamente a soma dos 5 níveis | passa | `buyUpgrade \| repetição até o máximo cobra exatamente a soma dos 5 níveis` |
| buyShop | feliz decoração | entra no inventário e não troca a cerca | passa | `buyShop \| feliz decoração: entra no inventário e não troca a cerca` |
| buyShop | feliz cerca | vira a cerca equipada | passa | `buyShop \| feliz cerca: vira a cerca equipada` |
| buyShop | fora do estoque | recusa mesmo com saldo | passa | `buyShop \| fora do estoque: recusa mesmo com saldo` |
| buyShop | — | item só-recompensa (cerca dourada) nunca é vendido, mesmo listado no estoque | passa | `buyShop \| item só-recompensa (cerca dourada) nunca é vendido, mesmo listado no estoque` |
| buyShop | já possuído | recusa e não cobra de novo | passa | `buyShop \| já possuído: recusa e não cobra de novo` |
| buyShop | falta de moedas (59 para um item de 60) | não marca como possuído | passa | `buyShop \| falta de moedas (59 para um item de 60): não marca como possuído` |
| buyShop | id inválido (nil, número, fracionário, texto enorme, id fora do catálogo) | recusa | passa | `buyShop \| id inválido (nil, número, fracionário, texto enorme, id fora do catálogo): recusa` |
| buyShop | evento de quarta (-20%) | cobra 48 de um item de 60 | passa | `buyShop \| evento de quarta (-20%): cobra 48 de um item de 60` |
| buyShop | estoque real do horário | cada item compra 1 vez; a 2ª rodada é toda recusada | passa | `buyShop \| estoque real do horário: cada item compra 1 vez; a 2ª rodada é toda recusada` |
| claimDaily | feliz no 1º dia | paga o mínimo sem renda, avança o ciclo e conta o resgate | passa | `claimDaily \| feliz no 1º dia: paga o mínimo sem renda, avança o ciclo e conta o resgate` |
| claimDaily | repetição no mesmo dia | a 2ª tentativa não paga nada | passa | `claimDaily \| repetição no mesmo dia: a 2ª tentativa não paga nada` |
| claimDaily | virada do dia | 1 s antes da meia-noite ainda é hoje; à meia-noite já pode resgatar | passa | `claimDaily \| virada do dia: 1 s antes da meia-noite ainda é hoje; à meia-noite já pode resgatar` |
| claimDaily | sem punição | 3 dias sem entrar não zeram o ciclo nem tiram moedas | passa | `claimDaily \| sem punição: 3 dias sem entrar não zeram o ciclo nem tiram moedas` |
| claimDaily | sequência de 7 dias seguidos | ciclo volta a 0 e o dia 7 entrega a cerca dourada | passa | `claimDaily \| sequência de 7 dias seguidos: ciclo volta a 0 e o dia 7 entrega a cerca dourada` |
| claimDaily | — | cerca dourada repetida vira 300 moedas no lugar, sem perder a recompensa | passa | `claimDaily \| cerca dourada repetida vira 300 moedas no lugar, sem perder a recompensa` |
| claimDaily | — | relógio voltando um dia não libera nova recompensa no mesmo calendário | passa | `claimDaily \| relógio voltando um dia não libera nova recompensa no mesmo calendário` |
| claimQuest | feliz | missão concluída paga a recompensa em moedas uma vez | passa | `claimQuest \| feliz: missão concluída paga a recompensa em moedas uma vez` |
| claimQuest | antes de concluir | recusa sem pagar | passa | `claimQuest \| antes de concluir: recusa sem pagar` |
| claimQuest | repetição | resgatar de novo não paga 2 vezes | passa | `claimQuest \| repetição: resgatar de novo não paga 2 vezes` |
| claimQuest | id inválido, inexistente ou de outro dia | recusa | passa | `claimQuest \| id inválido, inexistente ou de outro dia: recusa` |
| claimQuest | depois de expirar | missão de ontem concluída e não resgatada não paga hoje | passa | `claimQuest \| depois de expirar: missão de ontem concluída e não resgatada não paga hoje` |
| claimQuestBonus | antes de receber as 3 missões | recusa | passa | `claimQuestBonus \| antes de receber as 3 missões: recusa` |
| claimQuestBonus | com 2 de 3 recebidas | ainda recusa | passa | `claimQuestBonus \| com 2 de 3 recebidas: ainda recusa` |
| claimQuestBonus | feliz com as 3 | entrega 1 ovo e marca como recebido | passa | `claimQuestBonus \| feliz com as 3: entrega 1 ovo e marca como recebido` |
| claimQuestBonus | repetição no mesmo dia | não entrega de novo | passa | `claimQuestBonus \| repetição no mesmo dia: não entrega de novo` |
| claimQuestBonus | novo dia | o bônus volta a exigir as 3 missões do novo dia | passa | `claimQuestBonus \| novo dia: o bônus volta a exigir as 3 missões do novo dia` |
| claimQuest | — | relógio voltando e voltando de novo não zera as missões já recebidas do dia | passa | `claimQuest \| relógio voltando e voltando de novo não zera as missões já recebidas do dia` |
| claimQuest | — | a 1ª ação do dia (antes de qualquer leitura da tela) conta para a missão 'Compre 1 ovo' | passa | `claimQuest \| a 1ª ação do dia (antes de qualquer leitura da tela) conta para a missão 'Compre 1 ovo'` |
| claimGoal | antes de cumprir | recusa sem pagar | passa | `claimGoal \| antes de cumprir: recusa sem pagar` |
| claimGoal | feliz | 'Choque 3 ovos' entrega 60 moedas | passa | `claimGoal \| feliz: 'Choque 3 ovos' entrega 60 moedas` |
| claimGoal | repetição | a segunda vez não paga | passa | `claimGoal \| repetição: a segunda vez não paga` |
| claimGoal | id inválido (nil, número, inexistente, texto enorme) | recusa | passa | `claimGoal \| id inválido (nil, número, inexistente, texto enorme): recusa` |
| claimGoal | meta mista | 'Descubra as 3 espécies' entrega 1 ovo + 150 moedas | passa | `claimGoal \| meta mista: 'Descubra as 3 espécies' entrega 1 ovo + 150 moedas` |
| claimGoal | — | cosmético já possuído vira 300 moedas no lugar (além das 1000 da meta) | passa | `claimGoal \| cosmético já possuído vira 300 moedas no lugar (além das 1000 da meta)` |
| claimGoal | metas não expiram | resgatar meses depois ainda funciona | passa | `claimGoal \| metas não expiram: resgatar meses depois ainda funciona` |
| claimGoal | — | decoração comprada conta para 'Compre sua 1ª decoração ou cerca' | passa | `claimGoal \| decoração comprada conta para 'Compre sua 1ª decoração ou cerca'` |
| track | lista fechada | só os 4 eventos do cliente passam; eventos de compra e servidor ficam de fora | passa | `track \| lista fechada: só os 4 eventos do cliente passam; eventos de compra e servidor ficam de fora` |
| getState | — | montar a visão não muda moedas, ovos, estatísticas nem histórico de resgates | passa | `getState \| montar a visão não muda moedas, ovos, estatísticas nem histórico de resgates` |
| migrate | — | nil e tipos errados (texto, número, booleano, função) devolvem um save novo | passa | `migrate \| nil e tipos errados (texto, número, booleano, função) devolvem um save novo` |
| migrate | — | save vazio {} vira save novo sem erros | passa | `migrate \| save vazio {} vira save novo sem erros` |
| migrate | — | campos de tipo errado não derrubam o carregamento e viram padrão | passa | `migrate \| campos de tipo errado não derrubam o carregamento e viram padrão` |
| migrate | — | campos a mais são ignorados e não viram estado (inclusive trava do save) | passa | `migrate \| campos a mais são ignorados e não viram estado (inclusive trava do save)` |
| migrate | — | moedas e ovos negativos viram 0; fracionários são arredondados para baixo | passa | `migrate \| moedas e ovos negativos viram 0; fracionários são arredondados para baixo` |
| migrate | — | moedas acima do teto (1e15) são limitadas a 1e12 | passa | `migrate \| moedas acima do teto (1e15) são limitadas a 1e12` |
| migrate | — | NaN em moedas volta ao valor inicial (nunca vira NaN) | passa | `migrate \| NaN em moedas volta ao valor inicial (nunca vira NaN)` |
| migrate | — | id de dino com 100 mil caracteres é descartado | passa | `migrate \| id de dino com 100 mil caracteres é descartado` |
| migrate | — | espécie desconhecida e id repetido são descartados (fica o 1º válido) | passa | `migrate \| espécie desconhecida e id repetido são descartados (fica o 1º válido)` |
| migrate | — | fence de cerca não possuída cai para madeira | passa | `migrate \| fence de cerca não possuída cai para madeira` |
| migrate | eco | no máximo 40 motivos por fluxo | passa | `migrate \| eco: no máximo 40 motivos por fluxo` |
| migrate | — | readyAt em texto descarta a incubação | passa | `migrate \| readyAt em texto descarta a incubação` |
| migrate | — | fence apontando para decoração possuída (poste de luz) vira a cerca equipada | passa | `migrate \| fence apontando para decoração possuída (poste de luz) vira a cerca equipada` |
| migrate | — | nextId menor que o maior id de dino existente gera ids duplicados ao coletar | passa | `migrate \| nextId menor que o maior id de dino existente gera ids duplicados ao coletar` |
| migrate | — | readyAt NaN libera a coleta antes do tempo | passa | `migrate \| readyAt NaN libera a coleta antes do tempo` |
| trava | — | carimbo NaN é tratado como inválido (não bloqueia), como carimbo de tipo errado | passa | `trava \| carimbo NaN é tratado como inválido (não bloqueia), como carimbo de tipo errado` |
| trava | — | carimbo muito no futuro (relógio de outro servidor) bloqueia além de LockSeconds | passa | `trava \| carimbo muito no futuro (relógio de outro servidor) bloqueia além de LockSeconds` |
| recibos | tipo errado, vazio ou texto acima de 64 caracteres | inválido e não grava | passa | `recibos \| tipo errado, vazio ou texto acima de 64 caracteres: inválido e não grava` |
| recibos | produto de tipo errado ou desconhecido | não consome o recibo | passa | `recibos \| produto de tipo errado ou desconhecido: não consome o recibo` |
| recibos | — | recibo de compra antiga (200 compras depois, dentro de 30 dias) continua reconhecido | passa | `recibos \| recibo de compra antiga (200 compras depois, dentro de 30 dias) continua reconhecido` |
| recibos | — | recibo além de 30 dias é podado (e só então pode ser reconhecido de novo) | passa | `recibos \| recibo além de 30 dias é podado (e só então pode ser reconhecido de novo)` |
| passes | id desconhecido ou de tipo errado | recusa; Fundador repetido não duplica | passa | `passes \| id desconhecido ou de tipo errado: recusa; Fundador repetido não duplica` |
| eventos | — | desconto de quarta vale na quarta e acaba na quinta | passa | `eventos \| desconto de quarta vale na quarta e acaba na quinta` |
| eventos | fim de semana | ovo barato no sábado, preço cheio na segunda seguinte | passa | `eventos \| fim de semana: ovo barato no sábado, preço cheio na segunda seguinte` |
| eventos | sábado sem sexta | bônus de visitantes da sexta já não vale | passa | `eventos \| sábado sem sexta: bônus de visitantes da sexta já não vale` |
| eventos | — | evento ativo não aparece em 'próximos' | passa | `eventos \| evento ativo não aparece em 'próximos'` |
| checkMissions | — | 'Compre uma melhoria' não conta quando a 1ª compra é a reforma (4000 moedas) | passa | `checkMissions \| 'Compre uma melhoria' não conta quando a 1ª compra é a reforma (4000 moedas)` |
| fluxo | — | sessão nova até a primeira melhoria (missões pagam 50, 75 e 100) | passa | `fluxo \| sessão nova até a primeira melhoria (missões pagam 50, 75 e 100)` |
| fluxo | encher habitat e inventário | 4 habitats, 60 dinossauros, recusas nos limites e metas | passa | `fluxo \| encher habitat e inventário: 4 habitats, 60 dinossauros, recusas nos limites e metas` |
| fluxo | semana de logins diários com faltas | sem punição, calendário avança só com resgates | passa | `fluxo \| semana de logins diários com faltas: sem punição, calendário avança só com resgates` |
| invariante | fuzz | 3000 ações aleatórias (sorteio fixo) mantêm moedas ≥ 0, livro-razão, ids e habitat válidos | passa | `invariante \| fuzz: 3000 ações aleatórias (sorteio fixo) mantêm moedas ≥ 0, livro-razão, ids e habitat válidos` |

## Bugs encontrados e corrigidos

Os 9 bugs foram reproduzidos na rodada 1 pelo teste indicado, com a saída real abaixo ("Esperado" e "Obtido" são os da rodada 1). Na rodada 2, cada um foi corrigido e o teste passa. Os nomes dos testes perderam o prefixo `BUG:`, porque agora passam.

### B1. Primeira ação do dia não conta para a missão diária — média-baixa

- **Teste:** `claimQuest | a 1ª ação do dia (antes de qualquer leitura da tela) conta para a missão 'Compre 1 ovo'`
- **Rodada 1:** esperado progresso 1, obtido 0.
- **Causa:** a base das missões do dia só era recalculada em `Logic.rollDay`, que roda dentro de `retentionView`/`claimX`. Uma ação que muda estatística era contada antes desse recálculo.
- **Correção:** `buyEgg`, `buyShop`, `collect`, `buyUpgrade` e `place` agora chamam `rollDay` antes de mudar estatística (helper `syncDay`). `buyUpgrade` e `place` ganharam um parâmetro `now` opcional. No GameService, `buyUpgrade`/`place` passam `os.time()`, e o tick de renda chama `Logic.rollDay` antes de somar.

### B2. "Compre uma melhoria" não conta quando a 1ª compra é a reforma — média-baixa

- **Teste:** `checkMissions | 'Compre uma melhoria' não conta quando a 1ª compra é a reforma (4000 moedas)`
- **Rodada 1:** esperado `missions.upgrade == true`, obtido `false`.
- **Causa:** `checkMissions` ignorava `renovation` na soma de melhorias.
- **Correção:** a soma passa a incluir `renovation`.

### B3. Recibo podado é concedido de novo — média (hoje inativo: monetização desligada)

- **Teste:** `recibos | recibo de compra antiga (200 compras depois, dentro de 30 dias) continua reconhecido`
- **Rodada 1:** esperado `already`, obtido `granted`.
- **Causa:** `pruneReceipts` apagava os recibos mais antigos ao passar de 200, então um `PurchaseId` antigo voltava a ser pago.
- **Correção:** poda por idade. Recibos ficam reconhecidos por `Config.Monetization.ReceiptKeepSeconds` (30 dias, bem acima da janela de reenvio do Roblox). O teto por contagem subiu para 2000 e vira só uma proteção contra volume absurdo. O teste antigo de `logic_test.lua` que esperava poda por teto de 200 foi ajustado para a nova regra.
- **Ponto a confirmar:** a janela de 30 dias é uma hipótese. A documentação do Roblox sobre o tempo de reenvio do `ProcessReceipt` deve ser conferida antes de ligar a monetização.

### B4. Carimbo de trava muito no futuro bloqueia além de `LockSeconds` — média-baixa

- **Teste:** `trava | carimbo muito no futuro (relógio de outro servidor) bloqueia além de LockSeconds`
- **Rodada 1:** esperado não bloquear, obtido bloqueou.
- **Causa:** `lockedByOther` usava `now - t < lockSeconds`, então um carimbo no futuro bloqueava até o relógio alcançá-lo.
- **Correção:** carimbo com `t > now + lockSeconds` é tratado como inválido (não bloqueia).

### B5. Id de dinossauro repetido depois de `migrate` com `nextId` baixo — média (hoje só com save corrompido)

- **Teste:** `migrate | nextId menor que o maior id de dino existente gera ids duplicados ao coletar`
- **Rodada 1:** esperado ids únicos, obtido repetidos.
- **Correção:** `migrate` ajusta `nextId` para ser maior que o maior `dN` já carregado.

### B6. `claimDaily` paga de novo quando o relógio volta um dia — baixa

- **Teste:** `claimDaily | relógio voltando um dia não libera nova recompensa no mesmo calendário`
- **Rodada 1:** esperado `false`, obtido `true`.
- **Correção:** a recompensa só é liberada se `today > lastClaimDay`.

### B7. Flags de missões somem quando o relógio volta — baixa

- **Teste:** `claimQuest | relógio voltando e voltando de novo não zera as missões já recebidas do dia`
- **Rodada 1:** esperado `claimed == true`, obtido `false`.
- **Correção:** `rollDay` só avança o dia quando `today > daily.day`. Relógio para trás não zera as flags nem o bônus.

### B8. Fence de decoração equipada pelo `migrate` — baixa

- **Teste:** `migrate | fence apontando para decoração possuída (poste de luz) vira a cerca equipada`
- **Rodada 1:** esperado `"wood"`, obtido `"lamp"`.
- **Correção:** `migrate` só aceita `fence` se o item do catálogo tiver `kind == "fence"` e estiver possuído.

### B9. `readyAt` NaN libera a coleta antes do tempo — baixa

- **Teste:** `migrate | readyAt NaN libera a coleta antes do tempo`
- **Rodada 1:** esperado coleta recusada, obtido coleta feita.
- **Correção:** `migrate` só aceita `readyAt` finito.

## Lacunas: o que não dá para testar fora do Studio

Regras que estão só no servidor (fora de `Logic`) ou que dependem do Roblox. Nenhum código foi reescrito para testá-las.

1. **Validação de entrada do `GameService.onRequest`:** tipo de `action`, limite de 24 caracteres, `payload` precisa ser tabela, handler desconhecido, e o limite de frequência (`Config.RequestMinInterval`, medido com `os.clock()`).
2. **`dismissTutorial`:** a ação só marca um campo no GameService. Não há função em `Logic`.
3. **`track`:** o filtro `Config.ClientEvents[name]` está no GameService. Testei só a lista.
4. **`goHome`, entrada do parque, plots, decorações, texto da incubadora:** `ParkService` e Roblox.
5. **Carga e salvamento (`DataService`):** falha de carga leva a `canSave=false`; `UpdateAsync` da trava; retries; `MinSaveGap`; autosave; `BindToClose`. Só `lockedByOther`, `record` e `migrate` são puros e foram testados.
6. **Condição de ganho offline no `onPlayerAdded`:** `earned > 0 and not session.isNew` está no GameService.
7. **`MonetizationService`:** `ProcessReceipt` (salvar antes de `PurchaseGranted`, `NotProcessedYet`), `PromptGamePassPurchaseFinished`, e a flag `Enabled`. Só `Logic.processReceipt` e `Logic.grantPass` foram testados. Monetização está desligada.
8. **Telemetria:** o disparo em `logAction` (funil, `insufficient_coins`) e a ordem de `flushEconomy` ficam no GameService.
9. **Concorrência:** dois servidores ao mesmo tempo e duas ações dentro do intervalo mínimo não podem ser simulados em Lua pura.
10. **UI do cliente** (`DinoParkClient`, `RetentionClient`): textos, cores e layout não são testados.

## Observações e decisões a confirmar (não viraram falha)

- **Recompensas ignoram `MaxEggs`:** `buyEgg` recusa com 99 ovos, mas recompensas diárias, de missão e de meta somam ovos sem esse limite. Não há teste porque o comportamento desejado não está escrito.
- **Missão diária não resgatada expira sem pagar:** o teste `claimQuest | depois de expirar` fixa essa escolha. O `RETENTION_MONETIZATION_PLAN.md` não diz se a recompensa atrasada deve existir.
- **"Coloque 1 dinossauro" conta colocar, remover e colocar de novo**, porque `placements` conta cada colocação. Impacto baixo.
- **Fuzz com muitas recusas:** cerca de 78% das ações sorteadas são recusadas, por causa das entradas inválidas. Isso cobre bem os caminhos de recusa. Não é teste de carga.

## Fluxos ponta a ponta (passam)

1. **Sessão nova até a 1ª melhoria:** moedas 100 → 150 (missão "choque", +50) → 225 (missão "colocar", +75) → 249 (1 min de renda, 12 pagamentos de 2) → 149 (compra "Mais visitantes") → 249 (missão "melhoria", +100). O livro-razão fecha.
2. **Encher habitat e inventário:** 4 habitats após 3 melhorias de habitat; 60 dinossauros chocados; 5º habitat recusado; troca de habitat funciona; coleta com inventário cheio recusada e ovo mantido; metas de 4 habitats e de 50 ovos pagas; livro-razão fecha.
3. **Semana de logins com faltas:** 10 dias com 7 entradas e 3 faltas. Em cada falta, o resgate continua disponível, as moedas não caem e o contador não muda. As 7 recompensas somam 440 moedas e 4 ovos; a cerca dourada é entregue no 7º resgate. Na semana seguinte, o resgate volta ao dia 1 (+40 moedas). O livro-razão fecha.

## Próximos passos

- Revisar as três observações acima (MaxEggs em recompensas, expiração de missão, contagem de colocação).
- Conferir na documentação do Roblox a janela de reenvio de `ProcessReceipt` antes de ligar a monetização (B3).
- Testar no Studio os itens da seção de lacunas, principalmente DataStore com trava e `ProcessReceipt`. Nada disso foi testado.
