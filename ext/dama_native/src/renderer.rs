pub mod screenshot;
pub mod shape_renderer;
pub mod text_renderer;

use shape_renderer::{ShapeRenderer, Vertex};
use text_renderer::TextRenderer;

/// A batch of vertices grouped by texture and shader handle.
struct VertexBatch {
    texture_handle: u64,
    shader_handle: u64,
    vertices: Vec<Vertex>,
}

/// Core wgpu renderer. Manages GPU device, queue, render targets,
/// and batches vertices by texture for efficient draw calls.
pub struct Renderer {
    device: wgpu::Device,
    queue: wgpu::Queue,
    width: u32,
    height: u32,
    /// Logical resolution (what the game developer uses for coordinates).
    /// May differ from width/height on HiDPI displays.
    logical_width: u32,
    logical_height: u32,
    render_texture: Option<wgpu::Texture>,
    render_texture_view: Option<wgpu::TextureView>,
    surface_view: Option<wgpu::TextureView>,
    shape_renderer: Option<ShapeRenderer>,
    text_renderer: Option<TextRenderer>,
    pending_batches: Vec<VertexBatch>,
    current_texture: u64,
    current_shader: u64,
    elapsed_time: f32,
    /// Web-only: the wgpu Surface wrapping the HTML canvas.
    #[cfg(target_arch = "wasm32")]
    web_surface: Option<wgpu::Surface<'static>>,
    #[cfg(target_arch = "wasm32")]
    web_surface_texture: Option<wgpu::SurfaceTexture>,
}

