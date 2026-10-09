import hw1_common;
import hw1_shape_drawing;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int samples_per_axis,
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

    image[tid] = float4(background, 1.0);
    // TODO: your code here
    uint2 tid_fixed = uint2(tid.x, height - tid.y);
    float4 color_avg = float4(0.0, 1.0, 1.0, 1.0);


    for(uint i = 0; i < num_shapes; i++){
        Shape shape = shapes[num_shapes - i - 1];
        float4 color = float4(0.0);
        for(int xx = 0; xx < samples_per_axis; xx++){
            for(int yy = 0; yy < samples_per_axis; yy++){
                float2 p = float2(tid_fixed.x + xx/float(samples_per_axis),
                                    tid_fixed.y + yy / float(samples_per_axis));
                float2 coords = get_transformed_coords(p,shape.world_to_obj);
                if(shape.type == ShapeType.Circle){
                    Circle circle = circles[shape.index];
                    color += draw_circle(tid, coords, shape, circle, image);
                }
                if(shape.type == ShapeType.Polyline){
                    Polyline polyline = polylines[shape.index];
                    color += draw_polyline(tid, coords, shape, polyline, points, image);
                }
            }
        }
        image[tid] = color / (samples_per_axis*samples_per_axis);
    }
}
