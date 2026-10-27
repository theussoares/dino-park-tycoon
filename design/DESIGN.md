# Direção visual
Low-poly/cartoon acolhedor, cores saturadas porém suaves, silhuetas legíveis, poucas Parts, UI em português com botões grandes (toque), fonte Fredoka/GothamBold, contraste alto. Dinossauros originais: Leafling (verde, pequeno), Pebbleback (robusto, cinza-marrom), Embercrest (crista laranja).

## Tokens e componentes (UI do cliente)
Fonte: `src/StarterPlayer/StarterPlayerScripts/DinoParkClient.client.lua` (tabela `C`, `TEXT`, `BUTTON`).

- Cores: fundo #1F3327 (bg), painel #2B4636, cartão #36573F, fantasma #46624E, primária #7BD67A, dourada #FFD25A, desabilitada #4E5E54, texto #F4F8F1, texto secundário #C5D3C6, tinta (texto sobre botão claro) #13201A, aviso positivo #96F096, erro #FFAAA0, informação #BEE1FF.
- Raridade: Config.RarityColors (sempre com texto: COMUM, INCOMUM, RARO).
- Tipografia: títulos FredokaOne (22/26/28), cartões GothamBold (17), corpo GothamMedium (15), legendas (13). Nada abaixo de 13 px.
- Espaçamento: múltiplos de 4/8; cantos 10–16; botões 40 px de altura (mínimo de toque).
- Botões: primary (ação), gold (coleta/Meu Parque), ghost (secundária), disabled (mostra motivo ao tocar).
- Movimento: toque 0,94× em 80 ms; painel 0,96→1 em 120 ms; revelação Back 350 ms; "+N" 900 ms; sem animação contínua exceto a barra de incubação.
- Layout: referência lógica 900×560, escala 0,6–1,25; tela < 900 de largura lógica = modo retrato (ver design/features/ui-ux-redesign/design.md).
