Shader "Glass"
{
    Properties
    {
        _Matcap ("Texture", 2D) = "white" {}
        _RefracMatcap("RefracMatcap", 2D)= "white" {}
        _RefracMu("RefracMu", float) = 1
        _Color("Color", Color) = (1,1,1,1)
        _OpacityMu("OpactiyMu", float) = 1
        _BaseColor("BaseColor",Color) = (1,1,1,1)
        _MatcapMu("MatcapMu", float) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" }

        LOD 100

        Pass
        {
            ZWrite Off
            Cull Off
            Blend SrcAlpha One

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal_world : TEXCOORD1;
                float3 pos_world : TEXCOORD2;
            };

            sampler2D _Matcap;
            sampler2D _RefracMatcap;
            float4 _MainTex_ST;
            float _RefracMu;
            float4 _Color;
            float _OpacityMu;
            float _MatcapMu;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal_world = mul(float4(v.normal, 0.0), unity_WorldToObject);
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal_dir = normalize(i.normal_world);
                float3 pos_world = i.pos_world;
                float3 View_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);

                //World Normal * View Matrix
                float3 normal_viewspace = normalize(mul(UNITY_MATRIX_V, float4(normal_dir, 0.0)).xyz);

                //vertex position -> transform position(Object to View)
                float3 vertex_pos = mul(unity_WorldToObject, float4(pos_world, 1));
                float3 object_toview = normalize(mul(UNITY_MATRIX_MV, float4(vertex_pos, 1)).xyz);

                //计算matcap Uv
                float3 posxnormal = cross(normal_viewspace, object_toview);  // 叉乘
                float2 append_yx = (float2(-posxnormal.y, posxnormal.x));
                float2 scale_offset = append_yx * 0.5 + 0.5;
                fixed4 col = tex2D(_Matcap, scale_offset) * _MatcapMu;

                float VDotN = dot(View_dir, normal_dir);
                float Thickness = 1 - smoothstep( 0.0 , 1.0 , VDotN);  //厚度计算
                float2 Refrac_uv = scale_offset + Thickness * _RefracMu;  //uv偏移做折射效果
                float4 RefracMatcap = tex2D(_RefracMatcap, Refrac_uv);
                float4 lerp_thickness = lerp(_Color, RefracMatcap, Thickness * _RefracMu);
                float4 output_color = (lerp_thickness + col);

                float alpha = saturate(max(col.x, Thickness) * _OpacityMu);

                return float4(output_color.rgb, alpha);
            }
            ENDCG
        }
    }
}