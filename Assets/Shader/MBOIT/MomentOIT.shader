Shader "MomentOIT"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Roughness("Roughness", Float) = 10
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}

        HLSLINCLUDE

        #pragma shader_feature _SINGLE_PRECISION
        #pragma shader_feature _MORE_MOMENTS

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "MomentMath.hlsli"

         struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float3 normal : NORMAL;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
            float3 normal : TEXCOORD1;
            float3 lightDir: TEXCOORD2;
			float3 viewDir : TEXCOORD3;
        };

        struct PixelOutput0
        {
            float4 b0Result : COLOR0;
            float4 bResult : COLOR1;
        };

        struct PixelOutput1
        {
            float4 b0Result : COLOR0;
            float4 bEvenResult : COLOR1;
            float4 bOddResult : COLOR2;
        };

        half4 _Color;

        // Default: 5e-7
        float _Bias;

        // Default: 0.25
        float _Overestimation;

        sampler2D _ZeroMoment;
        sampler2D _Moments;
        sampler2D _MomentsSub;

        float _Roughness;

        // 1. Generate Moments.
        void generateMoments(float depth, float transmittance, /* float4 wrapping_zone_parameters, */ out float b_0, out float4 b)
        {
            float absorbance = -log(transmittance);

            // Stored Total Transimittance.
            b_0 = absorbance;

            float depth_pow2 = depth * depth;
            float depth_pow4 = depth_pow2 * depth_pow2;

            // Moments Vector. Stored Transimittance.
            b = float4(depth, depth_pow2, depth_pow2 * depth, depth_pow4) * absorbance;
        }

        void generateMoments(float depth, float transmittance, out float b_0, out float4 b_even, out float4 b_odd)
        {
            float absorbance = -log(transmittance);
            b_0 = absorbance;

            float depth_pow2 = depth * depth;
            float depth_pow4 = depth_pow2 * depth_pow2;
            float depth_pow6 = depth_pow4 * depth_pow2;
            b_even = float4(depth_pow2, depth_pow4, depth_pow6, depth_pow6 * depth_pow2) * absorbance;
            b_odd = float4(depth, depth_pow2 * depth, depth_pow4 * depth, depth_pow6 * depth) * absorbance;
        }

        // 2. Reconstruct Transimittance.
        void resolveMoments(out float transmittance_at_depth, out float total_transmittance, float depth, float2 sv_pos)
        {
            float2 idx0 = float2(sv_pos);

            transmittance_at_depth = 1;
            total_transmittance = 1;

            // Get b_0. 
            float b_0 = tex2D(_ZeroMoment, idx0).r;

            clip(b_0 - 0.00100050033f);
            total_transmittance = exp(-b_0);

            // Get b.
            float4 b_1234 = tex2D(_Moments,idx0);

            float2 b_even = b_1234.yw;
	        float2 b_odd = b_1234.xz;

	        b_even /= b_0;
	        b_odd /= b_0;

	        const float4 bias_vector = float4(0, 0.375, 0, 0.375);

            transmittance_at_depth = computeTransmittanceAtDepthFrom4PowerMoments(b_0, b_even, b_odd, depth, _Bias, _Overestimation, bias_vector);
        }

        // void resolveMomentsQ4(out float transmittance_at_depth, out float total_transmittance, float depth, float2 sv_pos)
        // {
        //     float2 idx0 = float2(sv_pos);

        //     transmittance_at_depth = 1;
        //     total_transmittance = 1;
            
        //     // Get b_0. 
        //     float b_0 = tex2D(_ZeroMoment, idx0).r;

        //     clip(b_0 - 0.00100050033f);
        //     total_transmittance = exp(-b_0);

        //     // Get b.
        //     float4 b_1234 = tex2D(_Moments,idx0);

        //     float2 b_even_q = b_1234.yw;
        //     float2 b_odd_q = b_1234.xz;

        //     float2 b_even;
        //     float2 b_odd;

        //     offsetAndDequantizeMoments(b_even, b_odd, b_even_q, b_odd_q);
        //     const float4 bias_vector = float4(0, 0.628, 0, 0.628);

        //     transmittance_at_depth = computeTransmittanceAtDepthFrom4PowerMoments(b_0, b_even, b_odd, depth, _Bias, _Overestimation, bias_vector);
        // }

        void resolveMoments8(out float transmittance_at_depth, out float total_transmittance, float depth, float2 sv_pos)
        {
            float2 idx0 = float2(sv_pos);

            transmittance_at_depth = 1;
            total_transmittance = 1;
            
            // Get b_0. 
            float b_0 = tex2D(_ZeroMoment, idx0).r;

            clip(b_0 - 0.00100050033f);
            total_transmittance = exp(-b_0);

            float4 b_even = tex2D(_Moments, idx0);
            float4 b_odd = tex2D(_MomentsSub, idx0);

            b_even /= b_0;
            b_odd /= b_0;
            const float bias_vector[8] = { 0, 0.75, 0, 0.67666666666666664, 0, 0.63, 0, 0.60030303030303034 };

            transmittance_at_depth = computeTransmittanceAtDepthFrom8PowerMoments(b_0, b_even, b_odd, depth, _Bias, _Overestimation, bias_vector);
        }

        // void resolveMomentsQ8(out float transmittance_at_depth, out float total_transmittance, float depth, float2 sv_pos)
        // {
        //     float2 idx0 = float2(sv_pos);

        //     transmittance_at_depth = 1;
        //     total_transmittance = 1;
            
        //     // Get b_0. 
        //     float b_0 = tex2D(_ZeroMoment, idx0).r;

        //     clip(b_0 - 0.00100050033f);
        //     total_transmittance = exp(-b_0);

        //     float4 b_even_q = tex2D(_Moments, idx0);
        //     float4 b_odd_q = tex2D(_MomentsSub, idx0);

        //     float4 b_even;
        //     float4 b_odd;

        //     offsetAndDequantizeMoments(b_even, b_odd, b_even_q, b_odd_q);
        //     const float bias_vector[8] = { 0, 0.42474916387959866, 0, 0.22407802675585284, 0, 0.15369230769230768, 0, 0.12900440529089119 };

        //     transmittance_at_depth = computeTransmittanceAtDepthFrom8PowerMoments(b_0, b_even, b_odd, depth, _Bias, _Overestimation, bias_vector);
        // }

        v2f vert (appdata v)
        {
            v2f o;
            o.vertex = TransformObjectToHClip(v.vertex.xyz);
            o.uv = v.uv;
            o.normal = normalize(v.normal);
            o.viewDir = normalize(TransformWorldToObject(_WorldSpaceCameraPos.xyz) - v.vertex.xyz);
            o.lightDir = normalize(TransformWorldToObjectDir(_MainLightPosition.xyz));
            return o;
        }

        half4 frag (v2f i) : SV_Target
        {
            // sample the texture
            half4 col = _Color;
            return col;
        }

        PixelOutput0 frag0(v2f i) :SV_Target
        {
            PixelOutput0 o;

            // Divide w to NDC Space ¡Ê [-1, 1]. Then *0.5+0.5 to [0, 1]. TODO: Check.
            float depth = i.vertex.z / i.vertex.w * 0.5 + 0.5;

            float b_0;

            float4 b;
            generateMoments(depth, 1 - _Color.a, b_0, b);

            float4 b0R = float4(b_0, 0, 0, 0);

            // Debug return.
            // b0R = float4(depth, 0,0,0);

            o.b0Result = b0R;
            o.bResult = b;
            return o;
        }

        half4 frag1(v2f i) : SV_Target
        {            
            float alpha;
            float totalAlpha;

            // Divide w to NDC Space ¡Ê [-1, 1]. Then *0.5+0.5 to [0, 1].
            float depth = i.vertex.z / i.vertex.w * 0.5 + 0.5;

            // #1 Uncorrect. R Channel always 0. G Channel always 1.
            // float2 pos = i.vertex.xy / i.vertex.w * 0.5 + 0.5;

            // #2 Uncorrect. R Channel always 1. G Channel always 0. ComputeScreenPos maybe only use in vertex shader.
            // float2 pos = i.posSS.xy / i.posSS.w;

            // #3 
            // float2 pos = i.vertex.xy / _ScaledScreenParams.xy;
            float2 pos = GetNormalizedScreenSpaceUV(i.vertex);

            half3 color = _Color.rgb;

            float3 normal = normalize(i.normal);
            float3 lightDir = normalize(i.lightDir);
            float3 viewDir = normalize(i.viewDir);

            half3 diffuse = max(0, dot(normal, lightDir)) * color;

            float3 h = normalize(lightDir + viewDir);
            float spec = pow(max(0, dot(normal, h)), _Roughness);

            color = diffuse + spec.xxx;

            // resolveMoments(alpha, totalAlpha, depth, pos);
            #if !_MORE_MOMENTS
            resolveMoments(alpha, totalAlpha, depth, pos);
            #elif _MORE_MOMENTS
            resolveMoments8(alpha, totalAlpha,depth, pos);
            #endif

            return half4(color, alpha);
        }

        sampler2D _CameraOpaqueTexture;
        sampler2D _CameraTransparentTexture;

        half4 frag2(v2f i) : SV_Target
        {
            float2 pos = i.vertex.xy / _ScreenParams.xy;
            float b_0 = tex2D(_ZeroMoment, pos).r;
            float alpha = exp(-b_0);

            half3 opaque = tex2D(_CameraOpaqueTexture, pos).rgb;
            half4 transparent = tex2D(_CameraTransparentTexture, pos);

            return half4(transparent.rgb * (1 - alpha) + opaque * alpha, 1);
        }

        PixelOutput1 frag3 (v2f i) :SV_Target
        {
            PixelOutput1 o;

            float depth = i.vertex.z / i.vertex.w * 0.5 + 0.5;

            float b_0;

            float4 b_even;
            float4 b_odd;
            generateMoments(depth, 1 - _Color.a, b_0, b_even, b_odd);

            float4 b0R = float4(b_0, 0, 0, 0);

            o.b0Result = b0R;
            o.bEvenResult = b_even;
            o.bOddResult = b_odd;
            return o;
        }

        ENDHLSL


        // #0 Generate moments.
        Pass
        {
            Tags { "LightMode"="GenerateMoment" }

            ZWrite Off
            ZTest On
            Cull Off

            Blend One One 

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag0

            ENDHLSL
        }

        // #1 Reconstruct transmittance.
        Pass
        {
                Tags {"LightMode"="ReconstructTransmittance"}

                ZWrite Off
                ZTest On
                Cull Off

                Blend SrcAlpha OneMinusSrcAlpha

                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag1
                ENDHLSL
        }

        // #2 Composite with opaque.
        Pass
        {
                Tags {"LightMode"="Composite"}

                // ZWrite Off
                // ZTest Off
                Cull Back
                // Blend One Zero

                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag2
                ENDHLSL
        }

        // #3 Generate more moments.
        Pass
        {
            Tags { "LightMode"="GenerateMoreMoment" }

            ZWrite Off
            ZTest On
            Cull Off

            Blend One One 

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag3

            ENDHLSL
        }
    }
}
