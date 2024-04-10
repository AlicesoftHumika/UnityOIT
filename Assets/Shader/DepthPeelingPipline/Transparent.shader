Shader "OITRP/Transparent"
{
    Properties
    {
         _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Normal ("Normal Texture", 2D) = "bump" {}
        _Roughness("Roughness", Float) = 0.1
    }

    SubShader
    {
        Tags 
        {
            "RenderPipeline" = "OITRenderPipeline"
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "IgnoreProjector" = "true"
        }

        HLSLINCLUDE
        
        #include "UnityCG.cginc"
        #include "Lib.hlsl"

         float4 _Color;
        sampler2D _MainTex;
		sampler2D _Normal;
		float4 _Normal_ST;
        float _BumpScale;
        
        float _Roughness;

        inline float4 renderFragment(v2f i)
        {
            float3 normal = i.normalWS;
            float3 lightDir = normalize(i.lightDir);
            
            float4 color = _Color;
            half3 diffuse = color.rgb * max(0, dot(normal, lightDir));

            // All in world space.
            float3 viewDir    = normalize(_WorldSpaceCameraPos  - i.worldPos);
            float3 halfwayDir = normalize(lightDir + viewDir);
            float spec = pow(max(dot(normal, halfwayDir), 0.0), _Roughness);
            half3 specular = half3(1,1,1) * spec;
            color.rgb = (diffuse + specular) * color.a ;
            
            return color;
        }

        float4 frag(v2f i) : SV_TARGET
        {
            
            return renderFragment(i);
        }

        struct DepthPeelingOutput
        {
            float4 color : SV_TARGET0;
            float depth : SV_TARGET1;
        };

        DepthPeelingOutput depthPeelingFirstPass(v2f i) : SV_TARGET
        {
            DepthPeelingOutput o;
            o.color = renderFragment(i);
            o.depth = i.pos.z;
            return o;
        }

        sampler2D _MaxDepthTex;
        sampler2D _DepthTex;
        sampler2D _TempColor;
        sampler2D _UpDepthTex;
        sampler2D _CameraDepthTexture;

        DepthPeelingOutput depthPeelingPass(v2f i) : SV_TARGET
        {
            i.screenPos /= i.screenPos.w;
            float maxDepth = tex2D(_MaxDepthTex, i.screenPos.xy).r;
            float selfDepth = i.pos.z;
            // DX reverse-Z, nearest is 1, farest is 0.
            if(selfDepth >= maxDepth)
            {
                clip(-1);
            }

            DepthPeelingOutput o;
            o.color = renderFragment(i);
            o.depth = i.pos.z;
            return o;
        }
        
        float4 finalPass(v2f i , out float depthOut : SV_DEPTH) : SV_TARGET
        {
            float4 color = tex2D(_MainTex, i.uv);
            float depth = tex2D(_DepthTex, i.uv);
            clip(depth <= 0 ? -1 : 1);
            depthOut = depth;
            return color;
        }
        
        float4  depthPeelingUnder(v2f i, out float depthOut : SV_DEPTH) : SV_TARGET
        {
            float4 color = tex2D(_MainTex, i.uv);
            float depth = tex2D(_DepthTex, i.uv);
            float4 tempColor = tex2D(_TempColor, i.uv);

            if(color.a > 0)
            {
                float upDepth = tex2D(_UpDepthTex, i.uv).r;
                depthOut = depth < upDepth ? upDepth :depth;
                return color;
            }
            clip(-1);
            return 0;
        }

        sampler2D _FirstColor;

        float4 finalPassProv(v2f i , out float depthOut : SV_DEPTH) : SV_TARGET
        {
            float4 color = tex2D(_MainTex, i.uv);
            float depth = tex2D(_UpDepthTex, i.uv);
            // float depth = tex2D(_DepthTex, i.uv);
            // clip((depth <= 0 ? -1 : 1));
            // Update alpha per frame, will make alpha continue per frame, lead to show a wrong result in game window.
            // float a = tex2D(_FirstColor, i.uv);

            //TODO: Blend with opaque texture. 


            depthOut = depth;
            return float4(color.rgb, .7);
        }

        ENDHLSL

             // #0
        Pass {
            Tags {"LightMode" = "TransparentBack"}

            ZWrite Off
            ZTest On
            Blend One OneMinusSrcAlpha
            Cull Front

            HLSLPROGRAM
            
            #pragma vertex default_vert
            #pragma fragment frag

            ENDHLSL
        }

        // #1
        Pass {
            Name "TransparentFront"
            Tags {"LightMode" = "TransparentFront"}

            ZWrite Off
            ZTest On
            Blend One OneMinusSrcAlpha
            Cull Back

            HLSLPROGRAM
            
            #pragma vertex default_vert
            #pragma fragment frag

            ENDHLSL
        }

        // #2
        Pass {
            Tags {"LightMode" = "DepthPeelingFirstPass"}

            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM

            #pragma vertex default_vert
            #pragma fragment depthPeelingFirstPass

            ENDHLSL
        }
        
        // #3
        Pass {
            Tags {"LightMode" = "DepthPeelingPass"}

            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM

            #pragma vertex default_vert
            #pragma fragment depthPeelingPass

            ENDHLSL
        }
        // #4
        Pass {
            Tags {"LightMode" = "DepthPeelingFinalPass"}

            ZWrite On
            ZTest LEqual
            Cull Off
            Blend One OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex default_vert
            #pragma fragment finalPass

            ENDHLSL
        }


        // #5 
        Pass{
            Tags {"LightMode" = "DepthPeelingUnder"}

            ZWrite On
            ZTest On
            Cull Off
            Blend One OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex default_vert
            #pragma fragment depthPeelingUnder

            ENDHLSL
        }

        // #6
        Pass {
            Tags {"LightMode" = "DepthPeelingFinalPass"}

            ZWrite On
            ZTest On
            Cull Off
            Blend One OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex default_vert
            #pragma fragment finalPassProv

            ENDHLSL
        }
    }
}
