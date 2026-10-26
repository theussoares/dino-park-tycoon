# HANDOFF --- Jurassic Park Tycoon (nome provisório)

## Documento de visão + prompt inicial para Claude

**Objetivo:** criar um protótipo jogável de um jogo Roblox de
gerenciamento de parque de dinossauros, usando ferramentas gratuitas e
assistência do Claude.\
**Plataforma do desenvolvedor:** macOS.\
**Experiência do usuário:** iniciante em Roblox Studio e modelagem 3D.\
**Restrição:** não depender de Blender, serviços pagos adicionais,
modelos pagos ou APIs pagas.\
**Princípio:** o Claude deve automatizar o máximo possível, explicar
cada passo manual com instruções curtas e não alegar que testou algo que
não executou.

------------------------------------------------------------------------

# 1. Visão do jogo

## Nome de trabalho

**Dino Park Tycoon** (nome provisório; verificar disponibilidade e
marcas antes de publicar).

## Fantasia principal

O jogador começa com um pequeno terreno, um ovo de dinossauro e recursos
limitados. Ele choca dinossauros, constrói habitats, atrai visitantes,
ganha moedas e reinveste para criar um parque cada vez maior e mais
raro.

## Pilares

1.  **Progresso visível:** o terreno muda conforme o parque evolui.
2.  **Coleção:** dinossauros de diferentes espécies e raridades.
3.  **Automação simples:** visitantes geram renda ao longo do tempo;
    incubadoras e melhorias reduzem tempos.
4.  **Novidade:** loja rotativa de itens cosméticos e decoração, com
    rotação previsível e transparente.
5.  **Social:** visitar parques de amigos, exibir criaturas e participar
    de eventos.
6.  **Justiça:** evitar que um jogador perca permanentemente dinossauros
    ou compras por ataques de outros jogadores.

## Loop principal

1.  Coletar moedas iniciais / concluir uma missão curta.
2.  Comprar ou receber um ovo.
3.  Incubar o ovo e desbloquear um dinossauro.
4.  Colocar o dinossauro em um habitat válido.
5.  Receber moedas de visitantes ao longo do tempo.
6.  Melhorar habitats, incubadora, decoração e capacidade do parque.
7.  Desbloquear novas espécies e áreas.
8.  Voltar depois para coletar ganhos acumulados e conferir a
    loja/evento.

## Direção visual

-   Estilo low-poly/cartoon, colorido, acolhedor e legível.
-   Construir a primeira versão com Parts, materiais, cores, formas
    simples e modelos procedurais feitos por código.
-   Não usar malhas externas nem exigir Blender no MVP.
-   Dinossauros iniciais podem ser modelos estilizados montados com
    Parts (corpo, cabeça, cauda, patas, olhos e detalhes). Priorizar
    silhuetas simpáticas e desempenho.
-   Se um modelo gratuito do Creator Store for sugerido depois, conferir
    licença/termos, reputação do criador, scripts embutidos e segurança
    antes de incluir. Não importar modelos aleatórios automaticamente.

------------------------------------------------------------------------

# 2. Escopo do MVP (primeira versão)

## Obrigatório

-   Um mapa pequeno e delimitado, gerado por script.
-   Área inicial de parque atribuída ao jogador.
-   Spawn e controles padrão Roblox.
-   Moedas do jogador exibidas na interface.
-   Um ovo inicial e uma ação de incubar.
-   Pelo menos 3 dinossauros estilizados diferentes, gerados por Parts.
-   Inventário de dinossauros.
-   Sistema para colocar/remover dinossauros em habitats próprios.
-   Um habitat inicial e pelo menos duas melhorias compráveis.
-   Visitantes abstratos ou um sistema simples de renda periódica; não
    simular multidões pesadas.
-   Loja básica com itens cosméticos e uma rotação de estoque controlada
    no servidor.
-   Salvamento de moedas, inventário, habitats desbloqueados e progresso
    usando DataStoreService, com tratamento de erro.
-   Tutorial inicial curto.
-   Feedback visual para ações, mensagens de erro e estados de
    carregamento.
