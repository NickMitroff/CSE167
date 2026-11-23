[shader("compute")]
[numthreads(64, 1, 1)]
void project_constraints(uint tid : SV_DispatchThreadID,
                         StructuredBuffer<float3> positions_in,
                         RWStructuredBuffer<float3> positions_out,
                         StructuredBuffer<float> inv_masses,
                         // The CSR matrix data structure
                         StructuredBuffer<uint> row_ptr,
                         StructuredBuffer<uint> neighbors,
                         // Rest lengths of the neighbor edges
                         StructuredBuffer<float> neighbor_rest,
                         uniform uint num_particles) {
    if (tid >= num_particles) {
        return;
    }
    if (inv_masses[tid] == 0) return;
    float num_neighbors = row_ptr[tid + 1] - row_ptr[tid];
    float3 correction = float3(0);
    for (uint i = row_ptr[tid]; i < row_ptr[tid + 1]; i++) {
        correction += get_correction(tid, neighbors[i], i, positions_in, inv_masses, neighbor_rest);
    }

    if (num_neighbors > 0) positions_out[tid] = positions_in[tid] + correction / num_neighbors;
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
