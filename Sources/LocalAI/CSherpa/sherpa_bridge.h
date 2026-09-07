// ============================================================
// FILE: Sources/LocalAI/CSherpa/sherpa_bridge.h
// FlowKeys — Local AI (Phase 4c)
//
// Tiny C ABI over sherpa-onnx (pinned: vendor/sherpa-onnx @ v1.13.7) for
// on-device Hindi/Bengali ASR with AI4Bharat's IndicConformer (NeMo CTC ONNX).
// sherpa-onnx statically links a universal ONNX Runtime — no dylib, no ggml
// collision with whisper.cpp.
// ============================================================

#ifndef FLK_SHERPA_BRIDGE_H
#define FLK_SHERPA_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct flk_sherpa_ctx flk_sherpa_ctx;

/// Load a NeMo-CTC ONNX model + its tokens file. `n_threads <= 0` → auto.
/// Returns NULL on failure (flk_sherpa_last_error()).
flk_sherpa_ctx *flk_sherpa_open(const char *model_path,
                                const char *tokens_path,
                                int n_threads);

/// Transcribe mono 16 kHz float PCM in [-1, 1]. Returns a newly-allocated UTF-8
/// string (free with flk_sherpa_string_free) or NULL on failure.
char *flk_sherpa_transcribe(flk_sherpa_ctx *ctx, const float *samples, int n_samples);

void flk_sherpa_string_free(char *s);
void flk_sherpa_close(flk_sherpa_ctx *ctx);

const char *flk_sherpa_last_error(void);
const char *flk_sherpa_version(void);

#ifdef __cplusplus
}
#endif

#endif // FLK_SHERPA_BRIDGE_H
