import hw1_shape_drawing;
[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float2 center,
                  uniform float radius,
                  uniform float3 color,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    uint2 tid_fixed = uint2(tid.x, height - tid.y);
    image[tid_fixed] = float4(0.5, 0.5, 0.5, 1);
    draw_circle_fill(tid_fixed, radius, float4(color, 1.0), image, float3x3(1, 0, center.x, 0, 1, height - center.y, 0, 0, 1));

}

