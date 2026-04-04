// Ball trail shader: creates a color-cycling effect on the ball.
// Shifts hue over time using the engine's time uniform.

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex_color = textureSample(t_diffuse, s_diffuse, in.uv);
    let t = u.time * 2.0;
    let color_shift = vec4<f32>(
        sin(t) * 0.3 + 0.7,
        sin(t + 2.094) * 0.3 + 0.7,
        sin(t + 4.189) * 0.3 + 0.7,
        1.0
    );
    return tex_color * in.color * color_shift;
}
