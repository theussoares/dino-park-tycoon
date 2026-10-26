# Dino Park Tycoon (nome provisório)

Jogo Roblox de parque de dinossauros. Visão completa: `HANDOFF_DINO_PARK.md` (coloque uma cópia nesta pasta).

## Fase 0 — decisões

- **Ambiente:** macOS (Apple Silicon). Git e Roblox Studio **não foram verificados** por mim no seu Mac; confirme `git --version` no Terminal.
- **Fluxo escolhido: Opção B (instalador por Command Bar).** Rojo não está instalado e eu não consigo instalá-lo no seu Mac; Opção B não exige nada além do Studio.
- Sem Blender, sem assets pagos, sem Creator Store.

## Fase 1 — primeiro cenário (5 passos)

1. Abra o Roblox Studio > **Baseplate** (novo lugar).
2. No Explorer, apague o `Baseplate` e o `SpawnLocation` padrão (evita spawn duplicado).
3. Menu **View > Command Bar**.
4. Abra `installer/Phase1_Installer.lua`, copie TUDO, cole na Command Bar e pressione **Enter**.
5. Pressione **Play (F5)**. Esperado: você nasce perto do portão "Dino Park", anda pelo caminho até o habitat cercado, vê o Leafling com nome flutuante; ao chegar perto, aparece o botão **Cumprimentar** (tecla E) e ele dá dois pulinhos.

Rodar de novo: o script avisa que já existe e não altera nada. Para recriar, mude `REPLACE_EXISTING` para `true` (só apaga `Workspace.DinoParkMVP`).

## Estado dos testes

- **Implementado:** cenário, spawn, habitat, portão, árvores, luz, Leafling de Parts, interação.
- **Executado:** nada. Não tenho o Studio; o código **não foi rodado**.
- **Depende de validação manual:** tudo acima. Se der erro na Command Bar, cole a mensagem para eu corrigir.

## Problemas conhecidos / dúvidas

- Script embutido (`LeaflingInteraction`) é gravado via `Script.Source` na Command Bar; deve funcionar, mas não foi testado.
- Fonte `FredokaOne` e materiais podem variar por versão do Studio.

## Próximo passo

Validar a Fase 1. Depois: moedas, ovo, incubação (Fase 2) em módulos `ServerScriptService`/`ReplicatedStorage`.
