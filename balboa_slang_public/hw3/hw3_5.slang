import hw3_common;
import hw3_4;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform Camera camera,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Sphere> spheres,
                  StructuredBuffer<TriangleMesh> meshes,
                  StructuredBuffer<float3> vertices,
                  StructuredBuffer<float3> vertex_normals,
                  StructuredBuffer<uint3> triangles,
                  StructuredBuffer<PointLight> lights,
                  uniform int num_lights,
                  uniform int max_depth,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }
    float plane_width = tan(radians(camera.fov_x) / 2.0);

    float2 p = float2(tid.x + 0.5, tid.y + 0.5);
    float half_width = float(width) / 2;
    float half_height = float(height) / 2;
    float a = float(width) / float(height);

    p.x = plane_width * (p.x - half_width) / half_width;
    p.y = (plane_width / a) * -(p.y - half_height) / half_height;

    float3 o = xform_pt(camera.cam_to_world, float3(0.0, 0.0, 0.0));

    float3 d = normalize(float3(p.x, p.y, -1.0));
    d = normalize(xform_vec(camera.cam_to_world, d));
    bool found_any_sphere = false;
    float3 throughput = float3(1.0);
    float3 color = float3(0.0);

    //Implement: Shoot the Ray and have it hit either the sphere or the triangle mesh first. 
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
            float normal_side = dot(d, normal) >= 0.0 ? 1.0 : -1.0;
            o = sphere_pos + normal_side * EPSILON * normal;

            throughput *= shapes[shape_index].Kr;
        }
        else break;
    }

    if (found_any_sphere) image[tid] = float4(color, 1);
    else image[tid] = float4(background, 1.0);

}