-   Validações no servidor para compras com moeda do jogo, incubação,
    posicionamento e recompensas.
-   Instruções de instalação, execução, teste e publicação privada.

## Não fazer na primeira versão

-   Mundo aberto enorme.
-   Combate PvP ou roubo de dinossauros.
-   Trocas entre jogadores.
-   Mercado de jogadores.
-   Sistema complexo de genética.
-   Pets ou dinossauros com centenas de animações.
-   Compras com dinheiro real antes de o loop principal ser testado.
-   Dependência de serviços externos, banco de dados próprio ou backend
    pago.
-   Prometer jogo viral ou receita garantida.

## Critério de conclusão do MVP

Um jogador consegue entrar, ganhar moedas, incubar um ovo, receber um
dinossauro, colocá-lo no habitat, ganhar moedas, comprar uma melhoria,
sair e entrar novamente sem perder os dados (quando o teste for feito em
uma experiência publicada/configurada para DataStore). O mapa deve ser
compreensível e jogável no computador; considerar mobile desde o desenho
da interface.

------------------------------------------------------------------------

# 3. Ferramentas e arquitetura desejadas

## Ferramentas gratuitas

-   Roblox Studio para criar, executar, testar e publicar.
-   Claude como assistente de programação, dentro dos limites da
    assinatura disponível.
-   Git para versionar os arquivos.
-   Opcional: Rojo para sincronizar arquivos do projeto com Roblox
    Studio, mas só se o Claude conseguir configurar e documentar a
    instalação no macOS. Não tornar Rojo um bloqueio inicial.
-   Ferramentas nativas do Roblox Studio para terreno, Parts, materiais,
    iluminação e testes.
-   Creator Store apenas como opção posterior; não é necessário para o
    MVP.

Roblox Studio é gratuito e tem versão para macOS. Documentação oficial:
https://create.roblox.com/docs/studio/setup\
Luau: https://create.roblox.com/docs/luau\
Terreno: https://create.roblox.com/docs/parts/terrain\
Creator Store: https://create.roblox.com/docs/marketplace/marketplace

## Preferência técnica

-   Linguagem: Luau.
-   Servidor como autoridade para moedas, incubação, compra de itens,
    colocação de dinossauros e salvamento.
-   Cliente responsável por interface, efeitos visuais e entrada do
    jogador.
-   ReplicatedStorage para módulos/remotes compartilhados quando
    apropriado.
-   ServerScriptService para lógica segura do servidor.
-   StarterGui/StarterPlayerScripts para UI e interação local.
-   Workspace para mapa e modelos em runtime.
-   DataStoreService para persistência, com `pcall`, tratamento de
    falhas e limites razoáveis de salvamento.
-   Usar `--!strict` quando viável, tipos simples, nomes consistentes e
    módulos pequenos.
-   Evitar um único script gigante. Separar responsabilidades por
    sistema.
-   Não criar RemoteEvents sem validação no servidor.
-   Nunca confiar em valores enviados pelo cliente para preços,
    recompensas, propriedade do terreno ou tempo de incubação.
-   Configurar a economia em módulos de configuração, sem números
    duplicados espalhados pelos scripts.

## Estrutura sugerida (ajuste se houver justificativa)

-   `ReplicatedStorage/Shared/Config`
-   `ReplicatedStorage/Shared/Types`
-   `ReplicatedStorage/Remotes`
-   `ServerScriptService/Bootstrap.server.lua`
-   `ServerScriptService/Services/PlayerDataService.lua`
-   `ServerScriptService/Services/EconomyService.lua`
-   `ServerScriptService/Services/DinosaurService.lua`
-   `ServerScriptService/Services/ParkService.lua`
-   `ServerScriptService/Services/ShopService.lua`
-   `ServerScriptService/Services/VisitorService.lua`
-   `StarterPlayer/StarterPlayerScripts/ClientBootstrap.client.lua`
-   `StarterGui` para a interface
-   `Workspace` para terreno e parques gerados

Essa estrutura é uma proposta, não uma obrigação. Adapte ao método de
sincronização realmente escolhido e explique onde cada arquivo deve
ficar.

