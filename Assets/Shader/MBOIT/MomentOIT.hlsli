/*! \file
	This header provides the functionality to create the vectors of moments and 
	to blend surfaces together with an appropriately reconstructed 
	transmittance. It is needed for both additive passes of moment-based OIT.
*/
#ifndef MOMENT_OIT_HLSLI
#define MOMENT_OIT_HLSLI

//// Code start
//#define MOMENT_GENERATION true
//#define ROV false
//#define TRIGONOMETRIC false
//#define NUM_MOMENTS 4
//#define USE_R_RG_RBBA_FOR_MBOIT6 false
//// Code End

cbuffer MomentOIT
{
	struct {
		float4 wrapping_zone_parameters;
		float overestimation;
		float moment_bias;
	}MomentOIT;
};

#include "MomentMath.hlsli"

#if MOMENT_GENERATION
/*! Generation of moments in case that rasterizer ordered views are used. 
	This includes the case if moments are stored in 16 bits. */
#if ROV
RasterizerOrderedTexture2DArray<float> b0 : register(u0);
#if SINGLE_PRECISION
#if NUM_MOMENTS == 6
RasterizerOrderedTexture2DArray<float2> b : register(u1);
#if USE_R_RG_RBBA_FOR_MBOIT6
RasterizerOrderedTexture2DArray<float4> b_extra : register(u2);
#endif
#else
RasterizerOrderedTexture2DArray<float4> b : register(u1);
#endif
#else
#if NUM_MOMENTS == 6
RasterizerOrderedTexture2DArray<unorm float2> b : register(u1);
#if USE_R_RG_RBBA_FOR_MBOIT6
RasterizerOrderedTexture2DArray<unorm float4> b_extra : register(u2);
#endif
#else
RasterizerOrderedTexture2DArray<unorm float4> b : register(u1);
#endif
#endif

#if !TRIGONOMETRIC

/*! This function handles the actual computation of the new vector of power 
	moments.*/
void generatePowerMoments(inout float b_0,
#if NUM_MOMENTS == 4
	inout float2 b_even, inout float2 b_odd,
#elif NUM_MOMENTS == 6
	inout float3 b_even, inout float3 b_odd,
#elif NUM_MOMENTS == 8
	inout float4 b_even, inout float4 b_odd,
#endif
	float depth, float transmittance)
{
	float absorbance = -log(transmittance);

	float depth_pow2 = depth * depth;
	float depth_pow4 = depth_pow2 * depth_pow2;

#if SINGLE_PRECISION
	b_0 += absorbance;
#if NUM_MOMENTS == 4
	b_even += float2(depth_pow2, depth_pow4) * absorbance;
	b_odd += float2(depth, depth_pow2 * depth) * absorbance;
#elif NUM_MOMENTS == 6
	b_even += float3(depth_pow2, depth_pow4, depth_pow4 * depth_pow2) * absorbance;
	b_odd += float3(depth, depth_pow2 * depth, depth_pow4 * depth) * absorbance;
#elif NUM_MOMENTS == 8
	float depth_pow6 = depth_pow4 * depth_pow2;
	b_even += float4(depth_pow2, depth_pow4, depth_pow6, depth_pow6 * depth_pow2) * absorbance;
	b_odd += float4(depth, depth_pow2 * depth, depth_pow4 * depth, depth_pow6 * depth) * absorbance;
#endif
#else // Quantized
	offsetMoments(b_even, b_odd, -1.0);
	b_even *= b_0;
	b_odd *= b_0;

	//  New Moments
#if NUM_MOMENTS == 4
	float2 b_even_new = float2(depth_pow2, depth_pow4);
	float2 b_odd_new = float2(depth, depth_pow2 * depth);
	float2 b_even_new_q, b_odd_new_q;
#elif NUM_MOMENTS == 6
	float3 b_even_new = float3(depth_pow2, depth_pow4, depth_pow4 * depth_pow2);
	float3 b_odd_new = float3(depth, depth_pow2 * depth, depth_pow4 * depth);
	float3 b_even_new_q, b_odd_new_q;
#elif NUM_MOMENTS == 8
	float depth_pow6 = depth_pow4 * depth_pow2;
	float4 b_even_new = float4(depth_pow2, depth_pow4, depth_pow6, depth_pow6 * depth_pow2);
	float4 b_odd_new = float4(depth, depth_pow2 * depth, depth_pow4 * depth, depth_pow6 * depth);
	float4 b_even_new_q, b_odd_new_q;
#endif
	quantizeMoments(b_even_new_q, b_odd_new_q, b_even_new, b_odd_new);

	// Combine Moments
	b_0 += absorbance;
	b_even += b_even_new_q * absorbance;
	b_odd += b_odd_new_q * absorbance;

	// Go back to interval [0, 1]
	b_even /= b_0;
	b_odd /= b_0;
	offsetMoments(b_even, b_odd, 1.0);
#endif
}

