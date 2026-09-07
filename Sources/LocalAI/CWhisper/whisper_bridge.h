// ============================================================
// FILE: Sources/LocalAI/CWhisper/whisper_bridge.h
// FlowKeys — Local AI (Phase 2 + Phase 3 VAD)
//
// Tiny, stable C ABI over whisper.cpp (pinned: vendor/whisper.cpp @ v1.9.3).
// The Swift side only ever sees this header — never whisper.h / ggml.h directly.
// Passed to swiftc via `-import-objc-header`.
// ============================================================

#ifndef FLK_WHISPER_BRIDGE_H
#define FLK_WHISPER_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct flk_whisper_ctx flk_whisper_ctx;

/// Progress callback: `percent` in 0..100, called from whisper's compute thread.
typedef void (*flk_progress_fn)(int percent, void *user_data);

/// Load a ggml Whisper model from disk. Returns NULL on failure
/// (call flk_whisper_last_error() for a message). `n_threads <= 0` → auto.
flk_whisper_ctx *flk_whisper_open(const char *model_path, int n_threads);

/// Transcribe mono 16 kHz float PCM in [-1, 1].
///   language:       "en" / "hi" / "bn" / ... or NULL to auto-detect.
///   initial_prompt: nullable decoder priming text (anti-hallucination / vocab).
///   translate:      0 = transcribe in source language, 1 = translate to English.
///   vad_model_path: nullable. When set, whisper.cpp runs Silero VAD first —
///                   trims silence and exposes speech segments (see below).
/// Returns a newly-allocated UTF-8 C string (free with flk_whisper_string_free),
/// or NULL on failure.
char *flk_whisper_transcribe(flk_whisper_ctx *ctx,
                             const float *samples,
                             int n_samples,
                             const char *language,
                             const char *initial_prompt,
                             int translate,
                             const char *vad_model_path,
                             flk_progress_fn on_progress,
                             void *progress_user_data);

/// Auto-detected language of the last transcription ("" if none / unknown).
const char *flk_whisper_detected_language(flk_whisper_ctx *ctx);

/// Number of text segments from the last transcription.
int flk_whisper_segment_count(flk_whisper_ctx *ctx);
/// Segment `i` timing in centiseconds on the original audio timeline,
/// and its text (borrowed, valid until the next transcribe). Returns 0 on bad index.
int flk_whisper_segment(flk_whisper_ctx *ctx, int i,
                        int64_t *out_t0_cs, int64_t *out_t1_cs,
                        const char **out_text);

/// VAD speech segments from the last transcription (0 unless a vad_model_path
/// was supplied). Times are centiseconds on the original timeline.
int flk_whisper_vad_segment_count(flk_whisper_ctx *ctx);
int flk_whisper_vad_segment(flk_whisper_ctx *ctx, int i,
                            int64_t *out_t0_cs, int64_t *out_t1_cs);

void flk_whisper_string_free(char *s);
void flk_whisper_close(flk_whisper_ctx *ctx);

/// Thread-local last error string ("" if none).
const char *flk_whisper_last_error(void);
/// whisper.cpp version string (for diagnostics / Run Log).
const char *flk_whisper_version(void);

#ifdef __cplusplus
}
#endif

#endif // FLK_WHISPER_BRIDGE_H
