using UnityEngine;
namespace Mmorpg.Runtime
{
    // Visual prefab data only. An actor adapter supplies the motor/health/authority at integration.
    public sealed class ProductionVisualDefinition : MonoBehaviour
    {
        [SerializeField] private ProductionCharacterSet character;
        [SerializeField] private SpriteRenderer body;
        [SerializeField] private Transform weaponPivot;
        public ProductionCharacterSet Character=>character;
        public SpriteRenderer Body=>body;
        public Transform WeaponPivot=>weaponPivot;
        public void Configure(ProductionCharacterSet set,SpriteRenderer renderer,Transform grip){character=set;body=renderer;weaponPivot=grip;}
    }
}
