// Native-only: winit window management and input tracking.
use std::collections::HashSet;
use std::sync::Arc;

use winit::application::ApplicationHandler;
use winit::event::{ElementState, WindowEvent};
use winit::event_loop::ActiveEventLoop;
use winit::keyboard::PhysicalKey;
use winit::window::{Window, WindowId};

pub struct WindowState {
    window: Option<Arc<Window>>,
    surface: Option<wgpu::Surface<'static>>,
    surface_config: Option<wgpu::SurfaceConfiguration>,
    current_texture: Option<wgpu::SurfaceTexture>,
    title: String,
    width: u32,
    height: u32,
    quit_requested: bool,
    keys_pressed: HashSet<u32>,
    keys_just_pressed: HashSet<u32>,
    keys_just_released: HashSet<u32>,
    mouse_x: f32,
    mouse_y: f32,
    mouse_buttons: HashSet<u32>,
}

impl WindowState {
    pub fn new(title: String, width: u32, height: u32) -> Self {
        Self {
            window: None, surface: None, surface_config: None, current_texture: None,
            title, width, height, quit_requested: false,
            keys_pressed: HashSet::new(), keys_just_pressed: HashSet::new(),
            keys_just_released: HashSet::new(),
            mouse_x: 0.0, mouse_y: 0.0, mouse_buttons: HashSet::new(),
        }
    }

    pub fn quit_requested(&self) -> bool { self.quit_requested }
    pub fn width(&self) -> u32 { self.width }
    pub fn height(&self) -> u32 { self.height }

    pub fn begin_input_frame(&mut self) {
        self.keys_just_pressed.clear();
        self.keys_just_released.clear();
    }

    pub fn is_key_pressed(&self, key_code: u32) -> bool { self.keys_pressed.contains(&key_code) }
    pub fn is_key_just_pressed(&self, key_code: u32) -> bool { self.keys_just_pressed.contains(&key_code) }
    pub fn is_key_just_released(&self, key_code: u32) -> bool { self.keys_just_released.contains(&key_code) }
    pub fn mouse_x(&self) -> f32 { self.mouse_x }
    pub fn mouse_y(&self) -> f32 { self.mouse_y }
    pub fn is_mouse_button_pressed(&self, button: u32) -> bool { self.mouse_buttons.contains(&button) }

    pub fn surface_config(&self) -> Option<&wgpu::SurfaceConfiguration> { self.surface_config.as_ref() }

    pub fn create_surface(
        &mut self, instance: &wgpu::Instance, device: &wgpu::Device, adapter: &wgpu::Adapter,
    ) -> Result<(), String> {
        let window = self.window.as_ref().ok_or("Window not yet created")?.clone();
        let surface = instance.create_surface(window.clone()).map_err(|e| format!("Failed to create surface: {e}"))?;
        let caps = surface.get_capabilities(adapter);

        // Use a non-sRGB format so colors are passed through without gamma correction.
        // This ensures the RGBA values from Ruby render as-is (vivid, matching web).
        let format = caps.formats.iter()
            .find(|f| !f.is_srgb())
            .copied()
            .unwrap_or(caps.formats[0]);

        // Use physical pixel dimensions for Retina/HiDPI sharpness.
        let physical = window.inner_size();

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT, format,
            width: physical.width, height: physical.height,
            present_mode: wgpu::PresentMode::AutoVsync,
            alpha_mode: caps.alpha_modes[0],
            view_formats: vec![], desired_maximum_frame_latency: 2,
        };
        surface.configure(device, &config);
        self.surface = Some(surface);
        self.surface_config = Some(config);

        // Update stored dimensions to physical for correct projection matrix.
        self.width = physical.width;
        self.height = physical.height;

        Ok(())
    }

    pub fn acquire_texture(&mut self) -> Result<&wgpu::SurfaceTexture, String> {
        let surface = self.surface.as_ref().ok_or("No surface")?;
        let texture = surface.get_current_texture().map_err(|e| format!("Failed to get surface texture: {e}"))?;
        self.current_texture = Some(texture);
        self.current_texture.as_ref().ok_or("Texture not acquired".to_string())
    }

    pub fn present(&mut self) {
        if let Some(texture) = self.current_texture.take() { texture.present(); }
    }
}

type WindowCallback<'a> = Box<dyn FnOnce(&Arc<Window>) + 'a>;

pub struct DamaAppHandler<'a> {
    pub window_state: &'a mut WindowState,
    pub on_window_created: Option<WindowCallback<'a>>,
}

impl ApplicationHandler for DamaAppHandler<'_> {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window_state.window.is_some() { return; }
        let attrs = Window::default_attributes()
            .with_title(&self.window_state.title)
            .with_inner_size(winit::dpi::LogicalSize::new(self.window_state.width, self.window_state.height));
        let window = Arc::new(event_loop.create_window(attrs).expect("Failed to create window"));
        self.window_state.window = Some(window.clone());
        if let Some(callback) = self.on_window_created.take() { callback(&window); }
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _window_id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => { self.window_state.quit_requested = true; event_loop.exit(); }
            WindowEvent::Resized(size) => { self.window_state.width = size.width; self.window_state.height = size.height; }
            WindowEvent::KeyboardInput { event, .. } => {
                if let PhysicalKey::Code(code) = event.physical_key {
                    let key_code = code as u32;
                    match event.state {
                        ElementState::Pressed => {
                            if !self.window_state.keys_pressed.contains(&key_code) {
                                self.window_state.keys_just_pressed.insert(key_code);
                            }
                            self.window_state.keys_pressed.insert(key_code);
                        }
                        ElementState::Released => {
                            self.window_state.keys_pressed.remove(&key_code);
                            self.window_state.keys_just_released.insert(key_code);
                        }
                    }
                }
            }
            WindowEvent::CursorMoved { position, .. } => {
                // Convert physical pixels to logical pixels using the window's scale factor.
                let scale = self.window_state.window.as_ref()
                    .map(|w| w.scale_factor())
                    .unwrap_or(1.0);
                self.window_state.mouse_x = (position.x / scale) as f32;
                self.window_state.mouse_y = (position.y / scale) as f32;
            }
            WindowEvent::MouseInput { state, button, .. } => {
                let btn = match button {
                    winit::event::MouseButton::Left => 0,
                    winit::event::MouseButton::Right => 1,
                    winit::event::MouseButton::Middle => 2,
                    winit::event::MouseButton::Back => 3,
                    winit::event::MouseButton::Forward => 4,
                    winit::event::MouseButton::Other(n) => n as u32 + 5,
                };
                match state {
                    ElementState::Pressed => { self.window_state.mouse_buttons.insert(btn); }
                    ElementState::Released => { self.window_state.mouse_buttons.remove(&btn); }
                }
            }
            _ => {}
        }
    }
}
