# Dino Park Tycoon — Retenção, economia e monetização

Skills usadas (já instaladas em `.claude/skills/roblox-skills/`, pacote AshExplained, nada foi baixado): `roblox-retention-monetization`, `roblox-economy-balancing`, `roblox-monetization-optimization`; apoio: `roblox-quest-progression-systems`, `roblox-security-economy`, `roblox-analytics-instrumentation`, `roblox-policy-compliance`.

> **Status honesto:** tudo abaixo está **implementado e coberto por testes de lógica** (36 testes, `node tests/run_tests.js`). **Nada foi testado no Roblox Studio** (estava em Play de outra sessão e não foi interrompido), **nada foi testado com jogadores reais** e **nenhuma métrica existe ainda**. Todos os números são hipóteses. A seção 9 lista o que não foi verificado.

## 1. Princípios
1. Jogar normalmente alcança todo o conteúdo; compras (futuras) são conveniência ou cosmético.
2. Voltar é recompensado, faltar nunca é punido (sem streak que zera, sem relógio de urgência, sem escassez falsa).
3. O servidor decide moedas, recompensas, inventário e (futuramente) recibos.
4. Nada de oferta no tutorial, na 1ª sessão, em pop-up ou em contexto de pressão. Público com muitos menores: sem loot box pago, chances sempre visíveis, sem “FOMO” agressivo.
5. Robux: **desligado** até o loop estar testado (regra do projeto).

## 2. Progressão (curto / médio / longo prazo)
| Prazo | O que existe | Onde |
|---|---|---|
| Minutos | Missões iniciais (3), ovo → incubar → colocar, 1º habitat extra | `Config.Missions`, melhorias |
| Dia | 3 missões diárias determinísticas + bônus “todas” (+1 ovo) | `Config.DailyQuestPool` |
| Dias | Calendário de 7 recompensas (ovos, impulso, cerca dourada no dia 7) | `Config.DailyRewards` |
| Semanas | 10 metas (curto/médio/longo), coleção de espécies (dex), cercas premium (800–1500 moedas) | `Config.Goals`, `ShopCatalog` |
| Longo | **Reforma do parque** (6 níveis, +10% renda cada; 4k → 900k) e metas “50 ovos”, “50.000 moedas”, “tudo no máximo” (cerca real) | `Config.Upgrades.renovation` |

Mostrado ao jogador pelo botão **Hoje** (`RetentionClient.client.lua`): Diário, Missões, Metas, Coleção, Eventos, Loja (guia). O botão só aparece depois do 1º ovo chocado, para não competir com o tutorial.
Limites desta entrega: só 3 espécies (novas exigem modelos 3D), 4 habitats (cenário fixo), melhorias “visíveis” só pelas decorações/cerca existentes.

## 3. Retorno ao jogo (sem punir)
- Recompensa diária: reclamar avança o ciclo; ausência de dias **não zera nada** (`Logic.claimDaily`, teste “sem punir ausência”). Dia 7 = cosmético prometido desde o dia 1; se já o possui, vira 300 moedas.
- Dia do jogo vira às 00:00 de Brasília (`Config.DayOffsetSeconds`), igual em todos os servidores.
- Missões do dia sorteadas pelo número do dia (iguais para todos, previsíveis).
- Loja rotativa já existente (a cada 30 min); itens só-recompensa nunca entram nela.
- **Calendário semanal fixo** (efeitos pequenos, sempre voltam): quarta = loja −20%; sexta = +15% renda; sábado/domingo = ovos −25%. O painel mostra “agora”, “em breve” e o calendário da semana.
- Ganhos offline já existentes (50%, teto 8 h).
- Metas dos dias da 1ª semana: D1 recompensa diária + missões; D2 dia 2 do calendário (ovo); D3 dia 3 + metas de médio prazo; D4 impulso; D7 cerca dourada.

