# Playtest Dino Park Tycoon: fluxos felizes e infelizes (2026-10-26)

Sessão: Haiku (Studio MCP). Place1 (`a665e277-1142-4a88-8ffd-9d51fb012a2f`), resolução 1511×781.

## 0. Ambiente e limites

- **Código testado = HEAD `fc1575c`** (main). Verificado por checksum (`h=(h*31+byte)%2147483629`, bytes) no place. Para `Config`, `Logic`, `GameService`, `DinoParkClient`, `RetentionClient`, `Telemetry`, `MonetizationService` e `DinoModels` a conferência foi contra `git show HEAD:...`. `DataService`, `ParkService` e `DinoParkMain` batiam com a árvore que estava limpa no início (= HEAD).
- **Divergência durante a sessão:** depois da instalação apareceram mudanças **não commitadas** em `src/ReplicatedStorage/Shared/Config.lua`, `Logic.lua`, `src/.../GameService.lua`, em `installer/Parte2_Scripts.lua`, em `tests/` e em `docs/tests/` (WIP de outra sessão). O place **não** contém esse WIP; estes resultados valem só para o `fc1575c`.
- Nada foi commitado. Não editei `src/`, `scene/`, `tests/` nem `installer/`. `node tools/build.js` foi rodado no início (árvore limpa; o `installer/` gerado era idêntico ao commitado).
- **DataStore indisponível no Studio:** `You must publish this place to the web to access DataStore.` O jogo entra com `canSave=false`, e o HUD mostra "Progresso não é salvo nesta sessão". Todo o salvamento, a trava de sessão e o resgate após reentrada ficaram **NÃO TESTADOS**.
- **HTTP** continuou desligado. **Config.Analytics.Debug** foi mudado para `true` só no place, para observar a telemetria, e voltou a `false` (checksum conferido: len 11794, h 795794750).
- **Incidente de procedimento (meu):** na primeira instalação o `RetentionClient` foi criado sem `Parent`. Detectado no teste (sem a GUI "Hoje"), reinstalado e conferido. Holder temporário `ServerStorage.__DinoInstaller` removido.
- **Cenário** (`Workspace.DinoParkWorld`): Ground, Bounds (Wall e WallInvisible), Plaza, Gate, Trees, Rocks e ParkSpawn conferem com `scene/SceneBuilder.lua` nas propriedades checadas (não foi um diff completo).
- **Chamadas diretas ao `Request` (InvokeServer)** foram usadas em: ataques, spam, checagem de resgates (diário, missão, meta) e uma compra de diário, porque o botão "Receber recompensa de hoje" não é clicável no fluxo normal (BUG-05 e BUG-01). Estão marcadas como "probe" na tabela.
- **Teleporte** do personagem foi usado só para posicionar (paredes, queda, rocha). Os movimentos das paredes foram feitos com teclas.

## 1. Tabela de casos

Resultado: **OK**, **FALHA** ou **NÃO TESTADO**.

### 1a. Fluxos felizes

