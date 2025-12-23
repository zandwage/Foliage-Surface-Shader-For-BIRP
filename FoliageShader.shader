Shader "Custom/FoliageShader"
{
    Properties
    {
        [TitleGroup(Material_Settings)]
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5

        [TitleGroup(Wind_Settings)]
        _NoiseTexture("Noise Texture", 2D) = "white" {}
        _NoiseScale("Noise Scale", Range(0, 2)) = 0.5

        [Space]

        _BendFactor("Bend Factor", Range(0, 5)) = 1
        _BendSpeed("Bend Speed", Range(0, 50)) = 10
        _BendDirection("Bend Direction", vector) = (1, 1, 0, 0)
        _BendRandomness("Bend Randomness", Range(0, 1)) = 0.5
        _FoliageHeight("Foliage Height", float) = 0
        _TreeTrunkHeight("Tree Trunk Height", float) = 0
    }

    CustomEditor "MarkupAttributes.Editor.MarkedUpShaderGUI"

    SubShader
    {
        Tags { "RenderType"="Cutout" }
        LOD 200
        Cull Off

        CGPROGRAM

        #pragma surface surf Standard alphatest:_Cutoff addshadow vertex:vert ditherCrossFade
        #pragma target 3.0
        #pragma multi_compile_instancing

        sampler2D _MainTex;
        sampler2D _NoiseTexture;

        float _BendFactor;
        float _BendSpeed;
        float4 _BendDirection;
        float _NoiseScale;
        float _BendRandomness;
        float _FoliageHeight;
        float _TreeTrunkHeight;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

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

            float3 vertPos = v.vertex;
            float3 worldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;

            // Generate random values based on world position
            float randomPhase = hash(worldPos) * 6.28318;
            float randomSpeed = 0.8 + hash(worldPos + 10) * 0.4;
            float randomStrength = 0.7 + hash(worldPos + 20) * 0.6;
            
            float timeWithPhase = (_Time.y + randomPhase) * _BendSpeed * randomSpeed;

            // Main bending (already has the good falloff)
            float remappedPosY = vertPos.y * _BendFactor / 100 * sin(timeWithPhase / 10);
            float distortedPosY = pow(remappedPosY, 2) - remappedPosY;
            float2 directedPos = distortedPosY * _BendDirection;
            float3 distortedPos = float3(directedPos.x, 0, directedPos.y) + vertPos;

            float noiseMask = saturate((vertPos.y - _TreeTrunkHeight) / max(0.001, (_FoliageHeight - _TreeTrunkHeight)));

            float4 newTexCoord = float4(vertPos.xz * _NoiseScale * sin(_Time * _BendSpeed / 100), 0, 0);
            float noiseX = (0.5 - tex2Dlod(_NoiseTexture, newTexCoord).r) * _BendFactor / 5;
            float noiseY = (0.5 - tex2Dlod(_NoiseTexture, newTexCoord + 50).r) * _BendFactor / 5;
            float noiseZ = (0.5 - tex2Dlod(_NoiseTexture, newTexCoord + 100).r) * _BendFactor / 5;
            float3 noise = float3(noiseX, noiseY, noiseZ);
            float3 noiseMasked = noise * noiseMask;

            float3 finalPosition = distortedPos + noiseMasked;
            v.vertex = float4(finalPosition, 1);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;

            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
