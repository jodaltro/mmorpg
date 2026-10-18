Shader "Valdoria/Ground13RGeology"
{
 Properties { _MainTex("Editable upland atlas",2D)="white"{} _MineralTex("Existing vertical mineral",2D)="white"{} _Color("Tint",Color)=(1,1,1,1) }
 SubShader
 {
  Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
  Pass
  {
   Tags { "LightMode"="SRPDefaultUnlit" }
   Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
   HLSLPROGRAM
   #pragma vertex Vert
   #pragma fragment Frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
   TEXTURE2D(_MineralTex); SAMPLER(sampler_MineralTex);
   CBUFFER_START(UnityPerMaterial)
    float4 _Color;
   CBUFFER_END
   struct Attributes { float4 positionOS:POSITION; float2 uv:TEXCOORD0; float2 source:TEXCOORD1; float4 color:COLOR; };
   struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float source:TEXCOORD1; float4 color:COLOR; };
   Varyings Vert(Attributes i){Varyings o;o.positionCS=TransformObjectToHClip(i.positionOS.xyz);o.uv=i.uv;o.source=i.source.x;o.color=i.color*_Color;return o;}
   half4 Frag(Varyings i):SV_Target { half4 pigment;if(i.source<.5) pigment=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);else pigment=SAMPLE_TEXTURE2D(_MineralTex,sampler_MineralTex,i.uv);return pigment*i.color; }
   ENDHLSL
  }
 }
}