## 4. Economia
**Fontes:** renda de visitantes (`income`), offline, missões iniciais (`mission`), missões diárias (`quest`), metas (`goal`), calendário (`daily`).
**Sumidouros:** ovos (`egg`, preço sobe +10% a cada 10 ovos chocados, teto +100%), melhorias (`upgrade`), loja (`shop`, cosméticos de 45 a 1500), reforma (parte de `upgrade`).
**Multiplicadores:** melhoria de visitantes (+25%/nível), reforma (+10%/nível), evento de sexta (+15%), impulso (×1.5 por 10 min, teto de 30 min acumulados). Eles se somam entre si (melhoria+reforma) e multiplicam com evento/impulso; máximo teórico ≈ ×(1+1,25+0,6)×1,15×1,5.
**Controle de inflação:** (a) tudo passa por `Logic.earn/spend` (livro-razão `data.eco`); (b) recompensas diárias em “minutos de renda” com mínimo e teto (escalam com o jogador mas não explodem); (c) missões/metas com valores fixos pequenos; (d) preço do ovo cresce; (e) reforma e cercas premium como sumidouros de longo prazo; (f) teto de moedas 1e12; (g) livro-razão enviado ao AnalyticsService (fonte/sumidouro por motivo) para detectar inflação ao vivo.

**Curva simulada** (jogador ativo e racional, determinístico, `tests/logic_test.lua`; é consequência das hipóteses de `Config`, **não** playtest):
- 1º habitat extra: ~7 min; 2º: ~21 min; 4 habitats: ~37 min; “Mais visitantes 5”: ~46 min; 1ª reforma: ~49 min; reforma 3: ~1,6 h; reforma 6 (máx.): ~19,6 h.
- Em 4 h reinveste ~77% do que ganha; em 24 h ~82%.
- **Achados da simulação:** (1) uma 1ª versão da reforma (2k–150k) esgotava em ~4 h, o muro de conteúdo das 2–3 h que a skill manda evitar; os custos atuais (4k–900k) levam ~20 h ativas. (2) O inventário (60 dinos) enche em ~59 ovos e **bloqueia o loop de ovos**: não existe “liberar dinossauro”. **Risco aberto, recomendo implementar antes de abrir ao público.** (3) Quem gasta o saldo inicial em ovos em vez de poupar demora ~24 min (não 7) para o 1º habitat: o começo é sensível; só playtest diz se é lento demais.

## 5. Monetização (opcional) — desenho, DESLIGADA
`Config.Monetization.Enabled = false`: sem MarketplaceService, ProcessReceipt, ids ou preços ativos. Código pronto e inerte em `MonetizationService.lua` (ProcessReceipt idempotente por `PurchaseId` guardado em `data.receipts`, só devolve `PurchaseGranted` depois de salvar; Game Pass idempotente). **Não testado no Studio.**

| Faixa | Item (hipótese) | Tipo | Duração | Repetível | Preço-alvo |
|---|---|---|---|---|---|
| Baixa | Impulso de visitantes (+50% 10 min, sem acumular além de 30 min) | Dev Product | 10 min | Sim | R$ 25 |
| Média | 3 ovos (chances visíveis, as mesmas de todos) | Dev Product | Consumível | Sim | R$ 75 |
| Média/alta | Coleta automática do ovo chocado (conveniência) | Game Pass | Permanente | Não | R$ 199 |
| Âncora | Pacote Fundador (cerca dourada + título, só visual) | Game Pass | Permanente | Não | R$ 399 |

Não vendemos: pular incubação/progressão, moeda direta, renda permanente, espécie rara garantida, loot box. Preços em Robux são ponto de partida para teste, sem base de mercado verificada. Cosméticos continuam comprados com moedas; a cerca dourada é recompensa do jogo e também do Fundador (decisão a revisar: pode soar como pagar por algo grátis — alternativa: cosmético exclusivo diferente).

## 6. Loja clara
Aba **Loja** do painel Hoje (`Logic.storeGuide`): para cada compra, preço, o que concede, duração, se repete. Preços e descontos de evento aparecem na loja rotativa (preço já com desconto, vindo do servidor). Sem Robux mostra “Não há compras com Robux neste jogo por enquanto”.

## 7. Momentos de oferta (para quando Robux for ligado)
`Logic.offerEligible`: só com a flag ligada **e** ≥5 ovos chocados **e** tutorial dispensado (ou ≥10 ovos) **e** ≥2 sessões **e** ≥10 min na sessão atual **e** ≥24 h desde a última oferta **e** 1 por dia. Superfície: passiva (aba Loja/etiqueta discreta), nunca pop-up, nunca durante tutorial, nunca após falha. Hoje o jogo só mostra **dicas sem compra** (“tem moedas para novo habitat”). Compra por Robux só por ação explícita do jogador.

