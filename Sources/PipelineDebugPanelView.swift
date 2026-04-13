import SwiftUI

struct PipelineDebugPanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Rectangle()
                .fill(KM.outline)
                .frame(height: 1)

            ScrollView {
                PipelineDebugContentView(
                    statusMessage: appState.debugStatusMessage,
                    postProcessingStatus: appState.lastPostProcessingStatus,
                    contextSummary: appState.lastContextSummary,
                    contextScreenshotStatus: appState.lastContextScreenshotStatus,
                    contextScreenshotDataURL: appState.lastContextScreenshotDataURL,
                    rawTranscript: appState.lastRawTranscript,
                    postProcessedTranscript: appState.lastPostProcessedTranscript,
                    postProcessingPrompt: appState.lastPostProcessingPrompt
                )
                .padding(16)

                if appState.lastContextSummary.isEmpty && appState.lastRawTranscript.isEmpty {
                    Text("Run a dictation pass to populate debug output.")
                        .font(.system(size: 12))
                        .foregroundColor(KM.muted)
                        .padding(16)
                }
            }
        }
        .background(KM.bg)
        .frame(width: 620, height: 640, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KM.outline, lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KM.accent)
            Text("Pipeline Debug")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KM.onSurface)
            Spacer()
            Text(Date(), style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(KM.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(KM.surface)
    }
}