#else

/*! This function handles the actual computation of the new vector of 
	trigonometric moments.*/
void generateTrigonometricMoments(inout float b_0,
#if NUM_MOMENTS == 4
	inout float4 b_12,
#elif NUM_MOMENTS == 6
	inout float2 b_1, inout float2 b_2, inout float2 b_3,
#elif NUM_MOMENTS == 8
	inout float4 b_even, inout float4 b_odd,
#endif
	float depth, float transmittance, float4 wrapping_zone_parameters)
{
	float absorbance = -log(transmittance);

	float phase = mad(depth, wrapping_zone_parameters.y, wrapping_zone_parameters.y);
	float2 circle_point;
	sincos(phase, circle_point.y, circle_point.x);
	float2 circle_point_pow2 = Multiply(circle_point, circle_point);

#if NUM_MOMENTS == 4
	float4 b_12_new = float4(circle_point, circle_point_pow2) * absorbance;
#if SINGLE_PRECISION
	b_0 += absorbance;
	b_12 += b_12_new;
#else
	b_12 = mad(b_12, 2.0, -1.0) * b_0;

	b_0 += absorbance;
	b_12 += b_12_new;

	b_12 /= b_0;
	b_12 = mad(b_12, 0.5, 0.5);
#endif
#elif NUM_MOMENTS == 6
	float2 b_1_new = circle_point * absorbance;
	float2 b_2_new = circle_point_pow2 * absorbance;
	float2 b_3_new = Multiply(circle_point, circle_point_pow2) * absorbance;
#if SINGLE_PRECISION
	b_0 += absorbance;
	b_1 += b_1_new;
	b_2 += b_2_new;
	b_3 += b_3_new;
#else
	b_1 = mad(b_1, 2.0, -1.0) * b_0;
	b_2 = mad(b_2, 2.0, -1.0) * b_0;
	b_3 = mad(b_3, 2.0, -1.0) * b_0;

	b_0 += absorbance;
	b_1 += b_1_new;
	b_2 += b_2_new;
	b_3 += b_3_new;

	b_1 /= b_0;
	b_2 /= b_0;
	b_3 /= b_0;
	b_1 = mad(b_1, 0.5, 0.5);
	b_2 = mad(b_2, 0.5, 0.5);
	b_3 = mad(b_3, 0.5, 0.5);
#endif
#elif NUM_MOMENTS == 8
	float4 b_even_new = float4(circle_point_pow2, Multiply(circle_point_pow2, circle_point_pow2)) * absorbance;
	float4 b_odd_new = float4(circle_point, Multiply(circle_point, circle_point_pow2)) * absorbance;
#if SINGLE_PRECISION
	b_0 += absorbance;
	b_even += b_even_new;
	b_odd += b_odd_new;
#else
	b_even = mad(b_even, 2.0, -1.0) * b_0;
	b_odd = mad(b_odd, 2.0, -1.0) * b_0;

	b_0 += absorbance;
	b_even += b_even_new;
	b_odd += b_odd_new;

	b_even /= b_0;
	b_odd /= b_0;
	b_even = mad(b_even, 0.5, 0.5);
	b_odd = mad(b_odd, 0.5, 0.5);
#endif
#endif
}
#endif

/*! This function reads the stored moments from the rasterizer ordered view, 
	calls the appropriate moment-generating function and writes the new moments 
	back to the rasterizer ordered view.*/
