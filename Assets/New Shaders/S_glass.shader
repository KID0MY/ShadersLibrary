Shader "LucasShaders/GlassWithProperExtrusion"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Normalmap", 2D) = "bump" {}
        _ScaleUV ("Scale", Range(1,20)) = 1
        _BumpExtrusion ("Extrusion Amount", Range(0, 0.1)) = 0.01
        _FresnelIntensity ("Fresnel Intensity", Range(0, 2)) = 1
        _EmissionColor ("Emission Color", Color) = (0,0,0,0)
        _TintIntensity ("Tint Intensity", Range(1, 5)) = 1.5
        _Transparacy ("Transparacy Intensity", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "Render"="Transparent" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off // Typically off for transparent/glass materials
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // Need the TANGENT for proper normal mapping in World Space
            // #pragma require_unity_editor_ext_stuff is often unnecessary in modern URP
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes // Renamed from appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT; // <-- ADDED TANGENT
            };

            struct Varyings // Renamed from v2f
            {
                float2 uv : TEXCOORD0;
                float4 uvgrab : TEXCOORD1;
                float2 uvbump : TEXCOORD2;
                float4 vertex : SV_POSITION;
                float3 viewDirWS : TEXCOORD3;
                float3 normalWS : TEXCOORD4;
                float3 tangentWS : TEXCOORD5;
                float3 bitangentWS : TEXCOORD6;
            };

            // Declare texture and sampler variables
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            float4 _BumpMap_ST;

            // Grab Pass textures
            TEXTURE2D(_GrabTexture);
            SAMPLER(sampler_GrabTexture);
            // float4 _GrabTexture_TexelSize; // Not needed if not correcting for pixel offset

            // Material properties
            float _Transparacy;
            float _ScaleUV;
            float _BumpExtrusion;
            float _FresnelIntensity;
            float _TintIntensity;
            float4 _EmissionColor;

            // Vertex shader
            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // 1. World Space Transformations & Extrusion
                float3 normalWS = TransformObjectToWorldNormal(IN.normal);
                
                // Get tangent and bitangent in World Space
                float3 tangentWS = TransformObjectToWorldDir(IN.tangent.xyz);
                float3 bitangentWS = cross(normalWS, tangentWS) * IN.tangent.w;

                // Transform vertex to world space
                float3 worldPos = TransformObjectToWorld(IN.vertex.xyz);

                // Extrude along vertex normal
                worldPos += normalWS * _BumpExtrusion;

                // Output the final vertex position in clip space
                OUT.vertex = TransformWorldToHClip(worldPos);

                // 2. UV Scaling Fix
                // Apply default tiling/offset, then multiply by custom scale
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex) * _ScaleUV; 
                OUT.uvbump = TRANSFORM_TEX(IN.uv, _BumpMap) * _ScaleUV;

                // 3. Screen-Space Grab UV Fix (Standard perspective calculation)
                float4 clipPos = OUT.vertex;
                
                // Transform Clip Space to Screen UVs (0 to 1)
                OUT.uvgrab.xy = clipPos.xy / clipPos.w * 0.5 + 0.5;
                OUT.uvgrab.w = clipPos.w;
                
                // Handle y-inversion based on platform/API
                #if UNITY_UV_STARTS_AT_TOP
                    OUT.uvgrab.y = 1.0 - OUT.uvgrab.y;
                #endif

                // 4. Pass WS vectors
                OUT.normalWS = normalWS;
                OUT.tangentWS = tangentWS;
                OUT.bitangentWS = bitangentWS;
                OUT.viewDirWS = normalize(_WorldSpaceCameraPos - worldPos);

                return OUT;
            }

            // Fragment shader
            half4 frag(Varyings IN) : SV_Target
            {
                // 1. Correct Normal Map Handling
                // Sample the normal map (in Tangent Space - TS)
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uvbump));
                
                // Construct the TBN matrix from the World Space vectors
                // TBN matrix: Tangent, Bitangent, Normal (columns or rows, depending on order)
                float3x3 TBN = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);
                
                // Transform the TS normal to World Space (WS)
                float3 normalWS = normalize(mul(TBN, normalTS));

                // 2. Fresnel effect (using the corrected normalWS)
                float viewNormalDot = saturate(dot(IN.viewDirWS, normalWS));
                float fresnelFactor = pow(1.0 - abs(viewNormalDot), _FresnelIntensity);

                // 3. Sample grab texture and main texture
                // Divide by w for perspective correction
                half4 col = SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, IN.uvgrab.xy / IN.uvgrab.w);
                half4 tint = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);

                // 4. Apply Fresnel effect and Tinting
                // Use Fresnel to blend the grabbed background (col) with the material's tint (tint)
                col.rgb = lerp(col.rgb, tint.rgb, fresnelFactor);

                // Apply tint intensity (assuming the texture provides the final color basis)
                col.rgb *= tint.rgb * _TintIntensity;

                // 5. Apply emission
                col.rgb += _EmissionColor.rgb;

                // 6. Alpha
                col.a = _Transparacy;
                
                return col;
            }
            ENDHLSL
        }
    }
}