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
    
    uint2 tid_fixed = uint2(tid.x, height - tid.y);
    float2 tid_float = float2(tid.x, height - tid.y); 
    image[tid] = float4(background, 1.0);

    // TODO: your code here

    for (uint i = 0; i < num_shapes; i++) {
        // for alpha test, draw the shapes BACK to FRONT
        Shape shape = shapes[num_shapes - i - 1];
        float2 coords =  get_transformed_coords(tid_fixed, shape.world_to_obj);
        float4 color = image[tid]; 
        if (shape.type == ShapeType.Circle) {
            Circle circle = circles[shape.index];
            color = draw_circle(tid, coords, shape, circle, image);
        }
        if(shape.type == ShapeType.Polyline){
            Polyline polyline = polylines[shape.index];
            color = draw_polyline(tid, coords, shape, polyline, points, image);
        }

        image[tid] = color; 
    }
}