| ID | Fluxo | Passos | Esperado | Obtido | Resultado |
|---|---|---|---|---|---|
| F01 | Loop completo | Ovo → Incubar → aguardar → Coletar → revelação → "Colocar no habitat" | Ovo incuba (12 s), revelação mostra espécie e raridade, dino vai ao habitat | "Chocando... 0:11"; "NOVO DINOSSAURO! Leafling / COMUM"; "No habitat"; missão "Choque seu primeiro ovo" +50 | OK |
| F02 | Revelação "Guardar para depois" | Coletar → "Guardar para depois" → Coleção → "Colocar" | Dino fica na coleção (Disponível) e depois vai ao habitat | Dino listado como "Disponível", botão "Colocar"; após colocar, "No habitat" | OK |
| F03 | Comprar ovo | Ovo → "Comprar" | −50 moedas, +1 ovo | Contagem de ovos e moedas corretas | OK |
| F04 | Melhorias (renda) | Melhorias → "Mais visitantes" (100) | Nível 1, renda +25%→+50% | "Renda: +25% → +50%" | OK |
| F05 | Melhorias (incubadora) | "Incubadora rápida" (120) | Incubação 12 s → 9 s → 6 s por nível | "Incubação: 12 s → 9 s", depois "9 s → 6 s" | OK |
| F06 | Melhorias (habitat) | "Novo habitat" (150) | Habitats +1 | Coleção "2/2" (habitats), depois "Habitats: 2 → 3" | OK |
| F07 | Melhorias (Reforma do parque) | Abrir Melhorias, rolar até o fim | Card com botão de compra e linha de efeito | Card sem botão e sem linha de efeito; erro no console (BUG-02) | **FALHA** |
| F08 | Missões automáticas | Completar as 3 missões de primeiro passo | Recompensas pagas (+50, +75, +100) | Aba Missões "Concluídas: 3 de 3"; moedas creditadas | OK |
| F09 | Loja cosmética | Loja → "Jardim de pedras" (55) | Compra única; item vira "Na coleção" | Item comprado; moedas −55; "Na coleção" | OK |
| F10 | Coleção (habitat cheio) | Guardar / Colocar / "Sem vaga" | Só cabe 1 dino por habitat livre | "Sem vaga" com habitat cheio; "Guardar" libera a vaga | OK |
| F11 | Meu Parque | Clicar "Meu Parque" | Teleporta para o portão do parque | Posição (−32, 3.3, −50); toast "Bem-vindo ao seu parque!" | OK |
| F12 | Painel "Hoje": abrir | Clicar "Hoje" (canto superior esquerdo) | Painel abre | Nada acontece (BUG-01) | **FALHA** |
| F13 | Painel "Hoje": conteúdo (lido) | Com a GUI principal oculta (contorno de diagnóstico, só em runtime) | Calendário de 7 dias, missões, metas, coleção, eventos e loja | Calendário correto (Dia 1 "disponível agora", 90 moedas, Dia 7 com cerca dourada); dica de habitat | OK (leitura) |
| F14 | Painel "Hoje": abas | Clicar em Missões (com o chat desligado) | Troca o conteúdo | Troca: "Missões do dia (novas em 1:40:03)". Com o chat ligado, o painel nem abre (BUG-01) | OK (chat desligado); FALHA com chat padrão (BUG-01) |
| F15 | Resgate diário (probe) | `claimDaily` | Recompensa do dia, ciclo avança | `ok=true`, "Recompensa diária: 72 moedas!" (valor depende da renda) | OK (probe) |
| F16 | Resgate diário pelo botão | Clicar "Receber recompensa de hoje" | Recebe a recompensa | Botão fica na última posição da lista, fora da área visível sem rolagem (BUG-05). Clique em y≈858 não atinge o botão | **NÃO TESTADO** (UI) |
| F17 | Missões do dia / bônus / metas (recusas) | `claimQuest` sem progresso, `claimQuestBonus`, `claimGoal` | Recusa com mensagem | "Missão ainda não concluída.", "Receba todas as missões do dia primeiro.", "Meta ainda não concluída." | OK (probe) |
| F18 | Missões diárias (resgate com sucesso) | Completar uma missão e resgatar | Recompensa paga uma vez | Não houve missão concluída de hoje para resgatar; UI bloqueada | **NÃO TESTADO** |
| F19 | Eventos | Ler o calendário | Sem evento ativo na segunda; próximos: quarta, sexta, fim de semana | Via `Logic` (cliente): sem evento ativo; próximos corretos | OK (dados). Aba Eventos: **NÃO TESTADO** (UI) |
| F20 | Guia da loja | Ler o guia (dados) | Itens só em moedas (Robux desligado) | Ovo, 4 melhorias, decorações; sem compras Robux | OK (dados). Aba Loja: **NÃO TESTADO** (UI) |
| F21 | Telemetria | `Config.Analytics.Debug=true` (no place) | Eventos aparecem no console | `[Telemetry] egg_bought`, `shop_view`, `insufficient_coins`, `economia sink egg 50 50` | OK, com erro (BUG-04) |
| F22 | Ganhos offline / boost / eventos ativos / rotação de dias | Reentrar, aguardar dias | Efeitos corretos | Exige DataStore e tempo real | **NÃO TESTADO** |

