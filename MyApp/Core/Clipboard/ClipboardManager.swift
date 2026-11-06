import AppKit
import Combine

@MainActor
final class ClipboardManager: ObservableObject {

    // MARK: - Item

    struct ClipboardItem:
        Identifiable,
        Equatable {

        enum Kind:
            Equatable {

            case text
            case file
        }

        let id:
            UUID

        let kind:
            Kind

        let text:
            String?

        let fileURL:
            URL?

        let copiedAt:
            Date

        // MARK: Display

        var preview:
            String {

            switch kind {

            case .text:

                let value =
                    text
                    ?? ""

                let cleaned =
                    value
                        .replacingOccurrences(
                            of: "\n",
                            with: " "
                        )
                        .replacingOccurrences(
                            of: "\t",
                            with: " "
                        )
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                guard
                    cleaned.count > 70
                else {
                    return cleaned
                }

                return String(
                    cleaned.prefix(
                        70
                    )
                )
                + "…"

            case .file:

                return fileURL?
                    .lastPathComponent
                    ?? "File"
            }
        }

        var subtitle:
            String? {

            switch kind {

            case .text:
                return nil

            case .file:

                guard let fileURL else {
                    return nil
                }

                return fileURL
                    .deletingLastPathComponent()
                    .path
            }
        }

        var systemImage:
            String {

            switch kind {

            case .text:

                return "doc.on.doc"

            case .file:

                guard let fileURL else {
                    return "doc.fill"
                }

                var isDirectory:
                    ObjCBool = false

                FileManager.default
                    .fileExists(
                        atPath:
                            fileURL.path,
                        isDirectory:
                            &isDirectory
                    )

                if isDirectory.boolValue {

                    return "folder.fill"
                }

                let ext =
                    fileURL
                        .pathExtension
                        .lowercased()

                switch ext {

                case "png",
                     "jpg",
                     "jpeg",
                     "gif",
                     "heic",
                     "webp",
                     "tiff":

                    return "photo.fill"

                case "pdf":

                    return "doc.richtext.fill"

                case "zip",
                     "rar",
                     "7z",
                     "tar",
                     "gz":

                    return "archivebox.fill"

                case "mp3",
                     "wav",
                     "m4a",
                     "aac",
                     "flac":

                    return "music.note"

                case "mp4",
                     "mov",
                     "mkv",
                     "avi":

                    return "film.fill"

                default:

                    return "doc.fill"
                }
            }
        }

        // MARK: Identity

        var identityKey:
            String {

            switch kind {

            case .text:

                return "text:"
                    + (
                        text
                        ?? ""
                    )

            case .file:

                return "file:"
                    + (
                        fileURL?
                            .standardizedFileURL
                            .path
                        ?? ""
                    )
            }
        }
    }

    // MARK: - Published State

    @Published
    private(set) var items:
        [ClipboardItem] = []

    // MARK: - Configuration

    private let maximumItems =
        10

    private let pasteboard =
        NSPasteboard.general

    // MARK: - Monitoring

    private var timer:
        Timer?

    private var lastChangeCount:
        Int

    // MARK: - Init

    init() {

        lastChangeCount =
            pasteboard.changeCount

        startMonitoring()
    }

    deinit {

        timer?
            .invalidate()
    }

    // MARK: - Monitoring

    private func startMonitoring() {

        let timer =
            Timer.scheduledTimer(
                withTimeInterval:
                    0.50,
                repeats:
                    true
            ) { [weak self] _ in

                Task { @MainActor in

                    self?
                        .checkClipboard()
                }
            }

        RunLoop.main.add(
            timer,
            forMode:
                .common
        )

        self.timer =
            timer
    }

    private func checkClipboard() {

        let currentChangeCount =
            pasteboard.changeCount

        guard
            currentChangeCount
                != lastChangeCount
        else {
            return
        }

        lastChangeCount =
            currentChangeCount

        /*
         Prima controlliamo i file.

         Il Finder spesso espone anche
         rappresentazioni testuali dei file.
         Se trovassimo prima .string,
         rischieremmo quindi di aggiungere
         una voce testuale invece del file vero.
         */

        let fileURLs =
            readFileURLs()

        if !fileURLs.isEmpty {

            addFiles(
                fileURLs
            )

            return
        }

        // Altrimenti proviamo il testo.

        guard
            let text =
                pasteboard.string(
                    forType:
                        .string
                )
        else {
            return
        }

        addText(
            text
        )
    }

