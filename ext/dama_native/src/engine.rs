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

pub struct Engine {
    renderer: Renderer,
    frame_count: u64,
    last_frame_time: Instant,
    delta_time: f64,
    last_error: Option<String>,
}

impl Engine {
    pub fn init_headless(width: u32, height: u32) -> Result<(), String> {
        let renderer = Renderer::new_headless(width, height)?;
        let engine = Engine {
            renderer,
            frame_count: 0,
            last_frame_time: Instant::now(),
            delta_time: 0.0,
            last_error: None,
        };
        engine_set(Some(engine));
        Ok(())
    }

    pub fn shutdown() -> Result<(), String> {
        let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            engine_set(None);
        }));
        Ok(())
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

    pub fn begin_frame(&mut self) -> Result<(), String> {
        let now = Instant::now();
        self.delta_time = now.duration_since(self.last_frame_time).as_secs_f64();
        self.last_frame_time = now;
        self.renderer.begin_frame(self.delta_time as f32)
    }

    pub fn end_frame(&mut self) -> Result<(), String> {
        self.renderer.end_frame()?;
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
