using UnityEngine;
using UnityEngine.Rendering.Universal;
namespace Mmorpg.Runtime
{
    [RequireComponent(typeof(PixelPerfectCamera))]
    public sealed class AdaptivePixelViewport : MonoBehaviour
    {
        private int width,height;private PixelPerfectCamera pixels;
        private void Awake(){pixels=GetComponent<PixelPerfectCamera>();}
        private void Update()
        {
            if(Screen.width==width&&Screen.height==height)return;width=Screen.width;height=Screen.height;
            int scale=Mathf.Max(1,height/360);if(height>=480)scale=Mathf.Max(2,scale);
            pixels.refResolutionX=Mathf.Max(2,width/scale/2*2);pixels.refResolutionY=Mathf.Max(2,height/scale/2*2);
            pixels.cropFrame=PixelPerfectCamera.CropFrame.Windowbox;
        }
    }
}
