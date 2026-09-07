// ============================================================
// FILE: Sources/LocalAI/CLlama/llama_bridge.cpp
// FlowKeys — Local AI (Phase 4b)
// ============================================================

#include "llama_bridge.h"
#include "llama.h"

#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <thread>
#include <mutex>

namespace {

thread_local std::string g_last_error;
std::once_flag g_backend_once;

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
    return n > 8 ? 8 : n;
}

std::string piece(const llama_vocab *vocab, llama_token tok) {
    char buf[256];
    int n = llama_token_to_piece(vocab, tok, buf, sizeof(buf), 0, true);
    if (n < 0) return {};
    return std::string(buf, n);
}

} // namespace

struct flk_llama_ctx {
    llama_model   *model = nullptr;
    llama_context *lctx  = nullptr;
    const llama_vocab *vocab = nullptr;
    int n_threads = 4;
};

extern "C" {

flk_llama_ctx *flk_llama_open(const char *model_path, int n_ctx, int n_threads) {
    g_last_error.clear();
    if (!model_path || !model_path[0]) { set_error("empty model path"); return nullptr; }

    std::call_once(g_backend_once, []{ llama_backend_init(); });

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = 0;             // CPU only (universal)

    llama_model *model = llama_model_load_from_file(model_path, mparams);
    if (!model) { set_error("failed to load model"); return nullptr; }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx     = n_ctx > 0 ? (uint32_t)n_ctx : 4096;
    cparams.n_batch   = 512;
    cparams.n_threads = resolve_threads(n_threads);
    cparams.n_threads_batch = cparams.n_threads;

    llama_context *lctx = llama_init_from_model(model, cparams);
    if (!lctx) {
        llama_model_free(model);
        set_error("failed to create context");
        return nullptr;
    }

    auto *c = new (std::nothrow) flk_llama_ctx();
    if (!c) { llama_free(lctx); llama_model_free(model); set_error("oom"); return nullptr; }
    c->model = model;
    c->lctx = lctx;
    c->vocab = llama_model_get_vocab(model);
    c->n_threads = cparams.n_threads;
    return c;
}

char *flk_llama_generate(flk_llama_ctx *c,
                         const char *system_prompt,
                         const char *user_prompt,
                         int max_tokens) {
    g_last_error.clear();
    if (!c || !c->lctx) { set_error("null context"); return nullptr; }
    if (max_tokens <= 0) max_tokens = 1024;

    // Build the prompt with the model's chat template.
    std::vector<llama_chat_message> msgs;
    if (system_prompt && system_prompt[0])
        msgs.push_back({"system", system_prompt});
    msgs.push_back({"user", user_prompt ? user_prompt : ""});

    const char *tmpl = llama_model_chat_template(c->model, nullptr);
    std::string prompt;
    prompt.resize(8192);
    int n = llama_chat_apply_template(tmpl, msgs.data(), msgs.size(), true,
                                     prompt.data(), (int32_t)prompt.size());
    if (n > (int)prompt.size()) {
        prompt.resize(n);
        n = llama_chat_apply_template(tmpl, msgs.data(), msgs.size(), true,
                                     prompt.data(), (int32_t)prompt.size());
    }
    if (n < 0) { set_error("chat template failed"); return nullptr; }
    prompt.resize(n);

    // Tokenize.
    std::vector<llama_token> tokens(prompt.size() + 16);
    int32_t nt = llama_tokenize(c->vocab, prompt.c_str(), (int32_t)prompt.size(),
                                tokens.data(), (int32_t)tokens.size(), true, true);
    if (nt < 0) {
        tokens.resize(-nt);
        nt = llama_tokenize(c->vocab, prompt.c_str(), (int32_t)prompt.size(),
                            tokens.data(), (int32_t)tokens.size(), true, true);
    }
    if (nt <= 0) { set_error("tokenize failed"); return nullptr; }
    tokens.resize(nt);

    // Fresh KV cache for this request.
    llama_memory_clear(llama_get_memory(c->lctx), true);

    llama_batch batch = llama_batch_get_one(tokens.data(), (int32_t)tokens.size());
    if (llama_decode(c->lctx, batch) != 0) { set_error("decode(prompt) failed"); return nullptr; }

    // Greedy sampler chain.
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_greedy());

    std::string out;
    llama_token id = 0;
    for (int i = 0; i < max_tokens; ++i) {
        id = llama_sampler_sample(smpl, c->lctx, -1);
        if (llama_vocab_is_eog(c->vocab, id)) break;
        out += piece(c->vocab, id);
        if (out.size() > 32768) break;   // safety
        llama_batch nb = llama_batch_get_one(&id, 1);
        if (llama_decode(c->lctx, nb) != 0) { set_error("decode(step) failed"); break; }
    }

    llama_sampler_free(smpl);

    // Strip any <think>…</think> reasoning block (Qwen3 hybrid-reasoning models).
    {
        size_t ts = out.find("<think>");
        if (ts != std::string::npos) {
            size_t te = out.find("</think>", ts);
            if (te != std::string::npos) out.erase(ts, te - ts + 8);
            else out.erase(ts);          // unterminated → drop the rest
        }
    }

    // Trim.
    size_t b = out.find_first_not_of(" \t\r\n");
    size_t e = out.find_last_not_of(" \t\r\n");
    if (b == std::string::npos) out.clear();
    else out = out.substr(b, e - b + 1);

    return dup_cstr(out);
}

void flk_llama_string_free(char *s) { std::free(s); }

void flk_llama_close(flk_llama_ctx *c) {
    if (!c) return;
    if (c->lctx)  llama_free(c->lctx);
    if (c->model) llama_model_free(c->model);
    delete c;
}

const char *flk_llama_last_error(void) { return g_last_error.c_str(); }

} // extern "C"
