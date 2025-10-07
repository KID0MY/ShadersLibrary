Shader "Custom/FakeSphereSkybox"
{
    Properties
    {
        _CubeTex ("Cubemap", CUBE) = "" {}
        _Exposure ("Exposure", Range(0.1, 3.0)) = 1.0
    }

    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Opaque" }

        Cull Front        // Render the INSIDE of the sphere
        ZWrite Off        // Don't block other geometry
        Lighting Off
        Fog { Mode Off }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            samplerCUBE _CubeTex;
            float _Exposure;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldDir : TEXCOORD0;
            };

            v2f vert (appdata v)
            {
                v2f o;

                // Transform to clip space
                o.pos = UnityObjectToClipPos(v.vertex);

                // Compute world direction (from camera to vertex)
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldDir = normalize(worldPos - _WorldSpaceCameraPos);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = texCUBE(_CubeTex, i.worldDir);
                col.rgb *= _Exposure;
                return col;
            }
            ENDHLSL
        }
    }

    FallBack Off
}
