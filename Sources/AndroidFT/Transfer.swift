import Foundation
import Observation

/// Progress state for the copy sheet. Mirrors CopyStatusViewController
/// (bytesToCopy, filesCompletedBytesCopied, fileInProgressBytesCopied, startTime).
@Observable @MainActor
final class Transfer: Identifiable {
    let id = UUID()
    enum Direction { case download, upload }

    let direction: Direction
    let destinationName: String
    var itemCount = 0
    var currentName = ""
    var bytesTotal: UInt64 = 0
    var bytesCompleted: UInt64 = 0      // from finished files
    var bytesInProgress: UInt64 = 0     // from the file being copied
    var preflightComplete = false
    var cancelled = false
    let startTime = Date()

    init(direction: Direction, destinationName: String) {
        self.direction = direction
        self.destinationName = destinationName
    }

    var bytesCopied: UInt64 { bytesCompleted + bytesInProgress }

    var title: String {
        if cancelled { return "Canceling" }
        if !preflightComplete { return "Preparing to copy to \"\(destinationName)\"" }
        if itemCount == 1 { return "Copying \"\(currentName)\" to \"\(destinationName)\"" }
        return "Copying \(itemCount) items to \"\(destinationName)\""
    }

    var detail: String {
        guard preflightComplete, bytesTotal > 0 else { return "" }
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining: TimeInterval? = bytesCopied > 0 && elapsed > 2
            ? elapsed * Double(bytesTotal - bytesCopied) / Double(bytesCopied) : nil
        return "\(Format.size(bytesCopied)) of \(Format.size(bytesTotal)) - \(Format.timeRemaining(remaining))"
    }

    var fraction: Double { bytesTotal == 0 ? 0 : Double(bytesCopied) / Double(bytesTotal) }
}

enum ReplaceChoice { case replace, replaceAll, skip }
