import hw1_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  StructuredBuffer<float2> polyline,
                  uniform int num_polyline,
                  uniform bool is_closed,
                  uniform bool use_fill_color,
                  uniform float3 fill_color,
                  uniform bool use_stroke_color,
                  uniform float3 stroke_color,
                  uniform float stroke_width,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    image[tid] = float4(1.0);
    // TODO: your code here

    uint2 q = tid;
    int iterations = is_closed ? num_polyline : num_polyline - 1;
    int count = 0; // if count != 0, fill pixel
    for (uint i = 0; i < iterations; i++) {
        float2 p0;
        float2 p1;
        bool line_up;

        p0 = polyline[i];
        p1 = polyline[i == num_polyline ? 0 : i + 1];
        line_up = p1.y > p0.y;

        float t = (q.y - p0.y) / (p1.y - p0.y);
        if (t < 0 || t > 1) continue; // if this polyline is entirely above/below point q
        float s = p0.x + t * (p1.x - p0.x) - q.x;
        if (s < 0) continue; // if the point to test is left of the point q

        if (line_up) count++;
        else count--;

    }

    use_fill_color = count != 0;
    if (use_fill_color) {
        image[tid] = float4(fill_color, 1.0);
    }
}
