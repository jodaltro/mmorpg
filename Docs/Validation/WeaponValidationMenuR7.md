# Menu Esc para validar armas — R7

Cena: `Assets/Mmorpg/Scenes/HumanoidSwordR7.unity`. **Esc → Validar armas → Espada / Arco frontal / Arco lateral → Continuar e testar**. Clique/J reproduz a puxada do arco; V muda a vista; Esc volta ao menu. Espada mantém WASD, básico e pesado. Arco é estudo estacionário de pose, sem projéteis ou dano. A seleção é temporária e F5 volta à espada.

## Implementação

Menu uGUI existente estendido com página opcional; nenhuma segunda implementação de pausa ou EventSystem. Referências serializadas. `WeaponValidationPreview` suspende e restaura apresentação/entrada/espada durante a validação do arco; alvo temporário da câmera enquadra o corpo e o arco. Nenhuma migração de perfil, propriedade de item ou regra de combate nova. Apenas R7 recebe o componente e a página; cenas oficiais e históricas não foram editadas.

Arquivos: `Assets/Mmorpg/Runtime/WeaponValidationPreview.cs`, `WeaponValidationMenu.cs`, `SessionMenuView.cs`. Autoria repetível pelo Editor conectado: `AgentScripts/BuildWeaponValidationMenuR7.cs`, com recusa de sobrescrita. Não executar Create novamente sobre o menu já montado.

## Testes reais executados

`InspectWeaponValidationMenuR7.Inspect` usou Keyboard/Mouse do Input System, raycasts UI, cliques reais e capturas após fim do frame, com perfil isolado em Temp.

- Esc pausou e clique abriu a página; ambas as vistas selecionáveis.
- Continuar não vazou clique para começar uma puxada involuntária.
- J reproduziu a puxada e voltou ao idle; V mudou a vista. Esc congelou a animação.
- Modo arco ficou estacionário e produziu zero acertos confirmados. Teste adicional confirmou clique real no mundo iniciando a sequência.
- Retorno à espada restaurou componentes e movimento. Gate próximo continuou com 20 de dano e um impacto confirmado.
- Troca durante golpe foi recusada. F5 com arco selecionado restaurou a espada, manteve a identidade isolada e não duplicou o seletor.
- Voltar/Continuar existentes funcionaram após F5.
- Smoke real no `MmorpgWorld`: Esc/Continuar funcionam; página experimental ausente e política LegacyGrip preservada.
- Reteste final do menu: frames 1634→3423; console corrente zero erros/avisos. Não foram repetidas as 112 combinações de combate do R7, pois física e dano não mudaram neste ajuste.

O primeiro teste revelou MissingReferenceException na desmontagem por F5: o HUD já podia ter sido destruído antes da restauração. A restauração agora verifica referências sobreviventes. O teste completo, incluindo F5, foi repetido após a correção; histórico do erro preservado em `HumanoidSwordR7/weapon-menu-fixed-unload-error.json`. Console corrente limpo é distinto do histórico do conector.

Evidências: `weapon-menu-qa.json`, `weapon-menu-pointer.json`, `weapon-menu-legacy-smoke.json`, `console-weapon-menu-play.json` em `Docs/Validation/HumanoidSwordR7/`. Capturas em `previews/weapon-menu.png`, `weapon-menu-bow-selected.png`, `weapon-bow-south-live.png`, `weapon-bow-east-live.png`.

As fontes R5/R6, 104 sprites de locomoção, 492 arquivos congelados e cinco saves pessoais continuam protegidos por verificação. Ao terminar: input nativo e opções do Editor restaurados, override removido, Time.timeScale=1, cena R7 aberta fora de Play.

## Registro consolidado

`Docs/Art/ProceduralWeapons.md` reúne o que o sistema já demonstra, os limites atuais, controles e caminhos de autoria. Aprovação artística do arco V4 em `BowAnatomyR7.md`; não equivale a aprovação de combate à distância completo ou promoção do protagonista.
