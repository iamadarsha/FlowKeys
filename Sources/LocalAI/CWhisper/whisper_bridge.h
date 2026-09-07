// ============================================================
// FILE: Sources/LocalAI/CWhisper/whisper_bridge.h
// FlowKeys — Local AI (Phase 2)
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

/// Load a ggml Whisper model from disk. Returns NULL on failure
/// (call flk_whisper_last_error() for a message). `n_threads <= 0` → auto.
flk_whisper_ctx *flk_whisper_open(const char *model_path, int n_threads);

/// Transcribe mono 16 kHz float PCM in [-1, 1].
///   language:       "en" / "hi" / "bn" / ... or NULL to auto-detect.
///   initial_prompt: nullable decoder priming text (anti-hallucination / vocab).
///   translate:      0 = transcribe in source language, 1 = translate to English.
/// Returns a newly-allocated UTF-8 C string (free with flk_whisper_string_free),
/// or NULL on failure.
char *flk_whisper_transcribe(flk_whisper_ctx *ctx,
                             const float *samples,
                             int n_samples,
                             const char *language,
                             const char *initial_prompt,
                             int translate);

/// Auto-detected language of the last transcription ("" if none / unknown).
/// Valid until the next flk_whisper_transcribe on the same ctx.
const char *flk_whisper_detected_language(flk_whisper_ctx *ctx);

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
