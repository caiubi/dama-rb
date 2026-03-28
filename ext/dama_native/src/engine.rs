#[cfg(not(target_arch = "wasm32"))]
use std::time::Instant;
#[cfg(target_arch = "wasm32")]
use web_time::Instant;

use crate::renderer::Renderer;

// Native: Mutex for thread safety.
// Web: RefCell in thread-local (single-threaded, avoids Sync requirement on glyphon types).
#[cfg(not(target_arch = "wasm32"))]
static ENGINE: std::sync::Mutex<Option<Engine>> = std::sync::Mutex::new(None);

#[cfg(target_arch = "wasm32")]
thread_local! {
    static ENGINE_CELL: std::cell::RefCell<Option<Engine>> = const { std::cell::RefCell::new(None) };
}

// Platform-agnostic helpers to access the global Engine.
#[cfg(not(target_arch = "wasm32"))]
fn engine_set(engine: Option<Engine>) {
    let mut guard = ENGINE.lock().unwrap();
    *guard = engine;
}

#[cfg(target_arch = "wasm32")]
fn engine_set(engine: Option<Engine>) {
    ENGINE_CELL.with(|cell| { *cell.borrow_mut() = engine; });
}

#[cfg(not(target_arch = "wasm32"))]
fn engine_with<F, T>(f: F) -> Result<T, String>
where F: FnOnce(&mut Engine) -> Result<T, String> {
    let mut guard = ENGINE.lock().map_err(|e| format!("Mutex poisoned: {e}"))?;
    let engine = guard.as_mut().ok_or("Engine not initialized")?;
    f(engine)
}

#[cfg(target_arch = "wasm32")]
fn engine_with<F, T>(f: F) -> Result<T, String>
where F: FnOnce(&mut Engine) -> Result<T, String> {
    ENGINE_CELL.with(|cell| {
        let mut borrow = cell.borrow_mut();
        let engine = borrow.as_mut().ok_or("Engine not initialized".to_string())?;
        f(engine)
    })
}

// Native-only: winit event loop in thread-local storage.
#[cfg(not(target_arch = "wasm32"))]
use std::cell::RefCell;
#[cfg(not(target_arch = "wasm32"))]
thread_local! {
    static EVENT_LOOP: RefCell<Option<winit::event_loop::EventLoop<()>>> = const { RefCell::new(None) };
}

pub struct Engine {
    renderer: Renderer,
    #[cfg(not(target_arch = "wasm32"))]
    window_state: Option<crate::window::WindowState>,
    frame_count: u64,
    last_frame_time: Instant,
    delta_time: f64,
    last_error: Option<String>,
    #[cfg(not(target_arch = "wasm32"))]
    wgpu_instance: Option<wgpu::Instance>,
    #[cfg(not(target_arch = "wasm32"))]
    wgpu_adapter: Option<wgpu::Adapter>,
}

impl Engine {
    #[cfg(not(target_arch = "wasm32"))]
    pub fn init_headless(width: u32, height: u32) -> Result<(), String> {
        let renderer = Renderer::new_headless(width, height)?;
        let engine = Engine {
            renderer,
            window_state: None,
            frame_count: 0,
            last_frame_time: Instant::now(),
            delta_time: 0.0,
            last_error: None,
            wgpu_instance: None,
            wgpu_adapter: None,
        };
        engine_set(Some(engine));
        Ok(())
    }

