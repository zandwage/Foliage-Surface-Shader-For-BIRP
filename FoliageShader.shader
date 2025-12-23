Shader "Custom/FoliageShader"
{
    Properties
    {
        _ColorTint ("Color Tint", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5

        [Header(Noise Settings)]
        [Space]
        _NoiseTexture("Noise Texture", 2D) = "white" {}
        _NoiseScale("Noise Scale", Range(0, 2)) = 0.5
        _NoiseBendFactor("Noise Bend Factor", Range(0, 5)) = 1
        _NoiseBendSpeed("Noise Bend Speed", Range(0, 50)) = 10

        [Space]

        [Header(Bend Settings)]
        [Space]
        _BendFactor("Bend Factor", Range(0, 5)) = 1
        _BendSpeed("Bend Speed", Range(0, 50)) = 10
        _BendDirection("Bend Direction", vector) = (1, 1, 0, 0)
        _BendRandomness("Bend Randomness", Range(0, 1)) = 0.5
        _FoliageHeight("Foliage Height", float) = 0
        _TreeTrunkHeight("Tree Trunk Height", float) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Cutout" "Queue"="AlphaTest"}
        LOD 200
        Cull Off

        CGPROGRAM

        #pragma surface surf Lambert alphatest:_Cutoff addshadow vertex:vert
        #pragma target 3.0
        #pragma multi_compile_instancing

        sampler2D _MainTex;

        sampler2D _NoiseTexture;
        float _NoiseScale;
        float _NoiseBendFactor;
        float _NoiseBendSpeed;

        float _BendFactor;
        float _BendSpeed;
        float4 _BendDirection;
        float _BendRandomness;
        float _FoliageHeight;
        float _TreeTrunkHeight;

        struct Input
        {
            float2 uv_MainTex;
        };

        fixed4 _ColorTint;

        UNITY_INSTANCING_BUFFER_START(Props)

        UNITY_INSTANCING_BUFFER_END(Props)

        // Simple hash function to generate pseudo-random values from world position
        float hash(float3 p)
        {
            p = frac(p * 0.3183099 + 0.1);
            p *= 17.0;
            return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
        }

        void vert(inout appdata_full v)
        {
            UNITY_SETUP_INSTANCE_ID(v);

            // calculates world pos from a matrix to save performance
            float3 vertPos = v.vertex;
            float3 worldPos = float3(unity_ObjectToWorld[0][3], unity_ObjectToWorld[1][3], unity_ObjectToWorld[2][3]);

            // optimized hash function
            float h1 = hash(worldPos);
            float h2 = hash(worldPos + 10);

            float randomPhase = h1 * 6.28138;
            float randomSpeed = 0.8 + h2 * 0.4;

            float randomDirOffset = (h1 - 0.5) * _BendRandomness * 2.0;
            float2 randomDir = float2(
                cos(randomDirOffset),
                sin(randomDirOffset)
            );

            float2 finalDir = normalize(_BendDirection.xy + (randomDir * _BendRandomness));

            float timeWithPhase = (_Time.y + randomPhase) * randomSpeed;

            float remappedPosY = vertPos.y * (_BendFactor * 0.01) * sin(timeWithPhase * _BendSpeed * 0.1);
            float distortedPosY = (remappedPosY * remappedPosY) - remappedPosY;

            float3 distortedPos = vertPos;
            distortedPos.xz += distortedPosY * finalDir;

            half noiseMask = saturate((vertPos.y - _TreeTrunkHeight) / max(0.001, (_FoliageHeight - _TreeTrunkHeight)));
            float2 noiseUV = vertPos.xz * _NoiseScale * sin(timeWithPhase * _NoiseBendSpeed * 0.008);
            half3 noiseSample = tex2Dlod(_NoiseTexture, float4(noiseUV, 0, 0)).rgb;
            half3 noise = (0.5 - noiseSample) * (_NoiseBendFactor * 0.2);

            v.vertex.xyz = distortedPos + (noise * noiseMask);
        }

        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _ColorTint;

            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
