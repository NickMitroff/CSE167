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

    // TODO: HW 2.1
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

    
}