### 1b. Fluxos infelizes

| ID | Fluxo | Passos | Esperado | Obtido | Resultado |
|---|---|---|---|---|---|
| U01 | Ovo sem moedas | Comprar ovos até zerar; clicar "Faltam 50" | Recusa com aviso | Botão "Faltam 50"; toast "Faltam 50 moedas para comprar um ovo."; probe: "Moedas insuficientes." | OK |
| U02 | Melhoria sem moedas | Clicar "Faltam 47" em "Novo habitat" | Recusa com aviso | Toast "Faltam 47 moedas para Novo habitat." | OK |
| U03 | Loja sem moedas | Clicar "Faltam 694" na Cerca lava (800) | Recusa com aviso | Toast com o valor faltante | OK |
| U04 | Resgate diário 2× | `claimDaily` três vezes | Só o primeiro paga | 1ª: ok (72 moedas); 2ª e 3ª: "Você já recebeu hoje. Volte amanhã!" | OK (probe). UI: **NÃO TESTADO** |
| U05 | Resgate de missão/meta 2× | Resgatar missão e meta concluídas, de novo | Só a primeira paga | Não houve missão/meta concluída para resgatar pela UI | **NÃO TESTADO** (só recusas, F17) |
| U06 | Cliques repetidos rápidos (compra) | 3 cliques em "Jardim de pedras"; 3 cliques em "Colocar" | Uma compra e uma colocação | Uma compra (55 moedas); uma colocação ("Dinossauro no habitat!") | OK |
| U07 | Spam (servidor) | 15 `buyEgg` em loop | Sem duplicação; saldo nunca negativo | 2 compras legítimas (143 → 43, 100 moedas = 2 ovos); 10 "Devagar!"; 3 "Moedas insuficientes." | OK |
| U08 | Colocar com habitat cheio | Coleção "Sem vaga"; reveal com "Sem habitat livre" | Não coloca; avisa | Toast "Sem habitat livre. Compre um novo em Melhorias." | OK |
| U09 | Coletar antes de chocar | Clicar "Aguarde" durante a incubação | Não coleta; mostra tempo | Toast "Ainda não chocou: faltam 0:05." | OK |
| U10 | Incubar sem ovo | Com 0 ovos, clicar "Incubar" | Não incuba; avisa | Toast "Você não tem ovos. Compre um abaixo."; probe: "Você não tem ovos." | OK |
| U11 | Abrir/fechar painéis rápido | 6 cliques em abas em sequência, depois abrir/fechar | Estado final correto, sem resíduo | Estado final correto; sem erro novo além de BUG-02 | OK |
| U12 | Dois painéis ao mesmo tempo | Abrir painel principal + "Hoje" | Sem sobreposição que impeça uso | Geometria: principal x∈[405,1105] y∈[115,612]; "Hoje" x∈[15,577] y∈[155,580]. Sobrepõe 172 px de largura. "Hoje" não abre por clique (BUG-01). Sobreposição **confirmada por geometria**, não visualmente | FALHA (sobreposição) / **NÃO TESTADO** (uso simultâneo) |
| U13 | Parede +X | Setup em x=124; D + 2 pulos | Para dentro do limite | Parou em x=128.9 | OK |
| U14 | Parede −X | Setup em x=−124; A + 2 pulos | Idem | Parou em x=−128.9 | OK |
| U15 | Parede −Z | Setup em z=−124; W + 2 pulos | Idem | Parou em z=−128.9 | OK |
| U16 | Parede +Z | Setup em z=124; S + 2 pulos | Idem | Parou em z=128.9 | OK |
| U17 | Passou dos limites | Teleporte para x=150 | Volta ao spawn | Voltou para (0, 4, 85) em <2 s | OK |
| U18 | Queda do mapa | Teleporte para y=−20 | Volta ao spawn | Voltou para (0, 4, 85) em <2 s | OK |
| U19 | Em cima de objetos | Em cima da rocha Rock1 e da copa de Tree1 | Permanece; não é resgatado | Permaneceu em ambos | OK |
| U20 | Ataque: tipos e ids | `place` com id −1, "nope", 123, tabela; payload string; `buyShop` com "fence_gold" (reward-only), "nope", nil; `remove` id inexistente; `claimGoal`/`claimQuest` com id inválido ou número | Recusa, sem moedas nem itens | Todas recusadas com mensagem apropriada (ver A1–A17 abaixo). Moedas só variaram pela renda | OK |
| U21 | Ataque: ação | Action numérica (5), action desconhecida ("giveCoins"), action com 30 caracteres | Recusa | "Pedido inválido.", "Ação desconhecida.", "Pedido inválido." | OK |
| U22 | Ataque: telemetria | `track` com `purchase_granted` (fora da lista) | Ignorado | `ok=true`, mensagem vazia; servidor ignora (sem efeito) | OK (nota: responde ok=true) |
| U23 | Persistência, trava de sessão, reentrada | Salvar, sair, voltar | Progresso preservado | DataStore indisponível no Studio | **NÃO TESTADO** |

