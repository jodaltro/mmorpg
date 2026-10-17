# Ocupação espacial — fonte profissional antes do padding

Coordenadas superiores no canvas original 128×160. Todos os quadros avaliados, sem recenter por pose. A lista de meshes e extremidades registra qualquer saída ao longo do clip, não somente a pose final.

| Ação | Vista | Amostras | Bounds x0,y0,x1,y1 | Padding L,T,R,B mínimo | Meshes fora | Extremidades fora |
|---|---|---:|---|---|---|---|
| Roll | south | 45 | 27.3, 27.8, 91.0, 152.5 | [0, 0, 0, 0] | nenhum | nenhuma |
| Roll | west | 45 | -6.9, 26.5, 142.3, 143.8 | [11, 0, 19, 0] | Fitted articulated leather gloves, Male_Ranger_Arms, Male_Ranger_Feet_Boots, SuperHero_Male | ball_l, ball_leaf_l, ball_leaf_r, ball_r, calf_l, calf_r, foot_l, foot_r |
| Roll | north | 45 | 37.0, 17.0, 100.7, 149.8 | [0, 0, 0, 0] | nenhum | nenhuma |
| Roll | east | 45 | -14.3, 27.2, 134.9, 145.3 | [19, 0, 11, 0] | Fitted articulated leather gloves, Male_Ranger_Arms, Male_Ranger_Feet_Boots, SuperHero_Male | ball_l, ball_leaf_l, ball_leaf_r, ball_r, calf_l, calf_r, foot_l, foot_r |
| Roll | southwest | 45 | 10.8, 27.1, 128.3, 152.3 | [0, 0, 5, 0] | Male_Ranger_Feet_Boots, SuperHero_Male | ball_leaf_l |
| Roll | northwest | 45 | 9.3, 24.0, 130.5, 147.6 | [0, 0, 7, 0] | Male_Ranger_Feet_Boots, SuperHero_Male | ball_leaf_r, ball_r |
| Roll | northeast | 45 | -0.3, 25.9, 117.2, 151.4 | [5, 0, 0, 0] | Male_Ranger_Feet_Boots, SuperHero_Male | ball_leaf_l |
| Roll | southeast | 45 | -2.5, 28.2, 118.7, 140.7 | [7, 0, 0, 0] | Male_Ranger_Feet_Boots, SuperHero_Male | ball_leaf_r, ball_r |
| Death01 | south | 73 | 19.1, 26.2, 97.5, 145.5 | [0, 0, 0, 0] | nenhum | nenhuma |
| Death01 | west | 73 | 28.1, 26.5, 179.4, 145.6 | [0, 0, 56, 0] | Eyebrows, Eyes, Fitted articulated leather gloves, Hair_SimpleParted, Indigo fitted under-armor lining, Indigo upper sleeves, Male_Ranger_Acc_Pauldron, Male_Ranger_Arms, Male_Ranger_Body, SuperHero_Male | Head, hand_l, hand_r, lowerarm_l, lowerarm_r |
| Death01 | north | 73 | 30.5, 24.9, 108.9, 187.2 | [0, 0, 0, 32] | Eyebrows, Eyes, Fitted articulated leather gloves, Hair_SimpleParted, Indigo fitted under-armor lining, Indigo upper sleeves, Male_Ranger_Acc_Pauldron, Male_Ranger_Arms, Male_Ranger_Body, Male_Ranger_Body_Belt_1, Male_Ranger_Body_Belt_2, SuperHero_Male | Head, hand_l, hand_r, lowerarm_l, lowerarm_r |
| Death01 | east | 73 | -51.4, 27.0, 99.9, 152.0 | [56, 0, 0, 0] | Eyebrows, Eyes, Fitted articulated leather gloves, Hair_SimpleParted, Indigo fitted under-armor lining, Indigo upper sleeves, Male_Ranger_Acc_Pauldron, Male_Ranger_Arms, Male_Ranger_Body, SuperHero_Male | Head, hand_l, hand_r, lowerarm_l, lowerarm_r |
| Death01 | southwest | 73 | 26.5, 26.2, 156.2, 148.5 | [0, 0, 33, 0] | Eyebrows, Eyes, Fitted articulated leather gloves, Hair_SimpleParted, Indigo fitted under-armor lining, Indigo upper sleeves, Male_Ranger_Acc_Pauldron, Male_Ranger_Arms, Male_Ranger_Body, SuperHero_Male | hand_l, lowerarm_l |
| Death01 | northwest | 73 | 23.9, 25.4, 172.6, 174.0 | [0, 0, 49, 19] | Eyebrows, Eyes, Fitted articulated leather gloves, Hair_SimpleParted, Indigo fitted under-armor lining, Indigo upper sleeves, Male_Ranger_Acc_Pauldron, Male_Ranger_Arms, Male_Ranger_Body, SuperHero_Male | hand_l, hand_r, lowerarm_l, lowerarm_r |
| Death01 | northeast | 73 | -28.2, 25.8, 101.5, 184.2 | [33, 0, 0, 29] | Eyebrows, Eyes, Fitted articulated leather gloves, Hair_SimpleParted, Indigo fitted under-armor lining, Indigo upper sleeves, Male_Ranger_Acc_Pauldron, Male_Ranger_Arms, Male_Ranger_Body, SuperHero_Male | hand_l, hand_r, lowerarm_l, lowerarm_r |
| Death01 | southeast | 73 | -44.6, 26.8, 104.1, 145.8 | [49, 0, 0, 0] | Eyebrows, Eyes, Fitted articulated leather gloves, Hair_SimpleParted, Indigo fitted under-armor lining, Indigo upper sleeves, Male_Ranger_Arms, Male_Ranger_Body, SuperHero_Male | hand_r, lowerarm_r |

A pelve desloca o corpo visualmente durante a queda, enquanto a transformação do rig é constante. O pivô lógico conserva a raiz física; não reposicionamos Rigidbody/colliders para acompanhar mãos/pés. Dados por quadro em `ArtSource/Labs/Humanoid2026/R8/spatial-audit.json`.

A fonte de esquiva integrada é o passo evasivo, não Roll. A comparação foi mantida para justificar a escolha em 0,22 s.
