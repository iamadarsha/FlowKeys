// ============================================================
// FILE: Sources/LocalAI/CSherpa/sherpa_bridge.cpp
// FlowKeys — Local AI (Phase 4c)
// ============================================================

#include "sherpa_bridge.h"
#include "sherpa-onnx/c-api/c-api.h"

#include <string>
#include <cstring>
#include <cstdlib>
#include <thread>

namespace {
thread_local std::string g_last_error;
void set_error(const char *m) { g_last_error = m ? m : ""; }

char *dup_cstr(const std::string &s) {
    char *out = static_cast<char *>(std::malloc(s.size() + 1));
    if (!out) return nullptr;
    std::memcpy(out, s.c_str(), s.size() + 1);
    return out;
}

int resolve_threads(int req) {
    if (req > 0) return req;
    unsigned hw = std::thread::hardware_concurrency();
    if (hw == 0) return 4;
    int n = static_cast<int>(hw > 2 ? hw - 1 : hw);
    return n > 6 ? 6 : n;
}
} // namespace

struct flk_sherpa_ctx {
    const SherpaOnnxOfflineRecognizer *rec = nullptr;
    std::string model_path;
    std::string tokens_path;
};

extern "C" {

flk_sherpa_ctx *flk_sherpa_open(const char *model_path,
                                const char *tokens_path,
                                int n_threads) {
    g_last_error.clear();
    if (!model_path || !model_path[0] || !tokens_path || !tokens_path[0]) {
        set_error("empty model or tokens path");
        return nullptr;
    }

    SherpaOnnxOfflineRecognizerConfig config;
    std::memset(&config, 0, sizeof(config));

    config.feat_config.sample_rate = 16000;
    config.feat_config.feature_dim = 80;

    config.model_config.nemo_ctc.model = model_path;
    config.model_config.tokens         = tokens_path;
    config.model_config.num_threads    = resolve_threads(n_threads);
    config.model_config.provider       = "cpu";
    config.model_config.debug          = 0;

    config.decoding_method = "greedy_search";

    const SherpaOnnxOfflineRecognizer *rec = SherpaOnnxCreateOfflineRecognizer(&config);
    if (!rec) {
        set_error("SherpaOnnxCreateOfflineRecognizer failed (bad model / tokens)");
        return nullptr;
    }

    auto *ctx = new (std::nothrow) flk_sherpa_ctx();
    if (!ctx) {
        SherpaOnnxDestroyOfflineRecognizer(rec);
        set_error("out of memory");
        return nullptr;
    }
    ctx->rec = rec;
    ctx->model_path = model_path;
    ctx->tokens_path = tokens_path;
    return ctx;
}

char *flk_sherpa_transcribe(flk_sherpa_ctx *ctx, const float *samples, int n_samples) {
    g_last_error.clear();
    if (!ctx || !ctx->rec) { set_error("null context"); return nullptr; }
    if (!samples || n_samples <= 0) { set_error("no audio"); return nullptr; }

    const SherpaOnnxOfflineStream *stream = SherpaOnnxCreateOfflineStream(ctx->rec);
    if (!stream) { set_error("could not create stream"); return nullptr; }

    SherpaOnnxAcceptWaveformOffline(stream, 16000, samples, n_samples);
    SherpaOnnxDecodeOfflineStream(ctx->rec, stream);

    const SherpaOnnxOfflineRecognizerResult *result =
        SherpaOnnxGetOfflineStreamResult(stream);

    std::string text;
    if (result && result->text) text = result->text;

    if (result) SherpaOnnxDestroyOfflineRecognizerResult(result);
    SherpaOnnxDestroyOfflineStream(stream);

    // Trim.
    size_t b = text.find_first_not_of(" \t\r\n");
    size_t e = text.find_last_not_of(" \t\r\n");
    if (b == std::string::npos) text.clear();
    else text = text.substr(b, e - b + 1);

    return dup_cstr(text);
}

void flk_sherpa_string_free(char *s) { std::free(s); }

void flk_sherpa_close(flk_sherpa_ctx *ctx) {
    if (!ctx) return;
    if (ctx->rec) SherpaOnnxDestroyOfflineRecognizer(ctx->rec);
    delete ctx;
}

const char *flk_sherpa_last_error(void) { return g_last_error.c_str(); }
const char *flk_sherpa_version(void) { return "sherpa-onnx v1.13.7"; }

} // extern "C"
