# Valdoria Environment R9 — piloto em avaliação

**Estado: tecnicamente integrado para inspeção; direção artística reprovada nesta iteração.** O piloto não foi promovido ao mundo oficial e não deve ser expandido para outros biomas até uma nova revisão visual.

## O que foi implementado

- Cena isolada `Assets/Mmorpg/Scenes/ValdoriaEnvironmentR9.unity`, clonada da R8. O gerador recusa sobrescrever a cena. A cena R8, `MmorpgWorld.unity` e Build Settings permaneceram sem alteração.
- Sete módulos experimentais de terreno, caminho, copa e tronco de árvore, rocha, parede e telhado. Foram produzidos localmente em Blender, convertidos para PNG/Aseprite e importados a 32 PPU com filtro Point e sem mipmaps. Manifesto registra dimensões, pivôs, origem e SHA-256.
- Receita editável e layout determinístico com seed `620913`; o mesmo recipe/layout reproduz as posições registradas. O posicionamento acontece no Editor, sem geração por Play.
- Restrições de colocação protegem o spawn, Helena, Brann e a Ponte dos Ecos; colisões usam apenas footprints de tronco, rocha e fundação. O caminho e a vegetação não recebem collider de copa.
- No clone R9, a projeção da sombra foi testada em `local Y=-0.125` contra o valor R8 `-0.53`. A raiz física, Rigidbody2D, Collider2D, câmera, animações e regras de combate não foram modificados.
- `ValdoriaR9ProfileIsolation` direciona o perfil somente durante Play nesta cena e restaura o caminho anterior ao sair. A prova observou o perfil em `Temp/ValdoriaEnvironmentR9/IsolatedProfile`; após sair, voltou a `DevelopmentJourneys/marco06b4`.

## Medições e resultado visual

Na inspeção Unity, o corpo usa canvas 128×160, 32 PPU, pivô Unity `(64,34)` e bounds de renderer 4×5 unidades. O recorte alfa do frame de repouso inspecionado foi `(45,28)-(93,137)`: 109 px visíveis, ou aproximadamente **3,41 unidades** na escala nativa. A câmera R8/R9 indicou `orthographicSize=3.96875` durante Play, sem alteração de zoom ou PixelPerfect.

O conjunto atual não atingiu a escala visual desejada. A árvore nova soma aproximadamente 3,66 unidades de altura de sprite, próxima do corpo visível em medida estática, mas sua silhueta facetada e sua leitura na câmera ficam pequenas e destoantes. A casa modular também não tem uma proporção de porta convincente quando comparada ao protagonista. O terreno de 12×8 aparece como uma placa retangular dentro da área visível, com transição abrupta para o mapa legado. A cópia da bancada R8 ainda mostra objetos de comparação que não pertencem a uma área de jogo limpa. A mudança experimental da sombra não foi aprovada como correção final do contato com o solo.

Captura abaixo é da Game View real da Unity, em Play Mode, na cena R9. Ela registra o estado alcançado, inclusive as falhas descritas; não é uma prancha nem uma imagem sintetizada.

O smoke test de teclado usou `KeyboardState` real do Input System por 220 ms: raiz de `(-8,-1)` a `(-6.546,-1)` durante a entrada, direção leste, estado `walk`; após soltar, terminou em `(-6.368,-1)`. Perfil isolado ativo. A casa foi afastada do corredor após a primeira execução, que a havia posicionado perto demais da rua; a prova final não é uma rota completa nem atesta acesso a NPCs.

![Captura real de gameplay Unity na cena R9](/D:/unity/Mmorpg/Docs/Validation/ValdoriaEnvironmentR9/gameplay-r9-play.png)

## Verificações executadas

