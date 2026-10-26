# Dino Park Tycoon (nome provisório)

Jogo Roblox de parque de dinossauros: choque ovos, coloque dinos no habitat, ganhe moedas com visitantes, melhore o parque e decore com itens da loja rotativa. Tudo (cenário, dinossauros, UI) é gerado por código — sem assets pagos.

> **Estado:** implementado e verificado **estaticamente** (sintaxe + 13 testes da lógica fora do Roblox). **Nunca foi executado no Roblox Studio.** Veja `TEST_REPORT.md`.

## Jogar (5 passos)

1. Roblox Studio > **New > Baseplate**. Apague `Baseplate` e `SpawnLocation` do Explorer. Salve o lugar (**File > Save to Roblox** para poder testar o DataStore).
2. **View > Command Bar**. Cole **todo** o `installer/Parte1_Cenario.lua` e Enter (cria o mapa).
3. Cole **todo** o `installer/Parte2_Scripts.lua` e Enter (cria scripts e interface).
4. **Home > Game Settings > Players > Max Players = 4** (há 4 parques).
5. **Play (F5)**. Siga o tutorial: Ovo > Incubar > Coletar; Inventário > Colocar; Melhorias.

Para salvar progresso no Studio: **Game Settings > Security > Enable Studio Access to API Services**, com o lugar publicado/salvo na nuvem. Sem isso o jogo funciona, mas avisa "sem salvamento".

Rodar de novo: os instaladores param sem mexer em nada se já existir. `REPLACE_EXISTING = true` no topo recria só os objetos do jogo.

## Estrutura

```
src/                     código-fonte Luau (fonte da verdade)
  ReplicatedStorage/Shared/{Config,Logic,DinoModels}.lua
  ServerScriptService/DinoParkMain.server.lua
  ServerScriptService/DinoParkServices/{DataService,ParkService,GameService}.lua
  StarterPlayer/StarterPlayerScripts/DinoParkClient.client.lua
scene/SceneBuilder.lua   cenário estático
installer/               GERADO por tools/build.js (cole na Command Bar)
tools/                   build.js, check.js, globals.js, xref.js
tests/                   logic_test.lua + run_tests.js
assets/                  pack Quaternius (CC0) baixado, não integrado — ver ASSET_CATALOG.md
```

Editar o jogo: mude `src/`, rode `cd tools && node build.js` e recole `installer/Parte2_Scripts.lua` com `REPLACE_EXISTING = true`.

## Verificações (precisa de Node)

```
cd tools && npm install   # luaparse + fengari
node build.js && node check.js && node globals.js <arquivos> && node xref.js && node ../tests/run_tests.js
```

## Publicar como teste privado

Studio: **File > Publish to Roblox**, deixe a experiência **Privada**. Não publiquei nada. Não há compras com Robux no MVP.

## Documentos

`HANDOFF_DINO_PARK.md` (visão + arquitetura), `ASSET_CATALOG.md`, `TEST_REPORT.md`.