    // MARK: - Read Files

    private func readFileURLs()
        -> [URL] {

        let options:
            [NSPasteboard.ReadingOptionKey: Any] = [

                .urlReadingFileURLsOnly:
                    true
            ]

        guard
            let objects =
                pasteboard.readObjects(
                    forClasses: [
                        NSURL.self
                    ],
                    options:
                        options
                )
        else {
            return []
        }

        return objects.compactMap {

            if let url =
                $0 as? URL {

                return url
            }

            if let nsURL =
                $0 as? NSURL {

                return nsURL as URL
            }

            return nil
        }
        .filter {

            $0.isFileURL
        }
    }

    // MARK: - Add Text

    private func addText(
        _ text: String
    ) {

        let trimmed =
            text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !trimmed.isEmpty
        else {
            return
        }

        let item =
            ClipboardItem(
                id:
                    UUID(),

                kind:
                    .text,

                text:
                    text,

                fileURL:
                    nil,

                copiedAt:
                    Date()
            )

        insert(
            item
        )
    }

    // MARK: - Add Files

    private func addFiles(
        _ urls: [URL]
    ) {

        /*
         Se copi più file dal Finder,
         li registriamo tutti.

         Inseriamo in ordine inverso
         perché insert() mette sempre
         la nuova voce in posizione 0.
         */

        for url in urls.reversed() {

            let normalizedURL =
                url
                    .standardizedFileURL

            let item =
                ClipboardItem(
                    id:
                        UUID(),

                    kind:
                        .file,

                    text:
                        nil,

                    fileURL:
                        normalizedURL,

                    copiedAt:
                        Date()
                )

            insert(
                item
            )
        }
    }

    // MARK: - Insert

    private func insert(
        _ item: ClipboardItem
    ) {

        /*
         Deduplica.

         Se esiste già lo stesso testo
         o lo stesso file, lo rimuoviamo
         e lo riportiamo in cima.
         */

        items.removeAll {

            $0.identityKey
                == item.identityKey
        }

        items.insert(
            item,
            at:
                0
        )

        if items.count
            > maximumItems {

            items =
                Array(
                    items.prefix(
                        maximumItems
                    )
                )
        }
    }

    // MARK: - Copy Item

    func copy(
        _ item: ClipboardItem
    ) {

        switch item.kind {

        case .text:

            guard
                let text =
                    item.text
            else {
                return
            }

            copyText(
                text
            )

        case .file:

            guard
                let fileURL =
                    item.fileURL
            else {
                return
            }

            copyFile(
                fileURL
            )
        }
    }

    // MARK: - Copy Text

    private func copyText(
        _ text: String
    ) {

        pasteboard.clearContents()

        pasteboard.setString(
            text,
            forType:
                .string
        )

        lastChangeCount =
            pasteboard.changeCount

        addText(
            text
        )
    }

    // MARK: - Copy File

    private func copyFile(
        _ url: URL
    ) {

        pasteboard.clearContents()

        pasteboard.writeObjects(
            [
                url as NSURL
            ]
        )

        lastChangeCount =
            pasteboard.changeCount

        let item =
            ClipboardItem(
                id:
                    UUID(),

                kind:
                    .file,

                text:
                    nil,

                fileURL:
                    url,

                copiedAt:
                    Date()
            )

        insert(
            item
        )
    }

    // MARK: - Remove

    func remove(
        _ item: ClipboardItem
    ) {

        items.removeAll {

            $0.id
                == item.id
        }
    }

    // MARK: - Clear

    func clearHistory() {

        /*
         Cancella solamente la cronologia
         interna di Dynamic Notch.

         Non tocchiamo il contenuto corrente
         della clipboard di macOS.
         */

        items.removeAll()
    }
}