- Unity 6000.6.5f1 conectada; recompilação concluída.
- Play Mode real avançou de frames; o smoke test final comprovou movimento e estado walk em entrada D. Não foi concluída a matriz de oito direções, passagem frente/atrás, interações, navegação regional ou combate.
- Console Unity: zero erros e zero avisos novos na janela de captura após limpar o console.
- Perfil de persistência isolado durante Play e caminho original restaurado no Stop. Nenhum fluxo de save pessoal foi exercitado intencionalmente.
- Não houve alterações no `SwordSwing`, autoridade, danos, alcances, cooldowns, colisões de combate ou nos 528 quadros aprovados. A revisão visual de espada A/B ainda não foi implementada; a melhoria de apresentação solicitada segue pendente.
- O menu de armas, arco, reinício F5 e regressão completa de combate não foram reexecutados neste marco.

## Respostas ao escopo R9

1. A sensação de flutuação do corpo aprovado não foi corrigida conclusivamente. Foi identificado que o pivô Unity acompanha a raiz física, mas falta medir os pés e a sombra em movimento, em todas as direções.
2. A sombra R8 não foi considerada comprovadamente correta. O offset alternativo foi apenas comparado em um clone e permanece experimental.
3. A correspondência dos pés com grama, terra e pedra ainda precisa de capturas em movimento e esquiva.
4. Física e raiz permaneceram intactas; nenhuma correção visual foi promovida por falta de evidência suficiente.
5. Altura visível estática do frame de repouso medido: 109/160 px, cerca de 3,41 unidades a 32 PPU. A pose varia durante as animações.
6. A porta, a casa e a vegetação deste kit não foram aprovadas em proporção de gameplay. Não extrapolar estas dimensões como padrão.
7. Câmera não alterada.
8. PixelPerfect e referência de 32 PPU preservados.
9. Criados os sete módulos listados acima, todos experimentais e de qualidade artística pendente.
10. Desenvolvidos exportador Blender→PNG/Aseprite/Unity e compositor/layout seedado com manifesto e footprint.
11. A composição de layout é determinística para recipe, assets e seed. Isso não significa que a arte seja aprovada.
12. Receita `valdoria-village.json`, layout `valdoria-village-seed-620913.json`, seed `620913`.
13. Reprodutibilidade é registrada por hashes no manifesto/layout; repetir a geração Unity requer abrir a cena R9 limpa e usar o authoring script.
14. Checagens geométricas preservam os anchors conhecidos. Ainda não houve teste de alcance/interação com todos os pontos narrativos.
15. Não validado além de movimentação local em Play. A cena-piloto não passou o critério de navegação completa.
16. Sorting dinâmico usa anchor de chão para bases/troncos; oclusão frente/atrás de árvores e edifícios não está aprovada.
17. Não implementado. As propostas A/B da espada e seus GIFs continuam pendentes.
18. O mecanismo atual de contato da mão permaneceu intacto; não foi revalidado nesta iteração.
19. Nenhuma regra foi alterada; testes de regressão completos não foram executados, então combate não é declarado como aprovado por este relatório.
20. R8, mundo oficial e Build Settings não foram modificados.
21. Zero erros/avisos novos na captura de Console feita durante Play.
22. O perfil foi isolado durante a prova e restaurado ao caminho anterior. Não se leu nem alterou conteúdo do save pessoal deliberadamente.
23. Todo o novo cenário e a nova sombra aguardam aprovação artística; a revisão da espada aguarda implementação e feedback.
24. A expansão deve reutilizar receitas, manifests, âncoras, footprints, protected anchors, regras por bioma e seeds, somente após um kit local passar revisão artística e circulação real.

## Próximos gates antes de expandir

1. Substituir os módulos low-poly por sprites com leitura pixel art coerente com o humanoide aprovado; revisar escala de árvore, porta e base de casa.
2. Compor terreno/transições que preencham a vista sem a borda retangular atual e retirar da cena de avaliação os elementos de bancada que não servem ao percurso.
3. Capturar escala junto a uma porta, árvore e NPC; testar contato de pés/sombra nas animações aprovadas.
4. Implementar e comparar as duas guardas de espada por meio do pipeline procedural já existente, sem alterar a física.
5. Reexecutar movimento, oclusão, interação, navegação, combate e F5 antes de qualquer promoção.
