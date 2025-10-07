Shader "LucasShaders/LambertWithAmbient"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque"
               "Queue"="Geometry"
               "RenderPipeline"="UniversalRenderPipeline" }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

           
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(posWS);
                OUT.normalWS    = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
               
                float3 N = SafeNormalize(IN.normalWS);

               
                Light mainLight = GetMainLight();           
                float  NdotL    = saturate(dot(N, mainLight.direction));
                half3  diffuse  = _Color.rgb * mainLight.color.rgb * NdotL;

                // Ambient from spherical harmonics (scene ambient)
                half3 ambient = SampleSH(N) * _Color.rgb;

                return half4(diffuse + ambient, 1);
            }
            ENDHLSL
        }
    }

    FallBack Off
}