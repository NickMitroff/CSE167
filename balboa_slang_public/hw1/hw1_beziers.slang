import hw1_common;
import hw1_shape_drawing;

float4 draw_bezier(uint2 tid, float2 coords, 
                    Shape shape, QuadraticBezier bezier, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image) {   
    float4 set_pixel = image[tid];
    bool draw_fill = false;
    if (shape.use_fill && bezier.closed && draw_bezier_fill(tid, coords, shape, bezier, points, image)) {
        set_pixel = set_pixel_with_alpha(tid, shape.fill_rgba, image);
        draw_fill = true;
    }

    if (shape.use_stroke && draw_bezier_stroke(tid, coords, shape, bezier, points, image)) {
        if (draw_fill) set_pixel = mix_colors(set_pixel, shape.stroke_rgba);
        else set_pixel = set_pixel_with_alpha(tid, shape.stroke_rgba, image);
    }
    return set_pixel;

}

// fill color
bool draw_bezier_fill(uint2 tid, float2 coords, 
                    Shape shape, QuadraticBezier bezier, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image) {
    int itr_start = bezier.pts_begin;
    int itr_end = bezier.pts_end;

    // because the fill loop is closed,
    // assume an even number of points
    // and that (pts_end - pts_begin) is even
    float2 q = coords;
    int count = 0;
    bool line_up = false;
    bool debug_draw_itr = false;
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
        int2 intersections = ray_intersects_bezier(q, p0, p1, p2, debug_draw_itr);
        if (debug_draw_itr) debug_draw = true;
        count += intersections.x;
        count += intersections.y;

    }
    
    if (debug_draw) {
        return false;
    }
    else if (count != 0) {
        // shape.fill_rgba.w = 0.5 + count * 0.1;
        return true;
    }
    return false;

}




// intersection test
int2 ray_intersects_bezier(float2 q, float2 p0, float2 p1, float2 p2, out bool debug_draw) {
    float2 solutions;
    bool root_x_valid = false;
    bool root_y_valid = false;
    debug_draw = false;
    int2 results = int2(0,0);
    bool line_up;
    
    float t;

    // want to solve: q.y = (1-t)^2 * p0.y + 2(1 - t) * t * p1.y + t^2 * p2l.y
    // which is equivalent to 
    // 0 = 
    // t^2(p0.y - 2 * p1.y + p2.y) 
    // + t(-2 * p0.y + 2 * p1.y)
    // + (p0.y - q.y)
    
    // use the built-in solve_quadratic method to find candidate values for t
    bool2 roots_valid = check_roots(p0, p1, p2, q, solutions);
    float epsilon = 0.000001;
    if (roots_valid.x && roots_valid.y) {
        t = solutions.y;
        float derivative = -2 * p0.y * (1 - t)
            - 4 * p1.y * t + 2 * p1.y
            + 2 * t * p2.y;
        
        line_up = derivative > 0;
        if (t < epsilon && line_up) results.y = 0;
        else if (t > 1 - epsilon && !line_up) results.y = 0;
        else if (derivative > epsilon || derivative < -epsilon) results.y = line_up ? 1 : -1;
        t = solutions.x;
    }
    else if (roots_valid.x) t = solutions.x;
    else if (roots_valid.y) t = solutions.y;
    else return results;

    // take the derivative to see if the line is going up at time t
    float derivative = -2 * p0.y * (1 - t)
        - 4 * p1.y * t + 2 * p1.y
        + 2 * t * p2.y;

    line_up = derivative > 0;
    

    if (t <= epsilon && line_up) results.x = 0;
    else if (t >= 1 - epsilon && !line_up) results.x = 0;
    else if (derivative > epsilon || derivative < -epsilon) results.x = line_up ? 1 : -1;

   


    return results;
}