## 8. Instrumentação (AnalyticsService via `Telemetry.lua`, sem dados pessoais)
| Evento | Mede |
|---|---|
| `session_start` (valor = dias desde 1º acesso), `return_day` (valor ≥1), `session_end` (segundos) | **Retorno D1/D7**, duração |
| Funil `onboarding`: first_join → first_hatch → first_place → first_upgrade → first_shop_buy → first_daily_claim | Progressão inicial, abandono |
| `dino_hatched{species}`, `egg_bought`, `upgrade_bought{key,level}`, `shop_buy{item}` | Progressão e ritmo |
| `daily_claim`, `quest_claim`, `quest_bonus_claim`, `goal_claim` | Uso do retorno |
| Economia (`LogEconomyEvent`, fonte/sumidouro por motivo, saldo) | Inflação, fontes × sumidouros |
| `insufficient_coins{action}` | Frustração/ritmo |
| `shop_view`, `today_view`, `store_guide_view`, `egg_view` (cliente, lista fechada) | Visualizações |
| `purchase_granted` (só com monetização ligada) | Conversão, compra repetida |
Conversão e compras repetidas = `purchase_granted` ÷ jogadores com `shop_view`; só terão dado depois que Robux for ligado. Nomes/assinaturas da API (`LogCustomEvent`, `LogEconomyEvent`, `LogFunnelStepEvent`, enums) foram escritos de memória e **não foram chamados no Studio**; tudo está em `pcall` e `Config.Analytics.Debug=true` imprime os eventos para conferir.

## 9. Segurança
Servidor autoridade: cliente só pede ações; payloads validados por tipo; recompensas liberadas por estado (`claimDaily` por dia, `claimQuest/claimGoal` marcam antes de pagar, 1x); metas/cosméticos só-recompensa fora da loja; save v2 sanitizado em `Logic.migrate` (ciclo, recibos, impulso, metas inventadas, passes); `track` aceita só nomes de `Config.ClientEvents`; limite de frequência já existente nos remotes; recibos idempotentes; teto de moedas.
Riscos conhecidos: relógio é `os.time()` do servidor (ok); dois servidores simultâneos são cobertos pela trava de sessão, mas **não testada com DataStore real**; vários jogadores no mesmo servidor não testados.

## 10. Hipóteses, métricas e experimentos (nenhum rodou)
| # | Hipótese | Métrica / meta provisória | Experimento |
|---|---|---|---|
| H1 | Recompensa diária + missões elevam o retorno D1 | D1 vs. linha de base sem o painel; meta: > D1 anterior | Ligar/desligar painel por flag de servidor (ex.: 50% dos novos) |
| H2 | 1º habitat em ~7–10 min mantém a sessão 1 | % que chega ao 1º habitat; tempo mediano | Variar custo 150 / 100 |
| H3 | Calendário semanal cria hábito de fim de semana | Sessões sáb/dom por jogador | Comparar semanas com/sem evento |
| H4 | Reforma evita muro de conteúdo | % ativos que compram reforma 1; moedas paradas por jogador | Ajustar custos pela mediana de saldo |
| H5 | Preço crescente do ovo contém inflação sem frustrar | `insufficient_coins{buyEgg}`; saldo p90 | Variar passo 10% / 5% |
| H6 | Oferta passiva às regras da seção 7 converte sem queda de retenção | Conversão, D1/D7 de quem viu vs. não viu | Só depois do loop validado |
Riscos: inventário cheio trava ovos; só 3 espécies limita coleção; fuso fixo BRT; telemetria não conferida; benefício de H1 pode ser nulo (retorno depende do divertimento do loop, ainda não medido). **Não declarar sucesso sem dados reais.**

## 11. Próximos passos
1. Playtest no Studio com este código (Play, 2 jogadores, DataStore publicado); conferir `Config.Analytics.Debug`.
2. “Liberar dinossauro” (inventário) e novas espécies/habitats.
3. Só então avaliar ligar `Config.Monetization` com ids reais, política (`roblox-policy-compliance`) e teste com compras de teste.

## 12. Verificação realizada
Ver `TEST_REPORT.md` (seção “Retenção e economia”). Resumo: build, check (15 arquivos), globals, xref e 36 testes de lógica passam. Studio: **não testado**.
