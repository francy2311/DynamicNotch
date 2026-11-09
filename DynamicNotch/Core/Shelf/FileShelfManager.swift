import Foundation
import AppKit
import Combine

@MainActor
final class FileShelfManager: ObservableObject {

    // MARK: - Item

    struct ShelfItem:
        Identifiable,
        Equatable {

        let id:
            UUID

        let url:
            URL

        init(
            url:
                URL
        ) {

            self.id =
                UUID()

            self.url =
                url
        }

        var name:
            String {

            url.lastPathComponent
        }

        var path:
            String {

            url
                .deletingLastPathComponent()
                .path
        }

        var isDirectory:
            Bool {

            var isDirectory:
                ObjCBool = false

            FileManager.default
                .fileExists(
                    atPath:
                        url.path,
                    isDirectory:
                        &isDirectory
                )

            return isDirectory.boolValue
        }

        var systemImage:
            String {

            isDirectory
            ? "folder.fill"
            : "doc.fill"
        }
    }

    // MARK: - State

    @Published
    private(set)
    var items:
        [ShelfItem] = []

    // MARK: - Configuration

    private let maximumItems =
        8

    // MARK: - Add

    func add(
        urls:
            [URL]
    ) {

        for url in urls {

            add(
                url:
                    url
            )
        }
    }

    func add(
        url:
            URL
    ) {

        let standardizedURL =
            url
                .standardizedFileURL

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        standardizedURL.path
                )
        else {

            return
        }

        /*
         Se il file è già presente,
         lo spostiamo semplicemente
         in cima.
         */

        items.removeAll {

            $0.url
                .standardizedFileURL
            ==
            standardizedURL
        }

        items.insert(
            ShelfItem(
                url:
                    standardizedURL
            ),
            at:
                0
        )

        if items.count > maximumItems {

            items =
                Array(
                    items.prefix(
                        maximumItems
                    )
                )
        }
    }

    // MARK: - Remove

    func remove(
        _ item:
            ShelfItem
    ) {

        items.removeAll {

            $0.id ==
            item.id
        }
    }

    func clear() {

        items.removeAll()
    }

    // MARK: - Open

    func open(
        _ item:
            ShelfItem
    ) {

        NSWorkspace.shared
            .open(
                item.url
            )
    }

    // MARK: - Reveal

    func revealInFinder(
        _ item:
            ShelfItem
    ) {

        NSWorkspace.shared
            .activateFileViewerSelecting(
                [
                    item.url
                ]
            )
    }
}