------------------------------------------------------------------------

# 4. Requisitos de design detalhados

## Dinossauros

Começar com três espécies fictícias e simples: - **Leafling**: pequeno
herbívoro verde, comum. - **Pebbleback**: quadrúpede robusto, incomum. -
**Embercrest**: dinossauro pequeno com crista laranja, raro.

Não usar nomes, modelos ou arte de franquias conhecidas como Jurassic
Park/World. Criar identidade original.

Cada espécie precisa ter: - ID estável. - Nome. - Raridade. - Custo ou
método de obtenção. - Receita base por intervalo. - Cor e escala
configuráveis. - Modelo gerado por função. - Regras de habitat. -
Descrição exibida na UI.

As chances de raridade, se houver aleatoriedade, devem ser exibidas
claramente antes de o jogador confirmar. Preferir no MVP um ovo
gratuito/inicial e ovos comprados com moeda ganha jogando. Não vender
caixas aleatórias com dinheiro real.

## Economia

-   Usar uma única moeda virtual inicial: Coins.
-   Mostrar saldo na UI.
-   Todos os custos e recompensas vêm de configuração central.
-   Impedir saldo negativo.
-   A operação de compra deve ser atômica no servidor: validar, debitar,
    conceder e responder.
-   Não usar dinheiro real no MVP.
-   Criar uma tabela de balanceamento inicial e indicar que os números
    são hipóteses a testar, não verdades de mercado.

## Loja rotativa

-   Estoque definido no servidor.
-   Rotação baseada em horário UTC ou horário de servidor consistente.
-   Mostrar tempo restante e próxima atualização.
-   Não atualizar estoque de forma diferente para cada jogador no MVP,
    salvo se houver justificativa técnica.
-   Itens cosméticos não devem dar vantagens injustas.
-   Garantir que o cliente não possa escolher um preço ou item que não
    esteja disponível.

## Offline progress

-   Registrar timestamp de última saída.
-   Ao entrar, calcular progresso offline com limite máximo configurável
    (por exemplo, 8 horas).
-   Validar todos os cálculos no servidor.
-   Não confiar em tempo enviado pelo cliente.
-   Mostrar resumo dos ganhos offline.
-   Evitar loops que gerem milhares de objetos enquanto o jogador está
    fora.

## Salvamento

-   Salvar dados com esquema versionado, por exemplo `schemaVersion`.
-   Carregar dados com valores padrão se for jogador novo.
-   Tratar falhas temporárias e não sobrescrever dados válidos com
    defaults após falha de carregamento.
-   Evitar chamadas excessivas; usar salvamento em momentos importantes
    e no encerramento quando possível.
-   Explicar que DataStore deve ser testado em uma experiência publicada
    de teste e que permissões/configuração precisam estar habilitadas.
-   Nunca afirmar que persistência está verificada até realizar um teste
    real.

## Segurança e privacidade

-   Validar no servidor todos os pedidos de
    RemoteEvents/RemoteFunctions.
-   Limitar frequência de chamadas.
-   Não usar scripts de terceiros desconhecidos.
-   Não coletar dados pessoais.
-   Não incluir mecanismos de pressão predatória, perda severa de
    progresso ou notificações enganosas.

## Monetização futura (fora do MVP)

Somente depois de provar que o loop central é divertido: - Game Pass
cosmético/permanente. - Developer Products para conveniência claramente
descrita. - Pacotes de decoração e skins. - Passe de evento com
recompensas transparentes. - Não prometer receita. - Consultar as regras
atuais da Roblox sobre monetização, itens aleatórios pagos, políticas
para menores e DevEx antes de lançar.

------------------------------------------------------------------------

# 5. Instruções para Claude

Você é o engenheiro principal e parceiro técnico deste projeto. O
desenvolvedor é iniciante em Roblox Studio e 3D, mas tem experiência
geral com desenvolvimento de software e usa macOS.

## Regras de trabalho

1.  Primeiro, inspecione o ambiente e os arquivos existentes. Não
    sobrescreva arquivos sem entender o projeto.
