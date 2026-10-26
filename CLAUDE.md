# Dino Park Tycoon — instruções para o Claude

Jogo Roblox (Luau) de parque de dinossauros. Leia `README.md` e `HANDOFF_DINO_PARK.md` (seção 10) antes de mexer.

## Onde o código vive (adaptação deste projeto)
- Fonte de verdade: arquivos em `src/` (Git). **Não** edite `installer/Parte2_Scripts.lua`: ele é gerado por `node tools/build.js`.
- Cenário: `scene/SceneBuilder.lua` → `installer/Parte1_Cenario.lua`.
- Sem Rojo e sem MCP do Studio por padrão: o usuário cola os instaladores na Command Bar do Studio.
- Se o Studio MCP oficial for conectado (ver `.mcp.json`), use-o só para inspecionar/testar; mudanças duradouras voltam para `src/`.

## Verificações obrigatórias após qualquer mudança em Luau
```
node tools/build.js && (cd tools && node check.js && node globals.js && node xref.js) && node tests/run_tests.js
```
Luau-only (`continue`, `+=`, anotações de tipo) é proibido: os checadores usam parser Lua 5.1/5.3.
Nunca afirme que algo foi testado no Studio sem ter sido; registre em `TEST_REPORT.md`.

## Regras do jogo
- Servidor é autoridade (moedas, incubação, compras, colocação, salvamento). Cliente só UI.
- Uma moeda: `Coins`. Números de economia só em `Config.lua`. Lógica pura em `Logic.lua` (sem APIs Roblox, testável).
- DataStore: falha de carga ⇒ `canSave=false`; trava de sessão via UpdateAsync; `schemaVersion` + `Logic.migrate`.
- Sem Robux, sem assets de terceiros sem licença verificada (`ASSET_CATALOG.md`).

## Roblox Skills
Pacote em `.claude/skills/roblox-skills/` (commit a3a7b94, MIT). Cada skill é `<nome>/SKILL.md`; se a ferramenta Skill não listá-las, leia o arquivo diretamente.

**Regra de ouro:** trabalhe em fatias verticais jogáveis (PRD → fatias → playtest), nunca em camadas horizontais.

Roteamento:
- Planejar/escopo: `roblox-game-development-lifecycle`, `roblox-to-prd`, `roblox-to-issues`, `roblox-triage`
- Arquitetura Luau: `roblox-luau-architecture`, `roblox-code-maintenance-refactor`
- Mundo/cenário: `roblox-world-level-design`, `roblox-genre-patterns`
- UI/UX: `roblox-ui-implementation`, `roblox-game-ux`, `roblox-localization-accessibility`
- Dados: `roblox-datastore-persistence`
- Economia: `roblox-economy-balancing`, `roblox-quest-progression-systems`
- Segurança: `roblox-security-economy`, `roblox-creator-store-security-audit`
- Assets: `roblox-asset-pipeline`, `roblox-animation-audio-feedback`
- Desempenho: `roblox-performance-optimization`
- Testes/bugs: `roblox-playtest-qa`, `roblox-mobile-playtest`, `roblox-debugging-bugfix`
- Publicação (futuro): `roblox-policy-compliance`, `roblox-publishing-discovery`, `roblox-release-operations`

### Configuração do projeto
- Tracker: roadmap local → `docs/agents/tracker.md`, `ROADMAP.md`, `roadmap/`
- Labels de triagem: `docs/agents/triage-labels.md`
- Design: `docs/agents/design.md`, `design/DESIGN.md`
