use std::ffi::CString;

#[test]
fn test_init_headless_and_shutdown() {
    let result = dama_native::dama_engine_init_headless(320, 240);
    assert_eq!(result, 0);
    let result = dama_native::dama_engine_shutdown();
    assert_eq!(result, 0);
}

#[test]
fn test_frame_lifecycle() {
    dama_native::dama_engine_init_headless(320, 240);
    assert_eq!(dama_native::dama_engine_begin_frame(), 0);
    assert_eq!(dama_native::dama_engine_end_frame(), 0);
    assert_eq!(dama_native::dama_engine_frame_count(), 1);
    dama_native::dama_engine_shutdown();
}

#[test]
fn test_clear_and_screenshot() {
    dama_native::dama_engine_init_headless(64, 64);
    dama_native::dama_render_clear(1.0, 0.0, 0.0, 1.0);

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("clear_red.png");
    let c_path = CString::new(path.to_str().unwrap()).unwrap();
    unsafe { dama_native::dama_debug_screenshot(c_path.as_ptr()) };

    let img = image::open(&path).unwrap().to_rgba8();
    let pixel = img.get_pixel(0, 0).0;
    assert!(pixel[0] > 200, "red channel: {}", pixel[0]);
    assert!(pixel[1] < 30);

    dama_native::dama_engine_shutdown();
}

/// Submit a green triangle as 8-float vertices (with UV=0,0).
#[test]
fn test_render_vertices_triangle() {
    dama_native::dama_engine_init_headless(100, 100);
    dama_native::dama_render_clear(0.0, 0.0, 0.0, 1.0);
    dama_native::dama_engine_begin_frame();

    // 3 vertices × 8 floats: [x, y, r, g, b, a, u, v]
    let vertices: [f32; 24] = [
        50.0, 10.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0,
        10.0, 90.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0,
        90.0, 90.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0,
    ];
    assert_eq!(unsafe { dama_native::dama_render_vertices(vertices.as_ptr(), 3) }, 0);
    dama_native::dama_engine_end_frame();

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("tri.png");
    let c_path = CString::new(path.to_str().unwrap()).unwrap();
    unsafe { dama_native::dama_debug_screenshot(c_path.as_ptr()) };

    let img = image::open(&path).unwrap().to_rgba8();
    let center = img.get_pixel(50, 50).0;
    assert!(center[1] > 200, "green: {}", center[1]);

    dama_native::dama_engine_shutdown();
}

/// Submit a blue rect as 6 vertices with 8-float format.
#[test]
fn test_render_vertices_rect() {
    dama_native::dama_engine_init_headless(100, 100);
    dama_native::dama_render_clear(0.0, 0.0, 0.0, 1.0);
    dama_native::dama_engine_begin_frame();

    let b = [0.0f32, 0.0, 1.0, 1.0, 0.0, 0.0]; // blue + uv(0,0)
    let vertices: Vec<f32> = vec![
        20.0, 20.0, b[0], b[1], b[2], b[3], b[4], b[5],
        80.0, 20.0, b[0], b[1], b[2], b[3], b[4], b[5],
        20.0, 80.0, b[0], b[1], b[2], b[3], b[4], b[5],
        80.0, 20.0, b[0], b[1], b[2], b[3], b[4], b[5],
        80.0, 80.0, b[0], b[1], b[2], b[3], b[4], b[5],
        20.0, 80.0, b[0], b[1], b[2], b[3], b[4], b[5],
    ];
    unsafe { dama_native::dama_render_vertices(vertices.as_ptr(), 6) };
    dama_native::dama_engine_end_frame();

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("rect.png");
    let c_path = CString::new(path.to_str().unwrap()).unwrap();
    unsafe { dama_native::dama_debug_screenshot(c_path.as_ptr()) };

    let img = image::open(&path).unwrap().to_rgba8();
    assert!(img.get_pixel(50, 50).0[2] > 200);
    assert!(img.get_pixel(5, 5).0[2] < 10);

    dama_native::dama_engine_shutdown();
}

