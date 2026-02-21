#![allow(clippy::too_many_arguments)]

pub mod engine;
pub mod renderer;
pub mod window;

use engine::Engine;

// ===========================================================================
// Native FFI exports (extern "C" for Ruby FFI)
// ===========================================================================
#[cfg(not(target_arch = "wasm32"))]
pub mod native_ffi {
    use super::*;
    use std::ffi::{CStr, CString};
    use std::os::raw::c_char;

    thread_local! {
        static LAST_ERROR: std::cell::RefCell<Option<CString>> = const { std::cell::RefCell::new(None) };
    }

    fn set_last_error(msg: &str) {
        LAST_ERROR.with(|cell| { *cell.borrow_mut() = CString::new(msg).ok(); });
    }

    fn ok_or_err<T>(result: Result<T, String>, success_val: i32) -> i32 {
        match result {
            Ok(_) => success_val,
            Err(e) => { set_last_error(&e); -1 }
        }
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_init_headless(width: u32, height: u32) -> i32 {
        let _ = env_logger::try_init();
        ok_or_err(Engine::init_headless(width, height), 0)
    }

    /// # Safety
    /// `title` must be a valid, non-null, null-terminated C string.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_engine_init(width: u32, height: u32, title: *const c_char) -> i32 {
        let _ = env_logger::try_init();
        let title = CStr::from_ptr(title).to_str().unwrap_or("dama");
        ok_or_err(Engine::init_windowed(width, height, title), 0)
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_shutdown() -> i32 { ok_or_err(Engine::shutdown(), 0) }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_poll_events() -> i32 {
        let is_windowed = Engine::with(|e| Ok(e.window_state().is_some())).unwrap_or(false);
        if !is_windowed { return 0; }
        match Engine::pump_events() {
            Ok(true) => 1, Ok(false) => 0,
            Err(e) => { set_last_error(&e); -1 }
        }
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_begin_frame() -> i32 { ok_or_err(Engine::with(|e| e.begin_frame()), 0) }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_end_frame() -> i32 { ok_or_err(Engine::with(|e| e.end_frame()), 0) }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_delta_time() -> f64 { Engine::with(|e| Ok(e.delta_time())).unwrap_or(0.0) }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_frame_count() -> u64 { Engine::with(|e| Ok(e.frame_count())).unwrap_or(0) }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_engine_last_error() -> *const c_char {
        LAST_ERROR.with(|cell| cell.borrow().as_ref().map(|s| s.as_ptr()).unwrap_or(std::ptr::null()))
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_render_clear(r: f32, g: f32, b: f32, a: f32) -> i32 {
        ok_or_err(Engine::with(|e| e.renderer().clear(r, g, b, a)), 0)
    }

    /// # Safety
    /// `vertex_data` must point to at least `vertex_count * 8` valid `f32` values.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_render_vertices(vertex_data: *const f32, vertex_count: u32) -> i32 {
        let count = vertex_count as usize;
        let floats = std::slice::from_raw_parts(vertex_data, count * 8);
        ok_or_err(Engine::with(|e| { e.renderer().submit_vertices(floats, count); Ok(()) }), 0)
    }

    /// # Safety
    /// `text` must be a valid, non-null, null-terminated C string.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_render_text(text: *const c_char, x: f32, y: f32, size: f32, r: f32, g: f32, b: f32, a: f32) -> i32 {
        let text_str = CStr::from_ptr(text).to_str().map_err(|e| format!("Invalid UTF-8: {e}"));
        match text_str {
            Ok(s) => ok_or_err(Engine::with(|e| { e.renderer().draw_text(s, x, y, size, r, g, b, a, None); Ok(()) }), 0),
            Err(e) => { set_last_error(&e); -1 }
        }
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_render_set_texture(handle: u64) -> i32 {
        ok_or_err(Engine::with(|e| { e.renderer().set_current_texture(handle); Ok(()) }), 0)
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_input_key_pressed(key_code: u32) -> i32 {
        Engine::with(|e| Ok(e.window_state().map(|ws| ws.is_key_pressed(key_code)).unwrap_or(false))).unwrap_or(false) as i32
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn dama_input_key_just_pressed(key_code: u32) -> i32 {
        Engine::with(|e| Ok(e.window_state().map(|ws| ws.is_key_just_pressed(key_code)).unwrap_or(false))).unwrap_or(false) as i32
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn dama_input_key_just_released(key_code: u32) -> i32 {
        Engine::with(|e| Ok(e.window_state().map(|ws| ws.is_key_just_released(key_code)).unwrap_or(false))).unwrap_or(false) as i32
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn dama_input_mouse_x() -> f32 {
        Engine::with(|e| Ok(e.window_state().map(|ws| ws.mouse_x()).unwrap_or(0.0))).unwrap_or(0.0)
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn dama_input_mouse_y() -> f32 {
        Engine::with(|e| Ok(e.window_state().map(|ws| ws.mouse_y()).unwrap_or(0.0))).unwrap_or(0.0)
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn dama_input_mouse_button_pressed(button: u32) -> i32 {
        Engine::with(|e| Ok(e.window_state().map(|ws| ws.is_mouse_button_pressed(button)).unwrap_or(false))).unwrap_or(false) as i32
    }

    /// # Safety
    /// `output_path` must be a valid, non-null, null-terminated C string.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_debug_screenshot(output_path: *const c_char) -> i32 {
        let path = CStr::from_ptr(output_path).to_str().map_err(|e| format!("Invalid UTF-8: {e}"));
        match path {
            Ok(path) => ok_or_err(Engine::with(|e| e.screenshot(path)), 0),
            Err(e) => { set_last_error(&e); -1 }
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub use native_ffi::*;
