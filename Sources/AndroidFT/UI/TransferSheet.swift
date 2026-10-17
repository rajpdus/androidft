import SwiftUI

struct TransferSheet: View {
    let transfer: Transfer
    let onCancel: () -> Void
    @State private var tick = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: transfer.direction == .download ? "arrow.down.doc" : "arrow.up.doc")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(transfer.title).font(.headline).lineLimit(1).truncationMode(.middle)
                    if transfer.preflightComplete {
                        ProgressView(value: transfer.fraction)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                    Text(transfer.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(height: 14)
                }
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(transfer.cancelled)
                .help("Cancel")
            }
        }
        .padding(20)
        .frame(width: 480)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick = $0 }
        .id(tick)   // refresh the time-remaining text once a second
    }
}