2.  Trabalhe em etapas pequenas e executáveis. Não tente gerar o jogo
    inteiro em uma única resposta.
3.  Comece com uma decisão explícita sobre o fluxo de trabalho:
    -   **Opção A:** projeto com Rojo e arquivos Luau locais, se viável;
    -   **Opção B:** scripts Luau e um instalador de cena por Command
        Bar, se isso for mais simples para o iniciante. Escolha uma
        opção e explique por quê. Evite exigir que o usuário copie
        dezenas de scripts manualmente.
4.  Sempre que possível, gere arquivos diretamente no repositório. Não
    responda apenas com blocos de código para o usuário copiar.
5.  Se usar um script instalador, ele deve criar uma cena MVP repetível
    e organizada; não pode apagar dados ou conteúdo do projeto sem pedir
    confirmação.
6.  Não invente APIs Roblox. Consulte documentação oficial quando houver
    dúvida.
7.  Não afirme que executou testes, abriu o Studio ou publicou o jogo se
    não fez isso.
8.  Após cada etapa, forneça:
    -   arquivos criados/alterados;
    -   como executar;
    -   resultado esperado;
    -   testes realizados e não realizados;
    -   problemas conhecidos;
    -   próximo passo.
9.  Se uma ação manual for inevitável, explique em passos numerados, com
    os nomes exatos dos menus/botões. Faça no máximo 3--5 passos manuais
    por vez.
10. Não peça ao usuário para tomar decisões técnicas que você possa
    resolver com um padrão seguro. Pergunte apenas quando uma escolha
    for realmente necessária.
11. Não instale dependências nem execute comandos destrutivos sem
    explicar a finalidade. Nunca peça segredos, tokens ou senhas.
12. Priorize simplicidade, segurança, desempenho e facilidade de
    manutenção.
13. Use português brasileiro para as instruções ao usuário. Código,
    identificadores e comentários técnicos podem estar em inglês.
14. Se a assinatura disponível não incluir Claude Code ou alguma
    ferramenta, ofereça uma alternativa usando a interface Claude e
    arquivos exportáveis, sem presumir acesso a recursos pagos
    adicionais.

------------------------------------------------------------------------

# 6. Plano de implementação por fases

## Fase 0 --- Verificação do ambiente

-   Confirmar macOS, versão de Roblox Studio, Git e ferramentas
    disponíveis.
-   Verificar se Claude Code está disponível com a assinatura atual; não
    assumir.
-   Escolher fluxo de arquivos.
-   Criar `README.md`, `.gitignore` e esta documentação.
-   Não instalar dependências desnecessárias.

## Fase 1 --- Primeiro cenário jogável

-   Criar terreno pequeno, caminhos, cercado, árvores estilizadas,
    portão e ponto de spawn.
-   Criar um dinossauro low-poly feito de Parts.
-   Adicionar iluminação e paleta visual coerentes.
-   Objetivo: ao pressionar Play, o jogador consegue andar em um parque
    visualmente legível.

## Fase 2 --- Loop principal

-   Moedas iniciais.
-   Ovo inicial.
-   Ação de incubar.
-   Mostrar o dinossauro recebido.
-   Colocar dinossauro em habitat.
-   Produzir moedas ao longo do tempo.
-   Comprar a primeira melhoria.

## Fase 3 --- UI e tutorial

-   Interface para saldo, inventário, loja e missões.
-   Tutorial de poucos passos.
-   Estados de carregamento, sucesso e erro.
-   UI adaptável a diferentes resoluções.

## Fase 4 --- Dados e progressão offline

-   DataStore, versão do esquema, tratamento de falhas.
-   Cálculo offline limitado.
-   Teste de sair e voltar.
-   Não declarar pronto sem teste no Studio/experiência de teste.

## Fase 5 --- Retenção básica e loja

-   Loja cosmética rotativa.
-   Missões diárias simples, sem punição por faltar.
-   Registro de eventos de gameplay para teste local.
-   Balanceamento inicial.

## Fase 6 --- Polimento e lançamento de teste

