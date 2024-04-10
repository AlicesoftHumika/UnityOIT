#include "UnityCG.cginc"

float4 _MainLightDirection;
float4 _MainLightColor;


struct v2f
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 t2w0 : TEXCOORD2;
    float3 t2w1 : TEXCOORD3;
    float3 t2w2 : TEXCOORD4;
    float4 screenPos : TEXCOORD5;
    float4 tangent : TEXCOORD6;
    float3 lightDir : TEXCOORD7;
    float3 normalWS : TEXCOORD8;
};

v2f default_vert(appdata_full i)
{
    v2f o;
	o.pos = UnityObjectToClipPos(i.vertex);
    o.uv = i.texcoord;
    o.worldPos = mul(unity_ObjectToWorld, i.vertex);
    float3 worldNormal = UnityObjectToWorldNormal(i.normal);
	float3 worldTangent = UnityObjectToWorldDir(i.tangent.xyz);
	float3 worldBinormal = cross(worldNormal, worldTangent) * i.tangent.w;
	o.t2w0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
	o.t2w1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
	o.t2w2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);
    o.screenPos = ComputeScreenPos(o.pos);
    //o.z = abs(mul(UNITY_MATRIX_MV, i.vertex).z);
    o.tangent = i.tangent;
    
    float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;
    float3x3 rotation = float3x3(i.tangent.xyz, binormal, i.normal);
    o.lightDir = mul(unity_ObjectToWorld, ObjSpaceLightDir(i.vertex)).xyz;
    o.normalWS = worldNormal;
    
    return o;
}

inline float3 tangentSpaceToWorld(v2f i, float3 v)
{
    return float3(dot(v, i.t2w0.xyz), dot(v, i.t2w1.xyz), dot(v, i.t2w2.xyz));
}

inline float3 fresnelFunc(float f0, float nv, float p) {
	return f0 + (1 - f0) * pow(1 - nv, p);
}