// stroke color
bool draw_bezier_stroke(uint2 tid, float2 coords, 
                    Shape shape, QuadraticBezier bezier, 
                    StructuredBuffer<float2> points,
                    RWTexture2D<float4> image) {
    int itr_start = bezier.pts_begin;
    int itr_end = bezier.pts_end;
    
    float2 d = coords;
    int count = 0;
    bool line_up = false;
    bool debug_draw = false;
    for (int i = itr_start; i <= itr_end - 1; i += 2) {
        int3 indices;
        if (i + 2 < itr_end) {
            indices = int3(i, i+1, i+2);
        }
        else if (bezier.closed) {
            indices = int3(itr_end - 2, itr_end - 1, itr_start);
        }
        else continue;
    
    
        float2 a = points[indices.x];
        float2 b = points[indices.y];
        float2 c = points[indices.z];

        // apply round joins using the same method we used for polylines
        bool p0_is_round = bezier.closed || indices.x > itr_start;
        bool p1_is_round = bezier.closed || indices.z < itr_end - 1;
        if (p0_is_round && length(a - d) < shape.stroke_width/2) {
            return true;
        }
        if (p1_is_round && length(c - d) < shape.stroke_width/2) {
            return true;
        }


        

        // LLM DISCLOSURE:
        // To avoid the headache of computing a bunch of 4th-degree polynomials,
        // I used AI tools to help with polynomial math
        // WolframAlpha & SymboLab were used to expand out the f(t) equation
        // and obtain the derivative
        // OpenAI Codex was used to extract the coefficients and write
        // the below snippet of code storing them in variables t3, t2, t1, and t0
        // -Nick
        
        float2 t3 =  4*a*a + 16*b*b + 4*c*c + 8*c*a
          - 16*a*b - 16*c*b;

        float2 t2 = -12*a*a - 24*b*b - 12*c*a
                + 36*a*b + 12*c*b;

        float2 t1 =  12*a*a + 8*b*b + 4*c*a
                - 24*a*b - 4*c*d + 8*d*b - 4*d*a;

        float2 t0 = 4*a*b - 4*a*a - 4*d*b + 4*d*a;

        // ^^ the code written by AI ^^

        float3 solutions = float3(0, 0, 0);
        float t = 100;
        solve_cubic(t3.x + t3.y, t2.x + t2.y, t1.x + t1.y, t0.x + t0.y, solutions);
        //else return false;
        float2 p0 = a;
        float2 p1 = b;
        float2 p2 = c;
        float2 q = d;
        if (solutions.x > 0 && solutions.x <= 1) t = solutions.x;
        if (solutions.y > 0 && solutions.y <= 1) t = solutions.y;
        if (solutions.z > 0 && solutions.z <= 1) t = solutions.z;
        // float2 solutions = float2(0, 0);
        // float t;
        // solve_quadratic(0, -1, 250, solutions);
        // //else return false;
        // float2 p0 = a;
        // float2 p1 = b;
        // float2 p2 = c;
        // float2 q = d;
        // if (solutions.x > 0 && solutions.x <= 1000) t = solutions.x;
        // else if (solutions.y > 0 && solutions.y <= 1000) t = solutions.y;

        float2 closest_point = float2(
            (1 - t) * (1 - t) * p0.x
                + 2 * (1 - t) * t * p1.x
                + t * t * p2.x,
            (1 - t) * (1 - t) * p0.y
                + 2 * (1 - t) * t * p1.y
                + t * t * p2.y,
        );
        
        if (length(closest_point - q) <= shape.stroke_width / 2) {
            return true;
        }
    }
    
    return false;
}

bool2 check_roots(float2 p0, float2 p1, float2 p2, float2 q, out float2 solutions) {
    bool2 roots_valid = bool2(false, false);
    float t;

    // want to solve: q.y = (1-t)^2 * p0.y + 2(1 - t) * t * p1.y + t^2 * p2l.y
    // which is equivalent to 
    // 0 = 
    // t^2(p0.y - 2 * p1.y + p2.y) 
    // + t(-2 * p0.y + 2 * p1.y)
    // + (p0.y - q.y)
    
    // use the built-in solve_quadratic method to find candidate values for t
    // q.y += 0.0001;
    if (!solve_quadratic(p0.y - 2 * p1.y + p2.y, 
        -2 * p0.y + 2 * p1.y, 
        p0.y - q.y, 
        solutions)) return roots_valid;

    if (solutions.x >= 0 && solutions.x <= 1) {
        t = solutions.x;
        float sx = (1 - t) * (1 - t) * p0.x
            + 2 * (1 - t) * t * p1.x
            + t * t * p2.x
            - q.x;
        if (sx >= 0) roots_valid.x = true;
    }
    if (solutions.y >= 0 && solutions.y <= 1) { 
        t = solutions.y;
        float sy = (1 - t) * (1 - t) * p0.x
            + 2 * (1 - t) * t * p1.x
            + t * t * p2.x
            - q.x;
        if (sy >= 0) roots_valid.y = true; 
    }
    return roots_valid;
    
}

