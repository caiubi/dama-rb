use glyphon::{
    Attrs, Buffer, Cache, Color, Family, FontSystem, Metrics, Resolution, Shaping, SwashCache,
    TextArea, TextAtlas, TextBounds, TextRenderer as GlyphonRenderer, Viewport,
};

/// A queued text draw command, collected between begin_frame and end_frame.
pub struct TextCommand {
    pub text: String,
    pub x: f32,
    pub y: f32,
    pub size: f32,
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
    /// Optional custom font family name. None = SansSerif (default).
    pub font_family: Option<String>,
}

/// Wraps glyphon for GPU text rendering. Integrates as middleware
/// into an existing wgpu render pass (renders after shapes).
pub struct TextRenderer {
    font_system: FontSystem,
    swash_cache: SwashCache,
    #[allow(dead_code)]
    cache: Cache,
    viewport: Viewport,
    atlas: TextAtlas,
    renderer: GlyphonRenderer,
    width: u32,
    height: u32,
    pending_texts: Vec<TextCommand>,
    /// Buffers created during prepare(), kept alive until after render().
    prepared_buffers: Vec<Buffer>,
}

impl TextRenderer {
    pub fn new(
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        format: wgpu::TextureFormat,
        width: u32,
        height: u32,
    ) -> Self {
        let font_system = FontSystem::new();

        // On wasm there are no system fonts — embed a default font.
        #[cfg(target_arch = "wasm32")]
        let font_system = {
            let mut fs = font_system;
            let font_data = include_bytes!("../fonts/NotoSans-Regular.ttf").to_vec();
            fs.db_mut().load_font_data(font_data);
            fs
        };
        let swash_cache = SwashCache::new();
        let cache = Cache::new(device);
        let viewport = Viewport::new(device, &cache);
        let mut atlas = TextAtlas::new(device, queue, &cache, format);
        let renderer =
            GlyphonRenderer::new(&mut atlas, device, wgpu::MultisampleState::default(), None);

        Self {
            font_system,
            swash_cache,
            cache,
            viewport,
            atlas,
            renderer,
            width,
            height,
            pending_texts: Vec::new(),
            prepared_buffers: Vec::new(),
        }
    }

    /// Load a custom font file into the font system.
    pub fn load_font(&mut self, data: Vec<u8>) {
        self.font_system.db_mut().load_font_data(data);
    }

    pub fn queue_text(
        &mut self, text: &str, x: f32, y: f32, size: f32,
        r: f32, g: f32, b: f32, a: f32,
        font_family: Option<&str>,
    ) {
        self.pending_texts.push(TextCommand {
            text: text.to_string(),
            x,
            y,
            size,
            r: (r * 255.0) as u8,
            g: (g * 255.0) as u8,
            b: (b * 255.0) as u8,
            a: (a * 255.0) as u8,
            font_family: font_family.map(|s| s.to_string()),
        });
    }

    /// Prepare text for rendering. Must be called before the render pass.
    /// Creates glyphon Buffers, shapes text, and uploads glyphs to the atlas.
    pub fn prepare(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
    ) -> Result<(), String> {
        self.prepared_buffers.clear();

        self.viewport.update(
            queue,
            Resolution {
                width: self.width,
                height: self.height,
            },
        );

        // Create a Buffer for each pending text command.
        for cmd in &self.pending_texts {
            let metrics = Metrics::new(cmd.size, cmd.size * 1.2);
            let mut buffer = Buffer::new(&mut self.font_system, metrics);
            buffer.set_size(
                &mut self.font_system,
                Some(self.width as f32),
                Some(self.height as f32),
            );
            let attrs = match &cmd.font_family {
                Some(name) => Attrs::new().family(Family::Name(name)),
                None => Attrs::new().family(Family::SansSerif),
            };
            buffer.set_text(
                &mut self.font_system,
                &cmd.text,
                &attrs,
                Shaping::Advanced,
                None,
            );
            buffer.shape_until_scroll(&mut self.font_system, false);
            self.prepared_buffers.push(buffer);
        }

        // Build TextArea references for all prepared buffers.
        let text_areas: Vec<TextArea> = self
            .prepared_buffers
            .iter()
            .zip(self.pending_texts.iter())
            .map(|(buffer, cmd)| TextArea {
                buffer,
                left: cmd.x,
                top: cmd.y,
                scale: 1.0,
                bounds: TextBounds {
                    left: 0,
                    top: 0,
                    right: self.width as i32,
                    bottom: self.height as i32,
                },
                default_color: Color::rgba(cmd.r, cmd.g, cmd.b, cmd.a),
                custom_glyphs: &[],
            })
            .collect();

        self.renderer
            .prepare(
                device,
                queue,
                &mut self.font_system,
                &mut self.atlas,
                &self.viewport,
                text_areas,
                &mut self.swash_cache,
            )
            .map_err(|e| format!("Text prepare failed: {e}"))
    }

    /// Render prepared text into an active render pass.
    pub fn render<'a>(&'a self, pass: &mut wgpu::RenderPass<'a>) -> Result<(), String> {
        self.renderer
            .render(&self.atlas, &self.viewport, pass)
            .map_err(|e| format!("Text render failed: {e}"))
    }

    /// Clear pending text and trim the glyph atlas.
    pub fn clear(&mut self) {
        self.pending_texts.clear();
        self.prepared_buffers.clear();
        self.atlas.trim();
    }

    pub fn update_dimensions(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }
}
