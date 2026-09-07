// ============================================================
// FILE: Sources/LocalAI/CWhisper/whisper_bridge.cpp
// FlowKeys — Local AI (Phase 2)
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
    // Leave headroom; cap at 8 — more rarely helps on dictation-length audio.
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
    // CPU + Accelerate build for Phase 2 (universal). GPU flag is harmless if unused.
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
                             int translate) {
    g_last_error.clear();
    if (!ctx || !ctx->wctx) { set_error("null context"); return nullptr; }
    if (!samples || n_samples <= 0) { set_error("no audio samples"); return nullptr; }

    whisper_full_params wparams =
        whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    wparams.n_threads         = ctx->n_threads;
    wparams.translate         = translate != 0;
    wparams.no_timestamps     = true;
    wparams.print_progress    = false;
    wparams.print_realtime    = false;
    wparams.print_timestamps  = false;
    wparams.print_special     = false;
    wparams.suppress_blank    = true;
    wparams.suppress_nst      = true;   // suppress non-speech tokens
    wparams.temperature       = 0.0f;
    wparams.no_context        = true;   // each dictation is independent

    const bool auto_lang =
        (language == nullptr || language[0] == '\0' ||
         std::strcmp(language, "auto") == 0);
    wparams.language        = auto_lang ? "auto" : language;
    wparams.detect_language = auto_lang;

    if (initial_prompt && initial_prompt[0] != '\0') {
        wparams.initial_prompt = initial_prompt;
    }

    const int rc = whisper_full(ctx->wctx, wparams, samples, n_samples);
    if (rc != 0) {
        set_error("whisper_full failed");
        return nullptr;
    }

    // Record detected language.
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

    // Trim leading/trailing whitespace (whisper pads a leading space).
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