    #[cfg(not(target_arch = "wasm32"))]
    pub fn init_windowed(width: u32, height: u32, title: &str) -> Result<(), String> {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::default(),
            compatible_surface: None,
            force_fallback_adapter: false,
        }))
        .map_err(|e| format!("Failed to find GPU adapter: {e}"))?;

        let (device, queue) = pollster::block_on(adapter.request_device(
            &wgpu::DeviceDescriptor { label: Some("dama_device"), ..Default::default() },
        ))
        .map_err(|e| format!("Failed to create device: {e}"))?;

        let renderer = Renderer::new_windowed(device, queue, width, height);
        let window_state = crate::window::WindowState::new(title.to_string(), width, height);

        let engine = Engine {
            renderer,
            window_state: Some(window_state),
            frame_count: 0,
            last_frame_time: Instant::now(),
            delta_time: 0.0,
            last_error: None,
            wgpu_instance: Some(instance),
            wgpu_adapter: Some(adapter),
        };

        engine_set(Some(engine));

        let event_loop = winit::event_loop::EventLoop::new()
            .map_err(|e| format!("Failed to create event loop: {e}"))?;
        EVENT_LOOP.with(|cell| { *cell.borrow_mut() = Some(event_loop); });

        Engine::pump_events()?;

        Engine::with(|engine| {
            let instance = engine.wgpu_instance.as_ref().ok_or("No wgpu instance")?;
            let adapter = engine.wgpu_adapter.as_ref().ok_or("No wgpu adapter")?;
            let device = engine.renderer.device();
            let ws = engine.window_state.as_mut().ok_or("No window state")?;
            ws.create_surface(instance, device, adapter)?;
            if let Some(config) = ws.surface_config() {
                // Update physical dimensions BEFORE creating renderers so
                // text renderer gets the correct viewport size.
                engine.renderer.set_physical_size(config.width, config.height);
                engine.renderer.set_surface_format(config.format);
            }
            Ok(())
        })?;

        Ok(())
    }

    // Web init: canvas-based surface via wgpu's WebGPU backend.
    #[cfg(target_arch = "wasm32")]
    pub fn init_web(canvas_id: &str, width: u32, height: u32) -> Result<(), String> {
        use wasm_bindgen::JsCast;

        console_error_panic_hook::set_once();
        let _ = console_log::init_with_level(log::Level::Warn);

        crate::window::InputState::init();

        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());

        let document = web_sys::window()
            .ok_or("No window")?
            .document()
            .ok_or("No document")?;
        let canvas = document
            .get_element_by_id(canvas_id)
            .ok_or(format!("Canvas '{canvas_id}' not found"))?
            .dyn_into::<web_sys::HtmlCanvasElement>()
            .map_err(|_| "Element is not a canvas")?;

        // Read the canvas's physical backing dimensions (set by JS to logical × DPR).
        let physical_width = canvas.width();
        let physical_height = canvas.height();

        let surface = instance
            .create_surface(wgpu::SurfaceTarget::Canvas(canvas))
            .map_err(|e| format!("Failed to create surface: {e}"))?;

        // wasm: adapter/device requests are async. Use spawn_local.
        let logical_width = width;
        let logical_height = height;
        wasm_bindgen_futures::spawn_local(async move {
            let adapter = instance
                .request_adapter(&wgpu::RequestAdapterOptions {
                    power_preference: wgpu::PowerPreference::default(),
                    compatible_surface: Some(&surface),
                    force_fallback_adapter: false,
                })
                .await
                .expect("Failed to find GPU adapter");

            let (device, queue) = adapter
                .request_device(&wgpu::DeviceDescriptor {
                    label: Some("dama_device"),
                    ..Default::default()
                })
                .await
                .expect("Failed to create device");

            let caps = surface.get_capabilities(&adapter);
            // Prefer non-sRGB for consistent colors with native.
            let format = caps.formats.iter()
                .find(|f| !f.is_srgb())
                .copied()
                .unwrap_or(caps.formats[0]);
            let config = wgpu::SurfaceConfiguration {
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
                format,
                width: physical_width,
                height: physical_height,
                present_mode: wgpu::PresentMode::AutoVsync,
                alpha_mode: caps.alpha_modes[0],
                view_formats: vec![],
                desired_maximum_frame_latency: 2,
            };
            surface.configure(&device, &config);

            // Renderer uses physical dims for GPU but logical for coordinate mapping.
            let mut renderer = Renderer::new_windowed(device, queue, physical_width, physical_height);
            renderer.set_logical_size(logical_width, logical_height);
            renderer.set_surface_format(format);
            renderer.set_web_surface(surface);

            let engine = Engine {
                renderer,
                frame_count: 0,
                last_frame_time: Instant::now(),
                delta_time: 0.0,
                last_error: None,
            };
            engine_set(Some(engine));

            // Signal to JS that the engine is ready.
            let window = web_sys::window().unwrap();
            js_sys::Reflect::set(
                &window, &"__damaReady".into(), &true.into()
            ).unwrap();
        });

        Ok(())
    }

    pub fn shutdown() -> Result<(), String> {
        // Catch panics during engine drop (e.g., surface already invalidated).
        let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            engine_set(None);
        }));
        #[cfg(not(target_arch = "wasm32"))]
        EVENT_LOOP.with(|cell| { *cell.borrow_mut() = None; });
        Ok(())
    }

    #[cfg(not(target_arch = "wasm32"))]
    pub fn pump_events() -> Result<bool, String> {
        use winit::platform::pump_events::EventLoopExtPumpEvents;

        let mut event_loop_opt = EVENT_LOOP.with(|cell| cell.borrow_mut().take());
        let event_loop = event_loop_opt.as_mut().ok_or("No event loop (headless mode?)")?;

        let mut ws = engine_with(|engine| {
            engine.window_state.take().ok_or("No window state".to_string())
        })?;

        ws.begin_input_frame();
        {
            let mut handler = crate::window::DamaAppHandler {
                window_state: &mut ws,
                on_window_created: None,
            };
            let _status = event_loop.pump_app_events(Some(std::time::Duration::ZERO), &mut handler);
        }
        let quit = ws.quit_requested();

        let _ = engine_with(|engine| { engine.window_state = Some(ws); Ok(()) });

        EVENT_LOOP.with(|cell| { *cell.borrow_mut() = event_loop_opt; });
        Ok(quit)
    }

    #[cfg(target_arch = "wasm32")]
    pub fn pump_events() -> Result<bool, String> {
        crate::window::InputState::begin_frame();
        Ok(false)
    }

    pub fn with<F, T>(f: F) -> Result<T, String>
    where F: FnOnce(&mut Engine) -> Result<T, String>,
    {
        engine_with(|engine| {
            let result = f(engine);
            if let Err(ref e) = result { engine.last_error = Some(e.clone()); }
            result
        })
    }

    pub fn renderer(&mut self) -> &mut Renderer { &mut self.renderer }

    #[cfg(not(target_arch = "wasm32"))]
    pub fn window_state(&self) -> Option<&crate::window::WindowState> { self.window_state.as_ref() }

    pub fn begin_frame(&mut self) -> Result<(), String> {
        // Compute delta time from Instant (works on both native and web via web-time crate).
        let now = Instant::now();
        self.delta_time = now.duration_since(self.last_frame_time).as_secs_f64();
        self.last_frame_time = now;

        #[cfg(not(target_arch = "wasm32"))]
        if let Some(ref mut ws) = self.window_state {
            let texture = ws.acquire_texture()?;
            let view = texture.texture.create_view(&wgpu::TextureViewDescriptor::default());
            self.renderer.set_surface_view(Some(view));
        }

        // Web: acquire surface texture from stored surface.
        #[cfg(target_arch = "wasm32")]
        self.renderer.acquire_web_surface()?;

        self.renderer.begin_frame(self.delta_time as f32)
    }

    pub fn end_frame(&mut self) -> Result<(), String> {
        self.renderer.end_frame()?;
        self.renderer.set_surface_view(None);

        #[cfg(not(target_arch = "wasm32"))]
        if let Some(ref mut ws) = self.window_state {
            ws.present();
        }

        #[cfg(target_arch = "wasm32")]
        self.renderer.present_web_surface();

        self.frame_count += 1;
        Ok(())
    }

    pub fn delta_time(&self) -> f64 { self.delta_time }
    pub fn frame_count(&self) -> u64 { self.frame_count }
    pub fn last_error(&self) -> Option<&str> { self.last_error.as_deref() }

    pub fn screenshot(&self, path: &str) -> Result<(), String> {
        self.renderer.screenshot(path)
    }

}
