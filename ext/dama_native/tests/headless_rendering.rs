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
