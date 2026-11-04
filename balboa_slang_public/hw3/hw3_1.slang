import hw3_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  StructuredBuffer<Sphere> spheres,
                  uniform int num_spheres,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    image[tid] = float4(background, 1.0);

    // need to convert p to image plane coords
    // see hw3 pg. 1 figure 1
    float2 p = float2(tid.x + 0.5, tid.y + 0.5);
    float half_width = float(width) / 2;
    float half_height = float(height) / 2;
    float a = float(width) / float(height);

    p.x = a * (p.x - half_width) / half_width;
    p.y = -(p.y - half_height) / half_height;

    float3 o = float3(0.0, 0.0, 0.0);
    float3 d = normalize(float3(p.x, p.y, -1.0));
    

    bool found_sphere = false;
    float tMin = float.maxValue;
    float3 normal;

    
    for (int i = 0; i < num_spheres; i++) {
        Sphere sphere = spheres[i];
        // test ray intersection with sphere
        // for this problem, o = (0, 0, 0)
        // we're given a coordinate p,
        // which is where we shoot the ray towards

        float3 x_c = sphere.center;
        float r = sphere.radius;

        // solve for magnitude(t*d - x_c)^2 = r^2
        float2 t;
        float t_intersect = float.maxValue;
        float coeff_2 = dot(d, d);
        float coeff_1 = -2 * dot(d, x_c);
            + 2 * dot(o, d);
        float coeff_0 = dot(x_c, x_c) - r * r
            + dot(o, o) - 2 * dot(o, x_c);

        // 0 solutions: the ray doesn't intersect the sphere
        if (!solve_quadratic(coeff_2, coeff_1, coeff_0, t)) continue;

        // pick the smallest positive value of t
        if (t.x > 0 && (t.x < t.y || t.y < 0)) t_intersect = t.x;
        else if (t.y > 0 && (t.y < t.x || t.x < 0)) t_intersect = t.y;

        if (t_intersect < tMin) {
            tMin = t_intersect;
            closest_sphere = sphere;
            normal = tMin * d - sphere.center;
            found_sphere = true;
        }
    }
    return found_sphere;
}

bool ray_intersects_sphere_shape(int count, StructuredBuffer<Shape> shapes, StructuredBuffer<Sphere> spheres,
        float3 d, float3 o, out float t_min, out float3 normal, out int shape_index) {
    bool found_sphere = false;
    t_min = float.maxValue;
    normal = float3(1);
    shape_index = -1;

    for (int i = 0; i < count; i++) {
        Shape shape = shapes[i];
        Sphere sphere = spheres[shape.index];
        // test ray intersection with sphere
        // for this problem, o = (0, 0, 0)
        // we're given a coordinate p,
        // which is where we shoot the ray towards

        float3 x_c = sphere.center;
        float r = sphere.radius;

        // solve for magnitude(o + t*d - x_c)^2 = r^2
        float2 t;
        float t_intersect = float.maxValue;
        float coeff_2 = dot(d, d);
        float coeff_1 = -2 * dot(d, x_c);
            + 2 * dot(o, d);
        float coeff_0 = dot(x_c, x_c) - r * r
            + dot(o, o) - 2 * dot(o, x_c);

        // 0 solutions: the ray doesn't intersect the sphere
        if (!solve_quadratic(coeff_2, coeff_1, coeff_0, t)) continue;

        // pick the smallest positive value of t
        if (t.x > 0 && (t.x < t.y || t.y < 0)) t_intersect = t.x;
        else if (t.y > 0 && (t.y < t.x || t.x < 0)) t_intersect = t.y;

        if (t_intersect < t_min) {
            t_min = t_intersect;
            shape_index = i;
            normal = o + t_min * d - sphere.center;
            found_sphere = true;
        }
    }
    return found_sphere;
}