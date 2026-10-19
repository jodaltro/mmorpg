# Village02 Anime — contrato de autoria

Atualização de19/10/2026: a ampliação e promoção autorizadas são regidas por [RoyalGardensContract](RoyalGardensContract.md). A receita AnimeRebuildV1 abaixo é o baseline histórico da arquitetura; a cena agora consome RoyalGardensV1, com172 volumes.

Direção autorizada em 19/10/2026: somente a adaptação animada de Release That Witch. Moradias pobres, madeira e reboco gastos; castelo mantido com pedra clara, gramado, fonte, árvores e flores. Autorização de direção não é aprovação dos assets resultantes. A premissa narrativa consta em GameVision.

Autoridade: AnimeRebuildV1/SourceV2 e GardenSourceV1; ExportV2 e GardenExportV1 verificam a exportação. IntegrationV2 contém a separação final de coberturas opacas. IntegrationV1 é evidência anterior à correção visual. Masters e selected-prompts.json preservam entradas e prompts. O produtor histórico da IntegrationV1 foi arquivado com hash coincidente em Docs/Validation/ValdoriaVillage02-Anime/QA/integration-producer-v1.py.

Geometria: manter os 120 volumes anteriores, acrescentar somente os três volumes explícitos do jardim; não extrair obstáculos de pixels. Plantas baixas não bloqueiam; troncos e fonte bloqueiam. Novas silhuetas devem ser revisadas em Play quanto à propriedade de piso/telhado e à oclusão opaca. Nunca interpretar diagnóstico de IoU ou teste de hash como aprovação artística ou garantia universal de colisão.

BuildVillage02Anime recusa destinos existentes e requer Editor parado e limpo. ApplyOpaqueRevision verifica igualdade dos polígonos antes de trocar apresentação. A cena candidata não altera Build Settings. Validação e limites reais em ../Validation/ValdoriaVillage02-Anime.md.