Registro dos ataques (probes, todos com `ok=false` quando devido):

| # | Chamada | Resposta |
|---|---|---|
| A1 | `place {id=-1}` | Dinossauro inválido. |
| A2 | `place {id="nope"}` | Você não tem esse dinossauro. |
| A3 | `place {id=123}` | Dinossauro inválido. |
| A4 | `place {id={}}` | Dinossauro inválido. |
| A5 | `place` com payload `"x"` (string) | Pedido inválido. |
| A6 | action `5` | Pedido inválido. |
| A7 | action `"giveCoins"` | Ação desconhecida. |
| A8 | action com 30 caracteres | Pedido inválido. |
| A9 | `buyUpgrade {key="hack"}` | Melhoria inválida. |
| A10 | `buyUpgrade {key=1}` | Melhoria inválida. |
| A11 | `buyShop {id="fence_gold"}` (reward-only) | Esse item não está na loja agora. |
| A12 | `buyShop {id="nope"}` | Esse item não está na loja agora. |
| A13 | `buyShop` sem payload | Item inválido. |
| A14 | `remove {id="d999"}` | Ele não está no habitat. |
| A15 | `claimGoal {id="g_fake"}` | Meta inválida. |
| A16 | `claimQuest {id="q_fake"}` | Essa missão não é de hoje. |
| A17 | `claimQuest {id=7}` | Missão inválida. |
| A18 | `track {name="purchase_granted"}` | ok=true, sem efeito. |

## 2. Bugs

### BUG-01 — **CORRIGIDO** (botão e painel movidos para o canto inferior esquerdo em `src/StarterPlayer/StarterPlayerScripts/RetentionClient.client.lua`; verificado no place com o chat ligado: o botão abre o painel e a aba "Missões" troca o conteúdo). Descrição original abaixo.

### BUG-01 (causa encontrada): o chat padrão do Roblox cobre o botão "Hoje" (severidade: ALTA)
- **Causa confirmada por experimento:** o chat padrão do Roblox (CoreGui) fica no canto superior esquerdo do Play e intercepta os cliques ali. Com o chat **ligado**, o botão "Hoje" (67,122) não recebe nenhum clique. Com o chat **desligado** (`StarterGui:SetCoreGuiEnabled(Chat, false)`), o mesmo clique abre o painel (contador do botão incrementa e `panel.Visible=true`). Reproduzido ligando/desligando só o chat, com o restante do estado igual.
- **Impacto:** o botão "Hoje" e as abas do painel (que ficam na mesma faixa, y≈207–242) ficam inacessíveis para quem mantém o chat padrão. Nenhum dos experimentos anteriores (ocultar o Root, desligar a DinoParkUI) mudou o resultado; a observação antiga de que o Root causava o bloqueio **estava errada**.
- **Como verificar sem diagnóstico:** Play limpo, 1 ovo chocado, clique em "Hoje" com o chat ligado (não abre) e depois desligado (abre).
- **Caveat:** o teste foi feito no Studio, onde o chat padrão está ligado. Em um cliente real, a posição do chat depende de o jogador ter o chat aberto ou minimizado.

