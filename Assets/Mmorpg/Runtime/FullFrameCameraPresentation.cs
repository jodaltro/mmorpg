using UnityEngine;

namespace Mmorpg.Runtime
{
    // Restore the full viewport after the former integer-zoom camera is disabled.
    [RequireComponent(typeof(Camera))]
    public sealed class FullFrameCameraPresentation : MonoBehaviour
    {
        [SerializeField] private Camera view;
        public void Configure(Camera camera) => view=camera;
        private void Start()
        {
            if(view==null)view=GetComponent<Camera>();
            view.rect=new Rect(0,0,1,1);
            view.ResetProjectionMatrix();
            view.ResetWorldToCameraMatrix();
        }
    }
}
