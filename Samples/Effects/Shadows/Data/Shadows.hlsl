/***************************************************************************
# Copyright (c) 2015, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
***************************************************************************/
__import DefaultVS;
__import Shading;
__import ShaderCommon;
__import Effects.CascadedShadowMap;

cbuffer PerFrameCB : register(b0)
{
    float3 gAmbient;
    CsmData gCsmData[_LIGHT_COUNT];
    bool visualizeCascades;
    float4x4 camVpAtLastCsmUpdate;
};

struct ShadowsVSOut
{
    VertexOut vsData;
    float shadowsDepthC : DEPTH;
};

ShadowsVSOut vs(VertexIn vIn)
{
    VertexOut defaultOut = defaultVS(vIn);
    ShadowsVSOut output;
    output.vsData = defaultOut;

    output.shadowsDepthC = mul(float4(defaultOut.posW, 1), camVpAtLastCsmUpdate).z;
    return output;
}

float4 ps(ShadowsVSOut pIn) : SV_TARGET0
{
    ShadingData sd = prepareShadingData(pIn.vsData, gMaterial, gCamera.posW);
    float4 color = float4(0,0,0,1);
    
    [unroll]
    for(uint l = 0 ; l < _LIGHT_COUNT ; l++)
    {
        float shadowFactor = calcShadowFactor(gCsmData[l], pIn.shadowsDepthC, sd.posW, pIn.vsData.posH.xy/pIn.vsData.posH.w);
        color.rgb += evalMaterial(sd, gLights[l], shadowFactor).color.rgb;
    }

    color.rgb += gAmbient * sd.diffuse * 0.1;
    if(visualizeCascades)
    {
        //Ideally this would be light index so you can visualize the cascades of the 
        //currently selected light. However, because csmData contains Textures, it doesn't
        //like getting them with a non literal index.
        color.rgb *= getBlendedCascadeColor(gCsmData[_LIGHT_INDEX], pIn.shadowsDepthC);
    }

    return color;
}