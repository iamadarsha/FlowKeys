// ============================================================
// FILE: Sources/LocalAI/CLlama/llama_bridge.h
// FlowKeys — Local AI (Phase 4b)
//
// Tiny C ABI over llama.cpp (pinned: vendor/llama.cpp @ v0.4.0) for on-device
// text cleanup with a small model (Qwen3-0.6B). llama.cpp is linked as a
// dylib bundled in Contents/Frameworks/ so its ggml 0.23 does not collide with
// whisper.cpp's static ggml 0.20.
// ============================================================

#ifndef FLK_LLAMA_BRIDGE_H
#define FLK_LLAMA_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct flk_llama_ctx flk_llama_ctx;

/// Load a GGUF model. `n_ctx` 0 → 4096. `n_threads` <= 0 → auto.
flk_llama_ctx *flk_llama_open(const char *model_path, int n_ctx, int n_threads);

/// Deterministic (greedy) chat completion. Returns a newly-allocated UTF-8
/// string (free with flk_llama_string_free) or NULL on failure.
char *flk_llama_generate(flk_llama_ctx *ctx,
                         const char *system_prompt,
                         const char *user_prompt,
                         int max_tokens);

void flk_llama_string_free(char *s);
void flk_llama_close(flk_llama_ctx *ctx);

const char *flk_llama_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // FLK_LLAMA_BRIDGE_H
