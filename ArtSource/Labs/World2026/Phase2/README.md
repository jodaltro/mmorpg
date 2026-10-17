# Camadas contextuais de profundidade — Fase 2

`valdoria-depth.aseprite` contém as três silhuetas editáveis da composição v3:
poço de telhas azuis, casa de telhas azuis e carvalho central. O Aseprite copia
os pixels da fonte através de polígonos de autoria, com alfa fora deles.

Fonte: `../R10/Aseprite/valdoria-village-detail-v3.aseprite`, topo 1536×800.
Receita: `Docs/Art/ValdoriaWorldBlueprint.json`, coordenadas em pixels com origem
superior esquerda. Física usa polígonos semânticos separados da silhueta.

Reprodução, sempre para pasta nova:

```
python Tools/ArtPipeline/World/rebuild_valdoria_depth.py --output <pasta-nova> --verify
```

Essas camadas preservam a composição existente. Não são objetos isolados prontos
para distribuição ou geração procedural: ainda falta reconstruir o chão oculto
e revisar os contornos na escala nativa. A aprovação artística está pendente.
Origem artística e licença seguem a fonte R10 registrada no projeto; não há
asset externo adicional ou geração de imagem nova nesta etapa.
