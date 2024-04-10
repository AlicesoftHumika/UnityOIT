Shader "OITRP/Opaque" 
{
    Properties {
        _MainTex("Main Texture", 2D) = "white" {}
        _Color("Color", Color) = (1, 1, 1, 1)
		_Normal ("Normal Textire", 2D) = "bump"{}
        _BumpScale ("Bump Scale", Float) = 1.0
    }
    SubShader {
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "OITRenderPipeline"
            "IgnoreProjector" = "true"
        }

        Pass {
            Tags {"LightMode" = "OpaquePass"}

            HLSLPROGRAM

			#include "UnityCG.cginc"
            #include "./Lib.hlsl"

            #pragma vertex default_vert
            #pragma fragment frag

			#define PI 3.14159265358979323846264338327950288419716939937510

            float4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Normal;
			float4 _Normal_ST;
            float _BumpScale;

            inline float3 diffuseLambert(float3 albedo){
                return albedo / PI;
            }

            struct OpaqueFragResult
            {
                float4 color : SV_TARGET0;
                float4 opaque : SV_TARGET1;
            };


			OpaqueFragResult frag(v2f i):SV_TARGET{
				
				float4 albedo = tex2D(_MainTex, i.uv) * _Color;
				float3 ambient = unity_AmbientSky.rgb * albedo.rgb;
				float4 packNormal = tex2D(_Normal, i.uv); 
                // float shadow = SHADOW_ATTENUATION(i);
                // UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				float3 normal = UnpackNormal(packNormal);
                normal.xy *= _BumpScale;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
                
				normal = normalize(float3(dot(normal, i.t2w0.xyz), dot(normal, i.t2w1.xyz), dot(normal, i.t2w2.xyz)));
				float3 lightDir = -_MainLightDirection;
				float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

				float3 halfDir = normalize(lightDir + viewDir);
				float nv = saturate(dot(normal, viewDir));
				float nl = saturate(dot(normal, lightDir));
				float nh = saturate(dot(normal, halfDir));
				float lv = saturate(dot(lightDir, viewDir));
				float hl = saturate(dot(halfDir, lightDir));

                float3 light = _MainLightColor;// * atten;

				float3 diffuseTerm = PI * diffuseLambert(albedo.rgb) * light * nl + ambient;
				float3 color = diffuseTerm;

                OpaqueFragResult o;
                o.color = float4(color, albedo.a);
                o.opaque = float4(color, albedo.a);

				return o;
			}

            ENDHLSL
        }
    }
}