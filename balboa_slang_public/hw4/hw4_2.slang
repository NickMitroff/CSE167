[shader("compute")]
[numthreads(64, 1, 1)]
void predict(uint tid : SV_DispatchThreadID,
             // Updated position
             RWStructuredBuffer<float3> positions,
             // Store the position before update
             RWStructuredBuffer<float3> old_positions,
             RWStructuredBuffer<float3> velocities,
             StructuredBuffer<float> inv_masses,
             uniform uint num_particles,
             // time step size
             uniform float dt) {
    if (tid >= num_particles) {
        return;
    }
    if (inv_masses[tid] == 0) return;
    // float3 gravity = float3(0);
    float3 gravity = float3(0, -9.8, 0);

    float3 position = positions[tid];
    // 
    old_positions[tid] = position;
    float3 velocity = velocities[tid];

    velocity += gravity * dt;
    position += velocity * dt;

    positions[tid] = position;
    velocities[tid] = velocity;

}

[shader("compute")]
[numthreads(64, 1, 1)]
void project_constraints(uint tid : SV_DispatchThreadID,
                         StructuredBuffer<float3> positions_in,
                         RWStructuredBuffer<float3> positions_out,
                         StructuredBuffer<float> inv_masses,
                         StructuredBuffer<float> rest_lengths,
                         uniform uint num_particles) {
    if (tid >= num_particles) {
        return;
    }
    float3 correction = float3(0);
    int num_neighbors = 0;
    if (inv_masses[tid] == 0) return;
    // "w" in the equations is inverse mass
    if (tid > 0) {
        // apply correction from above neighbor
        int i = tid;
        int j = tid - 1;
        num_neighbors++;
        correction += get_correction(i, j, positions_in, inv_masses, rest_lengths);        
    }

    if (tid < num_particles - 1) {
        // apply correction from below neighbor
        int i = tid;
        int j = tid + 1;
        num_neighbors++;
        correction += get_correction(i, j, positions_in, inv_masses, rest_lengths);
    }
    positions_out[tid] = positions_in[tid] + correction / num_neighbors;
}

float3 get_correction(uint i, uint j,
                      StructuredBuffer<float3> positions_in,
                      StructuredBuffer<float> inv_masses,
                      StructuredBuffer<float> rest_lengths) {
    float3 d = positions_in[j] - positions_in[i];
    float w_i = inv_masses[i];
    float w_j = inv_masses[j];

    float weight_frac = w_i / (w_i + w_j);
    float l_ij = rest_lengths[min(i, j)];
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
                     // time step size
                     uniform float dt) {
    if (tid >= num_particles) {
        return;
    }
    if (inv_masses[tid] == 0) return;
    float3 velocity = (positions[tid] - old_positions[tid]) / dt;

    if (old_positions[tid].y < -0.97) velocity.y *= -1;

    velocities[tid] = velocity;
}