#[test]
fn test_render_text_and_screenshot() {
    dama_native::dama_engine_init_headless(200, 100);
    dama_native::dama_render_clear(0.0, 0.0, 0.0, 1.0);
    dama_native::dama_engine_begin_frame();
    let text = CString::new("Hello").unwrap();
    assert_eq!(unsafe { dama_native::dama_render_text(text.as_ptr(), 10.0, 10.0, 24.0, 1.0, 1.0, 1.0, 1.0) }, 0);
    dama_native::dama_engine_end_frame();

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("text.png");
    let c_path = CString::new(path.to_str().unwrap()).unwrap();
    unsafe { dama_native::dama_debug_screenshot(c_path.as_ptr()) };

    let img = image::open(&path).unwrap().to_rgba8();
    assert!(img.pixels().any(|p| p.0[0] > 30 || p.0[1] > 30 || p.0[2] > 30));

    dama_native::dama_engine_shutdown();
}

#[test]
fn test_poll_events_headless() {
    dama_native::dama_engine_init_headless(64, 64);
    assert_eq!(dama_native::dama_engine_poll_events(), 0);
    dama_native::dama_engine_shutdown();
}

#[test]
fn test_delta_time_and_frame_count() {
    dama_native::dama_engine_init_headless(64, 64);
    assert_eq!(dama_native::dama_engine_frame_count(), 0);
    dama_native::dama_engine_begin_frame();
    dama_native::dama_engine_end_frame();
    assert_eq!(dama_native::dama_engine_frame_count(), 1);
    let dt = dama_native::dama_engine_delta_time();
    assert!((0.0..1.0).contains(&dt));
    dama_native::dama_engine_shutdown();
}

/// Load a PNG texture from bytes, render a textured quad, verify pixels.
#[test]
fn test_load_texture_and_render_sprite() {
    dama_native::dama_engine_init_headless(100, 100);
    dama_native::dama_render_clear(0.0, 0.0, 0.0, 1.0);

    // Create a 2x2 PNG in memory: red, green, blue, white pixels.
    let mut img = image::RgbaImage::new(2, 2);
    img.put_pixel(0, 0, image::Rgba([255, 0, 0, 255]));
    img.put_pixel(1, 0, image::Rgba([0, 255, 0, 255]));
    img.put_pixel(0, 1, image::Rgba([0, 0, 255, 255]));
    img.put_pixel(1, 1, image::Rgba([255, 255, 255, 255]));
    let mut png_bytes: Vec<u8> = Vec::new();
    img.write_to(&mut std::io::Cursor::new(&mut png_bytes), image::ImageFormat::Png).unwrap();

    let handle = unsafe { dama_native::dama_asset_load_texture(png_bytes.as_ptr(), png_bytes.len() as u32) };
    assert!(handle > 0, "texture handle should be > 0");

    dama_native::dama_engine_begin_frame();
    dama_native::dama_render_set_texture(handle);

    let vertices: Vec<f32> = vec![
        0.0,   0.0,   1.0, 1.0, 1.0, 1.0, 0.0, 0.0,
        100.0, 0.0,   1.0, 1.0, 1.0, 1.0, 1.0, 0.0,
        0.0,   100.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0,
        100.0, 0.0,   1.0, 1.0, 1.0, 1.0, 1.0, 0.0,
        100.0, 100.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        0.0,   100.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0,
    ];
    unsafe { dama_native::dama_render_vertices(vertices.as_ptr(), 6) };

    dama_native::dama_render_set_texture(0);
    dama_native::dama_engine_end_frame();

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("sprite.png");
    let c_path = CString::new(path.to_str().unwrap()).unwrap();
    unsafe { dama_native::dama_debug_screenshot(c_path.as_ptr()) };

    let result = image::open(&path).unwrap().to_rgba8();
    let tl = result.get_pixel(25, 25).0;
    assert!(tl[0] > 150, "top-left should be red-ish: {:?}", tl);

    dama_native::dama_asset_unload_texture(handle);
    dama_native::dama_engine_shutdown();
}
