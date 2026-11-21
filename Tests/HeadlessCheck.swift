import Foundation

@main struct HeadlessCheck {
    static func main() throws {
        let tools = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for path in CommandLine.arguments.dropFirst(2) {
            let file = URL(fileURLWithPath: path)
            guard let image = HeadlessRenderer.render(file, maxSide: 2048, tools: tools),
                  max(image.width,image.height) >= 600 else {
                throw NSError(domain: "HeadlessCheck", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Il renderer non ha prodotto un'anteprima dettagliata per \(file.lastPathComponent)"
                ])
            }
            print("\(file.lastPathComponent): \(image.width) × \(image.height)")
        }
    }
}
