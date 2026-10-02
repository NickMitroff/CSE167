import hw1_common;
import hw1_shape_drawing;

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

    uint2 screen_pos = uint2(tid.x, height - tid.y);
    image[screen_pos] = float4(1.0);

    Polyline pl;
    pl.closed = is_closed;
    pl.pts_begin = 0;
    pl.pts_end = num_polyline - 1;

    draw_polyline_fill(tid, screen_pos, polyline, pl, use_fill_color, float4(fill_color,1.0), use_stroke_color, float4(stroke_color,1.0), stroke_width, image);
}