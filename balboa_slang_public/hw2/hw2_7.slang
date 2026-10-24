StructuredBuffer<float3> vertices;
StructuredBuffer<float3> vertex_normals;
StructuredBuffer<float2> vertex_uvs;
uniform float4x4 MVP;
uniform float4x4 model_matrix;
uniform float3x3 normal_matrix; // inverse transpose of the top-left 3x3 above
uniform float3 light_dir;
uniform float3 light_color;
uniform float3 camera_position;
uniform float3 Ks;
uniform float exponent;
Texture2D<float4> Kd_texture;
SamplerState Kd_sampler;

struct VertexOutput {
    float4 position : SV_Position;
    float3 world_position : TEXCOORD0;
    float3 world_normal : TEXCOORD1;
    float2 uv : TEXCOORD2;
};

[shader("vertex")]
VertexOutput vertex_main(uint vid: SV_VertexID) {
    VertexOutput output;
    // HW 2.6: your code here
    float4 vertex = float4(vertices[vid], 1.0);
    float4 vertex_world = mul(model_matrix, vertex);
    vertex = mul(MVP, vertex);
    output.position = vertex;
    output.world_position = float3(vertex_world.x, vertex_world.y, vertex_world.z);
    output.world_normal = vertex_normals[vid];
    output.uv = vertex_uvs[vid];
    return output;
}

[shader("fragment")]
float4 fragment_main(VertexOutput input) : SV_Target {
    // HW 2.6: your code here
    // float4 p_raw = mul(MVP, float4(input.world_position, 1));
    // float3 p = float3(p_raw.x, p_raw.y, p_raw.z);
    // float3 p = float3(input.position.x, input.position.y, input.position.z);
    float3 p = input.world_position;
    float3 l = light_dir;
    float3 v = normalize(camera_position - p);
    float3 E = light_color;

    // get surface normal
    float3x3 N = normal_matrix;
    float3 n = mul(N, normalize(input.world_normal));
    // ambient
    float3 Kd = Kd_texture.Sample(Kd_sampler, input.uv).rgb;
    float3 Ca = 0.2 * Kd;

    // diffuse
    float3 Cd = (Kd * E) * (max(0, dot(n, l)));

    // specular
    float3 r = reflect(-l, n);
    float3 Cs = float3(0);
    if (dot(n, l) > 0) Cs = (Ks * E) * pow(max(0, dot(r, v)), exponent);
    float3 C = Ca + Cd + Cs;

    return float4(C, 1.0);
}
