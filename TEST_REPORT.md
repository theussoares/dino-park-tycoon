# TEST_REPORT — Dino Park Tycoon

Data: 2026-10-26. Ambiente: VM Linux do assistente (Node 22, `luaparse`, `fengari`). **Roblox Studio não foi aberto. O jogo não foi executado.**

## Testes realmente executados

| Teste | Comando | Resultado |
|---|---|---|
| Sintaxe de todos os `.lua` (13 arquivos, incluindo instaladores gerados) com `luaparse` (Lua 5.1) | `node tools/check.js` | 13/13 sem erro |
| Variáveis globais não declaradas / typos (9 arquivos de código; verificador validado com um typo plantado, que ele detectou) | `node tools/globals.js …` | nenhum global fora da lista de APIs esperadas |
| Referências cruzadas: ações do cliente × handlers do servidor, campos de estado, `Config.*`, `Logic.*`, `DinoModels.*` | `node tools/xref.js` | ok |
| Lógica pura (`Config` + `Logic`) em Lua 5.3 (fengari): 13 testes — economia, ovo/incubação, primeiro ovo = Leafling, sorteio ponderado, colocação/propriedade, renda, ganhos offline (teto 8h, NaN, relógio futuro), loja rotativa determinística, compras, melhorias, missões, sanitização de dados corrompidos | `node tests/run_tests.js` | 13 passaram, 0 falharam |

Observação de método: o código evita sintaxe exclusiva do Luau (sem `continue`, `+=`, anotações de tipo) para que o `luaparse` o valide. Isso **não** é um compilador Luau.

## Pendente (exige Roblox Studio — não testado)

- Os dois instaladores rodando na Command Bar (inclusive atribuir `Script.Source` por ali).
- Geração visual: parques, dinossauros, decorações, placas, posições/rotação dos modelos.
- Interface: layout, botões, painéis, escala em tela pequena, contagens regressivas.
- Remotes em runtime (RemoteFunction/Events), limite de frequência, mensagens de erro.
- Renda periódica, incubadora, ganhos offline com dados reais.
- DataStore: carregar/salvar/sair e voltar (exige lugar publicado + acesso a API Services).
- Multiplayer (2–4 jogadores), parque cheio (kick), saída durante o carregamento.
- Desempenho (quantidade de Parts) e dispositivos móveis.
- Importação dos FBX da Quaternius (não tentada).

## Limitações conhecidas

- Sem bloqueio de sessão no DataStore (dois servidores simultâneos para o mesmo usuário podem sobrescrever o progresso um do outro).
- Mapa de 4 parques fixos; servidor cheio expulsa o 5º jogador (configure Max Players = 4).
- Visitantes são abstratos (renda periódica), sem NPCs.
- Sons: apenas um "ping" nativo (`rbxasset://sounds/electronicpingshort.wav`, não verificado no cliente).
- Números de balanceamento são hipóteses a testar com jogadores.

## Limitação principal

Não consigo afirmar que o jogo funciona no Roblox: nunca rodou no Studio. Falhas de API do Roblox (nome de propriedade, ordem de carregamento, permissões) só aparecem em runtime. Se algo falhar, cole a mensagem do Output para correção.

## Atualização: trava de sessão + roblox-skills
- Novo: `Logic.lockedByOther`/`Logic.record`; `DataService` reserva o perfil com `UpdateAsync` (5 tentativas), renova a trava a cada autosave, libera ao sair, expulsa o jogador se o perfil está em outro servidor; `BindToClose` salva em paralelo (máx. 25 s).
- Executado: `tools/check.js` (sintaxe), `globals.js`, `xref.js`, `tests/run_tests.js` → 14 passam, 0 falham (inclui teste da trava).
- NÃO executado: nada no Studio. A trava, o kick e o BindToClose dependem de teste real (2 servidores/contas) com API Services ligado.
- Studio MCP: `.mcp.json` preparado conforme a documentação oficial; **não conectado/verificado** (roda no seu Mac).

