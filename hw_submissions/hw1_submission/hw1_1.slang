import hw1_shape_drawing;
import hw1_common;
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
    image[tid] = float4(0.5, 0.5, 0.5, 1);

    // For the first two homework problems, we have to use the data given to reconstruct the Shape struct
    // since our helper methods require a Shape struct
    Shape shape = Shape(ShapeType.Circle, 0, true, float4(color, 1.0), false, float4(0), 0, float3x3(1,0,0,0,1,0,0,0,1));
    Circle circle = Circle(center, radius);
    image[tid] = draw_circle(tid, tid_fixed, shape, circle, image);
}

