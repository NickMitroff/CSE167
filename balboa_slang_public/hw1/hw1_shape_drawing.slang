import hw1_common;
// Our code!

bool draw_circle(uint2 coords, uint height,
                    Shape shape, Circle circle, 
                    RWTexture2D<float4> image) {
    float2 screen_center = float2(circle.center.x, height - circle.center.y);

    float2 offset_vec = coords - screen_center;

    if (shape.use_fill) {
        if (draw_circle_fill(coords, height, 
            circle.center, circle.radius, shape.fill_rgba, image)) return true;
    }
    return false;
}

bool draw_circle_fill(uint2 coords, uint height, float2 center, float radius, float4 fill_rgba, RWTexture2D<float4> image) {

    float2 screen_center = float2(center.x, height - center.y);
    float2 offset_vec = coords - screen_center;

    if (length(offset_vec) <= radius) {
        image[coords] = fill_rgba;
        return true;
    }
    return false;
}