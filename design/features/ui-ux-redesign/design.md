# UI/UX redesign: HUD, coleção, incubação, loja e progressão

Status: approved

Aprovação: o pedido do usuário pediu explicitamente a implementação desta interface (não só o documento), o que cumpre o gate de `roblox-game-ux`. Ajustes posteriores seguem o mesmo registro.

## Objetivo do jogador
Entender em menos de 30 s o ciclo "ovo → incubar → colocar → renda" e saber sempre o próximo passo. Nenhuma tela inicial cheia de menus: o mundo fica visível e o HUD é só uma faixa no topo e uma barra embaixo.

## Arquitetura de informação
- Sempre visível
  - HUD (canto superior esquerdo): moedas e renda por pagamento.
  - Objetivo (centro superior): próximo passo do onboarding (missões em ordem); depois, o próximo passo de progressão.
  - Próxima melhoria (canto superior direito, só em tela larga): nome, custo e quanto falta.
  - Barra inferior: Ovo, Coleção, Loja, Melhorias, Missões, Meu Parque.
- Painel central (um por vez, fechável): abre sob o topo e acima da barra.
- Sobreposições: aviso curto (toast) e revelação de dinossauro (ao coletar um ovo).

## Layout e responsividade
Referência lógica de 900×560 com escala entre 0,6 e 1,25 (como antes).
- Largura lógica ≥ 900 (desktop, tablet paisagem, celular paisagem): HUD, objetivo e próxima melhoria lado a lado. Painel até 560 px de largura, até 460 px de altura.
- Largura lógica < 900 (celular retrato): HUD no topo à esquerda; objetivo ocupa a largura abaixo; próxima melhoria some (a informação aparece em Melhorias). Painel até 640 px de altura.
- Barra inferior: até 720 px de largura, 6 células de 48 px de altura. Alvos de toque de pelo menos 40 px.
- Coleção: 3 colunas em largura ≥ 480 px do painel; 2 colunas abaixo.
- Zonas seguras: a barra fica a 12 px da borda inferior; o HUD e o objetivo a 10 px do topo.

## Estados de cada superfície
- Coleção: vazia (texto + botão "Ir para Ovo"); com dinossauros (cards); carta sem habitat livre ("Aguardando vaga", botão "Sem vaga" com motivo ao tocar).
- Incubadora: vazia com ovos ("Incubar"); vazia sem ovos (botão desabilitado com motivo); chocando (texto com tempo e barra); pronta ("Coletar" em destaque).
- Loja: itens disponíveis ("N moedas"); faltam moedas ("Faltam N", motivo ao tocar); já comprado ("Na coleção"); rotação com contagem regressiva.
- Melhorias: nível máximo ("Máximo"); faltam moedas ("Faltam N"); disponível ("N moedas").
- Missões: pendente ou feito (texto + pílula, nunca só cor).
- Carregando e erro de carga: tela de carregamento com instrução de sair e entrar de novo (já existia).
- Salvamento indisponível: a linha de renda do HUD mostra "Progresso não é salvo nesta sessão" em texto vermelho-claro, além do aviso único.

## Interações e feedback
- Todo toque em botão encolhe para 94% e volta ao soltar (80 ms).
- Pedido aceito: aviso verde com "+" e som curto de confirmação. Erro: aviso com "!". Informação: sem prefixo.
- Ganho de moedas: "+N" dourado sobe e some (0,9 s), no máximo um por atualização de estado.
- Incubação concluída: revelação com pop-in (0,35 s, Back), faíscas leves (10 partes, 0,6 s), som mais agudo, nome, raridade (texto + cor), descrição e botões "Colocar no habitat" e "Guardar para depois". Não bloqueia: pode ser fechada a qualquer momento.
- Sem animações contínuas, exceto a barra de incubação, atualizada a cada 0,5 s.
- Painéis abrem com pequena escala (0,96 → 1, 0,12 s).

## Copy
- Português direto, verbo no imperativo, sem urgência falsa ("Faltam 40 moedas", nunca "Última chance").
- Loja: "Troca em m:ss · mesmos itens para todos · só enfeites, sem vantagem de jogo".
- Probabilidades explícitas e sem arredondamento enganoso (70%, 25%, 5%).

## Acessibilidade
- Texto mínimo de 13 px; títulos com FredokaOne; corpo com GothamMedium.
- Contraste: texto claro sobre fundo escuro (≥ 6:1); texto escuro sobre botões claros (≥ 9:1).
- Informações por cor sempre têm texto: raridade (COMUM/INCOMUM/RARO), estado (No habitat, Disponível, Aguardando vaga), missões (FEITO/PENDENTE), aviso (+/!).

## Critérios de aceitação
1. Primeiro ovo incubado em até 30 s a partir do spawn (guiado pelo objetivo).
2. Todo botão tem texto de estado e, quando desabilitado, um motivo ao tocar.
3. Layout sem sobreposição em 1280×720, 1920×1080, 844×390 (celular paisagem) e 390×844 (celular retrato) — a verificar no Studio.
4. Nenhuma ação de compra é decidida no cliente: a UI só pede (`Request`) e mostra `State`.