impl Renderer {
    // Headless mode is native-only (tests).
    #[cfg(not(target_arch = "wasm32"))]
    pub fn new_headless(width: u32, height: u32) -> Result<Self, String> {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());

        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::default(),
            compatible_surface: None,
            force_fallback_adapter: false,
        }))
        .map_err(|e| format!("Failed to find a suitable GPU adapter: {e}"))?;

        let (device, queue) = pollster::block_on(adapter.request_device(
            &wgpu::DeviceDescriptor {
                label: Some("dama_device"),
                ..Default::default()
            },
        ))
        .map_err(|e| format!("Failed to create device: {e}"))?;

        let format = wgpu::TextureFormat::Rgba8Unorm;

        let render_texture: wgpu::Texture =
            device.create_texture(&wgpu::TextureDescriptor {
                label: Some("headless_render_texture"),
                size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::COPY_SRC,
                view_formats: &[],
            });

        let render_texture_view =
            render_texture.create_view(&wgpu::TextureViewDescriptor::default());

        let shape_renderer = ShapeRenderer::new(&device, &queue, format);
        let text_renderer = TextRenderer::new(&device, &queue, format, width, height);

        Ok(Self {
            device, queue, width, height,
            logical_width: width, logical_height: height,
            render_texture: Some(render_texture),
            render_texture_view: Some(render_texture_view),
            surface_view: None,
            shape_renderer: Some(shape_renderer),
            text_renderer: Some(text_renderer),
            pending_batches: Vec::new(),
            current_texture: 0,
            current_shader: 0,
            elapsed_time: 0.0,
        })
    }

    pub fn new_windowed(device: wgpu::Device, queue: wgpu::Queue, width: u32, height: u32) -> Self {
        Self {
            device, queue, width, height,
            logical_width: width, logical_height: height,
            render_texture: None,
            render_texture_view: None,
            surface_view: None,
            shape_renderer: None,
            text_renderer: None,
            pending_batches: Vec::new(),
            current_texture: 0,
            current_shader: 0,
            elapsed_time: 0.0,
            #[cfg(target_arch = "wasm32")]
            web_surface: None,
            #[cfg(target_arch = "wasm32")]
            web_surface_texture: None,
        }
    }

    /// Store the web surface (called during async init on wasm).
    #[cfg(target_arch = "wasm32")]
    pub fn set_web_surface(&mut self, surface: wgpu::Surface<'static>) {
        self.web_surface = Some(surface);
    }

    /// Acquire the next frame from the web surface.
    #[cfg(target_arch = "wasm32")]
    pub fn acquire_web_surface(&mut self) -> Result<(), String> {
        let surface = self.web_surface.as_ref().ok_or("No web surface")?;
        let texture = surface.get_current_texture()
            .map_err(|e| format!("Failed to get web surface texture: {e}"))?;
        let view = texture.texture.create_view(&wgpu::TextureViewDescriptor::default());
        self.surface_view = Some(view);
        self.web_surface_texture = Some(texture);
        Ok(())
    }

    /// Present the web surface frame.
    #[cfg(target_arch = "wasm32")]
    pub fn present_web_surface(&mut self) {
        if let Some(texture) = self.web_surface_texture.take() {
            texture.present();
        }
    }

    pub fn set_surface_format(&mut self, format: wgpu::TextureFormat) {
        self.shape_renderer = Some(ShapeRenderer::new(&self.device, &self.queue, format));
        self.text_renderer = Some(TextRenderer::new(
            &self.device, &self.queue, format, self.width, self.height,
        ));
    }

    /// Update physical render dimensions (e.g., after Retina surface creation).
    /// Logical dimensions (used for coordinate mapping) remain unchanged.
    pub fn set_physical_size(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }

    /// Set logical dimensions separately from physical (for HiDPI).
    /// Game coordinates use logical; GPU renders at physical.
    pub fn set_logical_size(&mut self, width: u32, height: u32) {
        self.logical_width = width;
        self.logical_height = height;
    }

    pub fn set_surface_view(&mut self, view: Option<wgpu::TextureView>) {
        self.surface_view = view;
    }

    fn active_view(&self) -> Option<&wgpu::TextureView> {
        self.surface_view.as_ref().or(self.render_texture_view.as_ref())
    }

    pub fn begin_frame(&mut self, delta_time: f32) -> Result<(), String> {
        self.pending_batches.clear();
        self.current_texture = 0;
        self.current_shader = 0;
        self.elapsed_time += delta_time;

        // Update the uniform buffer with current time.
        if let Some(ref sr) = self.shape_renderer {
            sr.update_time(&self.queue, self.elapsed_time);
        }
        Ok(())
    }

    pub fn end_frame(&mut self) -> Result<(), String> {
        if let Some(ref mut tr) = self.text_renderer {
            tr.prepare(&self.device, &self.queue)?;
        }

        let view = self.active_view().ok_or("No render target available")?;

        let mut encoder = self.device.create_command_encoder(
            &wgpu::CommandEncoderDescriptor { label: Some("frame_encoder") },
        );

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("main_render_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view,
                    resolve_target: None,
                    depth_slice: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Load,
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });

            // Render vertex batches grouped by texture + shader.
            if let Some(ref mut shape_renderer) = self.shape_renderer {
                for batch in &self.pending_batches {
                    shape_renderer.render_batch(
                        &self.device,
                        &mut render_pass,
                        &batch.vertices,
                        batch.texture_handle,
                        batch.shader_handle,
                    );
                }
            }

            // Text overlays everything.
            if let Some(ref self_tr) = self.text_renderer {
                let _ = self_tr.render(&mut render_pass);
            }
        }

        self.queue.submit(std::iter::once(encoder.finish()));
        let _ = self.device.poll(wgpu::PollType::wait_indefinitely());

        if let Some(ref mut tr) = self.text_renderer {
            tr.clear();
        }

        Ok(())
    }

    pub fn clear(&mut self, r: f32, g: f32, b: f32, a: f32) -> Result<(), String> {
        let view = self.active_view().ok_or("No render target available")?;

        let mut encoder = self.device.create_command_encoder(
            &wgpu::CommandEncoderDescriptor { label: Some("clear_encoder") },
        );

        {
            let _render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("clear_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view,
                    resolve_target: None,
                    depth_slice: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color {
                            r: r as f64, g: g as f64, b: b as f64, a: a as f64,
                        }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
        }

        self.queue.submit(std::iter::once(encoder.finish()));
        Ok(())
    }

    /// Accept pre-decomposed vertices from Ruby.
    /// Each vertex is 8 floats: [x, y, r, g, b, a, u, v] in pixel coordinates.
    pub fn submit_vertices(&mut self, floats: &[f32], vertex_count: usize) {
        // Use logical dimensions for NDC conversion — game coordinates are in logical pixels.
        let w = self.logical_width as f32;
        let h = self.logical_height as f32;
        let tex = self.current_texture;
        let shd = self.current_shader;

        // Find or create a batch for the current texture + shader.
        let batch = self.pending_batches.iter_mut()
            .rfind(|b| b.texture_handle == tex && b.shader_handle == shd);

        let batch = match batch {
            Some(b) => b,
            None => {
                self.pending_batches.push(VertexBatch {
                    texture_handle: tex,
                    shader_handle: shd,
                    vertices: Vec::new(),
                });
                self.pending_batches.last_mut().unwrap()
            }
        };

        for i in 0..vertex_count {
            let base = i * 8;
            let px = floats[base];
            let py = floats[base + 1];

            batch.vertices.push(Vertex {
                position: [
                    (px / w) * 2.0 - 1.0,
                    1.0 - (py / h) * 2.0,
                ],
                color: [
                    floats[base + 2],
                    floats[base + 3],
                    floats[base + 4],
                    floats[base + 5],
                ],
                uv: [
                    floats[base + 6],
                    floats[base + 7],
                ],
            });
        }
    }

    /// Accept high-level draw commands from Ruby (web backend).
    /// Each command starts with a float type tag, followed by shape-specific data.
    /// Rust decomposes shapes into triangles — eliminating trig from Ruby/wasm.
    ///
    /// Command format:
    ///   0 = Circle:     [0, cx, cy, radius, r, g, b, a, segments]  (9 floats)
    ///   1 = Rect:       [1, x, y, w, h, r, g, b, a]               (9 floats)
    ///   2 = Triangle:   [2, x1, y1, x2, y2, x3, y3, r, g, b, a]  (11 floats)
    ///   3 = Sprite:     [3, handle, x, y, w, h, r, g, b, a, u0, v0, u1, v1] (14 floats)
    ///   4 = SetTexture: [4, handle]                                 (2 floats)
    ///   5 = SetShader:  [5, handle]                                 (2 floats)
    pub fn submit_commands(&mut self, commands: &[f32]) {
        const COMMAND_SIZES: [usize; 6] = [9, 9, 11, 14, 2, 2];

        let mut cursor = 0;
        while cursor < commands.len() {
            let tag = commands[cursor] as usize;
            if tag >= COMMAND_SIZES.len() {
                break;
            }

            let size = COMMAND_SIZES[tag];
            if cursor + size > commands.len() {
                break;
            }

            let cmd = &commands[cursor..cursor + size];
            match tag {
                0 => self.decompose_circle(cmd),
                1 => self.decompose_rect(cmd),
                2 => self.decompose_triangle(cmd),
                3 => self.decompose_sprite(cmd),
                4 => self.current_texture = cmd[1] as u64,
                5 => self.current_shader = cmd[1] as u64,
                _ => {}
            }

            cursor += size;
        }
    }

    /// Convert pixel coordinates to Normalized Device Coordinates.
    fn pixel_to_ndc(&self, px: f32, py: f32) -> [f32; 2] {
        let w = self.logical_width as f32;
        let h = self.logical_height as f32;
        [(px / w) * 2.0 - 1.0, 1.0 - (py / h) * 2.0]
    }

    /// Push a single vertex (in pixel coords) to the current texture+shader batch.
    fn push_vertex(&mut self, px: f32, py: f32, r: f32, g: f32, b: f32, a: f32, u: f32, v: f32) {
        let pos = self.pixel_to_ndc(px, py);
        let tex = self.current_texture;
        let shd = self.current_shader;

        let batch = self.pending_batches.iter_mut()
            .rfind(|b| b.texture_handle == tex && b.shader_handle == shd);

        let batch = match batch {
            Some(b) => b,
            None => {
                self.pending_batches.push(VertexBatch {
                    texture_handle: tex,
                    shader_handle: shd,
                    vertices: Vec::new(),
                });
                self.pending_batches.last_mut().unwrap()
            }
        };

        batch.vertices.push(Vertex {
            position: pos,
            color: [r, g, b, a],
            uv: [u, v],
        });
    }

    /// Decompose a circle command into a triangle fan.
    /// cmd: [0, cx, cy, radius, r, g, b, a, segments]
    fn decompose_circle(&mut self, cmd: &[f32]) {
        let cx = cmd[1];
        let cy = cmd[2];
        let radius = cmd[3];
        let r = cmd[4];
        let g = cmd[5];
        let b = cmd[6];
        let a = cmd[7];
        let segments = cmd[8] as u32;

        let step = std::f32::consts::TAU / segments as f32;
        for i in 0..segments {
            let a1 = step * i as f32;
            let a2 = step * (i + 1) as f32;
            let x1 = cx + radius * a1.cos();
            let y1 = cy + radius * a1.sin();
            let x2 = cx + radius * a2.cos();
            let y2 = cy + radius * a2.sin();

            self.push_vertex(cx, cy, r, g, b, a, 0.0, 0.0);
            self.push_vertex(x1, y1, r, g, b, a, 0.0, 0.0);
            self.push_vertex(x2, y2, r, g, b, a, 0.0, 0.0);
        }
    }

    /// Decompose a rect command into 2 triangles (6 vertices).
    /// cmd: [1, x, y, w, h, r, g, b, a]
    fn decompose_rect(&mut self, cmd: &[f32]) {
        let x = cmd[1];
        let y = cmd[2];
        let w = cmd[3];
        let h = cmd[4];
        let r = cmd[5];
        let g = cmd[6];
        let b = cmd[7];
        let a = cmd[8];

        // Triangle 1: top-left, top-right, bottom-left
        self.push_vertex(x, y, r, g, b, a, 0.0, 0.0);
        self.push_vertex(x + w, y, r, g, b, a, 0.0, 0.0);
        self.push_vertex(x, y + h, r, g, b, a, 0.0, 0.0);
        // Triangle 2: top-right, bottom-right, bottom-left
        self.push_vertex(x + w, y, r, g, b, a, 0.0, 0.0);
        self.push_vertex(x + w, y + h, r, g, b, a, 0.0, 0.0);
        self.push_vertex(x, y + h, r, g, b, a, 0.0, 0.0);
    }

    /// Pass through a triangle command as 3 vertices.
    /// cmd: [2, x1, y1, x2, y2, x3, y3, r, g, b, a]
    fn decompose_triangle(&mut self, cmd: &[f32]) {
        let r = cmd[7];
        let g = cmd[8];
        let b = cmd[9];
        let a = cmd[10];

        self.push_vertex(cmd[1], cmd[2], r, g, b, a, 0.0, 0.0);
        self.push_vertex(cmd[3], cmd[4], r, g, b, a, 0.0, 0.0);
        self.push_vertex(cmd[5], cmd[6], r, g, b, a, 0.0, 0.0);
    }

    /// Decompose a sprite command into a textured quad (6 vertices).
    /// cmd: [3, handle, x, y, w, h, r, g, b, a, u_min, v_min, u_max, v_max]
    fn decompose_sprite(&mut self, cmd: &[f32]) {
        let handle = cmd[1] as u64;
        let x = cmd[2];
        let y = cmd[3];
        let w = cmd[4];
        let h = cmd[5];
        let r = cmd[6];
        let g = cmd[7];
        let b = cmd[8];
        let a = cmd[9];
        let u_min = cmd[10];
        let v_min = cmd[11];
        let u_max = cmd[12];
        let v_max = cmd[13];

        // Temporarily switch texture for this sprite.
        let prev_texture = self.current_texture;
        self.current_texture = handle;

        self.push_vertex(x, y, r, g, b, a, u_min, v_min);
        self.push_vertex(x + w, y, r, g, b, a, u_max, v_min);
        self.push_vertex(x, y + h, r, g, b, a, u_min, v_max);
        self.push_vertex(x + w, y, r, g, b, a, u_max, v_min);
        self.push_vertex(x + w, y + h, r, g, b, a, u_max, v_max);
        self.push_vertex(x, y + h, r, g, b, a, u_min, v_max);

        // Restore previous texture.
        self.current_texture = prev_texture;
    }

    /// Set the current texture for subsequent vertex submissions.
    /// handle=0 means no texture (white pixel default).
    pub fn set_current_texture(&mut self, handle: u64) {
        self.current_texture = handle;
    }

    /// Load a texture from raw image bytes. Returns a handle.
    pub fn load_texture(&mut self, data: &[u8]) -> Result<u64, String> {
        let sr = self.shape_renderer.as_mut()
            .ok_or("Shape renderer not initialized")?;
        sr.load_texture(&self.device, &self.queue, data)
    }

    /// Unload a previously loaded texture.
    pub fn unload_texture(&mut self, handle: u64) {
        if let Some(ref mut sr) = self.shape_renderer {
            sr.unload_texture(handle);
        }
    }

    /// Set the current shader for subsequent vertex submissions.
    /// handle=0 means default shader.
    pub fn set_current_shader(&mut self, handle: u64) {
        self.current_shader = handle;
    }

    /// Load a custom WGSL fragment shader. Returns a handle.
    pub fn load_shader(&mut self, source: &str) -> Result<u64, String> {
        let sr = self.shape_renderer.as_mut()
            .ok_or("Shape renderer not initialized")?;
        Ok(sr.load_shader(source))
    }

    /// Unload a previously loaded shader.
    pub fn unload_shader(&mut self, handle: u64) {
        if let Some(ref mut sr) = self.shape_renderer {
            sr.unload_shader(handle);
        }
    }

    pub fn draw_text(
        &mut self, text: &str, x: f32, y: f32, size: f32,
        r: f32, g: f32, b: f32, a: f32,
        font_family: Option<&str>,
    ) {
        if let Some(ref mut tr) = self.text_renderer {
            let scale_x = self.width as f32 / self.logical_width as f32;
            let scale_y = self.height as f32 / self.logical_height as f32;
            tr.queue_text(text, x * scale_x, y * scale_y, size * scale_x, r, g, b, a, font_family);
        }
    }

    /// Load custom font data into the text renderer's font system.
    pub fn load_font(&mut self, data: Vec<u8>) {
        if let Some(ref mut tr) = self.text_renderer {
            tr.load_font(data);
        }
    }

    pub fn screenshot(&self, path: &str) -> Result<(), String> {
        let texture = self.render_texture.as_ref()
            .ok_or("Screenshot only works in headless mode")?;
        screenshot::capture(&self.device, &self.queue, texture, self.width, self.height, path)
    }

    pub fn device(&self) -> &wgpu::Device {
        &self.device
    }
}
