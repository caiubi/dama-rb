use std::time::Instant;

use crate::renderer::Renderer;

static ENGINE: std::sync::Mutex<Option<Engine>> = std::sync::Mutex::new(None);

fn engine_set(engine: Option<Engine>) {
    let mut guard = ENGINE.lock().unwrap();
    *guard = engine;
}

fn engine_with<F, T>(f: F) -> Result<T, String>
where F: FnOnce(&mut Engine) -> Result<T, String> {
    let mut guard = ENGINE.lock().map_err(|e| format!("Mutex poisoned: {e}"))?;
    let engine = guard.as_mut().ok_or("Engine not initialized")?;
    f(engine)
}

// Native-only: winit event loop in thread-local storage.
use std::cell::RefCell;
thread_local! {
    static EVENT_LOOP: RefCell<Option<winit::event_loop::EventLoop<()>>> = const { RefCell::new(None) };
}

pub struct Engine {
    renderer: Renderer,
    window_state: Option<crate::window::WindowState>,
    frame_count: u64,
    last_frame_time: Instant,
    delta_time: f64,
    last_error: Option<String>,
    wgpu_instance: Option<wgpu::Instance>,
    wgpu_adapter: Option<wgpu::Adapter>,
}

impl Engine {
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

    pub fn shutdown() -> Result<(), String> {
        let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            engine_set(None);
        }));
        EVENT_LOOP.with(|cell| { *cell.borrow_mut() = None; });
        Ok(())
    }

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

    pub fn window_state(&self) -> Option<&crate::window::WindowState> { self.window_state.as_ref() }

    pub fn begin_frame(&mut self) -> Result<(), String> {
        let now = Instant::now();
        self.delta_time = now.duration_since(self.last_frame_time).as_secs_f64();
        self.last_frame_time = now;

        if let Some(ref mut ws) = self.window_state {
            let texture = ws.acquire_texture()?;
            let view = texture.texture.create_view(&wgpu::TextureViewDescriptor::default());
            self.renderer.set_surface_view(Some(view));
        }

        self.renderer.begin_frame(self.delta_time as f32)
    }

    pub fn end_frame(&mut self) -> Result<(), String> {
        self.renderer.end_frame()?;
        self.renderer.set_surface_view(None);

        if let Some(ref mut ws) = self.window_state {
            ws.present();
        }

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
