Shader "OrderIndependentTransparency/BlinnPhongWithTex"
{
	Properties{
		_color("Color", Color) = (1,1,1,1)
		_MainTex("MainTex", 2D) = "white" {}
		_Roughness("Roughness", Float) = 20
		_Normal("Normal", 2D) = "white" {}
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

			sampler2D _MainTex;
			sampler2D _Normal;
			// float4 _MainTex_ST;
			half4 _color;
			float _Roughness;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f {
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 normal : TEXCOORD1;
				float3 lightDir : TEXCOORD2;
				float3 viewDir : TEXCOORD3;
				float4 tangent : TEXCOORD4;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.normal = normalize(v.normal);
				o.lightDir = ObjSpaceLightDir(v.vertex);
				o.viewDir = ObjSpaceViewDir(v.vertex);
				o.tangent = v.tangent;
				return o;
			}

			[earlydepthstencil]
			float4 frag(v2f i, uint uSampleIdx : SV_SampleIndex) : SV_Target
			{
				float3 normalTS = UnpackNormal(tex2D(_Normal, i.uv));
				float3 normalOS = normalize(i.normal);

				float3 normalWS = UnityObjectToWorldNormal(i.normal);
				float4 tangentOS = normalize(i.tangent);
				float3 tangentWS = UnityObjectToWorldDir(tangentOS);
				float3 binormalWS = cross(normalWS, tangentWS.xyz) * tangentOS.w;

				float3 T2W0 = float3(tangentWS.x,binormalWS.x,normalWS.x);
				float3 T2W1 = float3(tangentWS.y,binormalWS.y,normalWS.y);
				float3 T2W2 = float3(tangentWS.z,binormalWS.z,normalWS.z);

				float3x3 T2WMatrix = float3x3(T2W0.xyz, T2W1.xyz, T2W2.xyz);

				normalWS = mul(T2WMatrix, normalTS);

				float3 lightDir = UnityObjectToWorldDir(normalize(i.lightDir));
				float3 viewDir = UnityObjectToWorldDir(normalize(i.viewDir));

				// Blinn-Phong
				half3 color = tex2D(_MainTex, i.uv).rgb * _color.rgb;

				// float3 normal = normalize(i.normal);
				// float3 lightDir = normalize(i.lightDir);
				// float3 viewDir = normalize(i.viewDir);

				half3 diffuse = max(0, dot(normalWS, lightDir)) * color;

				float3 h = normalize(lightDir + viewDir);
				float spec = pow(max(0, dot(normalWS, h)), _Roughness);

				color = diffuse + spec.xxx;

				half4 col = half4(color, _color.a);

				createFragmentEntry(col, i.vertex.xyz, uSampleIdx);

				return col;
			}
			ENDHLSL
		}
	}
}