import hw3_common;
import hw3_1;
import hw3_2;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform Camera camera,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Sphere> spheres,
                  StructuredBuffer<PointLight> lights,
                  uniform int num_lights,
                  uniform int max_depth,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    // new in 3.4: apply FOV conversion for image plane
    // when we multiplied by 2, everything became
    // 2 times too small, so I guess don't do that?
    float plane_width = tan(radians(camera.fov_x) / 2.0);

    float2 p = float2(tid.x + 0.5, tid.y + 0.5);
    float half_width = float(width) / 2;
    float half_height = float(height) / 2;
    float a = float(width) / float(height);
    // height = width / a
    // a = width / height

    p.x = plane_width * (p.x - half_width) / half_width;
    p.y = (plane_width / a) * -(p.y - half_height) / half_height;

    float3 o = xform_pt(camera.cam_to_world, float3(0.0, 0.0, 0.0));

    float3 d = normalize(float3(p.x, p.y, -1.0));
    // new in 3.4: apply view transform to camera rays
    d = normalize(xform_vec(camera.cam_to_world, d));
    bool found_any_sphere = false;
    float3 throughput = float3(1.0);
    float3 color = float3(0.0);

    for (int bounce_index = 0; bounce_index < max_depth; bounce_index++) {
        float3 contribution = float3(0.0);
        float t_min = float.maxValue;
        float3 normal;
        float3 sphere_pos;
        int shape_index;
        bool found_sphere = ray_intersects_sphere_transform(num_shapes, shapes, spheres, d, o, t_min, normal, shape_index, sphere_pos);

        if (found_sphere) {
            // float3 color = shapes[shape_index].Kd;
            found_any_sphere = true;
            contribution = get_color_on_sphere_transform(sphere_pos, lights, num_lights, shapes, num_shapes, spheres,
                                               shape_index, normal);
        }
        else contribution = background;

        color += throughput * contribution;
        if (found_sphere) {
            d = d - 2 * (dot(d, normal) * normal);
            o = sphere_pos;

            throughput *= shapes[shape_index].Kr;
        }
        else break;
    }

    if (found_any_sphere) image[tid] = float4(color, 1);
    else image[tid] = float4(background, 1.0);

}

bool ray_intersects_sphere_transform(int count, StructuredBuffer<Shape> shapes, StructuredBuffer<Sphere> spheres,
                                 float3 d, float3 o, out float t_min, out float3 normal, out int shape_index, out float3 sphere_pos) {
    bool found_sphere = false;
    t_min = float.maxValue;
    normal = float3(1);
    shape_index = -1;
    sphere_pos = float3(0);

    for (int i = 0; i < count; i++) {
        Shape shape = shapes[i];
        Sphere sphere = spheres[shape.index];

        // new in 3.4: apply world to object space conversion to o and d
        float3 o_t = xform_pt(shape.world_to_obj, o);
        float3 d_t = xform_vec(shape.world_to_obj, d);

        // test ray intersection with sphere
        // for this problem, o = (0, 0, 0)
        // we're given a coordinate p,
        // which is where we shoot the ray towards

        float3 x_c = sphere.center;
        float r = sphere.radius;

        // solve for magnitude(o + t*d - x_c)^2 = r^2
        float2 t;
        float t_intersect = float.maxValue;
        float coeff_2 = d_t.x * d_t.x + d_t.y * d_t.y + d_t.z * d_t.z;
        float coeff_1 = -2 * (d_t.x * x_c.x + d_t.y * x_c.y + d_t.z * x_c.z)
            + 2 * dot(o_t, d_t);
        float coeff_0 = x_c.x * x_c.x + x_c.y * x_c.y + x_c.z * x_c.z - r * r
            + dot(o_t, o_t) - 2 * dot(o_t, x_c);

        // 0 solutions: the ray doesn't intersect the sphere
        if (!solve_quadratic(coeff_2, coeff_1, coeff_0, t)) continue;

        // pick the smallest positive value of t
        // for problems 3.2 onwards, compare with EPSILON instead of 0
        // to prevent pixels from being skipped
        if (t.x > EPSILON && (t.x < t.y || t.y < EPSILON)) t_intersect = t.x;
        else if (t.y > EPSILON && (t.y < t.x || t.x < EPSILON)) t_intersect = t.y;

        if (t_intersect < t_min) {
            t_min = t_intersect;
            shape_index = i;
            normal = normalize(o_t + t_min * d_t - sphere.center);
            float3x3 world_to_obj_3x3 = float3x3(shape.world_to_obj);
            normal = normalize(mul(transpose(world_to_obj_3x3), normal));
            found_sphere = true;
            sphere_pos = xform_pt(shape.obj_to_world, o_t + t_min * d_t);
        }

    }
    return found_sphere;
}

float3 get_color_on_sphere_transform(float3 sphere_pos, StructuredBuffer<PointLight> lights, int num_lights,
                                    StructuredBuffer<Shape> shapes, uniform int num_shapes,
                                    StructuredBuffer<Sphere> spheres, int shape_index, float3 normal) {
    float3 color = float3(0);
    // do lighting
    for (int i = 0; i < num_lights; i++) {
        PointLight light = lights[i];
        // Shoot a ray from the light toward the surface point, as in hw3_2.
        // The intersection routine handles transforming this world-space ray
        // into each sphere's object space.
        float3 d_light = normalize(sphere_pos - light.position);

        float t_min_light = float.maxValue;
        float3 normal_light = float3(0);
        int shape_index_light = -1;
        float3 light_hit_pos;
        bool light_hit_sphere = ray_intersects_sphere_transform(num_shapes, shapes, spheres,
            d_light, light.position, t_min_light, normal_light, shape_index_light, light_hit_pos);
        if (light_hit_sphere && shape_index == shape_index_light) {
            float3 light_color = light.intensity / (t_min_light * t_min_light);
            float3 Kd = shapes[shape_index].Kd;

            // reflectance = Kdmax(n dot l, 0)
            color += Kd * light_color * max(dot(normal, -d_light), 0);
        }
    }
    return color;
}
