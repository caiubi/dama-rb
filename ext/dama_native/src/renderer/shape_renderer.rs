use std::collections::HashMap;
use wgpu::util::DeviceExt;

/// A vertex with 2D position, RGBA color, and UV texture coordinates.
/// Used for all rendering: shapes (UV=0,0 with white texture) and sprites.
#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Vertex {
    pub position: [f32; 2],
    pub color: [f32; 4],
    pub uv: [f32; 2],
}

impl Vertex {
    const ATTRIBS: [wgpu::VertexAttribute; 3] =
        wgpu::vertex_attr_array![0 => Float32x2, 1 => Float32x4, 2 => Float32x2];

    fn layout() -> wgpu::VertexBufferLayout<'static> {
        wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<Vertex>() as wgpu::BufferAddress,
            step_mode: wgpu::VertexStepMode::Vertex,
            attributes: &Self::ATTRIBS,
        }
    }
}

/// Uniform data passed to custom shaders (Group 1, Binding 0).
#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
struct Uniforms {
    time: f32,
    _padding: [f32; 3], // Pad to 16 bytes (wgpu minimum).
}

/// Stored GPU texture with its bind group for rendering.
pub struct GpuTexture {
    #[allow(dead_code)]
    texture: wgpu::Texture,
    bind_group: wgpu::BindGroup,
}

/// A cached custom shader: WGSL source + lazily compiled pipeline.
struct ShaderEntry {
    source: String,
    pipeline: Option<wgpu::RenderPipeline>,
}

/// Renders colored and textured triangles with optional custom shaders.
///
/// The default shader samples a texture and multiplies by vertex color:
///   output = textureSample(tex, sampler, uv) * color
///
/// Custom shaders receive the same vertex data plus a uniform buffer
/// with `time: f32` for animated effects.
pub struct ShapeRenderer {
    /// Default pipeline (handle = 0).
    pipeline: wgpu::RenderPipeline,
    /// Bind group layout for textures (Group 0: texture + sampler).
    texture_bind_group_layout: wgpu::BindGroupLayout,
    /// Bind group layout for uniforms (Group 1: time).
    uniform_bind_group_layout: wgpu::BindGroupLayout,
    sampler: wgpu::Sampler,
    /// The default 1x1 white texture bind group (handle = 0).
    default_bind_group: wgpu::BindGroup,
    /// Uniform buffer for time + bind group.
    uniform_buffer: wgpu::Buffer,
    uniform_bind_group: wgpu::BindGroup,
    /// Surface format for lazy pipeline creation.
    surface_format: wgpu::TextureFormat,
    /// User-loaded textures keyed by handle.
    textures: HashMap<u64, GpuTexture>,
    next_texture_handle: u64,
    /// Custom shaders keyed by handle. Pipeline created lazily on first use.
    shaders: HashMap<u64, ShaderEntry>,
    next_shader_handle: u64,
}

