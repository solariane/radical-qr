import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Bytes of an image chosen in a `PhotosPicker`.
///
/// Asking for `Data.self` directly fails — "Given Transferable item does not
/// support import" — even when the item advertises `public.png`, because `Data`
/// names no content type for the two sides to agree on. Declaring the imported
/// type is what makes the transfer happen.
struct PickedImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        // Concrete types first: matching only the abstract `.image` is refused
        // with "Given Transferable item does not support import", even for an
        // item that advertises public.png.
        DataRepresentation(importedContentType: .png) { PickedImage(data: $0) }
        DataRepresentation(importedContentType: .jpeg) { PickedImage(data: $0) }
        DataRepresentation(importedContentType: .heic) { PickedImage(data: $0) }
        DataRepresentation(importedContentType: .tiff) { PickedImage(data: $0) }
        DataRepresentation(importedContentType: .image) { PickedImage(data: $0) }
    }
}
