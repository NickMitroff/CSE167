[shader("compute")]
[numthreads(64, 1, 1)]
void project_constraints(uint tid : SV_DispatchThreadID,
                         StructuredBuffer<float3> positions_in,
                         RWStructuredBuffer<float3> positions_out,
                         StructuredBuffer<float> inv_masses,
                         uniform int2 grid_size,
                         uniform float2 spacing) {
    if (tid >= grid_size.x * grid_size.y) {
        return;
    }
    if (inv_masses[tid] == 0) return;
    // TODO: HW 4.3. Your code below.

    uint x = tid % grid_size.x;
    uint y = tid / grid_size.x;

    float3 correction = float3(0);
    int num_neighbors = 0;

    bool has_left_neighbor = x > 0;
    bool has_right_neighbor = x < grid_size.x - 1;
    bool has_bottom_neighbor = y > 0;
    bool has_top_neighbor = y < grid_size.y - 1;

    bool has_left_bend_neighbor = x > 1;
    bool has_right_bend_neighbor = x < grid_size.x - 2;
    bool has_bottom_bend_neighbor = y > 1;
    bool has_top_bend_neighbor = y < grid_size.y - 2;
    uint2 root_pos = uint2(x, y);

    // structural constraint (x+1,y) (x-1,y) (x,y+1) (x,y-1)
    if (has_left_neighbor) {
        num_neighbors++;
        int2 offset = int2(-1, 0);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_right_neighbor) {
        num_neighbors++;
        int2 offset = int2(1, 0);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_top_neighbor) {
        num_neighbors++;
        int2 offset = int2(0, 1);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_bottom_neighbor) {
        num_neighbors++;
        int2 offset = int2(0, -1);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }

    // shearing constraint (x+1,y+1) (x+1,y-1) (x-1,y-1) (x-1,y+1)
    if (has_right_neighbor && has_top_neighbor) {
        num_neighbors++;
        int2 offset = int2(1, 1);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_right_neighbor && has_bottom_neighbor) {
        num_neighbors++;
        int2 offset = int2(1, -1);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_left_neighbor && has_bottom_neighbor) {
        num_neighbors++;
        int2 offset = int2(-1, -1);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_left_neighbor && has_top_neighbor) {
        num_neighbors++;
        int2 offset = int2(-1, 1);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }

    // bending constraint (x+2,y) (x-2,y) (x,y+2) (x,y-2)
    if (has_left_bend_neighbor) {
        num_neighbors++;
        int2 offset = int2(-2, 0);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_right_bend_neighbor) {
        num_neighbors++;
        int2 offset = int2(2, 0);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_top_bend_neighbor) {
        num_neighbors++;
        int2 offset = int2(0, 2);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }
    if (has_bottom_bend_neighbor) {
        num_neighbors++;
        int2 offset = int2(0, -2);
        correction += get_correction(root_pos, offset, positions_in, inv_masses, grid_size, spacing);
    }

    if (num_neighbors > 0) positions_out[tid] = positions_in[tid] + correction / num_neighbors;
}

float3 get_correction(uint2 root_pos, int2 offset,
                      StructuredBuffer<float3> positions_in,
                      StructuredBuffer<float> inv_masses,
                      uniform int2 grid_size,
                      uniform float2 spacing) {
    uint2 neighbor_pos = root_pos + offset;
    int i = root_pos.y * grid_size.x + root_pos.x;
    int j = neighbor_pos.y * grid_size.x + neighbor_pos.x;
    float3 p0 = positions_in[i];
    float3 p1 = positions_in[j];
    float3 d = p1 - p0;
    float w_i = inv_masses[i];
    float w_j = inv_masses[j];

    float weight_frac = w_i / (w_i + w_j);
    float l_ij = length(float2(spacing.x * abs(neighbor_pos.x - root_pos.x) ,
        spacing.y * abs(neighbor_pos.y - root_pos.y)));
    return weight_frac * (length(d) - l_ij) * d / length(d);
}