impl ShapeRenderer {
    pub fn new(device: &wgpu::Device, queue: &wgpu::Queue, format: wgpu::TextureFormat) -> Self {
        // --- Bind group layouts ---

        let texture_bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("texture_bind_group_layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        multisampled: false,
                        view_dimension: wgpu::TextureViewDimension::D2,
                        sample_type: wgpu::TextureSampleType::Float { filterable: true },
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
            ],
        });

        let uniform_bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("uniform_bind_group_layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        });

        // --- Uniform buffer ---

        let uniforms = Uniforms { time: 0.0, _padding: [0.0; 3] };
        let uniform_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("uniform_buffer"),
            contents: bytemuck::cast_slice(&[uniforms]),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        let uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("uniform_bind_group"),
            layout: &uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform_buffer.as_entire_binding(),
            }],
        });

        // --- Default pipeline (uses both bind group layouts) ---

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("shape_shader"),
            source: wgpu::ShaderSource::Wgsl(DEFAULT_SHADER.into()),
        });

        let pipeline = Self::create_pipeline(
            device, &shader, format,
            &texture_bind_group_layout, &uniform_bind_group_layout,
        );

        // --- Sampler + default white texture ---

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("sprite_sampler"),
            mag_filter: wgpu::FilterMode::Nearest,
            min_filter: wgpu::FilterMode::Nearest,
            ..Default::default()
        });

        let (default_bind_group, _white_tex) = Self::create_white_pixel(
            device, queue, &texture_bind_group_layout, &sampler,
        );

        Self {
            pipeline,
            texture_bind_group_layout,
            uniform_bind_group_layout,
            sampler,
            default_bind_group,
            uniform_buffer,
            uniform_bind_group,
            surface_format: format,
            textures: HashMap::new(),
            next_texture_handle: 1,
            shaders: HashMap::new(),
            next_shader_handle: 1,
        }
    }

    /// Update the time uniform. Call once per frame.
    pub fn update_time(&self, queue: &wgpu::Queue, time: f32) {
        let uniforms = Uniforms { time, _padding: [0.0; 3] };
        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&[uniforms]));
    }

    // --- Texture management ---

    pub fn load_texture(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        data: &[u8],
    ) -> Result<u64, String> {
        let img = image::load_from_memory(data)
            .map_err(|e| format!("Failed to decode image: {e}"))?
            .to_rgba8();

        let (width, height) = img.dimensions();

        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("user_texture"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba8UnormSrgb,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });

        queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                texture: &texture, mip_level: 0,
                origin: wgpu::Origin3d::ZERO, aspect: wgpu::TextureAspect::All,
            },
            &img,
            wgpu::TexelCopyBufferLayout {
                offset: 0, bytes_per_row: Some(4 * width), rows_per_image: Some(height),
            },
            wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
        );

        let view = texture.create_view(&wgpu::TextureViewDescriptor::default());
        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("user_texture_bind_group"),
            layout: &self.texture_bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&view) },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(&self.sampler) },
            ],
        });

        let handle = self.next_texture_handle;
        self.next_texture_handle += 1;
        self.textures.insert(handle, GpuTexture { texture, bind_group });
        Ok(handle)
    }

    pub fn unload_texture(&mut self, handle: u64) {
        self.textures.remove(&handle);
    }

    pub fn bind_group_for(&self, handle: u64) -> &wgpu::BindGroup {
        self.textures
            .get(&handle)
            .map(|t| &t.bind_group)
            .unwrap_or(&self.default_bind_group)
    }

    // --- Shader management ---

    /// Store a custom WGSL fragment shader. Returns a handle.
    /// The pipeline is created lazily on first render.
    pub fn load_shader(&mut self, source: &str) -> u64 {
        let handle = self.next_shader_handle;
        self.next_shader_handle += 1;
        self.shaders.insert(handle, ShaderEntry {
            source: source.to_string(),
            pipeline: None,
        });
        handle
    }

    pub fn unload_shader(&mut self, handle: u64) {
        self.shaders.remove(&handle);
    }

    pub fn shader_count(&self) -> usize {
        self.shaders.len()
    }

    // --- Rendering ---

    /// Render a batch of vertices with a specific texture and shader.
    /// shader_handle = 0 uses the default pipeline.
    pub fn render_batch(
        &mut self,
        device: &wgpu::Device,
        render_pass: &mut wgpu::RenderPass<'_>,
        vertices: &[Vertex],
        texture_handle: u64,
        shader_handle: u64,
    ) {
        if vertices.is_empty() {
            return;
        }

        let vertex_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("shape_vertex_buffer"),
            contents: bytemuck::cast_slice(vertices),
            usage: wgpu::BufferUsages::VERTEX,
        });

        // Select pipeline: default or custom shader.
        self.ensure_shader_pipeline(device, shader_handle);
        let pipeline = self.pipeline_for(shader_handle);

        let texture_bind_group = self.bind_group_for(texture_handle);

        render_pass.set_pipeline(pipeline);
        render_pass.set_bind_group(0, texture_bind_group, &[]);
        render_pass.set_bind_group(1, &self.uniform_bind_group, &[]);
        render_pass.set_vertex_buffer(0, vertex_buffer.slice(..));
        render_pass.draw(0..vertices.len() as u32, 0..1);
    }

    // --- Private helpers ---

    /// Lazily compile the shader pipeline if not yet created.
    fn ensure_shader_pipeline(&mut self, device: &wgpu::Device, shader_handle: u64) {
        if shader_handle == 0 { return; }

        match self.shaders.get(&shader_handle) {
            Some(e) if e.pipeline.is_some() => return,
            Some(_) => {},
            None => return,
        }

        // Build full WGSL by prepending the engine preamble to the user's fragment shader.
        let source = self.shaders.get(&shader_handle).unwrap().source.clone();
        let full_wgsl = format!("{SHADER_PREAMBLE}\n{source}");

        let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("custom_shader"),
            source: wgpu::ShaderSource::Wgsl(full_wgsl.into()),
        });

        let pipeline = Self::create_pipeline(
            device, &module, self.surface_format,
            &self.texture_bind_group_layout, &self.uniform_bind_group_layout,
        );

        if let Some(entry) = self.shaders.get_mut(&shader_handle) {
            entry.pipeline = Some(pipeline);
        }
    }

    fn pipeline_for(&self, shader_handle: u64) -> &wgpu::RenderPipeline {
        if shader_handle == 0 {
            return &self.pipeline;
        }

        self.shaders
            .get(&shader_handle)
            .and_then(|e| e.pipeline.as_ref())
            .unwrap_or(&self.pipeline)
    }

    fn create_pipeline(
        device: &wgpu::Device,
        shader: &wgpu::ShaderModule,
        format: wgpu::TextureFormat,
        texture_layout: &wgpu::BindGroupLayout,
        uniform_layout: &wgpu::BindGroupLayout,
    ) -> wgpu::RenderPipeline {
        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("shape_pipeline_layout"),
            bind_group_layouts: &[texture_layout, uniform_layout],
            immediate_size: 0,
        });

        device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("shape_pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: shader,
                entry_point: Some("vs_main"),
                buffers: &[Vertex::layout()],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: shader,
                entry_point: Some("fs_main"),
                targets: &[Some(wgpu::ColorTargetState {
                    format,
                    blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        })
    }

    fn create_white_pixel(
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        layout: &wgpu::BindGroupLayout,
        sampler: &wgpu::Sampler,
    ) -> (wgpu::BindGroup, wgpu::Texture) {
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("white_pixel"),
            size: wgpu::Extent3d { width: 1, height: 1, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba8UnormSrgb,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });

        queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                texture: &texture, mip_level: 0,
                origin: wgpu::Origin3d::ZERO, aspect: wgpu::TextureAspect::All,
            },
            &[255u8, 255, 255, 255],
            wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(4), rows_per_image: Some(1) },
            wgpu::Extent3d { width: 1, height: 1, depth_or_array_layers: 1 },
        );

        let view = texture.create_view(&wgpu::TextureViewDescriptor::default());
        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("default_texture_bind_group"),
            layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&view) },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(sampler) },
            ],
        });

        (bind_group, texture)
    }
}

