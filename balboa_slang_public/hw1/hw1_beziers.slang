import hw1_common;
import hw1_shape_drawing;

bool draw_bezier(uint2 tid, uint2 coords, 
                    Shape shape, QuadraticBezier bezier, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image) {
    bool set_pixel = false;
    if (shape.use_fill && bezier.closed) {
        set_pixel = draw_bezier_fill(tid, coords, shape, bezier, points, image);
    }

    return set_pixel;

}

// fill color
bool draw_bezier_fill(uint2 tid, uint2 coords, 
                    Shape shape, QuadraticBezier bezier, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image) {
    int itr_start = bezier.pts_begin;
    int itr_end = bezier.pts_end;

    // because the fill loop is closed,
    // assume an even number of points
    // and that (pts_end - pts_begin) is even
    float2 q = tid;
    int count = 0;
    bool line_up = false;
    bool debug_draw = false;
    for (int i = itr_start; i <= itr_end - 1; i += 2) {
        int3 indices;
        if (i + 2 < itr_end) {
            indices = int3(i, i+1, i+2);
        }
        else {
            indices = int3(itr_end - 2, itr_end - 1, itr_start);
        }
        float2 p0 = points[indices.x];
        float2 p1 = points[indices.y];
        float2 p2 = points[indices.z];
        if (p0.x == p1.x && p1.x == p2.x && p0.y == p1.y && p1.y == p2.y) continue;
        if (ray_intersects_bezier(q, p0, p1, p2, line_up, debug_draw)) {
            if (line_up) count++;
            else count--;
        }

        //// Uncomment to include debug drawings ////
        // draw_circle_fill(coords, 500, p0, 6 + 2 * i, float4(0, 1, 0, 1), image);
        // draw_circle_fill(coords, 500, p1, 6 + 2 * i, float4(0, 1, 1, 1), image);
        
        // for (float t = 0; t <= 1; t += 0.05) {
        //     float test_x = (1 - t) * (1 - t) * p0.x
        //         + 2 * (1 - t) * t * p1.x
        //         + t * t * p2.x;
        //     float test_y = (1 - t) * (1 - t) * p0.y
        //         + 2 * (1 - t) * t * p1.y
        //         + t * t * p2.y;
        //     float derivative = -2 * p0.y * (1 - t)
        //         - 4 * p1.y * t + 2 * p1.y
        //         + 2 * t * p2.y;

        //     line_up = derivative > 0;
        //     if (line_up) draw_circle_fill(coords, 500, float2(test_x, test_y), 5, float4(0, 1, 1, 1), image);
        // }
    }

    
    if (debug_draw) {
        set_pixel_with_alpha(coords, float4(0, 1, 0,1), image);

    }
    if (count != 0) {
        // shape.fill_rgba.w = 0.5 + count * 0.1;
        set_pixel_with_alpha(coords, shape.fill_rgba, image);
        return true;
    }
    return false;

}


// stroke color
bool draw_bezier_stroke(uint2 tid, uint2 coords, 
                    Shape shape, QuadraticBezier bezier, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image) {
    return false;
}

// intersection test
bool ray_intersects_bezier(float2 q, float2 p0, float2 p1, float2 p2, out bool line_up, out bool debug_draw) {
    float2 solutions;
    bool root_x_valid = false;
    bool root_y_valid = false;
    
    float t;
    line_up = false;

    // want to solve: q.y = (1-t)^2 * p0.y + 2(1 - t) * t * p1.y + t^2 * p2l.y
    // which is equivalent to 
    // 0 = 
    // t^2(p0.y - 2 * p1.y + p2.y) 
    // + t(-2 * p0.y + 2 * p1.y)
    // + (p0.y - q.y)
    
    // use the built-in solve_quadratic method to find candidate values for t
    if (!solve_quadratic(p0.y - 2 * p1.y + p2.y, 
        -2 * p0.y + 2 * p1.y, 
        p0.y - q.y, 
        solutions)) return false;
    if (solutions.x >= 0 && solutions.x <= 1) {
        t = solutions.x;
        float sx = (1 - t) * (1 - t) * p0.x
            + 2 * (1 - t) * t * p1.x
            + t * t * p2.x
            - q.x;
        if (sx >= 0) root_x_valid = true;
    }
    if (solutions.y >= 0 && solutions.y <= 1) { 
        t = solutions.y;
        float sy = (1 - t) * (1 - t) * p0.x
            + 2 * (1 - t) * t * p1.x
            + t * t * p2.x
            - q.x;
        if (sy >= 0) root_y_valid = true; 
    }
    
    
    if (root_x_valid && root_y_valid) {
        // debug_draw = true;
        return false;
    }
    else if (root_x_valid) t = solutions.x;
    else if (root_y_valid) t = solutions.y;
    else return false;

    // take the derivative to see if the line is going up at time t
    float derivative = -2 * p0.y * (1 - t)
        - 4 * p1.y * t + 2 * p1.y
        + 2 * t * p2.y;

    line_up = derivative > 0;
    
    // vertex edge case checking (still have no idea how to correctly do this)
    bool isStartVertex = (t == 0);
    bool isEndVertex = (t == 1);
    // if (isStartVertex && line_up) debug_draw = true;
    // if (isEndVertex && !line_up) debug_draw = true;

    // now that we have t, we can find the x-coordinate of the point
    // and use it to find s
    float s = (1 - t) * (1 - t) * p0.x
        + 2 * (1 - t) * t * p1.x
        + t * t * p2.x
        - q.x;

    // if the intersection point is to the left of point q
    // then return false
    if (s < 0) return false; 

    return true;
}