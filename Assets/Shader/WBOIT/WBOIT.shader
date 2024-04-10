Shader "WBOIT"
{
    Properties
    {
        _color ("color Tint", Color) = (1, 1, 1, 1)
		_Smoothness("Smoothness", Float) = 0.1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True"}

        // 0
        Pass
        { 
            Tags { "LightMode"="WBOITAcc" }

            ZWrite Off
			ZTest On
			Blend One One

			Cull Off

            CGPROGRAM

            #pragma shader_feature  _WEIGHTED_ON
			#pragma multi_compile _WEIGHTED0 _WEIGHTED1 _WEIGHTED2 _WEIGHTED3 _WEIGHTED4

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            half4 _color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;

			float _Smoothness;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 lightDir: TEXCOORD0;
				float3 viewDir : TEXCOORD1;
				float2 uv : TEXCOORD2;
				float z : TEXCOORD3;
				float3 normal : TEXCOORD4;
			};

            v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;

				o.lightDir = ObjSpaceLightDir(v.vertex);
				o.viewDir = ObjSpaceViewDir(v.vertex);

				// Depth
				o.z =  UnityObjectToClipPos(v.vertex).w;

				// NDC depth
				// o.z = o.pos.z / o.pos.w;

				o.normal = v.normal;

				return o;
			}

			// Weight Function
			float w(float z, float alpha) {
				#ifdef _WEIGHTED0
					return pow(z, -2.5);
				#elif _WEIGHTED1
					return alpha * max(1e-2, min(3 * 1e3, 10.0/(1e-5 + pow(z/5, 2) + pow(z/200, 6))));
					// return alpha * max(1e-2, min(3 * 1e3, 10.0/(1e-5 + pow(z * 2, 2) + pow(z/20, 6))));
				#elif _WEIGHTED2
					return alpha * max(1e-2, min(3 * 1e3, 0.03/(1e-5 + pow(z/200, 4))));
				#elif _WEIGHTED3
				    return clamp(pow(min(1.0, alpha * 10.0) + 0.01, 3.0) * 1e8 * pow(1.0 - z * 0.9, 3.0), 1e-2, 3e3);
				// In KleyGE. Shold use NDC depth.
				#elif _WEIGHTED4
					return alpha * clamp(0.03f / (1e-5f + pow(z / 200, 4.0f)), 0.01f, 3000);
				#endif 
				return 1.0;
			}
			
			float4 frag(v2f i) : SV_Target {
				// fixed3 tangentLightDir = normalize(i.lightDir);
				// // fixed3 tangentViewDir = normalize(i.viewDir);
				// fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
				float3 normal = normalize(i.normal);
				float3 lightDir = normalize(i.lightDir);

				float3 viewDir = normalize(i.viewDir);

				// Color Tint.
				// fixed4 albedo = tex2D(_MainTex, i.uv) * _color;
				half4 albedo = _color;

				// fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo.rgb;
				fixed3 ambient = albedo.rgb;
				// fixed3 diffuse = _LightColor0.rgb * albedo.rgb * max(0, dot(normal, tangentLightDir));
				fixed3 diffuse = albedo.rgb * max(0, dot(normal, lightDir));
				float alpha = _color.a;

				float3 h = normalize(viewDir + lightDir);
				float spec = pow(max(dot(h, normal), 0), _Smoothness);

				float3 C = (diffuse + spec.xxx) * alpha;
				// float3 C = (diffuse) * alpha;

				// C = _color.rgb;
				// float z = i.pos.z / i.pos.w;

				#ifdef _WEIGHTED_ON
					return float4(C, alpha) * w(i.z, alpha);
					// return float4(C * w(i.z, alpha).xxx, alpha);
				#else
					return float4(C, alpha);
				#endif
			}

            ENDCG
        }

		// 1
		Pass
		{
			Tags {"LightMode"="WBOITAlpha" }

			ZWrite Off
			ZTest On
			Blend Zero OneMinusSrcAlpha
			Cull Off

			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			half4 _color;
			sampler2D _MainTex;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
				float z : TEXCOORD1;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float z : TEXCOORD0;
				float2 uv : TEXCOORD1;
			};

			// Weight Function
			float w(float z, float alpha) {
				#ifdef _WEIGHTED0
					return pow(z, -2.5);
				#elif _WEIGHTED1
					return alpha * max(1e-2, min(3 * 1e3, 10.0/(1e-5 + pow(z/5, 2) + pow(z/200, 6))));
					// return alpha * max(1e-2, min(3 * 1e3, 10.0/(1e-5 + pow(z * 2, 2) + pow(z/20, 6))));
				#elif _WEIGHTED2
					return alpha * max(1e-2, min(3 * 1e3, 0.03/(1e-5 + pow(z/200, 4))));
				#elif _WEIGHTED3
				    return clamp(pow(min(1.0, alpha * 10.0) + 0.01, 3.0) * 1e8 * pow(1.0 - z * 0.9, 3.0), 1e-2, 3e3);
				// In KleyGE
				#elif _WEIGHTED4
					return alpha * clamp(0.03f / (1e-5f + pow(z / 200, 4.0f)), 0.01f, 3000);
				#endif 
				return 1.0;
			}
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				
				// Depth
				o.z = UnityObjectToClipPos(v.vertex).w;

				// NDC depth
				// o.z = o.pos.z / o.pos.w;


				return o;
			}
			
			float4 frag(v2f i) : SV_Target {
				float alpha = _color.a;

				#ifdef _WEIGHTED_ON
					// return alpha * w(i.z, alpha);
					return alpha;
				#else
					return alpha;
				#endif
			}
			ENDCG
		}

		// 2
		Pass
        {
			Tags {"Queue"="Transparent" "LightMode"="WBOITBlend"}

            ZTest On 
            Cull Off 
            ZWrite Off

			// Blend One Zero 
			// Blend SrcAlpha OneMinusSrcAlpha
			Blend OneMinusSrcAlpha SrcAlpha

            CGPROGRAM

            #pragma vertex vert
			#pragma fragment frag

			sampler2D _CameraOpaqueTexture;
			sampler2D _AccTex;
			sampler2D _AlphaTex;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				
				return o;
			}
			
			half4 frag(v2f i) : SV_Target {
				// half4 background = tex2D(_CameraOpaqueTexture, i.uv);
				float4 acc = tex2D(_AccTex, i.uv);
				float alpha = tex2D(_AlphaTex, i.uv).x;

				// KleyGE
				// half4 col = half4(acc.rgb / max(alpha, 1e-4f), acc.a);

				// if (acc.a == 0)
				// {
				// 	discard; 
				// }

				// if(isinf(acc.r) || isinf(acc.g) || isinf(acc.b))
				// {
				// 	acc.rgb = alpha.xxx;
				// }

				// half4 col = float4(acc.rgb / clamp(alpha, 1e-4, 5e4), acc.a);
				half4 col = float4(acc.rgb / clamp(acc.a, 1e-4, 5e4), alpha);

				return col;
				// return half4(col.rgb * (1 - acc.a) + background.rgb * acc.a, 1);
			}
            ENDCG
        }
    }
}
