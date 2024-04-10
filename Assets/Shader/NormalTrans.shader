Shader "Unlit/NormalTrans"
{
    Properties
    {
        _color ("color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_Roughness ("Roughness", Float) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 100

        Pass
        {
			ZTest On
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            fixed4 _color;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			float _Roughness;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 lightDir: TEXCOORD0;
				float3 viewDir : TEXCOORD1;
				float2 uv : TEXCOORD2;
				float3 normal : TEXCOORD3;
				float3 posOS : TEXCOORD4;
			};

            v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;

				// TANGENT_SPACE_ROTATION;
				// Transform the light direction from object space to tangent space
				// o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
				o.lightDir = ObjSpaceLightDir(v.vertex);
				// Transform the view direction from object space to tangent space
				// o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;
				o.viewDir = ObjSpaceViewDir(v.vertex);
				o.normal = v.normal;
				o.posOS = v.vertex;

				return o;
			}

			float4 frag(v2f i) : SV_Target {
				float3 lightDir = normalize(i.lightDir);
				float3 normal = normalize(i.normal);
				// fixed3 tangentViewDir = normalize(i.viewDir);
				// Color Tint.
				// fixed4 albedo = tex2D(_MainTex, i.uv) * _color;
				fixed4 albedo = _color;
				// fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo.rgb;
				fixed3 ambient = albedo.rgb;
				// fixed3 diffuse = _LightColor0.rgb * albedo.rgb * max(0, dot(tangentNormal, tangentLightDir));
				fixed3 diffuse = albedo.rgb * max(0, dot(normal, lightDir));
				float alpha = _color.a;

				// In object space.
				float3 viewDir = normalize(i.viewDir);
				float3 h = normalize(lightDir + viewDir);
				float spec = pow(max(dot(normal, h), 0), _Roughness);

				float3 C = (diffuse + spec.xxx);

				// C = _color.rgb;

				return float4(C, alpha);
			}
            ENDCG
        }
    }
}
