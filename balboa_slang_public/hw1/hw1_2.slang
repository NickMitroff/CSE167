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

    uint2 tid_fixed = uint2(tid.x, height - tid.y);
    image[tid] = float4(0.5,0.5,0.5,1.0);

    Polyline pl;
    pl.closed = is_closed;
    pl.pts_begin = 0;
    pl.pts_end = num_polyline;
    Shape shape = Shape(ShapeType.Polyline, 0, use_fill_color, float4(fill_color, 1.0), use_stroke_color, float4(stroke_color, 1.0), stroke_width, 
        float3x3(1,0,0,0,1,0,0,0,1));

    draw_polyline(tid, tid_fixed, shape, pl, polyline, image);
}