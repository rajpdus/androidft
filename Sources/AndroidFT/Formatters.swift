import Foundation

enum Format {
    /// Same thresholds and precision as the original app's size strings.
    static func size(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        switch b {
        case ..<1024: return String(format: "%.0f bytes", b)
        case ..<1_048_576: return String(format: "%.0f KB", b / 1024)
        case ..<1_073_741_824: return String(format: "%.1f MB", b / 1_048_576)
        case ..<1_099_511_627_776: return String(format: "%.2f GB", b / 1_073_741_824)
        case ..<1_125_899_906_842_624: return String(format: "%.3f TB", b / 1_099_511_627_776)
        default: return String(format: "%.3f PB", b / 1_125_899_906_842_624)
        }
    }

    static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func date(_ d: Date?) -> String { d.map { date.string(from: $0) } ?? "--" }

    static func timeRemaining(_ seconds: TimeInterval?) -> String {
        guard let s = seconds, s.isFinite, s >= 0 else { return "Estimating time remaining…" }
        switch s {
        case ..<5: return "Less than 5 seconds remaining"
        case ..<15: return "Less than 15 seconds remaining"
        case ..<30: return "Less than 30 seconds remaining"
        case ..<90: return "About 1 minute remaining"
        case ..<3600: return "About \(Int((s / 60).rounded())) minutes remaining"
        case ..<5400: return "About 1 hour remaining"
        default: return "About \(Int((s / 3600).rounded())) hours remaining"
        }
    }
}
