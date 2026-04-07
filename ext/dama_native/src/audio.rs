/// Audio playback via rodio. Native-only (not available on wasm).
///
/// Gracefully degrades when no audio device is available: sounds are still
/// loaded and tracked (load_sound returns valid handles), but playback is
/// silently skipped.  This allows headless / CI environments to run without
/// a physical audio output.
///
/// Uses thread_local storage because rodio's OutputStream is not Send/Sync.
/// All audio functions must be called from the main thread.
use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};

use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink, Source};

static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);

struct AudioState {
    /// None when no audio output device is available (headless / CI).
    output: Option<AudioOutput>,
    sounds: HashMap<u64, Vec<u8>>,
}

struct AudioOutput {
    _stream: OutputStream,
    stream_handle: OutputStreamHandle,
    sinks: Vec<Sink>,
}

thread_local! {
    static AUDIO: RefCell<Option<AudioState>> = const { RefCell::new(None) };
}

/// Initialize the audio system. Called automatically on first use.
/// When no audio device is present the state is still created (with
/// output = None) so that load_sound can store data.
fn ensure_init() {
    AUDIO.with(|cell| {
        if cell.borrow().is_some() {
            return;
        }
        let output = OutputStream::try_default()
            .ok()
            .map(|(stream, handle)| AudioOutput {
                _stream: stream,
                stream_handle: handle,
                sinks: Vec::new(),
            });
        *cell.borrow_mut() = Some(AudioState {
            output,
            sounds: HashMap::new(),
        });
    });
}

fn with_state<F, T>(f: F) -> Result<T, String>
where
    F: FnOnce(&mut AudioState) -> Result<T, String>,
{
    ensure_init();
    AUDIO.with(|cell| {
        let mut borrow = cell.borrow_mut();
        let state = borrow
            .as_mut()
            .ok_or_else(|| "Audio state not initialized".to_string())?;
        f(state)
    })
}

/// Load a sound file into memory and return a handle.
/// Works even without an audio device — the data is stored for later use.
pub fn load_sound(path: &str) -> Result<u64, String> {
    let data = std::fs::read(path).map_err(|e| format!("Failed to read {path}: {e}"))?;
    with_state(|state| {
        let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
        state.sounds.insert(handle, data.clone());
        Ok(handle)
    })
}

/// Play a loaded sound with the given volume (0.0..1.0) and optional looping.
/// Silently succeeds when no audio device is available.
pub fn play_sound(handle: u64, volume: f32, looping: bool) -> Result<(), String> {
    with_state(|state| {
        let data = state
            .sounds
            .get(&handle)
            .ok_or_else(|| format!("Unknown sound handle: {handle}"))?;

        let output = match state.output.as_mut() {
            Some(o) => o,
            None => return Ok(()),
        };

        let cursor = std::io::Cursor::new(data.clone());
        let source = Decoder::new(std::io::BufReader::new(cursor))
            .map_err(|e| format!("Failed to decode sound: {e}"))?;

        let sink = Sink::try_new(&output.stream_handle)
            .map_err(|e| format!("Failed to create sink: {e}"))?;
        sink.set_volume(volume);

        if looping {
            sink.append(source.repeat_infinite());
        } else {
            sink.append(source);
        }

        output.sinks.retain(|s| !s.empty());
        output.sinks.push(sink);
        Ok(())
    })
}

/// Stop all currently playing sounds.
pub fn stop_all() {
    let _ = with_state(|state| {
        if let Some(output) = state.output.as_mut() {
            for sink in &output.sinks {
                sink.stop();
            }
            output.sinks.clear();
        }
        Ok(())
    });
}

/// Unload a sound and free its memory.
pub fn unload_sound(handle: u64) {
    let _ = with_state(|state| {
        state.sounds.remove(&handle);
        Ok(())
    });
}
