import SwiftUI
import UniformTypeIdentifiers

/// The bytes of one export, handed to the system save panel (`fileExporter`)
/// so the user picks the name and the folder. Written, never opened.
nonisolated struct ExportedFile: FileDocument {
    static let readableContentTypes: [UTType] = [.png, .jpeg, .pdf, .webP, .svg]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