void generateMoments(float depth, float transmittance, float2 sv_pos, float4 wrapping_zone_parameters)
{
	uint3 idx0 = uint3(sv_pos, 0);
	uint3 idx1 = idx0;
	idx1[2] = 1;

	// Return early if the surface is fully transparent
	clip(0.9999999f - transmittance);

#if NUM_MOMENTS == 4
	float b_0 = b0[idx0];
	float4 b_raw = b[idx0];

#if TRIGONOMETRIC
	generateTrigonometricMoments(b_0, b_raw, depth, transmittance, wrapping_zone_parameters);
	b[idx0] = b_raw;
#else
	float2 b_even = b_raw.yw;
	float2 b_odd = b_raw.xz;

	generatePowerMoments(b_0, b_even, b_odd, depth, transmittance);

	b[idx0] = float4(b_odd.x, b_even.x, b_odd.y, b_even.y);
#endif
	b0[idx0] = b_0;
#elif NUM_MOMENTS == 6
	uint3 idx2 = idx0;
	idx2[2] = 2;

	float b_0 = b0[idx0];
	float2 b_raw[3];
	b_raw[0] = b[idx0].xy;
#if USE_R_RG_RBBA_FOR_MBOIT6
	float4 tmp = b_extra[idx0];
	b_raw[1] = tmp.xy;
	b_raw[2] = tmp.zw;
#else
	b_raw[1] = b[idx1].xy;
	b_raw[2] = b[idx2].xy;
#endif

#if TRIGONOMETRIC
	generateTrigonometricMoments(b_0, b_raw[0], b_raw[1], b_raw[2], depth, transmittance, wrapping_zone_parameters);
#else
	float3 b_even = float3(b_raw[0].y, b_raw[1].y, b_raw[2].y);
	float3 b_odd = float3(b_raw[0].x, b_raw[1].x, b_raw[2].x);

	generatePowerMoments(b_0, b_even, b_odd, depth, transmittance);

	b_raw[0] = float2(b_odd.x, b_even.x);
	b_raw[1] = float2(b_odd.y, b_even.y);
	b_raw[2] = float2(b_odd.z, b_even.z);
#endif

	b0[idx0] = b_0;
	b[idx0] = b_raw[0];
#if USE_R_RG_RBBA_FOR_MBOIT6
	b_extra[idx0] = float4(b_raw[1], b_raw[2]);
#else
	b[idx1] = b_raw[1];
	b[idx2] = b_raw[2];
#endif
#elif NUM_MOMENTS == 8
	float b_0 = b0[idx0];
	float4 b_even = b[idx0];
	float4 b_odd = b[idx1];

#if TRIGONOMETRIC
	generateTrigonometricMoments(b_0, b_even, b_odd, depth, transmittance, wrapping_zone_parameters);
#else
	generatePowerMoments(b_0, b_even, b_odd, depth, transmittance);
#endif

	b0[idx0] = b_0;
	b[idx0] = b_even;
	b[idx1] = b_odd;
#endif

}

#else // NO ROVs, therefore only single precision

/*! This functions relies on fixed function additive blending to compute the 
	vector of moments.moment vector. The shader that calls this function must 
	provide the required render targets.*/
#if NUM_MOMENTS == 4
void generateMoments(float depth, float transmittance, float4 wrapping_zone_parameters, out float b_0, out float4 b)
#elif NUM_MOMENTS == 6
#if USE_R_RG_RBBA_FOR_MBOIT6
void generateMoments(float depth, float transmittance, float4 wrapping_zone_parameters, out float b_0, out float2 b_12, out float4 b_3456)
#else
void generateMoments(float depth, float transmittance, float4 wrapping_zone_parameters, out float b_0, out float2 b_12, out float2 b_34, out float2 b_56)
#endif
#elif NUM_MOMENTS == 8
void generateMoments(float depth, float transmittance, float4 wrapping_zone_parameters, out float b_0, out float4 b_even, out float4 b_odd)
#endif
{
	float absorbance = -log(transmittance);

	b_0 = absorbance;
#if TRIGONOMETRIC
	float phase = mad(depth, wrapping_zone_parameters.y, wrapping_zone_parameters.y);
	float2 circle_point;
	sincos(phase, circle_point.y, circle_point.x);
	float2 circle_point_pow2 = Multiply(circle_point, circle_point);
#if NUM_MOMENTS == 4
	b = float4(circle_point, circle_point_pow2) * absorbance;
#elif NUM_MOMENTS == 6
	b_12 = circle_point * absorbance;
#if USE_R_RG_RBBA_FOR_MBOIT6
	b_3456 = float4(circle_point_pow2, Multiply(circle_point, circle_point_pow2)) * absorbance;
#else
	b_34 = circle_point_pow2 * absorbance;
	b_56 = Multiply(circle_point, circle_point_pow2) * absorbance;
#endif
#elif NUM_MOMENTS == 8
	b_even = float4(circle_point_pow2, Multiply(circle_point_pow2, circle_point_pow2)) * absorbance;
	b_odd = float4(circle_point, Multiply(circle_point, circle_point_pow2)) * absorbance;
#endif
#else
	float depth_pow2 = depth * depth;
	float depth_pow4 = depth_pow2 * depth_pow2;
#if NUM_MOMENTS == 4
	b = float4(depth, depth_pow2, depth_pow2 * depth, depth_pow4) * absorbance;
#elif NUM_MOMENTS == 6
	b_12 = float2(depth, depth_pow2) * absorbance;
#if USE_R_RG_RBBA_FOR_MBOIT6
	b_3456 = float4(depth_pow2 * depth, depth_pow4, depth_pow4 * depth, depth_pow4 * depth_pow2) * absorbance;
#else
	b_34 = float2(depth_pow2 * depth, depth_pow4) * absorbance;
	b_56 = float2(depth_pow4 * depth, depth_pow4 * depth_pow2) * absorbance;
#endif
#elif NUM_MOMENTS == 8
	float depth_pow6 = depth_pow4 * depth_pow2;
	b_even = float4(depth_pow2, depth_pow4, depth_pow6, depth_pow6 * depth_pow2) * absorbance;
	b_odd = float4(depth, depth_pow2 * depth, depth_pow4 * depth, depth_pow6 * depth) * absorbance;
#endif
#endif
}
#endif

