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
