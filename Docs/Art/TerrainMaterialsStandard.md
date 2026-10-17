# Padrão artístico — materiais de terreno de Valdoria

Estudo World Studio 03, câmera 2D 3/4 e Quaternius R8. Candidato experimental, sem aprovação estética automática.

## Paleta, luz e escala

A paleta exata fica nas receitas e `Library/library.json`, sem depender de configuração pessoal do Aseprite. Seis tons por família: verdes terrosos, ocres secos, cinzas esverdeados, lama oliva e areia quente. Sombras mantêm matiz; destaques têm contraste moderado. Luz superior esquerda em todos os motivos. Espelhar ou rotacionar motivos assimétricos é proibido.

Escala de autoria: 32 pixels/u. Os motivos úteis têm aproximadamente 3–27 pixels de extensão; pequenos fragmentos não devem parecer rochedos ou objetos interativos. O módulo 128×32 é um recipiente de biblioteca, não o tamanho de um tile de chão. Quaternius conserva a escala visual candidata 1,25 e todas as animações existentes.

## Hierarquia

- Macro: pigmento com campo de 193 px; sem quadrados, listras periódicas ou contraste que domine o ator.
- Meso: manchas e grupos de superfície com campo de 57 px; limites orgânicos no espaço semântico. Umidade e ocupação rochosa orientam materiais.
- Micro: motivos esparsos, variação fina de 17 px, fraturas e pequenos reflexos. Evitar saturar o chão; o protagonista e a estrada precisam continuar legíveis.

Grama varia de tufo isolado a grupo úmido. Terra alterna fragmentos, solo exposto e desgaste. Rocha usa placas, fissuras e musgo. Lama tem depressões e poucos reflexos; areia tem linhas de deposição. Estrada tem pedra pequena, sulco e exposição do pigmento central. Essas funções são três variantes por família, não dezenas de duplicatas.

A — Natural equilibrado é a referência de baixa densidade. B — Medieval detalhado aumenta riqueza de pigmento e motivos. C — Fantasia orgânica dá mais variação aos verdes, sem acrescentar física ou vegetação de outro agente. Os três compartilham relevo, estrada, navegação, seed e enquadramento.

## Como revisar

1. Examinar os pixels nativos; ampliações precisam ser nearest e identificadas.
2. Conferir superfície base, depois transições, depois detalhes. Defeito estrutural precisa desaparecer antes da última camada.
3. Comparar antes/depois na mesma câmera 1280×720, ortográfica 11,25, posição `(33.5,23.5)`, seed 710202, Quaternius 1,25.
4. Caminhar e esquivar, observar câmera seguindo o ator, emendas em ambos os eixos, repetição e cintilação. Animação em GIF é somente prévia; PNGs originais e trace preservam a evidência.
5. Separar defeitos de pigmento/transição de contornos do relevo e contato com collider. Não declarar terreno escalável.
6. Se as células de 32×32 continuarem claramente legíveis, registrar reprovação artística mesmo com testes verdes. Feedback explícito do usuário é necessário para aprovar e promover.

A biblioteca Aseprite tem pigmento, formas, bordas/contato, microacento e camada de refinamento. Para editar, copiar fonte, preservar canvas e nomes, salvar revisão e executar `export-library` em destino ausente. O exportador grava PNG/manifest novos; regenerar não sobrescreve a fonte antiga.
