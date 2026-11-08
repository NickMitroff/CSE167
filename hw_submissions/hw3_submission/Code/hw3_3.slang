import hw3_common;
import hw3_1;
import hw3_2;

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


    float2 p = float2(tid.x + 0.5, tid.y + 0.5);
    float half_width = float(width) / 2;
    float half_height = float(height) / 2;
    float a = float(width) / float(height);

    p.x = a * (p.x - half_width) / half_width;
    p.y = -(p.y - half_height) / half_height;

    float3 o = float3(0.0, 0.0, 0.0);
    float3 d = normalize(float3(p.x, p.y, -1.0));
    bool found_any_sphere = false;
    float3 throughput = float3(1.0);
    float3 color = float3(0.0);

    for (int bounce_index = 0; bounce_index < max_depth; bounce_index++) {
        float3 contribution = float3(0.0);
        float t_min = float.maxValue;
        float3 normal;
        float3 sphere_pos;
        int shape_index;
        bool found_sphere = ray_intersects_sphere_shape(num_shapes, shapes, spheres, d, o, t_min, normal, shape_index);

        if (found_sphere) {
            // float3 color = shapes[shape_index].Kd;
            found_any_sphere = true;
            sphere_pos = o + t_min * d;
            float3 hit_sphere_normal = float3(0.0);
            contribution = get_color_on_sphere(sphere_pos, lights, num_lights, shapes, num_shapes, spheres,
                                               t_min, shape_index, normal);
        }
        else contribution = background;

        color += throughput * contribution;
        if (found_sphere) {
            o = sphere_pos;
            d = d - 2 * (dot(d, normal) * normal);

            throughput *= shapes[shape_index].Kr;
        }
        else break;

    }

    if (found_any_sphere) image[tid] = float4(color, 1);
    else image[tid] = float4(background, 1.0);
}
