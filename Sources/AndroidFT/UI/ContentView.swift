import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.state {
            case .noDevice:
                MessageView(symbol: "iphone.slash",
                            title: "No Android device found",
                            message: "Please connect your Android device with a USB cable to get started.")
            case .connecting:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to \(model.deviceInfo?.displayName ?? "device")…")
                        .foregroundStyle(.secondary)
                }
            case .locked:
                MessageView(symbol: "lock.iphone",
                            title: "Can't access device storage",
                            message: "Make sure your device is unlocked and \"File Transfer\" or \"MTP\" mode is selected.") {
                    Button("Try Again") { model.refreshDevice() }
                }
            case .connected:
                BrowserView()
            }
        }
        .alert(item: $model.alert) { info in
            Alert(title: Text(info.title), message: Text(info.message))
        }
        .sheet(item: $model.transfer) { transfer in
            TransferSheet(transfer: transfer) { model.cancelTransfer() }
        }
    }
}

struct MessageView<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    init(symbol: String, title: String, message: String, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.title2.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
            actions
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