### BUG-01 (histórico de verificação, Play limpo)
- **Passos:** 1) Play limpo, comprar/incubar/coletar 1 ovo (o botão "Hoje" aparece); 2) clicar no botão "Hoje" (canto superior esquerdo, abaixo da HUD).
- **Esperado:** o painel "Hoje" abre.
- **Obtido:** nada. Painel continua `Visible=false`. Sem erro no console. Reproduzido em 3 variações de clique real: clique simples em (67,122); pressionar e soltar em (40,135); clique em (90,105). Também com `Root` oculto (runtime), em play limpo, sem listeners de diagnóstico: continua fechado.
- **Correção do diagnóstico anterior:** antes eu escrevi que ocultar `DinoParkUI.Root` fazia o botão responder. Isso **não se reproduziu** em play limpo. Aquela observação aconteceu só dentro da sessão com listeners de diagnóstico ligados, então não é confiável. **A causa segue não confirmada.** O `InputBegan` chega com a posição correta, mas o `MouseButton1Down/Click` do botão não é disparado.
- **Impacto:** a retenção inteira (recompensa diária, missões, metas, eventos, guia) fica inacessível pelo clique, num jogo que depende dela.
- **Impacto:** a retenção inteira (recompensa diária, missões, metas, eventos, guia) fica inacessível pelo clique, num jogo que depende dela.

### BUG-02: card "Reforma do parque" sem botão e erro de render (severidade: ALTA)
- **Passos:** Melhorias → rolar até "Reforma do parque".
- **Esperado:** card com nível, efeito e botão de compra.
- **Obtido:** card sem botão e sem a linha de efeito. Cada abertura do painel repete o erro.
- **Console:** `Players.<player>.PlayerScripts.DinoParkClient:246: attempt to perform arithmetic (mul) on number and nil`, em `effectText` (linha 709 em `renderers.upgrades`).
- **Causa:** `effectText` cai no ramo da incubação para qualquer chave que não seja `slots` nem `income`. `Config.Upgrades.renovation` não tem `reduction`.
- **Impacto:** a Reforma (4.000 a 900.000 moedas) não pode ser comprada pela UI, então a meta **"Todas as melhorias no máximo"** (`g_upall`) fica inalcançável. Também bloqueia a melhoria de fim de jogo.

### BUG-03: NÃO é bug separado. Mesma causa do BUG-01 (chat), e as abas funcionam.
- **Com o chat desligado:** clicar em "Missões" (160,225) troca o conteúdo ("Missões do dia (novas em 1:40:03)"). Funciona.
- **A falha anterior** foi o chat cobrindo a faixa das abas, além de um erro de teste meu: eu tinha deslocado o painel para fora da tela e não restaurei (o que também fazia as abas irem para (−3647,−3697)). Corrigido e registrado aqui.
- Para testar as abas com o chat ligado, é preciso antes corrigir o BUG-01.

### BUG-04: telemetria de economia gera erro em toda transação (severidade: MÉDIA)
- **Passos:** `Config.Analytics.Debug=true` no place, Play, comprar um ovo.
- **Console:**
  ```
  argument #6 expects a string, but EnumItem was passed
  Script 'ServerScriptService.DinoParkServices.Telemetry', Line 66
  Script 'ServerScriptService.DinoParkServices.Telemetry', Line 63 - function economy
  ```
- **Causa:** `Telemetry.economy` passa `Enum.AnalyticsEconomyTransactionType[...]` onde o `LogEconomyEvent` espera string. Além disso, `balance` e `amount` estão trocados na chamada (`LogEconomyEvent(player, flowType, "Coins", balance, amount, txType, reason)`): o 4º argumento é o valor da transação e o 5º é o saldo final. **Confirmar contra a documentação da API do Roblox.**
- **Impacto:** o erro aparece a cada evento de economia. Os dados enviados podem estar errados. O `pcall` não impede o log.

