[shader("compute")]
[numthreads(64, 1, 1)]
void compute_main(uint tid : SV_DispatchThreadID,
                  RWStructuredBuffer<float3> positions,
                  RWStructuredBuffer<float3> velocities,
                  uniform uint num_particles,
                  // time step size
                  uniform float dt) {
    if (tid >= num_particles) {
        return;
    }
    // TODO: HW 4.1. Your code below.

    float3 gravity = float3(0, -9.8, 0);

    for (int i = 0; i < num_particles; i++) {
        float3 position = positions[i];
        float3 velocity = velocities[i];
        position += velocity * dt;

        if (position.y < -0.97) velocity.y *= -1;
        else velocity += gravity * dt;

        positions[i] = position;
        velocities[i] = velocity;
    }
}
