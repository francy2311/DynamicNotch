import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct FileShelfView: View {

    // MARK: - Manager

    @ObservedObject
    var shelfManager:
        FileShelfManager

    // MARK: - Activity

    let onActivity:
        () -> Void

    // MARK: - State

    @State
    private var isDropTargeted =
        false

    // MARK: - Body

    var body: some View {

        VStack(
            spacing:
                9
        ) {

            header

            if shelfManager
                .items
                .isEmpty {

                emptyState

            } else {

                itemList
            }
        }
        .foregroundStyle(
            .white
        )
        .padding(
            .horizontal,
            18
        )
        .padding(
            .bottom,
            12
        )
        .dropDestination(
            for:
                URL.self
        ) {
            urls,
            _ in

            let fileURLs =
                urls.filter {

                    $0.isFileURL
                }

            guard
                !fileURLs.isEmpty
            else {

                return false
            }

            shelfManager
                .add(
                    urls:
                        fileURLs
                )

            onActivity()

            return true

        } isTargeted: {
            targeted in

            withAnimation(
                .easeOut(
                    duration:
                        0.15
                )
            ) {

                isDropTargeted =
                    targeted
            }

            if targeted {

                onActivity()
            }
        }
    }

    // MARK: - Header

    private var header:
        some View {

        HStack {

            HStack(
                spacing:
                    6
            ) {

                Image(
                    systemName:
                        "tray.full.fill"
                )
                .font(
                    .system(
                        size:
                            9
                    )
                )

                Text(
                    "File Shelf"
                )
                .font(
                    .system(
                        size:
                            10,
                        weight:
                            .semibold
                    )
                )
            }
            .foregroundStyle(
                .secondary
            )

            Spacer()

            if !shelfManager
                .items
                .isEmpty {

                Button {

                    shelfManager
                        .clear()

                    onActivity()

                } label: {

                    Image(
                        systemName:
                            "trash"
                    )
                }
                .buttonStyle(
                    .plain
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState:
        some View {

        VStack(
            spacing:
                7
        ) {

            Image(
                systemName:
                    isDropTargeted
                    ? "arrow.down.doc.fill"
                    : "tray.and.arrow.down.fill"
            )
            .font(
                .system(
                    size:
                        23
                )
            )
            .foregroundStyle(
                isDropTargeted
                ? .white
                : .secondary
            )

            Text(
                isDropTargeted
                ? "Rilascia qui"
                : "Trascina qui file o cartelle"
            )
            .font(
                .system(
                    size:
                        12,
                    weight:
                        .semibold
                )
            )

            Text(
                "Tienili a portata di mano temporaneamente."
            )
            .font(
                .system(
                    size:
                        9
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
        .background {

            if isDropTargeted {

                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
                .fill(
                    Color.white
                        .opacity(
                            0.06
                        )
                )
            }
        }
    }

    // MARK: - List

    private var itemList:
        some View {

        ScrollView(
            .vertical,
            showsIndicators:
                false
        ) {

            LazyVStack(
                spacing:
                    5
            ) {

                ForEach(
                    shelfManager.items
                ) {
                    item in

                    shelfRow(
                        item
                    )
                }
            }
        }
        .frame(
            maxHeight:
                145
        )
    }

    // MARK: - Row

    private func shelfRow(
        _ item:
            FileShelfManager.ShelfItem
    ) -> some View {

        HStack(
            spacing:
                8
        ) {

            Button {

                shelfManager
                    .open(
                        item
                    )

                onActivity()

            } label: {

                HStack(
                    spacing:
                        9
                ) {

                    Image(
                        systemName:
                            item.systemImage
                    )
                    .frame(
                        width:
                            28
                    )

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            1
                    ) {

                        Text(
                            item.name
                        )
                        .font(
                            .system(
                                size:
                                    10,
                                weight:
                                    .medium
                            )
                        )
                        .lineLimit(
                            1
                        )

                        Text(
                            item.path
                        )
                        .font(
                            .system(
                                size:
                                    8
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(
                            1
                        )
                    }

                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .draggable(
                item.url
            ) {

                dragPreview(
                    item
                )
            }

            Button {

                shelfManager
                    .revealInFinder(
                        item
                    )

                onActivity()

            } label: {

                Image(
                    systemName:
                        "folder"
                )
            }
            .buttonStyle(
                .plain
            )
            .foregroundStyle(
                .secondary
            )

            Button {

                shelfManager
                    .remove(
                        item
                    )

                onActivity()

            } label: {

                Image(
                    systemName:
                        "xmark"
                )
            }
            .buttonStyle(
                .plain
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .horizontal,
            8
        )
        .frame(
            minHeight:
                38
        )
        .background(
            Color.white
                .opacity(
                    0.04
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    9,
                style:
                    .continuous
            )
        )
    }

    // MARK: - Drag Preview

    private func dragPreview(
        _ item:
            FileShelfManager.ShelfItem
    ) -> some View {

        HStack(
            spacing:
                8
        ) {

            Image(
                systemName:
                    item.systemImage
            )

            Text(
                item.name
            )
            .lineLimit(
                1
            )
        }
        .font(
            .system(
                size:
                    11,
                weight:
                    .medium
            )
        )
        .foregroundStyle(
            .white
        )
        .padding(
            .horizontal,
            12
        )
        .padding(
            .vertical,
            8
        )
        .background(
            .black.opacity(
                0.9
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    10,
                style:
                    .continuous
            )
        )
    }
}
