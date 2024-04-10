Shader "Hidden/OitRenderURP"
{
	SubShader
	{
		PackageRequirements {
			"com.unity.render-pipelines.universal"
		}
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }
		Pass {
            Name "URP Order-Independent Transparency Pass"
			ZTest Always
			ZWrite Off
			Cull Off
			Blend Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma require randomwrite
			// #pragma enable_d3d11_debug_symbols
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
			#include "../LinkedListRendering.hlsl"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f 
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 posSS : TEXCOORD1;
			};

			TEXTURE2D_X(_CameraOpaqueTexture);
			SAMPLER(sampler_CameraOpaqueTexture);

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = TransformObjectToHClip(v.vertex);
				o.uv = v.uv;
				o.posSS = ComputeScreenPos(o.vertex);
				return o;
			}

			//Pixel function returns a solid color for each point.
			half4 frag(v2f input, uint uSampleIndex: SV_SampleIndex) : SV_Target
			{
				float2 screenUV = input.posSS.xy / input.posSS.w;
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
				// Retrieve current color from background texture
				float4 col = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV);
				return renderLinkedList(col, input.vertex.xy, uSampleIndex);
			}
			ENDHLSL
		}
	}
}