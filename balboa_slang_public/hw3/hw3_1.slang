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

    float2 p = float2(tid.x + 0.5, tid.y + 0.5);
    // need to convert p to image plane coords
    // see hw3 pg. 1 figure 1
    float half_width = width / 2;
    float half_height = height / 2;
    float a = width / height;

    p.x = a * (p.x - half_width) / half_height;
    p.y = -(p.y - half_height) / half_height;

    float3 o = float3(0.0, 0.0, 0.0);
    float3 d = normalize(float3(p.x, p.y, -1.0));

    Sphere closest_sphere;
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
        float coeff_2 = d.x * d.x + d.y * d.y + d.z * d.z;
        float coeff_1 = -2 * (d.x * x_c.x + d.y * x_c.y + d.z * x_c.z);
        float coeff_0 = x_c.x * x_c.x + x_c.y * x_c.y + x_c.z * x_c.z - r * r;

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

    if (found_sphere) {
        float3 normal_color = (normalize(normal) + 1) / 2;
        image[tid] = float4(normal_color, 1);
    }


}