/// Preamble prepended to custom fragment shaders.
/// Provides VertexOutput struct, texture/sampler bindings, and uniform buffer.
const SHADER_PREAMBLE: &str = r#"
struct VertexInput {
    @location(0) position: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) uv: vec2<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) uv: vec2<f32>,
};

@group(0) @binding(0) var t_diffuse: texture_2d<f32>;
@group(0) @binding(1) var s_diffuse: sampler;

struct Uniforms {
    time: f32,
};
@group(1) @binding(0) var<uniform> u: Uniforms;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.clip_position = vec4<f32>(in.position, 0.0, 1.0);
    out.color = in.color;
    out.uv = in.uv;
    return out;
}
"#;

/// Default shader: the same as before but with the uniform bind group present
/// (Group 1 exists but is unused by the default fragment shader).
const DEFAULT_SHADER: &str = r#"
struct VertexInput {
    @location(0) position: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) uv: vec2<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) uv: vec2<f32>,
};

@group(0) @binding(0) var t_diffuse: texture_2d<f32>;
@group(0) @binding(1) var s_diffuse: sampler;

struct Uniforms {
    time: f32,
};
@group(1) @binding(0) var<uniform> u: Uniforms;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.clip_position = vec4<f32>(in.position, 0.0, 1.0);
    out.color = in.color;
    out.uv = in.uv;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex_color = textureSample(t_diffuse, s_diffuse, in.uv);
    return tex_color * in.color;
}
"#;
