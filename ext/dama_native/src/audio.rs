/// Audio playback via rodio. Native-only (not available on wasm).
///
/// Uses thread_local storage because rodio's OutputStream is not Send/Sync.
/// All audio functions must be called from the main thread.
use std::cell::RefCell;
use std::collections::HashMap;
use std::io::BufReader;
use std::sync::atomic::{AtomicU64, Ordering};

use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink, Source};

static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);

struct AudioState {
    _stream: OutputStream,
    stream_handle: OutputStreamHandle,
    sounds: HashMap<u64, Vec<u8>>,
    sinks: Vec<Sink>,
}

thread_local! {
    static AUDIO: RefCell<Option<AudioState>> = const { RefCell::new(None) };
}

/// Initialize the audio system. Called automatically on first use.
fn ensure_init() {
    AUDIO.with(|cell| {
        if cell.borrow().is_some() {
            return;
        }
        if let Ok((stream, handle)) = OutputStream::try_default() {
            *cell.borrow_mut() = Some(AudioState {
                _stream: stream,
                stream_handle: handle,
                sounds: HashMap::new(),
                sinks: Vec::new(),
            });
        }
    });
}

fn with_audio<F, T>(f: F) -> Result<T, String>
where
    F: FnOnce(&mut AudioState) -> Result<T, String>,
{
    ensure_init();
    AUDIO.with(|cell| {
        let mut borrow = cell.borrow_mut();
        let state = borrow
            .as_mut()
            .ok_or_else(|| "Audio not available".to_string())?;
        f(state)
    })
}

/// Load a sound file into memory and return a handle.
pub fn load_sound(path: &str) -> Result<u64, String> {
    let data = std::fs::read(path).map_err(|e| format!("Failed to read {path}: {e}"))?;
    with_audio(|state| {
        let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
        state.sounds.insert(handle, data.clone());
        Ok(handle)
    })
}

/// Play a loaded sound with the given volume (0.0..1.0) and optional looping.
pub fn play_sound(handle: u64, volume: f32, looping: bool) -> Result<(), String> {
    with_audio(|state| {
        let data = state
            .sounds
            .get(&handle)
            .ok_or_else(|| format!("Unknown sound handle: {handle}"))?;

        let cursor = std::io::Cursor::new(data.clone());
        let source = Decoder::new(BufReader::new(cursor))
            .map_err(|e| format!("Failed to decode sound: {e}"))?;

        let sink = Sink::try_new(&state.stream_handle)
            .map_err(|e| format!("Failed to create sink: {e}"))?;
        sink.set_volume(volume);

        if looping {
            sink.append(source.repeat_infinite());
        } else {
            sink.append(source);
        }

        state.sinks.retain(|s| !s.empty());
        state.sinks.push(sink);
        Ok(())
    })
}

/// Stop all currently playing sounds.
pub fn stop_all() {
    let _ = with_audio(|state| {
        for sink in &state.sinks {
            sink.stop();
        }
        state.sinks.clear();
        Ok(())
    });
}

/// Unload a sound and free its memory.
pub fn unload_sound(handle: u64) {
    let _ = with_audio(|state| {
        state.sounds.remove(&handle);
        Ok(())
    });
}
