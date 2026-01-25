pub mod screenshot;
pub mod shape_renderer;

use shape_renderer::ShapeRenderer;

/// Core wgpu renderer. Manages GPU device, queue, render targets,
/// and renders vertices for shape drawing.
pub struct Renderer {
    device: wgpu::Device,
    queue: wgpu::Queue,
    width: u32,
    height: u32,
    render_texture: Option<wgpu::Texture>,
    render_texture_view: Option<wgpu::TextureView>,
    surface_view: Option<wgpu::TextureView>,
    shape_renderer: Option<ShapeRenderer>,
}

impl Renderer {
    // Headless mode is native-only (tests).
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

        Ok(Self {
            device, queue, width, height,
            render_texture: Some(render_texture),
            render_texture_view: Some(render_texture_view),
            surface_view: None,
            shape_renderer: Some(shape_renderer),
        })
    }

    pub fn set_surface_view(&mut self, view: Option<wgpu::TextureView>) {
        self.surface_view = view;
    }

    fn active_view(&self) -> Option<&wgpu::TextureView> {
        self.surface_view.as_ref().or(self.render_texture_view.as_ref())
    }

    pub fn begin_frame(&mut self, _delta_time: f32) -> Result<(), String> {
        Ok(())
    }

    pub fn end_frame(&mut self) -> Result<(), String> {
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

    pub fn screenshot(&self, path: &str) -> Result<(), String> {
        let texture = self.render_texture.as_ref()
            .ok_or("Screenshot only works in headless mode")?;
        screenshot::capture(&self.device, &self.queue, texture, self.width, self.height, path)
    }

    pub fn device(&self) -> &wgpu::Device {
        &self.device
    }
}
