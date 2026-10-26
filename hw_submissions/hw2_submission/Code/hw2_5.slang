import hw2_2;

[shader("compute")]
[numthreads(64, 1, 1)]
void clear_buffers(uint tid : SV_DispatchThreadID,
                   uniform uint num_pixels,
                   RWStructuredBuffer<uint> depth_buffer,
                   RWStructuredBuffer<uint> triangle_id_buffer) {
    if (tid >= num_pixels)
        return;

    depth_buffer[tid] = 0xffffffff;
    triangle_id_buffer[tid] = 0xffffffff;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void transform_vertices(
    uint tid : SV_DispatchThreadID,
    uniform uint num_vertices,
    uniform uint vertex_offset,
    uniform float4x4 MVP,
    StructuredBuffer<float3> vertices,
    RWStructuredBuffer<float3> projected_vertices)
{
    if (tid >= num_vertices)
        return;

    uint i = vertex_offset + tid;
    float4 p = mul(MVP, float4(vertices[i], 1.0));
    projected_vertices[i] = p.xyz / p.w;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void rasterize_depth(
        uint tid : SV_DispatchThreadID,
        uniform uint num_triangles,
        uniform uint width,
        uniform uint height,
        uniform float s,
        uniform float a,
        StructuredBuffer<uint3> faces,
        // A projected vertex store the screen space coordinates
        // in xy, and the inverse depth in z.
        StructuredBuffer<float3> projected_vertices,
        RWStructuredBuffer<uint> depth_buffer) {
    // HW 2.5 TODO

    //If there are more threads than triangles, don't do anything. 
    if(tid >= num_triangles) return; 

    int v0 = faces[tid][0];
    int v1 = faces[tid][1];
    int v2 = faces[tid][2];
    
    float3 sp0 = projected_vertices[v0];
    float3 sp1 = projected_vertices[v1];
    float3 sp2 = projected_vertices[v2];
    
    float inv_depth0 = sp0.z;
    float inv_depth1 = sp1.z;
    float inv_depth2 = sp2.z;

    uint2 aabb_min = uint2((int)min(min(sp0[0],sp1[0]),sp2[0]), (int)min(min(sp0[1],sp1[1]),sp2[1]));
    uint2 aabb_max = uint2((int)max(max(sp0[0],sp1[0]),sp2[0]) + 1, (int)max(max(sp0[1],sp1[1]),sp2[1]) + 1);

    // first, get e01, e12, e20
    float3 edge_01 = sp1 - sp0;
    float3 edge_12 = sp2 - sp1;
    float3 edge_20 = sp0 - sp2;

    // then, get the normals
    float2 normal_01 = float2(edge_01.y, -edge_01.x);
    float2 normal_12 = float2(edge_12.y, -edge_12.x);
    float2 normal_20 = float2(edge_20.y, -edge_20.x);

    for (int x = aabb_min[0]; x <= aabb_max[0]; x++) {
        for (int y = aabb_min[1]; y <= aabb_max[1]; y++) {
            float2 p = float2(x + 0.5, y + 0.5);

            // then, plug into the equation Eij(p) = (p - vi) * nij
            // and extract the sign
            bool is_pos_01 = dot(p - float2(sp0.x, sp0.y), normal_01) > 0;
            bool is_pos_12 = dot(p - float2(sp1.x, sp1.y), normal_12) > 0;
            bool is_pos_20 = dot(p - float2(sp2.x, sp2.y), normal_20) > 0;

            bool point_in_triangle = false;
            // if all 3 edges are equal, then the point is in the triangle
            if (is_pos_01 == is_pos_12 && is_pos_12 == is_pos_20) point_in_triangle = true;

            if (point_in_triangle) {
                float4 z = interpolate_barycentric(
                    float2(sp0.x, sp0.y), float2(sp1.x, sp1.y), float2(sp2.x, sp2.y), 
                    inv_depth0, inv_depth1, inv_depth2, p);
                    // atomically set depth buffer (see hw page 16)
                    uint depth_bits = asuint(1 / z[0]);
                    InterlockedMin(depth_buffer[y * width + x], depth_bits);
            }
        }
    }
}

[shader("compute")]
[numthreads(64, 1, 1)]
void rasterize_id(
        uint tid : SV_DispatchThreadID,
        uniform uint num_triangles,
        uniform uint width,
        uniform uint height,
        uniform float s,
        uniform float a,
        StructuredBuffer<uint3> faces,
        StructuredBuffer<float3> projected_vertices,
        RWStructuredBuffer<uint> depth_buffer,
        RWStructuredBuffer<uint> triangle_id_buffer) {
    // HW 2.5 TODO

    if(tid >= num_triangles) return; 

    uint v0 = faces[tid][0];
    uint v1 = faces[tid][1];
    uint v2 = faces[tid][2];
    
    float3 sp0 = projected_vertices[v0];
    float3 sp1 = projected_vertices[v1];
    float3 sp2 = projected_vertices[v2];
    
    float inv_depth0 = sp0.z;
    float inv_depth1 = sp1.z;
    float inv_depth2 = sp2.z;

    //float inv_depth0 = inv_depth[mesh.faces[tri_id][0]]
    //float inv_depth1 = inv_depth[mesh.faces[tri_id][1]]
    //float inv_depth2 = inv_depth[mesh.faces[tri_id][2]]

    uint2 aabb_min = uint2((int)min(min(sp0[0],sp1[0]),sp2[0]), (int)min(min(sp0[1],sp1[1]),sp2[1]));
    uint2 aabb_max = uint2((int)max(max(sp0[0],sp1[0]),sp2[0]) + 1, (int)max(max(sp0[1],sp1[1]),sp2[1]) + 1);

    // first, get e01, e12, e20
    float3 edge_01 = sp1 - sp0;
    float3 edge_12 = sp2 - sp1;
    float3 edge_20 = sp0 - sp2;

    // then, get the normals
    float2 normal_01 = float2(edge_01.y, -edge_01.x);
    float2 normal_12 = float2(edge_12.y, -edge_12.x);
    float2 normal_20 = float2(edge_20.y, -edge_20.x);

    for (int x = aabb_min[0]; x <= aabb_max[0]; x++) {
        for (int y = aabb_min[1]; y <= aabb_max[1]; y++) {
            float2 p = float2(x + 0.5, y + 0.5);

            // Use the edge equations as described in HW2.1
            // since this is a lot faster than our polyline implementation


            // then, plug into the equation Eij(p) = (p - vi) * nij
            // and extract the sign
            bool is_pos_01 = dot(p - float2(sp0.x, sp0.y), normal_01) > 0;
            bool is_pos_12 = dot(p - float2(sp1.x, sp1.y), normal_12) > 0;
            bool is_pos_20 = dot(p - float2(sp2.x, sp2.y), normal_20) > 0;

            bool point_in_triangle = false;
            // if all 3 edges are equal, then the point is in the triangle
            if (is_pos_01 == is_pos_12 && is_pos_12 == is_pos_20) point_in_triangle = true;

            if (point_in_triangle) {
                float4 z = interpolate_barycentric(
                    float2(sp0.x, sp0.y), float2(sp1.x, sp1.y), float2(sp2.x, sp2.y), 
                    inv_depth0, inv_depth1, inv_depth2, p);
                // atomically set triangle id buffer (see hw page 16)
                uint depth_bits = asuint(1 / z[0]);
                if (depth_buffer[y * width + x] == depth_bits) {
                    InterlockedMin(triangle_id_buffer[y * width + x], tid);
                }
            }
        }
    }
}

[shader("compute")]
[numthreads(8, 8, 1)]
void shade(
        uint2 tid : SV_DispatchThreadID,
        uniform uint width,
        uniform uint height,
        uniform float s,
        uniform float a,
        StructuredBuffer<uint3> faces,
        StructuredBuffer<float3> vertex_colors,
        StructuredBuffer<float3> projected_vertices,
        StructuredBuffer<uint> triangle_id_buffer,
        RWTexture2D<float4> image) {
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    // HW 2.5 TODO


    uint face_id = triangle_id_buffer[tid.y * width + tid.x];
    if (face_id != 0xffffffff) {

        uint v0 = faces[face_id][0];
        uint v1 = faces[face_id][1];
        uint v2 = faces[face_id][2];

        float3 sp0 = projected_vertices[v0];
        float3 sp1 = projected_vertices[v1];
        float3 sp2 = projected_vertices[v2];

        float inv_depth0 = sp0.z;
        float inv_depth1 = sp1.z;
        float inv_depth2 = sp2.z;

        float4 z = interpolate_barycentric(
            float2(sp0.x, sp0.y), float2(sp1.x, sp1.y), float2(sp2.x, sp2.y),
            inv_depth0, inv_depth1, inv_depth2, tid);

        float3 c0 = vertex_colors[v0];
        float3 c1 = vertex_colors[v1];
        float3 c2 = vertex_colors[v2];
        float3 c = z[1] * c0 + z[2] * c1 + z[3] * c2;
        image[tid] = float4(c, 1);
    }
}
