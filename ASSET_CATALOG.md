# ASSET_CATALOG — Dino Park Tycoon

Data da pesquisa: 2026-10-26. Só conto como "verificado" o que consegui abrir e ler nesta sessão.

## Resumo honesto

- **Em uso no jogo agora: nenhum asset externo.** Cenário, árvores, dinossauros, decorações e interface são gerados por código (Parts nativas).
- **Baixado e guardado (não integrado):** pack de dinossauros animados da Quaternius (CC0), 6 arquivos FBX em `assets/quaternius-dinosaurs/`.
- **Por que não integrei os FBX:** colocar uma malha com animação no Roblox exige o **3D Importer / Asset Manager do Roblox Studio** (ou a Open Cloud API, que pede uma chave de API sua — não peço nem manuseio segredos). Não consigo operar o Studio daqui, então não afirmo que foi importado ou testado. Passo a passo abaixo.

## Aprovados (licença verificada)

| Asset | Criador | Preço observado | Licença | Formato | Link | Status |
|---|---|---|---|---|---|---|
| Animated LowPoly Dinosaurs ("Dinosaur Animated Pack - Dec 2018") | Quaternius | "Name your own price" — baixado por $0 | CC0 1.0 (texto da página: "FBX, OBJ and Blend formats and CC0 license"; `License.txt` dentro do ZIP confirma CC0 1.0) | FBX/OBJ/Blend; 6 dinos rigged com idle, walk, run, attack, jump, death | https://quaternius.itch.io/animated-lowpoly-dinosaurs | **Baixado** (10 MB, SHA-256 do ZIP `d9ca7d35…8931c`). FBX em `assets/quaternius-dinosaurs/`. **Não importado no Roblox.** |
| 150+ LowPoly Nature Models | Quaternius | "Name your own price" (página lida) | CC0 (página: "CC0 License as always") | Blend/FBX/OBJ; árvores, cactos, pedras, arbustos, troncos, plantas | https://quaternius.itch.io/150-lowpoly-nature-models | **Aprovado como candidato; NÃO baixado, NÃO importado.** |

Dinossauros no pack: Apatosaurus, Parasaurolophus, Stegosaurus, T-Rex, Triceratops, Velociraptor (conferido na lista de arquivos do ZIP).

Observação de segurança: FBX é formato de dados (não executa código) e não abri nem rodei nenhum script do pack; só listei e extraí os arquivos. Não inspecionei visualmente as malhas.

## Candidatos NÃO aprovados (não consegui verificar)

| Fonte | Motivo |
|---|---|
| Kenney Nature Kit — https://kenney.nl/assets/nature-kit | A página foi bloqueada nesta sessão; licença **não** verificada por mim (não presumo). |
| Roblox Creator Store (buscas de dinosaur, trees, fence, rocks) — https://create.roblox.com/store/models | Página bloqueada/dinâmica nesta sessão: não consegui conferir preço, criador, licença nem scripts embutidos. Regra do projeto: não usar modelo sem inspecionar os scripts. |
| Poly Pizza — https://poly.pizza/ | Página bloqueada nesta sessão; licenças por modelo (CC0 / CC-BY) não verificadas. |
| Sketchfab, OpenGameArt | Não pesquisados em profundidade; licença varia por item. |

## Como integrar os dinossauros da Quaternius (passos manuais, ~5 min)

Opcional — o jogo já funciona sem isso.

1. No Studio, abra **View > Asset Manager > Bulk Import** (ou **Import 3D**).
2. Selecione um FBX de `assets/quaternius-dinosaurs/Dinosaur Animated Pack - Dec 2018/FBX/` (ex.: `Triceratops.fbx`). Aceite o diálogo de importação (mantenha "Import as: Model").
3. Verifique se a malha vem com `MeshPart`/`Bone` e se **não** há Scripts dentro (o importador não cria scripts; se aparecer algum, apague).
4. Guarde o resultado em `ServerStorage/ImportedDinos/` e, se quiser usá-lo, aponte uma espécie nova em `Config.Species` e construa o modelo clonando de lá (hoje `DinoModels.buildDino` só usa Parts).
5. Animações: o importador cria um `AnimationClip`; publique-o pelo Animation Editor para obter um ID e carregue com `Animator:LoadAnimation`. (Não implementado.)

Atribuição: CC0 não exige, mas o autor pede apoio no Patreon (https://www.patreon.com/quaternius).

## Critérios de aprovação (do ASSETS_GRATUITOS_DINO_PARK.md)

Pack dinossauros: preço ✔ (US$0 obtido), licença ✔ (página + License.txt), criador ✔, scripts n/a (só malhas; não inspecionei visualmente), compatibilidade ✘ **não testada** em Roblox, link ✔.
Pack natureza: preço ✔ (página), licença ✔ (página), criador ✔, **sem download**, compatibilidade ✘ não testada, link ✔.
