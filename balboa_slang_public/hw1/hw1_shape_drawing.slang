import hw1_common;
// Our code!


void set_pixel_with_alpha(uint2 tid, float4 color_rgba, RWTexture2D<float4> image) {
    uint2 coords = int2(tid.x, tid.y);

    // apply alpha compositing
    float4 background = image[coords];
    float4 c0 = float4(color_rgba.x, color_rgba.y, color_rgba.z, 1.0);
    float a0 = color_rgba.w;
    float4 new_color = a0 * c0 + (1 - a0) * background;
    image[coords] = new_color;
}



bool draw_circle(uint2 tid, float2 scaled_coords,
                    Shape shape, Circle circle, 
                    RWTexture2D<float4> image) {

    bool set_pixel = false;

    if (shape.use_fill) {
        if (circle_should_draw_fill(scaled_coords, shape, circle, image)) {
            set_pixel_with_alpha(tid, shape.fill_rgba, image);
            set_pixel = true;
        };
    }

    if (shape.use_stroke) {
        if (circle_should_draw_stroke(scaled_coords, shape, circle, image)) {
                set_pixel_with_alpha(tid, shape.stroke_rgba, image);
                set_pixel = true;
            }
    }

    return set_pixel;
}

bool circle_should_draw_fill(float2 scaled_coords,
                    Shape shape, Circle circle, 
                    RWTexture2D<float4> image) {

    // float2 point_in_object_space = get_transformed_coords(tid, world_to_obj);

    if (length(circle.center - scaled_coords) <= circle.radius) {
        return true;
    }
    return false;
}

bool circle_should_draw_stroke(float2 scaled_coords,
                    Shape shape, Circle circle, 
                    RWTexture2D<float4> image) {

    float distance = length(circle.center - scaled_coords);
    float half_width = shape.stroke_width / 2;

    if (distance <= circle.radius + half_width && distance >= circle.radius - half_width) {
        return true;
    }
    return false;
}

//Drawing Polylines
bool draw_polyline(uint2 tid, float2 scaled_coords,
                    Shape shape, Polyline polyline, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image){
    int num_polylines, stride;
    points.GetDimensions(num_polylines, stride); 
    bool2 should_draw = polyline_should_draw(scaled_coords, points, shape, polyline, image);
    bool set_pixel = false;

    // fill
    if (should_draw.x) {
        set_pixel_with_alpha(tid, shape.fill_rgba, image);
        set_pixel = true;
    }

    // stroke
    if (should_draw.y) {
        set_pixel_with_alpha(tid, shape.stroke_rgba, image);
        set_pixel = true;
    }
    return set_pixel;
}


// returns a bool2
// bool2.x = should draw fill
// bool2.y = should draw stroke
bool2 polyline_should_draw(float2 scaled_coords,
                        StructuredBuffer<float2> points, Shape shape,
                        Polyline pl, 
                        RWTexture2D<float4> image){
    bool apply_stroke = false; 
    bool apply_fill = false;
    bool is_closed = pl.closed;
    int num_polyline = pl.pts_end - pl.pts_begin;
    int iterations = is_closed ? num_polyline : num_polyline - 1; 
    float2 q = scaled_coords;
        int count = 0; 
        for(uint i = pl.pts_begin; i < pl.pts_begin + iterations; i++){
            float2 p0; 
            float2 p1;
            bool line_up; 
            int p0_index = i;
            int p1_index = i == pl.pts_begin + num_polyline - 1 ? pl.pts_begin : i + 1;
            p0 = points[p0_index];
            // if the polyline is NOT closed, then don't iterate from last point back to start
            // which means using num_polyline-1 instead of iterations
            p1 = points[p1_index];

            line_up = p1.y > p0.y;
            if (shape.use_fill) {
                if(ray_intersects_polyline(q, p0, p1, line_up)){
                    if (line_up) count++;
                        else count--;
                }
                apply_fill = count != 0;
            } 
            

            //Calculate Magnitude
            if (shape.use_stroke) {
                bool p0_is_round = is_closed || p0_index != pl.pts_begin;
                bool p1_is_round = is_closed || p1_index != pl.pts_end - 1;
                if (point_is_in_stroke_range(q, p0, p1, shape.stroke_width, p0_is_round, p1_is_round)) apply_stroke = true;
            }

        }

    
    return bool2(apply_fill, apply_stroke);
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

bool point_is_in_stroke_range(float2 q, float2 p0, float2 p1, float stroke_width, bool p0_is_round, bool p1_is_round) {
    float pntMagnitude = length(p1 - p0);
    if (pntMagnitude == 0.0) return false;
    float l = dot((p1 - p0), (q - p0)) / pntMagnitude;
    if (p0_is_round && length(p0 - q) < stroke_width/2) return true;
    if (p1_is_round && length(p1 - q) < stroke_width/2) return true;
    if (l <= 0 || l >= pntMagnitude) return false;
    float2 q2 = p0 + l * ((p1 - p0) / pntMagnitude);
    float compare = length(q - q2);
    if (compare < stroke_width / 2) return true;
    return false;
}



float2 get_transformed_coords(uint2 tid, float3x3 world_to_obj) {

    
    float scale_x = world_to_obj[0][0];
    float scale_y = world_to_obj[1][1];
    
    float shear_x = world_to_obj[0][1];
    float shear_y = world_to_obj[1][0];

    float translate_x = world_to_obj[0][2];
    float translate_y = world_to_obj[1][2];

    float x_prime = scale_x * tid.x +
                    shear_x * tid.y + translate_x;
    float y_prime = scale_y * tid.y +
                    shear_y * tid.x + translate_y;
    return float2(x_prime, y_prime);
}