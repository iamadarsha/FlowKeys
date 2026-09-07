// ============================================================
// FILE: Sources/LocalAI/flowkeys_bridging.h
// Single Objective-C bridging header for the Local AI C ABIs.
// swiftc accepts only one -import-objc-header, so both bridges live here.
// llama_bridge symbols exist only when the app is built with LOCAL_LLM=1.
// ============================================================

#import "CWhisper/whisper_bridge.h"

#if defined(FLK_LOCAL_LLM)
#import "CLlama/llama_bridge.h"
#endif
