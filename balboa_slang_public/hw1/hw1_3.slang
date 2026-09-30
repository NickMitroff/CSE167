import hw1_common;
import hw1_shape_drawing;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int /*samples_per_axis*/, // ignore for now
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Circle> circles,
                  StructuredBuffer<Polyline> polylines,
                  StructuredBuffer<QuadraticBezier> /*quadratic_beziers*/, // ignore for now
                  StructuredBuffer<float2> points,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    uint2 coords = uint2(tid.x, height - tid.y);
    image[coords] = float4(background, 1.0);

    // TODO: your code here
    for (uint i = 0; i < num_shapes; i++) {
        Shape shape = shapes[i];
        if (shape.type == ShapeType.Circle) {
            Circle circle = circles[shape.index];
            float3 fill_rgb = float3(shape.fill_rgba.x, shape.fill_rgba.y, shape.fill_rgba.z);
            draw_circle(coords, height, shape, circle, image);
        }
    }


}
