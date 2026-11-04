import hw3_common;
import hw3_1;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid: SV_DispatchThreadID,
                  uniform float3 background,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Sphere> spheres,
                  StructuredBuffer<PointLight> lights,
                  uniform int num_lights,
                  uniform int max_depth,
                  RWTexture2D<float4> image)
{
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height)
    {
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
    float3 total_color = float3(0);
    bool found_any_sphere = false;
    float3 throughput = 1.0;
    
    for (int bounce_index = 0; bounce_index < max_depth; bounce_index++) {
        float3 color_from_bounce = float3(0);
        float3 throughput = float3(1);
        float3 Kr;
        bool should_reflect = false;

        bool found_sphere = false;
        float t_min = float.maxValue;
        float3 normal;
        int shape_index;

        found_sphere = ray_intersects_sphere_shape(num_shapes, shapes, spheres, d, o, t_min, normal, shape_index);

        if (found_sphere) {
            found_any_sphere = true;

            float3 n = normalize(normal);
            // float3 color = shapes[shape_index].Kd;
            float3 sphere_pos = o + t_min * d;
            // do lighting
            for (int i = 0; i < num_lights; i++) {
                float3 color = float3(0);
                PointLight light = lights[i];
                float3 d_light = normalize(sphere_pos - light.position);

                float t_min_light = float.maxValue;
                float3 normal_light = float.maxValue;
                int shape_index_light = -1;
                bool light_hit_sphere = ray_intersects_sphere_shape(num_shapes, shapes, spheres, d_light, light.position,
                                                                    t_min_light, normal_light, shape_index_light);
                if (light_hit_sphere && t_min > EPSILON && shape_index == shape_index_light) {
                    float3 light_color = light.intensity / (t_min_light * t_min_light);
                    float3 Kd = shapes[shape_index].Kd;
                    // reflectance = Kdmax(n dot l, 0)
                    color = Kd * light_color * max(dot(n, -d_light), 0);
                    color_from_bounce += color;
                }
                // else if (bounce_index > 0 && !light_hit_sphere) color_from_bounce += background * max(dot(n, -d_light), 0);
            }

            Kr = shapes[shape_index].Kr;
            if (Kr.x + Kr.y + Kr.z > 0) {
                o = sphere_pos;
                d = d - dot(2 * d, n) * n;

                should_reflect = true;
            }
        }

       

        if (should_reflect) {

            total_color += color_from_bounce * throughput;
            throughput *= Kr;
        }
        else {
            total_color += color_from_bounce;
            break;
        }

    }
    
    if (found_any_sphere) image[tid] = float4(total_color, 1);
}
