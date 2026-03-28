#![allow(clippy::too_many_arguments)]

pub mod engine;
pub mod renderer;
pub mod window;

#[cfg(not(target_arch = "wasm32"))]
pub mod audio;

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
    /// `command_data` must point to at least `float_count` valid `f32` values.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_render_commands(command_data: *const f32, float_count: u32) -> i32 {
        let count = float_count as usize;
        let commands = std::slice::from_raw_parts(command_data, count);
        ok_or_err(Engine::with(|e| { e.renderer().submit_commands(commands); Ok(()) }), 0)
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_render_set_texture(handle: u64) -> i32 {
        ok_or_err(Engine::with(|e| { e.renderer().set_current_texture(handle); Ok(()) }), 0)
    }

    /// # Safety
    /// `data` must point to at least `length` valid bytes of PNG image data.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_asset_load_texture(data: *const u8, length: u32) -> u64 {
        let bytes = std::slice::from_raw_parts(data, length as usize);
        match Engine::with(|e| e.renderer().load_texture(bytes)) {
            Ok(handle) => handle,
            Err(e) => { set_last_error(&e); 0 }
        }
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_asset_unload_texture(handle: u64) -> i32 {
        ok_or_err(Engine::with(|e| { e.renderer().unload_texture(handle); Ok(()) }), 0)
    }

    // --- Shader management ---

    /// # Safety
    /// `source` must be a valid null-terminated C string, or null (null is handled gracefully).
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_shader_load(source: *const c_char) -> u64 {
        if source.is_null() {
            set_last_error("Null shader source pointer");
            return 0;
        }
        let source_str = match CStr::from_ptr(source).to_str() {
            Ok(s) => s,
            Err(e) => { set_last_error(&format!("Invalid UTF-8 in shader source: {e}")); return 0; }
        };
        match Engine::with(|e| e.renderer().load_shader(source_str)) {
            Ok(handle) => handle,
            Err(e) => { set_last_error(&e); 0 }
        }
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_shader_unload(handle: u64) -> i32 {
        ok_or_err(Engine::with(|e| { e.renderer().unload_shader(handle); Ok(()) }), 0)
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_render_set_shader(handle: u64) -> i32 {
        ok_or_err(Engine::with(|e| { e.renderer().set_current_shader(handle); Ok(()) }), 0)
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

    /// # Safety
    /// `text` and `font_family` must be valid, non-null, null-terminated C strings.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_render_text_with_font(
        text: *const c_char, x: f32, y: f32, size: f32,
        r: f32, g: f32, b: f32, a: f32,
        font_family: *const c_char,
    ) -> i32 {
        let text_str = CStr::from_ptr(text).to_str().unwrap_or("");
        let family = CStr::from_ptr(font_family).to_str().ok();
        ok_or_err(Engine::with(|e| { e.renderer().draw_text(text_str, x, y, size, r, g, b, a, family); Ok(()) }), 0)
    }

    /// # Safety
    /// `path` must be a valid, non-null, null-terminated C string pointing to a font file.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_font_load(path: *const c_char) -> i32 {
        let path_str = CStr::from_ptr(path).to_str().unwrap_or("");
        let data = match std::fs::read(path_str) {
            Ok(d) => d,
            Err(e) => { set_last_error(&format!("Failed to read font: {e}")); return -1; }
        };
        ok_or_err(Engine::with(|e| { e.renderer().load_font(data); Ok(()) }), 0)
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

    // --- Audio ---

    /// # Safety
    /// `path` must be a valid, non-null, null-terminated C string pointing to an audio file.
    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn dama_audio_load_sound(path: *const c_char) -> u64 {
        let path = CStr::from_ptr(path).to_str().unwrap_or("");
        match crate::audio::load_sound(path) {
            Ok(handle) => handle,
            Err(e) => { set_last_error(&e); 0 }
        }
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_audio_play_sound(handle: u64, volume: f32, looping: i32) -> i32 {
        ok_or_err(crate::audio::play_sound(handle, volume, looping != 0), 0)
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_audio_stop_all() -> i32 {
        crate::audio::stop_all();
        0
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn dama_audio_unload_sound(handle: u64) -> i32 {
        crate::audio::unload_sound(handle);
        0
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub use native_ffi::*;

// ===========================================================================
// Web WASM exports (wasm_bindgen for JavaScript)
// ===========================================================================
#[cfg(target_arch = "wasm32")]
mod web_exports {
    use super::*;
    use wasm_bindgen::prelude::*;

    #[wasm_bindgen]
    pub fn dama_init(canvas_id: &str, width: u32, height: u32) {
        Engine::init_web(canvas_id, width, height).unwrap();
    }

    #[wasm_bindgen]
    pub fn dama_shutdown() { let _ = Engine::shutdown(); }

    #[wasm_bindgen]
    pub fn dama_poll_events() -> bool {
        Engine::pump_events().unwrap_or(false)
    }

    #[wasm_bindgen]
    pub fn dama_begin_frame() { let _ = Engine::with(|e| e.begin_frame()); }

    #[wasm_bindgen]
    pub fn dama_end_frame() { let _ = Engine::with(|e| e.end_frame()); }

    #[wasm_bindgen]
    pub fn dama_delta_time() -> f64 { Engine::with(|e| Ok(e.delta_time())).unwrap_or(0.0) }

    #[wasm_bindgen]
    pub fn dama_frame_count() -> u64 { Engine::with(|e| Ok(e.frame_count())).unwrap_or(0) }

    #[wasm_bindgen]
    pub fn dama_clear(r: f32, g: f32, b: f32, a: f32) { let _ = Engine::with(|e| e.renderer().clear(r, g, b, a)); }

    #[wasm_bindgen]
    pub fn dama_render_vertices(vertex_data: &[f32], vertex_count: u32) {
        let count = vertex_count as usize;
        let _ = Engine::with(|e| { e.renderer().submit_vertices(vertex_data, count); Ok(()) });
    }

    /// Accept high-level draw commands. Rust decomposes shapes into triangles.
    /// This eliminates geometry decomposition from Ruby/wasm, dramatically
    /// improving web performance.
    #[wasm_bindgen]
    pub fn dama_render_commands(command_data: &[f32], float_count: u32) {
        let count = float_count as usize;
        let _ = Engine::with(|e| { e.renderer().submit_commands(&command_data[..count]); Ok(()) });
    }

    #[wasm_bindgen]
    pub fn dama_set_texture(handle: u64) {
        let _ = Engine::with(|e| { e.renderer().set_current_texture(handle); Ok(()) });
    }

    #[wasm_bindgen]
    pub fn dama_load_texture(data: &[u8]) -> u64 {
        Engine::with(|e| e.renderer().load_texture(data)).unwrap_or(0)
    }

    #[wasm_bindgen]
    pub fn dama_unload_texture(handle: u64) {
        let _ = Engine::with(|e| { e.renderer().unload_texture(handle); Ok(()) });
    }

    // Shader management.
    #[wasm_bindgen]
    pub fn dama_shader_load(source: &str) -> u64 {
        match Engine::with(|e| e.renderer().load_shader(source)) {
            Ok(handle) => handle,
            Err(_) => 0,
        }
    }

    #[wasm_bindgen]
    pub fn dama_shader_unload(handle: u64) {
        let _ = Engine::with(|e| { e.renderer().unload_shader(handle); Ok(()) });
    }

    #[wasm_bindgen]
    pub fn dama_set_shader(handle: u64) {
        let _ = Engine::with(|e| { e.renderer().set_current_shader(handle); Ok(()) });
    }

    #[wasm_bindgen]
    pub fn dama_render_text(text: &str, x: f32, y: f32, size: f32, r: f32, g: f32, b: f32, a: f32) {
        let _ = Engine::with(|e| { e.renderer().draw_text(text, x, y, size, r, g, b, a, None); Ok(()) });
    }

    // Input: JS calls these to forward browser events to Rust state.
    #[wasm_bindgen]
    pub fn dama_input_set_key(key_code: u32, pressed: bool) {
        crate::window::InputState::set_key(key_code, pressed);
    }

    #[wasm_bindgen]
    pub fn dama_input_set_mouse(x: f32, y: f32) {
        crate::window::InputState::set_mouse(x, y);
    }

    #[wasm_bindgen]
    pub fn dama_input_set_mouse_button(button: u32, pressed: bool) {
        crate::window::InputState::set_mouse_button(button, pressed);
    }

    #[wasm_bindgen]
    pub fn dama_input_begin_frame() {
        crate::window::InputState::begin_frame();
    }

    #[wasm_bindgen]
    pub fn dama_key_pressed(key_code: u32) -> bool {
        crate::window::InputState::with(|s| s.is_key_pressed(key_code))
    }

    #[wasm_bindgen]
    pub fn dama_key_just_pressed(key_code: u32) -> bool {
        crate::window::InputState::with(|s| s.is_key_just_pressed(key_code))
    }

    #[wasm_bindgen]
    pub fn dama_mouse_x() -> f32 {
        crate::window::InputState::with(|s| s.mouse_x())
    }

    #[wasm_bindgen]
    pub fn dama_mouse_y() -> f32 {
        crate::window::InputState::with(|s| s.mouse_y())
    }

    #[wasm_bindgen]
    pub fn dama_mouse_button_pressed(button: u32) -> bool {
        crate::window::InputState::with(|s| s.is_mouse_button_pressed(button))
    }
}
