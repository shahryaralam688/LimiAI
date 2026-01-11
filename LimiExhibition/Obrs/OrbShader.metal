//
//  Uniforms.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 29/11/2025.
//


#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float3 resolution;
    float hue;
    float hover;
    float rot;
    float hoverIntensity;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Full-screen triangle, like the ogl Triangle in JS
vertex VertexOut vertex_main(uint vid [[vertex_id]],
                             constant Uniforms &u [[buffer(0)]]) {
    VertexOut out;

    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    float2 pos = positions[vid];
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5; // map [-1,1] -> [0,1]
    return out;
}

// ---- Shader functions ported from GLSL ----

float3 rgb2yiq(float3 c) {
    float y = dot(c, float3(0.299, 0.587, 0.114));
    float i = dot(c, float3(0.596, -0.274, -0.322));
    float q = dot(c, float3(0.211, -0.523, 0.312));
    return float3(y, i, q);
}

float3 yiq2rgb(float3 c) {
    float r = c.x + 0.956 * c.y + 0.621 * c.z;
    float g = c.x - 0.272 * c.y - 0.647 * c.z;
    float b = c.x - 1.106 * c.y + 1.703 * c.z;
    return float3(r, g, b);
}

float3 adjustHue(float3 color, float hueDeg) {
    float hueRad = hueDeg * 3.14159265 / 180.0;
    float3 yiq = rgb2yiq(color);
    float cosA = cos(hueRad);
    float sinA = sin(hueRad);
    float i = yiq.y * cosA - yiq.z * sinA;
    float q = yiq.y * sinA + yiq.z * cosA;
    yiq.y = i;
    yiq.z = q;
    return yiq2rgb(yiq);
}

float3 hash33(float3 p3) {
    p3 = fract(p3 * float3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yxz + 19.19);
    return -1.0 + 2.0 * fract(float3(
        p3.x + p3.y,
        p3.x + p3.z,
        p3.y + p3.z
    ) * p3.zyx);
}

float snoise3(float3 p) {
    const float K1 = 0.333333333;
    const float K2 = 0.166666667;
    float3 i = floor(p + (p.x + p.y + p.z) * K1);
    float3 d0 = p - (i - (i.x + i.y + i.z) * K2);
    float3 e = step(float3(0.0), d0 - d0.yzx);
    float3 i1 = e * (1.0 - e.zxy);
    float3 i2 = 1.0 - e.zxy * (1.0 - e);
    float3 d1 = d0 - (i1 - K2);
    float3 d2 = d0 - (i2 - K1);
    float3 d3 = d0 - 0.5;
    float4 h = max(0.6 - float4(
        dot(d0, d0),
        dot(d1, d1),
        dot(d2, d2),
        dot(d3, d3)
    ), 0.0);
    float4 n = h * h * h * h * float4(
        dot(d0, hash33(i)),
        dot(d1, hash33(i + i1)),
        dot(d2, hash33(i + i2)),
        dot(d3, hash33(i + 1.0))
    );
    return dot(float4(31.316), n);
}

float4 extractAlpha(float3 colorIn) {
    float a = max(max(colorIn.r, colorIn.g), colorIn.b);
    return float4(colorIn.rgb / (a + 1e-5), a);
}

constant float3 baseColor1 = float3(0.611765, 0.262745, 0.996078);
constant float3 baseColor2 = float3(0.298039, 0.760784, 0.913725);
constant float3 baseColor3 = float3(0.062745, 0.078431, 0.600000);
constant float innerRadius = 0.6;
constant float noiseScale = 0.65;

float light1(float intensity, float attenuation, float dist) {
    return intensity / (1.0 + dist * attenuation);
}

float light2(float intensity, float attenuation, float dist) {
    return intensity / (1.0 + dist * dist * attenuation);
}

float4 drawOrb(float2 uv, constant Uniforms &u) {
    float3 color1 = adjustHue(baseColor1, u.hue);
    float3 color2 = adjustHue(baseColor2, u.hue);
    float3 color3 = adjustHue(baseColor3, u.hue);

    float ang = atan2(uv.y, uv.x);
    float len = length(uv);
    float invLen = (len > 0.0) ? 1.0 / len : 0.0;

    float n0 = snoise3(float3(uv * noiseScale, u.time * 0.5)) * 0.5 + 0.5;
    float r0 = mix(mix(innerRadius, 1.0, 0.4), mix(innerRadius, 1.0, 0.6), n0);
    float d0 = distance(uv, (r0 * invLen) * uv);
    float v0 = light1(1.0, 10.0, d0);
    v0 *= smoothstep(r0 * 1.05, r0, len);
    float cl = cos(ang + u.time * 2.0) * 0.5 + 0.5;

    float a = u.time * -1.0;
    float2 pos = float2(cos(a), sin(a)) * r0;
    float d = distance(uv, pos);
    float v1 = light2(1.5, 5.0, d);
    v1 *= light1(1.0, 50.0, d0);

    float v2 = smoothstep(1.0, mix(innerRadius, 1.0, n0 * 0.5), len);
    float v3 = smoothstep(innerRadius, mix(innerRadius, 1.0, 0.5), len);

    float3 col = mix(color1, color2, cl);
    col = mix(color3, col, v0);
    col = (col + v1) * v2 * v3;
    col = clamp(col, 0.0, 1.0);

    return extractAlpha(col);
}

float4 mainImage(float2 fragCoord, constant Uniforms &u) {
    float2 center = u.resolution.xy * 0.5;
    float size = min(u.resolution.x, u.resolution.y);
    float2 uv = (fragCoord - center) / size * 2.0;

    // rotation
    float angle = u.rot;
    float s = sin(angle);
    float c = cos(angle);
    uv = float2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);

    // hover distortions
    uv.x += u.hover * u.hoverIntensity * 0.1 * sin(uv.y * 10.0 + u.time);
    uv.y += u.hover * u.hoverIntensity * 0.1 * sin(uv.x * 10.0 + u.time);

    return drawOrb(uv, u);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 fragCoord = in.uv * u.resolution.xy;
    float4 col = mainImage(fragCoord, u);
    return float4(col.rgb * col.a, col.a);
}
