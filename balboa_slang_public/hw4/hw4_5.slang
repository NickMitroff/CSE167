[shader("compute")]
[numthreads(64, 1, 1)]
void detect_collision(uint tid : SV_DispatchThreadID,
                      StructuredBuffer<float3> positions,
                      StructuredBuffer<float> inv_masses,
                      // Plane stores (a, b, c, d) where ax+by+cz=d
                      // a, b, c are normalized to a unit 3D vector
                      StructuredBuffer<float4> planes,
                      // Sphere stores center (xyz) + radius (w)
                      StructuredBuffer<float4> spheres,
                      // Contact plane: dot(n, x) = d, with unit normal n
                      // Set to (0, 0, 0, 0) if there is no contact
                      RWStructuredBuffer<float4> contact_planes,
                      uniform uint num_particles,
                      uniform uint num_planes,
                      uniform uint num_spheres,
                      // How much should we shift the generated 
                      // contact plane in the normal direction
                      // (similar to how we shifted the floor by 0.03
                      //  earlier)
                      uniform float collision_distance,
                      // When the signed distance function
                      // evaluates to a value below 
                      // contact_margin + collision_distance
                      // (even when it's positive), we count the
                      // particle to be inside the collider and
                      // a collision event has happened.
                      uniform float contact_margin) {
    if (tid >= num_particles) {
        return;
    }
    if (inv_masses[tid] == 0) return;

    float min_distance = contact_margin + collision_distance;

    // loop through every plane and sphere
    // and find the one that is the closest
    float3 point = positions[tid];
    int closest_shape = -1;
    bool closest_shape_is_sphere = true;

    // sphere SDF = length(point - center) - radius
    for (uint i = 0; i < num_spheres; i++) {
        float3 sphere_center = spheres[i].xyz;
        float radius = spheres[i].w;
        float sphere_sdf = length(point - sphere_center) - radius;
        if (sphere_sdf < min_distance) {
            min_distance = sphere_sdf;
            closest_shape = i;
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
            closest_shape_is_sphere = false;
        }
    }

    float4 contact_plane = float4(0);

    if (closest_shape >= 0) {
        if (closest_shape_is_sphere) {
            float3 sphere_center = spheres[closest_shape].xyz;
            float3 unit_normal = normalize(point - sphere_center);
            contact_plane = float4(unit_normal, dot(unit_normal, point));
        }
        else {
            contact_plane = planes[closest_shape];
        }
        contact_plane.w += collision_distance;
    }

    contact_planes[tid] = contact_plane;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void project_constraints(uint tid : SV_DispatchThreadID,
                         StructuredBuffer<float3> positions_in,
                         StructuredBuffer<float3> old_positions,
                         RWStructuredBuffer<float3> positions_out,
                         StructuredBuffer<float> inv_masses,
                         StructuredBuffer<uint> row_ptr,
                         StructuredBuffer<uint> neighbors,
                         StructuredBuffer<float> neighbor_rest,
                         // Contact plane: dot(n, x) = d, with unit normal n
                         StructuredBuffer<float4> contact_planes,
                         uniform uint num_particles,
                         uniform float static_friction,
                         uniform float kinetic_friction) {
    if (tid >= num_particles) {
        return;
    }
    if (inv_masses[tid] == 0) return;
    float3 next_position = positions_in[tid];
    float num_neighbors = row_ptr[tid + 1] - row_ptr[tid];
    float3 correction = float3(0);
    for (uint i = row_ptr[tid]; i < row_ptr[tid + 1]; i++) {
        correction += get_correction(tid, neighbors[i], i, positions_in, inv_masses, neighbor_rest);
    }

    if (num_neighbors > 0) next_position = positions_in[tid] + correction / num_neighbors;

    float4 plane = contact_planes[tid];
    // if contact plane is not (0,0,0,0), then handle collision
    if (plane.x != 0 || plane.y != 0 || plane.z != 0 || plane.w != 0) {

        // apply contact constraint
        float3 n = plane.xyz;
        float3 point = next_position;
        float d = plane.w;

        // penetration = signed distance between point and plane using n
        float penetration = dot(n, point) - d;
        if (penetration < 0) next_position += -n * penetration;
        // apply friction in tangential direction
    }


    positions_out[tid] = next_position;
}

float3 get_correction(uint i, uint j, uint neighbor_index,
                      StructuredBuffer<float3> positions_in,
                      StructuredBuffer<float> inv_masses,
                      StructuredBuffer<float> neighbor_rest) {
    float3 d = positions_in[j] - positions_in[i];
    float w_i = inv_masses[i];
    float w_j = inv_masses[j];

    float weight_frac = w_i / (w_i + w_j);
    float l_ij = neighbor_rest[neighbor_index];
    return weight_frac * (length(d) - l_ij) * d / length(d);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void update_velocity(uint tid : SV_DispatchThreadID,
                     RWStructuredBuffer<float3> positions,
                     StructuredBuffer<float3> old_positions,
                     RWStructuredBuffer<float3> velocities,
                     StructuredBuffer<float> inv_masses,
                     uniform uint num_particles,
                     uniform float dt) {
    if (tid >= num_particles) {
        return;
    }
    if (inv_masses[tid] == 0) return;

    // this is all we need in update velocity
    // friction is applied by correcting position, not velocity

    
    float3 position = positions[tid];
    float3 velocity = (position - old_positions[tid]) / dt;

    velocities[tid] = velocity;
}
