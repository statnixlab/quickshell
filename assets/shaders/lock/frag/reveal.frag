#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float progress;
} ubuf;

void main()
{
    // Animate a uniform on the displayed effect itself, rather than an
    // independently rendered mask texture. Keep distances in logical pixels
    // so the reveal remains circular at every output aspect ratio and scale.
    float distanceFromOrigin = length(qt_TexCoord0 * ubuf.resolution);
    float radius = (length(ubuf.resolution) + 2.0) * ubuf.progress;
    float edgeWidth = max(fwidth(distanceFromOrigin), 0.5);
    float coverage = 1.0 - smoothstep(radius - edgeWidth, radius + edgeWidth,
                                    distanceFromOrigin);
    if (ubuf.progress <= 0.0)
        coverage = 0.0;
    else if (ubuf.progress >= 1.0)
        coverage = 1.0;
    fragColor = texture(source, qt_TexCoord0) * coverage * ubuf.qt_Opacity;
}
