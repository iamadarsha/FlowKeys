// ============================================================
// FILE: Sources/LocalAI/CWhisper/whisper_bridge.cpp
// FlowKeys — Local AI (Phase 2 + Phase 3 VAD)
//
// Implementation of the tiny C ABI declared in whisper_bridge.h.
// Links against vendor/whisper.cpp (v1.9.3) static libs.
// ============================================================

#include "whisper_bridge.h"
#include "whisper.h"

#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <thread>

namespace {

thread_local std::string g_last_error;

void set_error(const char *msg) { g_last_error = msg ? msg : ""; }

char *dup_cstr(const std::string &s) {
    char *out = static_cast<char *>(std::malloc(s.size() + 1));
    if (!out) return nullptr;
    std::memcpy(out, s.c_str(), s.size() + 1);
    return out;
}

int resolve_threads(int requested) {
    if (requested > 0) return requested;
    unsigned hw = std::thread::hardware_concurrency();
    if (hw == 0) return 4;
    int n = static_cast<int>(hw > 2 ? hw - 1 : hw);
    return n > 8 ? 8 : n;
}

} // namespace

struct flk_whisper_ctx {
    whisper_context *wctx = nullptr;
    int n_threads = 4;
    std::string detected_language;
};

extern "C" {

flk_whisper_ctx *flk_whisper_open(const char *model_path, int n_threads) {
    g_last_error.clear();
    if (!model_path || model_path[0] == '\0') {
        set_error("empty model path");
        return nullptr;
    }

    whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = false;
    cparams.flash_attn = false;

    whisper_context *wctx =
        whisper_init_from_file_with_params(model_path, cparams);
    if (!wctx) {
        set_error("whisper_init_from_file_with_params failed (bad or missing model file)");
        return nullptr;
    }

    auto *ctx = new (std::nothrow) flk_whisper_ctx();
    if (!ctx) {
        whisper_free(wctx);
        set_error("out of memory");
        return nullptr;
    }
    ctx->wctx = wctx;
    ctx->n_threads = resolve_threads(n_threads);
    return ctx;
}

char *flk_whisper_transcribe(flk_whisper_ctx *ctx,
                             const float *samples,
                             int n_samples,
                             const char *language,
                             const char *initial_prompt,
                             int translate,
                             const char *vad_model_path) {
    g_last_error.clear();
    if (!ctx || !ctx->wctx) { set_error("null context"); return nullptr; }
    if (!samples || n_samples <= 0) { set_error("no audio samples"); return nullptr; }

    whisper_full_params wparams =
        whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    wparams.n_threads         = ctx->n_threads;
    wparams.translate         = translate != 0;
    wparams.no_timestamps     = false;  // keep segment timings for pause analysis
    wparams.print_progress    = false;
    wparams.print_realtime    = false;
    wparams.print_timestamps  = false;
    wparams.print_special     = false;
    wparams.suppress_blank    = true;
    wparams.suppress_nst      = true;
    wparams.temperature       = 0.0f;
    wparams.no_context        = true;

    const bool auto_lang =
        (language == nullptr || language[0] == '\0' ||
         std::strcmp(language, "auto") == 0);
    wparams.language        = auto_lang ? "auto" : language;
    wparams.detect_language = auto_lang;

    if (initial_prompt && initial_prompt[0] != '\0') {
        wparams.initial_prompt = initial_prompt;
    }

    if (vad_model_path && vad_model_path[0] != '\0') {
        wparams.vad            = true;
        wparams.vad_model_path = vad_model_path;
        wparams.vad_params     = whisper_vad_default_params();
        // Dictation-tuned: quick end-of-utterance, small pads.
        wparams.vad_params.threshold               = 0.5f;
        wparams.vad_params.min_speech_duration_ms  = 90;
        wparams.vad_params.min_silence_duration_ms = 180;
        wparams.vad_params.speech_pad_ms           = 60;
    }

    const int rc = whisper_full(ctx->wctx, wparams, samples, n_samples);
    if (rc != 0) {
        set_error(vad_model_path ? "whisper_full failed (check VAD model)" : "whisper_full failed");
        return nullptr;
    }

    ctx->detected_language.clear();
    const int lang_id = whisper_full_lang_id(ctx->wctx);
    if (lang_id >= 0) {
        const char *lang = whisper_lang_str(lang_id);
        if (lang) ctx->detected_language = lang;
    }

    std::string text;
    const int n_segments = whisper_full_n_segments(ctx->wctx);
    for (int i = 0; i < n_segments; ++i) {
        const char *seg = whisper_full_get_segment_text(ctx->wctx, i);
        if (seg) text += seg;
    }

    size_t b = text.find_first_not_of(" \t\r\n");
    size_t e = text.find_last_not_of(" \t\r\n");
    if (b == std::string::npos) text.clear();
    else text = text.substr(b, e - b + 1);

    return dup_cstr(text);
}

const char *flk_whisper_detected_language(flk_whisper_ctx *ctx) {
    return (ctx && !ctx->detected_language.empty())
        ? ctx->detected_language.c_str()
        : "";
}

int flk_whisper_segment_count(flk_whisper_ctx *ctx) {
    if (!ctx || !ctx->wctx) return 0;
    return whisper_full_n_segments(ctx->wctx);
}

int flk_whisper_segment(flk_whisper_ctx *ctx, int i,
                        int64_t *out_t0_cs, int64_t *out_t1_cs,
                        const char **out_text) {
    if (!ctx || !ctx->wctx) return 0;
    if (i < 0 || i >= whisper_full_n_segments(ctx->wctx)) return 0;
    if (out_t0_cs) *out_t0_cs = whisper_full_get_segment_t0(ctx->wctx, i);
    if (out_t1_cs) *out_t1_cs = whisper_full_get_segment_t1(ctx->wctx, i);
    if (out_text)  *out_text  = whisper_full_get_segment_text(ctx->wctx, i);
    return 1;
}

int flk_whisper_vad_segment_count(flk_whisper_ctx *ctx) {
    if (!ctx || !ctx->wctx) return 0;
    return whisper_full_n_vad_segments(ctx->wctx);
}

int flk_whisper_vad_segment(flk_whisper_ctx *ctx, int i,
                            int64_t *out_t0_cs, int64_t *out_t1_cs) {
    if (!ctx || !ctx->wctx) return 0;
    if (i < 0 || i >= whisper_full_n_vad_segments(ctx->wctx)) return 0;
    if (out_t0_cs) *out_t0_cs = whisper_full_get_vad_segment_t0(ctx->wctx, i);
    if (out_t1_cs) *out_t1_cs = whisper_full_get_vad_segment_t1(ctx->wctx, i);
    return 1;
}

void flk_whisper_string_free(char *s) { std::free(s); }

void flk_whisper_close(flk_whisper_ctx *ctx) {
    if (!ctx) return;
    if (ctx->wctx) whisper_free(ctx->wctx);
    delete ctx;
}

const char *flk_whisper_last_error(void) { return g_last_error.c_str(); }

const char *flk_whisper_version(void) {
    return "whisper.cpp v1.9.3";
}

} // extern "C"
