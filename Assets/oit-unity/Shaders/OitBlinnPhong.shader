Shader "OrderIndependentTransparency/BlinnPhong"
{
	Properties{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("MainTex", 2D) = "white" {}
		_Roughness("Roughness", Float) = 20
	}
	SubShader
	{
		Tags{ "Queue" = "Geometry" }

		Pass {
			ZTest LEqual
			ZWrite Off
			ColorMask 0
			Cull Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma require randomwrite
			// #pragma enable_d3d11_debug_symbols

			#include "UnityCG.cginc"
    		#include "LinkedListCreation.hlsl"

			// sampler2D _MainTex;
			// float4 _MainTex_ST;
			half4 _Color;
			float _Roughness;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f {
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 normal : TEXCOORD1;
				float3 lightDir : TEXCOORD2;
				float3 viewDir : TEXCOORD3;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.normal = normalize(v.normal);
				o.lightDir = ObjSpaceLightDir(v.vertex);
				o.viewDir = ObjSpaceViewDir(v.vertex);
				return o;
			}

			[earlydepthstencil]
			float4 frag(v2f i, uint uSampleIdx : SV_SampleIndex) : SV_Target
			{
				// Blinn-Phong
				half3 color = _Color.rgb;

				float3 normal = normalize(i.normal);
				float3 lightDir = normalize(i.lightDir);
				float3 viewDir = normalize(i.viewDir);

				half3 diffuse = max(0, dot(normal, lightDir)) * color;

				float3 h = normalize(lightDir + viewDir);
				float spec = pow(max(0, dot(normal, h)), _Roughness);

				color = diffuse + spec.xxx;

				half4 col = half4(color, _Color.a);

				createFragmentEntry(col, i.vertex.xyz, uSampleIdx);

				return col;
			}
			ENDHLSL
		}
	}

    FallBack "Unlit/Transparent"
}