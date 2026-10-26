#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 fillColor;
    float cornerRadius;
} ubuf;

void main()
{
    // The quad includes a 1-logical-pixel fringe around the actual panel.
    vec2 halfSize = max((ubuf.resolution - vec2(2.0)) * 0.5, vec2(0.0));
    float radius = clamp(ubuf.cornerRadius, 0.0, min(halfSize.x, halfSize.y));
    vec2 point = (qt_TexCoord0 - vec2(0.5)) * ubuf.resolution;
    vec2 edge = abs(point) - halfSize + vec2(radius);
    float distanceToEdge = min(max(edge.x, edge.y), 0.0)
        + length(max(edge, vec2(0.0))) - radius;
    // Derivatives track physical pixels, including fractional output scaling.
    float edgeWidth = max(fwidth(distanceToEdge), 0.5);
    float coverage = 1.0 - smoothstep(-edgeWidth, edgeWidth, distanceToEdge);
    fragColor = ubuf.fillColor * coverage * ubuf.qt_Opacity;
}