## Playtest no Studio via MCP (2026-10-26)
Ambiente: Roblox Studio no Mac do usuário ("Place1", lugar **não publicado**), conectado pelo Studio MCP. Solo, 1 jogador, viewport 1511×781.

Instalação (executada de verdade):
- `installer/Parte1_Cenario.lua` rodado via `execute_luau` (modo Edit): cenário criado sem erro; Workspace não tinha Baseplate padrão.
- `installer/Parte2_Scripts.lua` enviado em 4 partes e executado com `loadstring` (HTTP desligado no lugar; não foi alterado). Conteúdo conferido no Studio: 64927 bytes, checksum idêntico ao arquivo local. Criou Shared(3), DinoParkServices(3), DinoParkMain, DinoParkClient.

Play (executado de verdade):
- Console: apenas `DataStore indisponível: You must publish this place...` (esperado: lugar não publicado ⇒ `canSave=false`, UI mostra "(sem salvamento)") e `Servidor iniciado.` Nenhum erro de script.
- 4 parques gerados; jogador recebeu o Plot1 com placa "Parque de <nome>"; tela de carregamento some ao receber o estado.
- Loop completo chamado pelo cliente via `Request` (não por cliques na UI): incubar → "Ainda não chocou" → após 12 s coletar (Leafling, como previsto) → colocar → recolocar recusado → comprar ovo → melhoria de renda → "Meu Parque" teleporta → compra na loja → ação desconhecida e payload inválido recusados. Moedas batem com a conta (100+50+75−50−100+100 = 175); renda +3 por pagamento (2×1,25 arredondado); a renda passiva entrou.

Bugs encontrados e corrigidos (em `src/StarterPlayer/StarterPlayerScripts/DinoParkClient.client.lua`):
1. **Barra inferior fora da tela / painel descentralizado**: o `UIScale` (1,25) também escalava o `Root` (`fromScale(1,1)`), que ficava com 125% da tela; a barra caía em y=823 numa tela de 781 px. Correção: `root.Size = 1/scale`. Verificado depois da correção: Root = 1511×723 (área útil), barra em y=643–710, centralizada; captura de tela confirma.
2. **Texto "Renda ... (sem salvamento)" cortado** no HUD de 230 px. HUD alargado para 300 px; `TextFits = true` verificado.
- A correção foi aplicada no script do Studio por substituição e conferida por checksum (17623 bytes) contra `src/`.

Ainda não verificado:
- Uma "camada" verde com textura de folhas no alto das capturas de tela. Um raycast para cima a partir da câmera não acertou nenhuma peça; pode ser artefato da captura ou do material Grass. Precisa ser olhado no viewport.
- Cliques reais nos botões, painéis abertos (só a barra/HUD/tutorial foram vistos), modelos dos dinos/decorações vistos de perto, escala < 1 (telas pequenas/mobile), DataStore real, multiplayer, BindToClose.

## Retenção e economia (branch `claude/retention-monetization-e71094`)

Executado em 2026-10-26 (Node, `luaparse`, `fengari`): `node tools/build.js && (cd tools && node check.js && node globals.js && node xref.js) && node tests/run_tests.js` → check 15/15, xref ok, **36 testes de lógica passam** (migração v1→v2, livro-razão, preço do ovo, eventos semanais e fuso, impulso, calendário diário sem punição, missões/metas anti-duplicação, recibos idempotentes, ofertas, guia da loja, funil, simulações de economia de 4 h e 24 h).

**Não verificado:** Roblox Studio estava em Play de outra sessão e não foi interrompido, então o painel Hoje, `Telemetry`/AnalyticsService (nomes de API de memória), remotes novos, DataStore v2 em runtime e `MonetizationService` (desligado) **nunca rodaram**. As simulações de economia são consequência dos números de `Config`, não playtest. Sem multiplayer, mobile ou dados reais.
