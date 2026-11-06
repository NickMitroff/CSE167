import hw3_common;

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
    bool found_any_shape = false;
    float3 throughput = float3(1.0);
    float3 color = float3(0.0);

    //Implement: Shoot the Ray and have it hit either the sphere or the triangle mesh first. 
    for (int bounce_index = 0; bounce_index < max_depth; bounce_index++) {
        float3 contribution = float3(0.0);
        float t_min = float.maxValue;
        float3 normal;
        float3 hit_pos;
        int shape_index;
        bool found_shape = ray_intersects_shape(num_shapes, shapes, spheres,
                                                meshes,
                                                vertices,
                                                vertex_normals,
                                                triangles, d, o, t_min, normal, shape_index, hit_pos);

        if (found_shape) {
            // float3 color = shapes[shape_index].Kd;
            found_any_shape = true;
            contribution = get_color_on_shape(hit_pos, lights, num_lights, num_shapes, shapes, spheres,
                                              meshes,
                                              vertices,
                                              vertex_normals,
                                              triangles,
                                              shape_index, normal);
        }
        else contribution = background;

        color += throughput * contribution;
        if (found_shape) {
            d = d - 2 * (dot(d, normal) * normal);
            float normal_side = dot(d, normal) >= 0.0 ? 1.0 : -1.0;
            o = hit_pos + normal_side * EPSILON * normal;

            throughput *= shapes[shape_index].Kr;
        }
        else break;
    }

    if (found_any_shape) image[tid] = float4(color, 1);
    else image[tid] = float4(background, 1.0);

}

bool ray_intersects_shape(uniform int num_shapes, StructuredBuffer<Shape> shapes, StructuredBuffer<Sphere> spheres,
                            StructuredBuffer<TriangleMesh> meshes,
                            StructuredBuffer<float3> vertices,
                            StructuredBuffer<float3> vertex_normals,
                            StructuredBuffer<uint3> triangles,
                            float3 d, float3 o, out float t_min, out float3 normal, out int shape_index, out float3 hit_pos) {
    bool found_shape = false;
    t_min = float.maxValue;
    normal = float3(1);
    shape_index = -1;
    hit_pos = float3(0);

    for (int i = 0; i < num_shapes; i++) {
        Shape shape = shapes[i];

        float3 o_t = xform_pt(shape.world_to_obj, o);
        float3 d_t = xform_vec(shape.world_to_obj, d);

        // new in 3.5: shape can be a sphere or a triangle mesh
        if (shape.type == ShapeType.Sphere) {
            Sphere sphere = spheres[shape.index];


            float3 x_c = sphere.center;
            float r = sphere.radius;

            float2 t;
            float t_intersect = float.maxValue;
            float coeff_2 = d_t.x * d_t.x + d_t.y * d_t.y + d_t.z * d_t.z;
            float coeff_1 = -2 * (d_t.x * x_c.x + d_t.y * x_c.y + d_t.z * x_c.z)
            + 2 * dot(o_t, d_t);
            float coeff_0 = x_c.x * x_c.x + x_c.y * x_c.y + x_c.z * x_c.z - r * r
            + dot(o_t, o_t) - 2 * dot(o_t, x_c);

            if (!solve_quadratic(coeff_2, coeff_1, coeff_0, t)) continue;

            if (t.x > EPSILON && (t.x < t.y || t.y < EPSILON)) t_intersect = t.x;
            else if (t.y > EPSILON && (t.y < t.x || t.x < EPSILON)) t_intersect = t.y;

            if (t_intersect < t_min) {
                t_min = t_intersect;
                shape_index = i;
                normal = normalize(o_t + t_min * d_t - sphere.center);
                float3x3 world_to_obj_3x3 = float3x3(shape.world_to_obj);
                normal = normalize(mul(transpose(world_to_obj_3x3), normal));
                found_shape = true;
                hit_pos = xform_pt(shape.obj_to_world, o_t + t_min * d_t);
            }
        }
        else if (shape.type == ShapeType.TriangleMesh) {
            TriangleMesh mesh = meshes[shape.index];

            float3 b;
            float t;
            float t_intersect = float.maxValue;

            for (int j = mesh.triangle_begin; j < mesh.triangle_end; j++) {
                uint3 tri = triangles[j] + mesh.vertex_offset;

                // get vertices
                float3 p0 = vertices[tri.x];
                float3 p1 = vertices[tri.y];
                float3 p2 = vertices[tri.z];

                if (!intersect_tri(p0, p1, p2, o_t, d_t, EPSILON, float.maxValue, b, t)) continue;
                else t_intersect = t;

                if (t_intersect < t_min) {
                    t_min = t_intersect;
                    shape_index = i;
                    // normal = normalize(o_t + t_min * d_t - sphere.center);
                    // TODO: figure out how to actually get tri normal

                    // Compute the triangle normal, then transform it
                    // from object space to world space.
                    // We can get the normal vectors from the buffer given to us
                    float3 n0 = vertex_normals[tri.x];
                    float3 n1 = vertex_normals[tri.y];
                    float3 n2 = vertex_normals[tri.z];

                    normal = normalize((1 - b[1] - b[2]) * n0 + b[1] * n1 + b[2] * n2);
                    float3x3 world_to_obj_3x3 = float3x3(shape.world_to_obj);
                    normal = normalize(mul(transpose(world_to_obj_3x3), normal));
                    found_shape = true;
                    hit_pos = xform_pt(shape.obj_to_world, o_t + t_min * d_t);
                }
            }
        }

        
    }
    return found_shape;
}

float3 get_color_on_shape(float3 hit_pos, StructuredBuffer<PointLight> lights, int num_lights,
                          uniform int num_shapes, StructuredBuffer<Shape> shapes,
                          StructuredBuffer<Sphere> spheres,
                          StructuredBuffer<TriangleMesh> meshes,
                          StructuredBuffer<float3> vertices,
                          StructuredBuffer<float3> vertex_normals,
                          StructuredBuffer<uint3> triangles, int shape_index, float3 normal) {
    float3 color = float3(0);
    // do lighting
    for (int i = 0; i < num_lights; i++) {
        PointLight light = lights[i];
        // Shoot a ray from the light toward the surface point, as in hw3_2.
        // The intersection routine handles transforming this world-space ray
        // into each sphere's object space.
        float3 d_light = normalize(hit_pos - light.position);

        float t_min_light = float.maxValue;
        float3 normal_light = float3(0);
        int shape_index_light = -1;
        float3 light_hit_pos;
        bool light_hit_shape = ray_intersects_shape(num_shapes, shapes, spheres,
                                                    meshes,
                                                    vertices,
                                                    vertex_normals,
                                                    triangles,
                                                    d_light, light.position, t_min_light, normal_light, shape_index_light, light_hit_pos);
        if (light_hit_shape && shape_index == shape_index_light) {
            float3 light_color = light.intensity / (t_min_light * t_min_light);
            float3 Kd = shapes[shape_index].Kd;

            // reflectance = Kdmax(n dot l, 0)
            color += Kd * light_color * max(dot(normal, -d_light), 0);
        }
    }
    return color;
}
