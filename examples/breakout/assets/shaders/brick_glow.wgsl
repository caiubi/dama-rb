// Brick gem shader: radial center glow + animated shine sweep.
// Creates a "lit from within" crystal look where the center
// is brighter than the edges, with a periodic light sweep.

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex_color = textureSample(t_diffuse, s_diffuse, in.uv);

    // Radial glow: center of brick is brighter, edges are darker.
    // This is the key "gem" effect — makes bricks look 3D and luminous.
    let center = vec2<f32>(0.5, 0.5);
    let dist = length(in.uv - center);
    let radial = 1.3 - dist * 0.9;

    // Animated shine sweep — a bright diagonal band that moves across
    let diagonal = in.uv.x + in.uv.y;
    let sweep = fract(u.time * 0.4) * 3.5 - 0.75;
    let shine = smoothstep(0.5, 0.0, abs(diagonal - sweep)) * 0.6;

    let brightness = radial + shine;
    return tex_color * in.color * vec4<f32>(brightness, brightness, brightness, 1.0);
}
