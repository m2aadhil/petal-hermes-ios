import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel
    var body: some View {
        Group {
            if model.connections.isEmpty && !model.demo {
                OnboardingView(model: model)
            } else {
                ChatView(model: model)
            }
        }
        .background(DS.Palette.background)
        .alert(Text(verbatim: "Petal"), isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("Got it", role: .cancel) { model.notice = nil }
        } message: { Text(model.notice ?? "") }
    }
}
