using UnityEngine;

namespace Mmorpg.Runtime
{
    public sealed class CameraFollow : MonoBehaviour
    {
        [SerializeField] private Transform target;
        [SerializeField, Min(0)] private float followTime = .045f;
        [SerializeField, Min(1)] private int pixelsPerUnit=16;
        private Vector3 velocity, center;
        private bool initialized;
        [SerializeField] private bool clampToWorld;
        [SerializeField] private Rect worldBounds;
        public void ConfigureBounds(Rect bounds){worldBounds=bounds;clampToWorld=true;}
        public void Configure(Transform value) => target = value;
        public void ConfigurePixelGrid(int ppu) => pixelsPerUnit=Mathf.Max(1,ppu);
        private void LateUpdate()
        {
            if (target == null) return;
            var desired = new Vector3(target.position.x,target.position.y,-10);
            if(clampToWorld)
            {
                var camera=GetComponent<Camera>();float halfY=camera.orthographicSize,halfX=halfY*camera.aspect;
                desired.x=worldBounds.width<=halfX*2?worldBounds.center.x:Mathf.Clamp(desired.x,worldBounds.xMin+halfX,worldBounds.xMax-halfX);
                desired.y=worldBounds.height<=halfY*2?worldBounds.center.y:Mathf.Clamp(desired.y,worldBounds.yMin+halfY,worldBounds.yMax-halfY);
            }
            if(!initialized || Vector3.Distance(center,desired)>5) {center=desired;initialized=true;}
            center=Vector3.SmoothDamp(center,desired,ref velocity,followTime,Mathf.Infinity,Time.deltaTime);
            transform.position = new Vector3(Mathf.Round(center.x * pixelsPerUnit) / pixelsPerUnit, Mathf.Round(center.y * pixelsPerUnit) / pixelsPerUnit, -10);
        }
    }
}
