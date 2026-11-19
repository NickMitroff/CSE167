struct BVHNode {
    float3 bbox_min;
    float3 bbox_max;

    // which BVH node we should skip
    // to if this node is totally not
    // intersecting the ray
    // if next_index < 0, then we don't
    // have the next node to skip to
    int next_index;

    uint triangle_begin;
    uint triangle_end;

    bool is_leaf;
};

float point_aabb_distance(float3 x, float3 bmin, float3 bmax) {
    return length(x - clamp(x, bmin, bmax));
}

struct ClosestPoint {
    float3 position;
    float3 bary;
};

// From https://iquilezles.org/articles/distfunctions/
ClosestPoint closest_point_triangle(
        float3 p, float3 a, float3 b, float3 c) {
    float3 ba = b - a, pa = p - a;
    float3 cb = c - b, pb = p - b;
    float3 ac = a - c, pc = p - c;
    float3 nor = cross(ba, ac);

    float t0 = clamp(dot(ba, pa) / dot(ba, ba), 0.0, 1.0);
    float t1 = clamp(dot(cb, pb) / dot(cb, cb), 0.0, 1.0);
    float t2 = clamp(dot(ac, pc) / dot(ac, ac), 0.0, 1.0);

    float3 q0 = a + ba * t0;
    float3 q1 = b + cb * t1;
    float3 q2 = c + ac * t2;

    if (sign(dot(cross(ba, nor), pa)) +
        sign(dot(cross(cb, nor), pb)) +
        sign(dot(cross(ac, nor), pc)) < 2.0) {

        float d0 = dot(p - q0, p - q0);
        float d1 = dot(p - q1, p - q1);
        float d2 = dot(p - q2, p - q2);

        if (d0 < d1 && d0 < d2)
            return {q0, float3(1.0 - t0, t0, 0.0)};
        if (d1 < d2)
            return {q1, float3(0.0, 1.0 - t1, t1)};
        return {q2, float3(t2, 0.0, 1.0 - t2)};
    }

    float inv_nor2 = 1.0 / dot(nor, nor);
    float3 q = p - nor * (dot(nor, pa) * inv_nor2);

    float wb = dot(cross(pa, ac), nor) * inv_nor2;
    float wc = dot(cross(pa, ba), nor) * inv_nor2;
    return {q, float3(1.0 - wb - wc, wb, wc)};
}


[shader("compute")]
[numthreads(64, 1, 1)]
void detect_collision(uint tid: SV_DispatchThreadID,
                      StructuredBuffer<float3> positions,
                      StructuredBuffer<float> inv_masses,
                      StructuredBuffer<float4> planes,
                      StructuredBuffer<float4> spheres,
                      StructuredBuffer<float3> mesh_vertices,
                      StructuredBuffer<float3> mesh_vertex_normals,
                      StructuredBuffer<uint3> mesh_triangles,
                      StructuredBuffer<BVHNode> bvh_nodes,
                      RWStructuredBuffer<float4> contact_planes,
                      uniform uint num_particles,
                      uniform uint num_planes,
                      uniform uint num_spheres,
                      uniform uint num_bvh_nodes,
                      uniform float collision_distance,
                      uniform float contact_margin) {
    if (tid >= num_particles) {
        return;
    }
    if (inv_masses[tid] == 0) return;

    float min_distance = contact_margin + collision_distance;

    float4 contact_plane = float4(0);
    // loop through every plane and sphere
    // and find the one that is the closest
    float3 point = positions[tid];
    int closest_shape = -1;
    // 0 = sphere, 1 = plane, 2 = trimesh
    int closest_shape_type = -1;

    // sphere SDF = length(point - center) - radius
    for (uint i = 0; i < num_spheres; i++) {
        float3 sphere_center = spheres[i].xyz;
        float radius = spheres[i].w;
        float sphere_sdf = length(point - sphere_center) - radius;
        if (sphere_sdf < min_distance) {
            min_distance = sphere_sdf;
            closest_shape = i;
            closest_shape_type = 0;
        }
    }

    for (uint i = 0; i < num_planes; i++) {
        float4 plane = planes[i];
        float3 n = plane.xyz;
        float d = plane.w;
        float plane_sdf = dot(n, point) - d;
        if (plane_sdf < min_distance) {
            min_distance = plane_sdf;
            closest_shape = i;
            closest_shape_type = 1;
        }
    }

    // copied from 3.6: instead of looping through each triangle in mesh,
    // use the BVH to find relevant triangles
    int bvh_index = 0;
    // the root's skip pointer is set to the "end" of the flattened BVH array
    int end_index = bvh_nodes[bvh_index].next_index;
    BVHNode cur_node;
    while (bvh_index < end_index) {
        cur_node = bvh_nodes[bvh_index];
        bool intersects = point_aabb_distance(point, cur_node.bbox_min, cur_node.bbox_max) < min_distance;

        if (!intersects) {
            // if we don't intersect, go to the node designated by this node's skip pointer
            bvh_index = cur_node.next_index;
            continue;
        }
        // if we do intersect, move forward 1 index in the flattened DFS order
        else bvh_index++;

        // if we hit a leaf node, it has triangles which we can check for intersection with
        // note that one ray can hit multiple leaf nodes,
        // which is why we don't exit early even if we hit a leaf node
        if (cur_node.is_leaf) {
            for (int j = cur_node.triangle_begin; j < cur_node.triangle_end; j++) {
                uint3 tri = mesh_triangles[j];


                // get vertices
                float3 p0 = mesh_vertices[tri.x];
                float3 p1 = mesh_vertices[tri.y];
                float3 p2 = mesh_vertices[tri.z];

                float3 n0 = mesh_vertex_normals[tri.x];
                float3 n1 = mesh_vertex_normals[tri.y];
                float3 n2 = mesh_vertex_normals[tri.z];

                ClosestPoint cp = closest_point_triangle(point, p0, p1, p2);

                float3 b0 = cp.bary.x;
                float3 b1 = cp.bary.y;
                float3 b2 = cp.bary.z;

                float tri_unsigned_distance = length(cp.position - point);
                if (tri_unsigned_distance < contact_margin + collision_distance) {
                    // now we get the signed distance
                    // and check it against min_distance
                    
                    // Face normal
                    float3 ng = normalize(cross(p1 - p0, p2 - p0));
                    // Phong normal
                    float3 ns = normalize(b0 * n0 + b1 * n1 + b2 * n2);
                    if (dot(ng, ns) < 0.0) {
                        ng = -ng;
                    }

                    float4 plane = float4(ng, dot(ng, cp.position));
                    float3 n = plane.xyz;
                    float d = plane.w;
                    float plane_sdf = dot(n, point) - d;
                    if (plane_sdf < min_distance) {
                        min_distance = plane_sdf;
                        closest_shape = j;
                        closest_shape_type = 2;

                        // easier to just set the contact plane here
                        contact_plane = plane;
                    }
                }
            }
        }
    }


    if (closest_shape >= 0) {
        if (closest_shape_type == 0) {
            float3 sphere_center = spheres[closest_shape].xyz;
            float3 unit_normal = normalize(point - sphere_center);
            contact_plane = float4(unit_normal, dot(unit_normal, sphere_center) + spheres[closest_shape].w);
        }
        else if (closest_shape_type == 1) {
            contact_plane = planes[closest_shape];
        }
        // if it was a triangle, contact plane is already set
        
        contact_plane.w += collision_distance;
    }

    contact_planes[tid] = contact_plane;
}
