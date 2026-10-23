[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float2 sp0, // vertex at screen space
                  uniform float2 sp1,
                  uniform float2 sp2,
                  uniform float inv_depth0, // inverse depth in camera space
                  uniform float inv_depth1,
                  uniform float inv_depth2,
                  uniform int2 aabb_min,
                  uniform float3 c0, // vertex color
                  uniform float3 c1,
                  uniform float3 c2,
                  uniform float s,
                  uniform float a,
                  RWTexture2D<float4> color_image,
                  RWTexture2D<float> depth_image) {
    int2 ipixel = int2(tid) + int2(aabb_min);
    uint width, height;
    color_image.GetDimensions(width, height);
    if (ipixel.x < 0 || ipixel.y < 0 || ipixel.x >= width || ipixel.y >= height) {
        return;
    }

    // TODO: HW 2.2
    // This code fills in the bounding box with black
    // which is nice for testing where the bounding box is drawn
    // image[ipixel] = float4(float3(0.0), 1.0);

    float2 p = float2(ipixel.x + 0.5, ipixel.y + 0.5);

    // Use the edge equations as described in HW2.1
    // since this is a lot faster than our polyline implementation

    // first, get e01, e12, e20
    float2 edge_01 = sp1 - sp0;
    float2 edge_12 = sp2 - sp1;
    float2 edge_20 = sp0 - sp2;

    // then, get the normals
    float2 normal_01 = float2(edge_01.y, -edge_01.x);
    float2 normal_12 = float2(edge_12.y, -edge_12.x);
    float2 normal_20 = float2(edge_20.y, -edge_20.x);

    // then, plug into the equation Eij(p) = (p - vi) * nij
    // and extract the sign
    bool is_pos_01 = dot(p - sp0, normal_01) > 0;
    bool is_pos_12 = dot(p - sp1, normal_12) > 0;
    bool is_pos_20 = dot(p - sp2, normal_20) > 0;

    bool point_in_triangle = false;
    // if all 3 edges are equal, then the point is in the triangle
    if (is_pos_01 == is_pos_12 && is_pos_12 == is_pos_20) point_in_triangle = true;

    if (point_in_triangle) {
        //// interpolate Z ////
        float4 z = interpolate_barycentric(sp0, sp1, sp2, inv_depth0, inv_depth1, inv_depth2, p);

        if (depth_image[ipixel] > z[0]) {
            depth_image[ipixel] = z[0];
            float3 c = z[1] * c0 + z[2] * c1 + z[3] * c2;
            color_image[ipixel] = float4(c, 1.0);
        }

    }
    
}

float4 interpolate_barycentric(float2 sp0, float2 sp1, float2 sp2, float inv_depth0, float inv_depth1, float inv_depth2,
            float2 p) {
    // get p0, p1, p2 (see hw page 6) //
        float3 p0 = float3(sp0, 2);
        float3 p1 = float3(sp1, 2);
        float3 p2 = float3(sp2, 2);

        // get vectors p->p0, p->p1, p->p2, p0->p1, p0->p2
        float2 p_p0 = sp0 - p;
        float2 p_p1 = sp1 - p;
        float2 p_p2 = sp2 - p;
        float2 p0_p1 = sp1 - sp0;
        float2 p0_p2 = sp2 - sp0;

        // get area of triangles for barycentric coordinates //
        float area_total = 0.5 * length(cross(float3(p0_p1, 0), float3(p0_p2, 0)));
        if (area_total < 0.0001) return float.maxValue;
        float area_b0 = 0.5 * length(cross(float3(p_p1, 0), float3(p_p2, 0)));
        float area_b1 = 0.5 * length(cross(float3(p_p0, 0), float3(p_p2, 0)));
        float area_b2 = 0.5 * length(cross(float3(p_p0, 0), float3(p_p1, 0)));
        

        // get screen-space barycentric coordinates
        float b0_prime = area_b0 / area_total;
        float b1_prime = area_b1 / area_total;
        float b2_prime = area_b2 / area_total;

        // convert to object space barycentric coordinates (see page 8 eq. 15)
        float divide_by = b0_prime / (p0.z) + b1_prime / (p1.z) + b2_prime / (p2.z);
        float b0 = (b0_prime / p0.z) / divide_by;
        float b1 = (b1_prime / p1.z) / divide_by;
        float b2 = (b2_prime / p2.z) / divide_by;

        float z = b0 * inv_depth0 + b1 * inv_depth1 + b2 * inv_depth2;
        return float4(z, b0, b1, b2);
}