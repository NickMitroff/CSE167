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

    // float2 p = float2(tid.x + 0.5, tid.y + 0.5);
    // // need to convert p to image plane coords
    // // see hw3 pg. 1 figure 1
    // float half_width = width / 2;
    // float half_height = height / 2;
    // float a = width / height;

    // p.x = a * (p.x - half_width) / half_width;
    // p.y = (p.y - half_height) / half_height;

    // lowkey just use the code shown in class:
    float2 p = 2.0 * (float2(tid) / float2(width, height) - 0.5);
    p.y *= -1;
    float3 o = float3(0.0, 0.0, 0.0);
    float3 d = normalize(float3(p.x, p.y, -1.0));

    Sphere closestSphere;
    float tMin = 0;

    for (int i = 0; i < num_spheres; i++) {
        Sphere sphere = spheres[i];
        // test ray intersection with sphere
        // for this problem, o = (0, 0, 0)
        // we're given a coordinate p,
        // which is where we shoot the ray towards
        float3 d = float3(p, -1);

        float3 x_c = sphere.center;
        float r = sphere.radius;

        // solve for magnitude(t*d - x_c)^2 = r^2
        // this is

    }
}
