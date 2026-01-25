use image::{ImageBuffer, Rgba};

/// Capture the contents of a GPU texture to a PNG file.
///
/// This performs a GPU readback: copies the texture into a staging buffer,
/// maps it to CPU memory, and encodes it as PNG. The `bytes_per_row` is
/// padded to wgpu's COPY_BYTES_PER_ROW_ALIGNMENT (256 bytes).
pub fn capture(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    texture: &wgpu::Texture,
    width: u32,
    height: u32,
    path: &str,
) -> Result<(), String> {
    let bytes_per_pixel = 4u32; // Rgba8UnormSrgb
    let unpadded_bytes_per_row = width * bytes_per_pixel;
    let align = wgpu::COPY_BYTES_PER_ROW_ALIGNMENT;
    let padded_bytes_per_row = unpadded_bytes_per_row.div_ceil(align) * align;
    let buffer_size = (padded_bytes_per_row * height) as u64;

    let staging_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("screenshot_staging_buffer"),
        size: buffer_size,
        usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
        label: Some("screenshot_encoder"),
    });

    encoder.copy_texture_to_buffer(
        wgpu::TexelCopyTextureInfo {
            texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        wgpu::TexelCopyBufferInfo {
            buffer: &staging_buffer,
            layout: wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(padded_bytes_per_row),
                rows_per_image: Some(height),
            },
        },
        wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
    );

    queue.submit(std::iter::once(encoder.finish()));

    let buffer_slice = staging_buffer.slice(..);
    let (tx, rx) = std::sync::mpsc::channel();
    buffer_slice.map_async(wgpu::MapMode::Read, move |result| {
        tx.send(result).unwrap();
    });
    let _ = device.poll(wgpu::PollType::wait_indefinitely());
    rx.recv()
        .map_err(|e| format!("Failed to receive map result: {e}"))?
        .map_err(|e| format!("Buffer mapping failed: {e}"))?;

    let data = buffer_slice.get_mapped_range();

    // Strip row padding to get contiguous pixel data.
    let mut pixels = Vec::with_capacity((width * height * bytes_per_pixel) as usize);
    for row in 0..height {
        let start = (row * padded_bytes_per_row) as usize;
        let end = start + (unpadded_bytes_per_row) as usize;
        pixels.extend_from_slice(&data[start..end]);
    }

    drop(data);
    staging_buffer.unmap();

    let img: ImageBuffer<Rgba<u8>, _> =
        ImageBuffer::from_raw(width, height, pixels).ok_or("Failed to create image buffer")?;

    img.save(path).map_err(|e| format!("Failed to save PNG: {e}"))
}
