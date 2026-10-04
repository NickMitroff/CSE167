import hw1_common;
// Our code!

bool draw_circle(uint2 coords, uint height,
                    Shape shape, Circle circle, 
                    RWTexture2D<float4> image) {
    float2 screen_center = float2(circle.center.x, height - circle.center.y);

    float2 offset_vec = coords - screen_center;

    if (shape.use_stroke) {
        if (draw_circle_stroke(coords, height,
            circle.center, circle.radius, shape.stroke_width, shape.stroke_rgba, image)) return true;
    }
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
        set_pixel_with_alpha(coords, fill_rgba, image);
        return true;
    }
    return false;
}

bool draw_circle_stroke(uint2 coords, uint height,
    float2 center, float radius, float stroke_width, 
    float4 stroke_rgba, RWTexture2D<float4> image) {

    float2 screen_center = float2(center.x, height - center.y);
    float2 offset_vec = coords - screen_center;
    float distance = length(offset_vec);
    float half_width = stroke_width / 2;

    if (distance <= radius + half_width && distance >= radius - half_width) {
        set_pixel_with_alpha(coords, stroke_rgba, image);
        return true;
    }
    return false;
}

//Drawing Polylines
bool draw_polyline(uint2 tid, uint2 coords, 
                    Shape shape, Polyline polyline, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image){
    if (draw_polyline_fill_stroke(tid, coords, points, 
            polyline, shape.use_fill, shape.fill_rgba, 
            shape.use_stroke, shape.stroke_rgba, shape.stroke_width, 
            image)) return true; 
    return false; 
}

bool draw_polyline_fill_stroke(uint2 q, uint2 screen_pos, 
                        StructuredBuffer<float2> points, 
                        Polyline pl, 
                        bool use_fill_color, float4 fill_color, 
                        bool use_stroke_color, float4 stroke_color,
                        float stroke_width, 
                        RWTexture2D<float4> image){
    bool apply_stroke = false; 
    bool apply_fill = false;
    bool is_closed = pl.closed;
    int num_polyline = pl.pts_end - pl.pts_begin;
    int iterations = is_closed ? num_polyline : num_polyline - 1; 
    
        int count = 0; 
        for(uint i = pl.pts_begin; i < pl.pts_begin + iterations; i++){
            float2 p0; 
            float2 p1;
            bool line_up; 

            p0 = points[i];
            // if the polyline is NOT closed, then don't iterate from last point back to start
            // which means using num_polyline-1 instead of iterations
            p1 = points[i == pl.pts_begin + num_polyline - 1 ? pl.pts_begin : i + 1];

            line_up = p1.y > p0.y;
            if (use_fill_color) {
                if(ray_intersects_polyline(q, p0, p1, line_up)){
                    if (line_up) count++;
                        else count--;
                }
                apply_fill = count != 0;
            } 
            

            //Calculate Magnitude
            if (use_stroke_color) {
                if (point_is_in_stroke_range(q, p0, p1, stroke_width)) apply_stroke = true;
            }

        }
    
    if(apply_fill){
        set_pixel_with_alpha(screen_pos, fill_color, image);
    }

    if(apply_stroke){
        set_pixel_with_alpha(screen_pos, stroke_color, image);
    }

    return apply_fill || apply_stroke; 
}

bool ray_intersects_polyline(float2 q, float2 p0, float2 p1, bool line_up) {
    float t;
    if (p1.y != p0.y) t = (q.y - p0.y) / (p1.y - p0.y);
    else return false; // if a line lies completely flat, we ignore it
    if (t < 0 || t > 1) return false; // if this polyline is entirely above/below point q
    // edge case where the test point is on a vertex (where two polylines intersect)
    if (t == 0 && line_up) return false;
    if (t == 1 && !line_up) return false;
    float s = p0.x + t * (p1.x - p0.x) - q.x;
    if (s < 0) return false; // if the point to test is left of the point q
    return true;
}

bool point_is_in_stroke_range(float2 q, float2 p0, float2 p1, float stroke_width) {
    float pntMagnitude = length(p1 - p0);
    if (pntMagnitude == 0.0) return false;
    float l = dot((p1 - p0), (q - p0)) / pntMagnitude;
    if (l <= 0 || l >= pntMagnitude) return false;
    float2 q2 = p0 + l * ((p1 - p0) / pntMagnitude);
    float compare = length(q - q2);
    if (compare < stroke_width / 2) return true;
    return false;
}

void set_pixel_with_alpha(uint2 coords, float4 color_rgba, RWTexture2D<float4> image) {
    float4 background = image[coords];
    float4 c0 = float4(color_rgba.x, color_rgba.y, color_rgba.z, 1.0);
    float a0 = color_rgba.w;
    float4 new_color = a0 * c0 + (1 - a0) * background;
    image[coords] = new_color;

}