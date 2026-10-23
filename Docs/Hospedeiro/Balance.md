# Hospedeiro — balanceamento das habilidades e das mutações

O balanceamento é uma **medição**, não uma sensação: `BioBalance` (`clients/hospedeiro/scripts/domain/bio_balance.gd`) usa uma régua única, os números afinados ficam em `clients/hospedeiro/data/balance.json` e os testes (`tests/test_balance.gd`) seguram tudo dentro das faixas.

## A régua

- **Valor** de uma habilidade: quanto uma conjuração vale em pontos de dano ou de vida numa luta típica (2,2 inimigos juntos, o chicote básico a 31 de dano por segundo, 14 de dano por segundo contra a célula). Cada tipo (cone, onda, lança, projétil, salva, investida, marca, zona, cura, escudo, aura, invocação) tem sua fórmula em `ability_value`.
- **Preço**: o ATP mais o tempo do tempo de recarga (1,2 ATP por segundo).
- **Valor por preço** (*worth*): o chicote básico vale 1,64. Cada classe tem uma meta própria em torno de 2,05, com correção empírica por classe (`CLASS_ADJUST`), tolerância de 18%.
- **Pontuação de uma mutação**: o que seus números dão menos o que tiram, na mesma régua (1% de membrana, de velocidade, de dano, +1 ATP/s, poder e recarga das habilidades, e quanto cada perk aumenta o valor da habilidade que remodela). Metas por raridade: comum 5, incomum 8, rara 12, épica 17 (tolerância de 30%, no mínimo 1,5).

## Como se reafina

1. `python clients/hospedeiro/tools/gen_mutations.py` gera as mutações (motor e cliente) a partir de uma tabela.
2. `godot --headless --path clients/hospedeiro --script res://tests/balance_tune.gd -- abilities` calcula os números das habilidades; depois `... -- genes` calcula os das mutações.
3. Repetir o passo 1 aplica os números das mutações. O roteiro completo está em `clients/hospedeiro/tools/` (o que rodei foi o mesmo encadeamento).
4. `tests/balance_report.gd` imprime a tabela; `tests/balance_duel.gd` confere na prática: cada classe, com um lutador automático, limpa a mesma sala.

## Resultado

Antes: o valor por preço ia de 0,75 (Muralha de Carne) a 3,98 (Febre Dirigida), mais de cinco vezes; as mutações de -10 a +36 pontos, sem relação com a raridade. Depois: todas as 24 habilidades dentro de ±18% da meta da classe, e as 48 mutações a ~1 ponto da meta da raridade.

No duelo prático (sala do anel, três execuções por classe) o tempo médio para limpar ficou entre 15,6 s e 20,5 s: macrófago 20,5, neutrófilo 18,7, linfócito B 18,1, dendrítica 17,5, T citotóxico 15,7 e T auxiliar 15,6. Antes da correção por classe era de 10,1 s (T auxiliar) a 22,7 s (macrófago).

## Habilidades afinadas (diferenças sobre o padrão do catálogo)

| habilidade | números |
|---|---|
| anticorpo_y | cooldown 1.0, damage 23.5 |
| apoptose | cooldown 6.0, cost 18.0, damage 28.0 |
| apresentar_antigeno | mult 1.42 |
| canto_de_citocinas | regen_atp 7.0, speed 1.28 |
| chamado_a_linfa | tick 4.0 |
| chuva_de_esporos | cooldown 7.5, cost 14.5, regen_atp 9.5, regen_membrane 3.5 |
| citocina_curativa | amount 39.5 |
| degranulacao | tick 8.0 |
| dendritos_em_chicote | damage 22.5 |
| engolir | damage 16.5, heal 0.53 |
| explosao_de_plasmocito | damage 37.5 |
| explosao_neutrofilica | damage 34.0 |
| febre_dirigida | cooldown 17.5, cost 29.0, tick 3.5 |
| golpe_litico | damage 33.0 |
| lisossomo_acido | tick 5.5 |
| mapa_quimico | mult 1.39 |
| muralha_de_carne | cooldown 8.5, cost 20.5, duration 8.0, taken 0.2 |
| netose | burst 41.5 |
| onda_de_pseudopodes | damage 34.0 |
| opsonizacao | mult 1.35 |
| perforina | cooldown 2.0, damage 11.5 |
| rede_de_dna | cooldown 4.5, cost 12.5, tick 3.5 |
| salva_de_anticorpos | cooldown 3.5, cost 18.0, damage 16.5 |
| sinal_de_morte | mult 1.76 |

## Limites conhecidos

- O modelo é uma aproximação: não conhece o jogador, só um lutador simples. O duelo automático mede dano em área e zonas melhor que habilidades de mobilidade e de apoio.
- As mutações de apoio (cura, aura, invocação) valem pela eficiência calculada, mas o efeito em grupo só será medido quando houver grupo.
- Os números dos inimigos do granuloma não entram nesta régua.