-   Testar com 1 jogador e depois com múltiplos jogadores.
-   Verificar RemoteEvents e economia no servidor.
-   Testar respawn, desconexão, falha de salvamento e interface.
-   Otimizar quantidade de Parts e efeitos.
-   Publicar como experiência privada/de teste primeiro.
-   Monetização real só após estabilidade e validação com jogadores.

------------------------------------------------------------------------

# 7. Métricas para validar se vale continuar

Não assumir que a ideia vai viralizar. Testar com pessoas reais e
medir: - Quantos iniciam e completam o tutorial. - Quantos chocam o
primeiro ovo. - Quantos colocam o primeiro dinossauro no habitat. -
Quantos compram a primeira melhoria. - Quantos voltam no dia seguinte e
depois de uma semana. - Onde os jogadores abandonam. - Desempenho em
computadores modestos e celulares.

Antes de adicionar dezenas de espécies, melhorar o ponto do jogo onde as
pessoas param de jogar.

------------------------------------------------------------------------

# 8. Prompt inicial --- cole no Claude

Você é o engenheiro principal do projeto **Dino Park Tycoon**, um jogo
Roblox de gerenciamento de parque de dinossauros. Leia todo o documento
`HANDOFF_DINO_PARK.md` antes de agir.

O desenvolvedor é iniciante em Roblox Studio e modelagem 3D, usa macOS e
quer aproveitar ao máximo o Claude, sem ferramentas pagas adicionais.
Sua missão é construir uma primeira versão realmente executável, não
apenas descrever como seria o jogo.

**Comece pela Fase 0.** Inspecione o diretório atual, informe o que
encontrou e escolha o fluxo mais simples entre Rojo e arquivos Luau
locais ou um instalador de cena por Command Bar. Verifique a
disponibilidade real das ferramentas antes de depender delas. Não
suponha que tenha acesso ao Roblox Studio por automação.

Depois: 1. Crie um plano de execução curto e liste as dependências
necessárias. 2. Gere os arquivos reais do projeto e documentação no
diretório de trabalho. 3. Implemente apenas a primeira fatia vertical:
cenário pequeno, spawn, um dinossauro estilizado gerado por Parts e uma
interação funcional. 4. Inclua instruções manuais mínimas e exatas para
importar/executar no Roblox Studio. 5. Só avance para moedas, incubação,
inventário, habitats, loja e DataStore depois de a primeira fatia estar
pronta e de explicar como validá-la. 6. Use arquitetura modular,
validação no servidor e configuração central. 7. Não use ativos pagos,
serviços pagos, franquias protegidas ou scripts desconhecidos. 8. Não
invente resultados de testes. Separe claramente o que foi implementado,
o que foi executado e o que depende de validação manual. 9. Ao terminar
cada etapa, pare e forneça o próximo procedimento mais simples para mim.

**Primeira entrega exigida:** estrutura de pastas, README com
instruções, scripts necessários para gerar o primeiro parque e um
procedimento de teste de no máximo cinco passos. Comece agora pela Fase
0; não tente construir todas as fases de uma vez.

------------------------------------------------------------------------

# 9. Checklist do desenvolvedor

-   [ ] Instalar/abrir Roblox Studio no Mac.
-   [ ] Criar ou escolher uma pasta para o projeto.
-   [ ] Abrir essa pasta no Claude Code, se a assinatura permitir; caso
    contrário, usar a interface do Claude e transferir os arquivos
    gerados.
-   [ ] Enviar o documento e o prompt.
-   [ ] Fazer a Fase 0 e a Fase 1.
-   [ ] Executar o primeiro teste no Studio.
-   [ ] Corrigir erros antes de adicionar sistemas.
-   [ ] Versionar o projeto com Git.
-   [ ] Testar salvamento em uma experiência de teste.
-   [ ] Validar o jogo com jogadores reais antes de investir em
    monetização.

## Princípio final

O objetivo inicial não é lançar um jogo enorme nem garantir viralização.
É obter uma pequena experiência divertida, funcional e testável, usando
ferramentas gratuitas, e evoluir com base no comportamento real dos
jogadores.