### BUG-05: resgate diário fora da área visível (severidade: MÉDIA, UX)
- **Passos:** abrir "Hoje" → aba "Diário".
- **Esperado:** o botão principal "Receber recompensa de hoje" visível de imediato.
- **Obtido:** ele fica depois de 7 cartões (~500 px abaixo do topo do painel). Em 1511×781, fica fora da tela sem rolagem.

### BUG-06: recusas no painel "Hoje" são silenciosas (severidade: BAIXA)
- **Origem:** leitura do código em `RetentionClient.client.lua`, função `request`. A mensagem só é mostrada quando `result.ok` é verdadeiro. Recusas como "Você já recebeu hoje" não aparecem ao jogador. **Não reproduzido pela UI** (BUG-01 e BUG-03).

### BUG-07: sobreposição de painéis (severidade: BAIXA)
- **Observado por geometria:** painel principal x∈[405,1105], y∈[115,612]; "Hoje" x∈[15,577], y∈[155,580]. Os dois se sobrepõem em 172 px de largura.
- **Obtido:** a `DinoParkUI` está acima, então o painel principal cobre a parte direita do "Hoje" quando os dois estão abertos. Não reproduzido por clique (BUG-01 e BUG-03).

### Observações menores
- Ação `track` com evento fora da lista responde `ok=true` (o servidor ignora, sem efeito).
- O guia da loja mostra "50+ moedas" para o ovo (texto de copy).
- O HUD mostra "Progresso não é salvo nesta sessão" quando `canSave=false`. Correto para o Studio.

## 3. O que funcionou
- Loop completo de ovo (comprar, incubar, coletar, revelar, colocar, guardar).
- Revelação com "Colocar no habitat" e "Guardar para depois", incluindo habitat cheio.
- Melhorias de renda, incubadora e habitat, com preços e efeitos corretos.
- Missões automáticas com recompensas corretas.
- Loja: compra única, "Na coleção", aviso de moedas faltando.
- Avisos de moedas insuficientes e de coleta antes de chocar.
- Meu Parque com toast de boas-vindas.
- Paredes nos quatro lados, resgate ao passar dos limites e ao cair do mapa, em cima de rochas e árvores.
- Servidor recusa todos os ataques de tipo, id e ação, sem dar moedas nem itens.
- Spam não duplica compra.
- Resgates (diário, missão, meta) não pagam duas vezes e recusam corretamente quando não estão prontos.
- Telemetria de eventos (`egg_bought`, `shop_view`, `insufficient_coins`, `session_start`) aparece no console com Debug ligado.

## 4. O que não foi testado
- **Persistência:** salvar, sair, voltar, trava de sessão, `BindToClose` e ganhos offline. Motivo: DataStore indisponível no Studio.
- **Painel "Hoje" por clique:** resgate diário pelo botão, missões, metas, eventos, coleção e loja (BUG-01 e BUG-03). Só dados lidos e probes.
- **Ciclo diário:** virada de dia, sequência de 7 dias, boost ativo e eventos com desconto.
- **Robux:** desligado por flag (nada a testar).
- **Multiplayer:** dois jogadores, limite de 4 parques, servidor cheio.
- **Responsividade:** só resolução 1511×781. Sem mobile.
- **Visual:** sem captura de tela. Sobreposição medida por geometria.
- **Telemetria de funil:** `LogFunnelStepEvent` aparece como "fired", mas o conteúdo não foi validado.
- **Mudança de WIP:** o `src/` com mudanças não commitadas (Config, Logic, GameService) não foi instalado nem testado.

## 5. Próximos passos sugeridos
1. Corrigir BUG-02 (ramo de `effectText` para `renovation`) e testar a meta `g_upall`.
2. Investigar BUG-01 e BUG-03 (o painel "Hoje" é inacessível por clique) antes de qualquer outro teste de retenção.
3. Corrigir a argumentação de `LogEconomyEvent` (BUG-04), depois de confirmar a documentação.
4. Publicar o place na web para testar o DataStore, a persistência e a trava de sessão.
5. Repetir a sessão com o `src/` atual (WIP) depois que a outra sessão commitar.
