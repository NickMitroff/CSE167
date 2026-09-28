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

    uint2 coords = uint2(tid.x, height - tid.y);
    float2 screen_center = float2(center.x, height - center.y);
    image[coords] = float4(0.5, 0.5, 0.5, 1);

    float2 offset_vec = coords - screen_center;
    if (length(offset_vec) <= radius) {
        image[coords] = float4(color, 1.0);
    }

}
