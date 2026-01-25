use std::ffi::CString;

#[test]
fn test_init_headless_and_shutdown() {
    let result = dama_native::dama_engine_init_headless(320, 240);
    assert_eq!(result, 0);
    let result = dama_native::dama_engine_shutdown();
    assert_eq!(result, 0);
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