#else //MOMENT_GENERATION is disabled

Texture2DArray moments;
Texture2DArray zeroth_moment;
#if USE_R_RG_RBBA_FOR_MBOIT6
Texture2DArray extra_moments;
#endif

/*! This function is to be called from the shader that composites the 
	transparent fragments. It reads the moments and calls the appropriate 
	function to reconstruct the transmittance at the specified depth.*/
void resolveMoments(out float transmittance_at_depth, out float total_transmittance, float depth, float2 sv_pos)
{
	int4 idx0 = int4(sv_pos, 0, 0);
	int4 idx1 = idx0;
	idx1[2] = 1;

	transmittance_at_depth = 1;
	total_transmittance = 1;
	
	float b_0 = zeroth_moment.Load(idx0).x;
	clip(b_0 - 0.00100050033f);
	total_transmittance = exp(-b_0);

#if NUM_MOMENTS == 4
#if TRIGONOMETRIC
	float4 b_tmp = moments.Load(idx0);
	float2 trig_b[2];
	trig_b[0] = b_tmp.xy;
	trig_b[1] = b_tmp.zw;
#if SINGLE_PRECISION
	trig_b[0] /= b_0;
	trig_b[1] /= b_0;
#else
	trig_b[0] = mad(trig_b[0], 2.0, -1.0);
	trig_b[1] = mad(trig_b[1], 2.0, -1.0);
#endif
	transmittance_at_depth = computeTransmittanceAtDepthFrom2TrigonometricMoments(b_0, trig_b, depth, MomentOIT.moment_bias, MomentOIT.overestimation, MomentOIT.wrapping_zone_parameters);
#else
	float4 b_1234 = moments.Load(idx0).xyzw;
#if SINGLE_PRECISION
	float2 b_even = b_1234.yw;
	float2 b_odd = b_1234.xz;

	b_even /= b_0;
	b_odd /= b_0;

	const float4 bias_vector = float4(0, 0.375, 0, 0.375);
#else
	float2 b_even_q = b_1234.yw;
	float2 b_odd_q = b_1234.xz;

	// Dequantize the moments
	float2 b_even;
	float2 b_odd;
	offsetAndDequantizeMoments(b_even, b_odd, b_even_q, b_odd_q);
	const float4 bias_vector = float4(0, 0.628, 0, 0.628);
#endif
	transmittance_at_depth = computeTransmittanceAtDepthFrom4PowerMoments(b_0, b_even, b_odd, depth, MomentOIT.moment_bias, MomentOIT.overestimation, bias_vector);
#endif
#elif NUM_MOMENTS == 6
	int4 idx2 = idx0;
	idx2[2] = 2;
#if TRIGONOMETRIC
	float2 trig_b[3];
	trig_b[0] = moments.Load(idx0).xy;
#if USE_R_RG_RBBA_FOR_MBOIT6
	float4 tmp = extra_moments.Load(idx0);
	trig_b[1] = tmp.xy;
	trig_b[2] = tmp.zw;
#else
	trig_b[1] = moments.Load(idx1).xy;
	trig_b[2] = moments.Load(idx2).xy;
#endif
#if SINGLE_PRECISION
	trig_b[0] /= b_0;
	trig_b[1] /= b_0;
	trig_b[2] /= b_0;
#else
	trig_b[0] = mad(trig_b[0], 2.0, -1.0);
	trig_b[1] = mad(trig_b[1], 2.0, -1.0);
	trig_b[2] = mad(trig_b[2], 2.0, -1.0);
#endif
	transmittance_at_depth = computeTransmittanceAtDepthFrom3TrigonometricMoments(b_0, trig_b, depth, MomentOIT.moment_bias, MomentOIT.overestimation, MomentOIT.wrapping_zone_parameters);
#else
	float2 b_12 = moments.Load(idx0).xy;
#if USE_R_RG_RBBA_FOR_MBOIT6
	float4 tmp = extra_moments.Load(idx0);
	float2 b_34 = tmp.xy;
	float2 b_56 = tmp.zw;
#else
	float2 b_34 = moments.Load(idx1).xy;
	float2 b_56 = moments.Load(idx2).xy;
#endif
#if SINGLE_PRECISION
	float3 b_even = float3(b_12.y, b_34.y, b_56.y);
	float3 b_odd = float3(b_12.x, b_34.x, b_56.x);

	b_even /= b_0;
	b_odd /= b_0;

	const float bias_vector[6] = { 0, 0.48, 0, 0.451, 0, 0.45 };
#else
	float3 b_even_q = float3(b_12.y, b_34.y, b_56.y);
	float3 b_odd_q = float3(b_12.x, b_34.x, b_56.x);
	// Dequantize b_0 and the other moments
	float3 b_even;
	float3 b_odd;
	offsetAndDequantizeMoments(b_even, b_odd, b_even_q, b_odd_q);

	const float bias_vector[6] = { 0, 0.5566, 0, 0.489, 0, 0.47869382 };
#endif
	transmittance_at_depth = computeTransmittanceAtDepthFrom6PowerMoments(b_0, b_even, b_odd, depth, MomentOIT.moment_bias, MomentOIT.overestimation, bias_vector);
#endif
#elif NUM_MOMENTS == 8
#if TRIGONOMETRIC
	float4 b_tmp = moments.Load(idx0);
	float4 b_tmp2 = moments.Load(idx1);
#if SINGLE_PRECISION
	float2 trig_b[4] = {
		b_tmp2.xy / b_0,
		b_tmp.xy / b_0,
		b_tmp2.zw / b_0,
		b_tmp.zw / b_0
	};
#else
	float2 trig_b[4] = {
		mad(b_tmp2.xy, 2.0, -1.0),
		mad(b_tmp.xy, 2.0, -1.0),
		mad(b_tmp2.zw, 2.0, -1.0),
		mad(b_tmp.zw, 2.0, -1.0)
	};
#endif
	transmittance_at_depth = computeTransmittanceAtDepthFrom4TrigonometricMoments(b_0, trig_b, depth, MomentOIT.moment_bias, MomentOIT.overestimation, MomentOIT.wrapping_zone_parameters);
#else
#if SINGLE_PRECISION
	float4 b_even = moments.Load(idx0);
	float4 b_odd = moments.Load(idx1);

	b_even /= b_0;
	b_odd /= b_0;
	const float bias_vector[8] = { 0, 0.75, 0, 0.67666666666666664, 0, 0.63, 0, 0.60030303030303034 };
#else
	float4 b_even_q = moments.Load(idx0);
	float4 b_odd_q = moments.Load(idx1);

	// Dequantize the moments
	float4 b_even;
	float4 b_odd;
	offsetAndDequantizeMoments(b_even, b_odd, b_even_q, b_odd_q);
	const float bias_vector[8] = { 0, 0.42474916387959866, 0, 0.22407802675585284, 0, 0.15369230769230768, 0, 0.12900440529089119 };
#endif
	transmittance_at_depth = computeTransmittanceAtDepthFrom8PowerMoments(b_0, b_even, b_odd, depth, MomentOIT.moment_bias, MomentOIT.overestimation, bias_vector);
#endif
#endif

}
#endif

#endif