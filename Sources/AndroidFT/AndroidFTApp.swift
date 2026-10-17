import SwiftUI

@main
struct AndroidFTApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("AndroidFT") {
            ContentView()
                .environment(model)
                .frame(minWidth: 640, minHeight: 400)
                .onAppear { model.start() }
        }
        .defaultSize(width: 860, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Folder") { model.newFolder() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(model.state != .connected)
                Button("Open") { model.openSelection() }
                    .keyboardShortcut("o")
                    .disabled(model.selection.isEmpty)
            }
            CommandGroup(after: .pasteboard) {
                Button("Delete") { model.deleteSelection() }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(model.selection.isEmpty || model.transfer != nil)
            }
            CommandMenu("Go") {
                Button("Back") { model.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!model.canGoBack)
                Button("Forward") { model.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!model.canGoForward)
                Button("Enclosing Folder") { model.goUp() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                    .disabled(!model.canGoUp)
            }
        }
    }
}
