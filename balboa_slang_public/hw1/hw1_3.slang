import hw1_common;
import hw1_shape_drawing;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid: SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int /*samples_per_axis*/, // ignore for now
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Circle> circles,
                  StructuredBuffer<Polyline> polylines,
                  StructuredBuffer<QuadraticBezier> /*quadratic_beziers*/, // ignore for now
                  StructuredBuffer<float2> points,
                  RWTexture2D<float4> image)
{
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height)
    {
        return;
    }

    image[tid] = float4(background, 1.0);

    for (uint i = 0; i < num_shapes; i++) {
        // for alpha test, draw the shapes BACK to FRONT
        Shape shape = shapes[num_shapes - i - 1];
        if (shape.type == ShapeType.Circle) {
            Circle circle = circles[shape.index];
            draw_circle(tid, height, shape, circle, image);
        }
        if(shape.type == ShapeType.Polyline){
            Polyline polyline = polylines[shape.index];
            draw_polyline(tid, shape, polyline, points, image);
        }
    }
}
