import SwiftUI

@MainActor
struct ClipboardView: View {

    // MARK: - Manager

    @ObservedObject
    var clipboardManager:
        ClipboardManager

    // MARK: - State

    @State
    private var copiedClipboardItemID:
        UUID?

    // MARK: - Body

    var body: some View {

        VStack(
            spacing:
                9
        ) {

            header

            if clipboardManager
                .items
                .isEmpty {

                emptyState

            } else {

                clipboardList
            }
        }
        .foregroundStyle(
            .white
        )
        .padding(
            .bottom,
            12
        )
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
                        "pin.fill"
                )
                .font(
                    .system(
                        size:
                            8
                    )
                )

                Text(
                    "Fissa"
                )
                .font(
                    .system(
                        size:
                            9,
                        weight:
                            .semibold
                    )
                )
            }
            .foregroundStyle(
                .secondary
            )

            Spacer()

            if !clipboardManager
                .items
                .isEmpty {

                Button {

                    clipboardManager
                        .clearHistory()

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
        .padding(
            .horizontal,
            18
        )
    }

    // MARK: - Clipboard List

    private var clipboardList:
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
                    clipboardManager.items
                ) { item in

                    ClipboardRow(
                        item:
                            item,

                        copied:
                            copiedClipboardItemID
                            == item.id,

                        onCopy: {

                            copyClipboardItem(
                                item
                            )
                        },

                        onRemove: {

                            clipboardManager
                                .remove(
                                    item
                                )
                        }
                    )
                }
            }
        }
        .frame(
            maxHeight:
                145
        )
        .padding(
            .horizontal,
            18
        )
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
                    "doc.on.clipboard"
            )
            .font(
                .system(
                    size:
                        22
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "Nessun elemento copiato"
            )
            .font(
                .system(
                    size:
                        12,
                    weight:
                        .medium
                )
            )

            Text(
                "Copia testo o file dal Finder."
            )
            .font(
                .system(
                    size:
                        10
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
    }

    // MARK: - Copy

    private func copyClipboardItem(
        _ item:
            ClipboardManager.ClipboardItem
    ) {

        clipboardManager
            .copy(
                item
            )

        copiedClipboardItemID =
            item.id

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.8
        ) {

            guard
                copiedClipboardItemID
                == item.id
            else {

                return
            }

            copiedClipboardItemID =
                nil
        }
    }
}

// MARK: - Clipboard Row

private struct ClipboardRow: View {

    let item:
        ClipboardManager.ClipboardItem

    let copied:
        Bool

    let onCopy:
        () -> Void

    let onRemove:
        () -> Void

    var body: some View {

        HStack(
            spacing:
                8
        ) {

            Button(
                action:
                    onCopy
            ) {

                HStack(
                    spacing:
                        9
                ) {

                    Image(
                        systemName:
                            copied
                            ? "checkmark"
                            : item.systemImage
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
                            item.preview
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

                        if let subtitle =
                            item.subtitle {

                            Text(
                                subtitle
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
                    }

                    Spacer()
                }
            }
            .buttonStyle(
                .plain
            )

            Button(
                action:
                    onRemove
            ) {

                Image(
                    systemName:
                        "xmark"
                )
            }
            .buttonStyle(
                .plain
            )
        }
        .padding(
            .horizontal,
            8
        )
        .frame(
            minHeight:
                36
        )
        .background(
            Color.white
                .opacity(
                    copied
                    ? 0.09
                    : 0.04
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
}
