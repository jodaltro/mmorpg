---
name: terrain-materials
description: Autoria e revisÃ£o de materiais pixel art procedurais de Valdoria em Aseprite e Python. Use para pigmento contÃ­nuo, variantes contextuais, transiÃ§Ãµes subcÃ©lula, detalhes multiescala e composiÃ§Ã£o com WorldRegion e Organic Roads, sem alterar fÃ­sica ou traÃ§ados.
---

# Material Agent

Leia `AGENTS.md`, `Docs/Art/TerrainMaterialsStandard.md` e `Docs/WorldGen/TerrainMaterialsContract.md`. Use tambÃ©m `aseprite-pixel-art` para fontes e `terrain-generation` para interpretar os dados. A skill Ã© um especialista operado pelo agente, nÃ£o um serviÃ§o independente.

## Responsabilidade

O Terrain Agent decide relevo, solos e circulaÃ§Ã£o. Este mÃ³dulo decide pigmento, transiÃ§Ãµes, desgaste e detalhes. Consuma WorldRegion v1, composiÃ§Ã£o v2 e road v1/mÃ¡scaras verificadas. Nunca modifique `blocked`, altura, navegaÃ§Ã£o, waypoints, largura ou cobertura da estrada para obter um visual mais fÃ¡cil.

`Tools/ArtPipeline/WorldGen/terrain_materials.py` implementa biblioteca editÃ¡vel, composiÃ§Ã£o por coordenadas globais, recortes, patches retangulares de tom, manifests e reconstruÃ§Ã£o verificÃ¡vel. `OrganicRoadStudioImporter.Materials.cs` amplia o importador existente; `TerrainReliefBuilder.Materials.cs` substitui a apresentaÃ§Ã£o quadriculada do relevo no novo laboratÃ³rio. A fÃ­sica continua original.

## Autoria efetiva

1. Confira worktree e pull conforme AGENTS. Identifique primeiro emendas, repetiÃ§Ã£o, transiÃ§Ãµes e relevo. Guarde o diagnÃ³stico antes de criar material novo.
2. Gere em destino ausente. Use seed, origem, PPU e versÃ£o explÃ­citos; todos os chunks da regiÃ£o compartilham contexto completo. Nunca alegue continuidade entre regiÃµes independentes sem halo semÃ¢ntico compartilhado.
3. Biblioteca: seis materiais, trÃªs funÃ§Ãµes por material em mÃ³dulos 128Ã—32; Ã¡rea Ãºtil menor para stamps transparentes. Camadas semÃ¢nticas Aseprite, paleta e luz superior esquerda. NÃ£o espelhe/rotacione luz. Edite a fonte em cÃ³pia e exporte nova revisÃ£o, preservando contrato do canvas.
4. Componha em trÃªs estados: base sem stamps; transiÃ§Ãµes sem stamps; final com detalhes. Corrija contornos/UVs na camada estrutural. NÃ£o esconda grade com ruÃ­do ou vegetaÃ§Ã£o.
5. Varie macro pigmento, meso manchas e micro motivos contextualizados por umidade/material/estrada. Densidade moderada e distÃ¢ncia mÃ­nima espacial; nÃ£o use uma rotaÃ§Ã£o aleatÃ³ria de tiles iluminados.
6. Importe no Editor real em cena/arte novas. Point, RGBA, mipmaps/compressÃ£o off. Atlases sÃ£o saÃ­das reproduzÃ­veis de fontes modulares, nÃ£o um panorama canÃ´nico. NÃ£o gere em Play nem crie um GameObject por detalhe.
7. Execute testes, recompile, Console, Play/Input System, caminhada/esquiva, sorting, pÃ©s, sequÃªncia de cÃ¢mera em movimento. Restaure dispositivos, perfil, resoluÃ§Ã£o e Play. Apresente A/B/C na mesma estrada, seed, pose, cÃ¢mera e escala.

```powershell
python Tools/ArtPipeline/WorldGen/terrain_materials.py library --output Temp/Materials/new-library
python Tools/ArtPipeline/WorldGen/terrain_materials.py export-library --source ArtSource/Labs/World2026/WorldStudio03/LibraryV2/terrain-motifs.aseprite --output Temp/Materials/edited-library
python Tools/ArtPipeline/WorldGen/terrain_materials.py generate --recipe ArtSource/Labs/World2026/WorldStudio03/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio03/LibraryV2 --output Temp/Materials/new-region
python Tools/ArtPipeline/WorldGen/terrain_materials.py verify --recipe ArtSource/Labs/World2026/WorldStudio03/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio03/LibraryV2 --output ArtSource/Labs/World2026/WorldStudio03/BuildR7/A
python Tools/ArtPipeline/WorldGen/terrain_materials.py render --recipe ArtSource/Labs/World2026/WorldStudio03/Recipes/recipe-A.json --library ArtSource/Labs/World2026/WorldStudio03/LibraryV2 --bounds '[1024,704,192,160]' --stage final --output Temp/Materials/local-revision
python -m unittest discover -s Tools/ArtPipeline/WorldGen -p 'test_*.py' -v
```

## RevisÃ£o e limites

- NÃ£o chamar grid removido ou arte concluÃ­da sÃ³ porque testes passaram. Inspecione base, transiÃ§Ãµes, detalhes e movimento na Game View. Grade claramente visÃ­vel reprova o marco artisticamente.
- Hashes provam integridade, mÃ©tricas de linhas revelam periodicidade; nenhum deles certifica beleza. AprovaÃ§Ã£o artÃ­stica Ã© explÃ­cita do usuÃ¡rio.
- Lama/umidade sÃ£o aparÃªncia sobre o proxy existente, nÃ£o simulaÃ§Ã£o hÃ­drica. Areia Ã© uma superfÃ­cie, nÃ£o um bioma novo.
- Patches atuais alteram pigmento em Ã¡rea definida; nÃ£o sÃ£o pintura vetorial universal nem editor completo de materiais. Regenerar Ã© autoria offline.
- Relevo projetado continua visual no plano 2D. NÃ£o anunciar escalada, hidrologia, vegetaÃ§Ã£o fÃ­sica, construÃ§Ã£o ou promoÃ§Ã£o ao mundo oficial.
- Ferramentas de IA podem ajudar o agente a decidir receitas e formas; nÃ£o afirmar uso de ImageGen/Blender quando nÃ£o executados. Preserve proveniÃªncia/licenÃ§as das fontes usadas.
