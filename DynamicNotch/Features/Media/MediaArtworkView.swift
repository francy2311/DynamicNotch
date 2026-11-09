import SwiftUI
import AppKit

struct MediaArtworkView: View {

    let artwork:
        NSImage?

    var body: some View {

        ZStack {

            RoundedRectangle(
                cornerRadius:
                    10
            )
            .fill(
                Color.white
                    .opacity(
                        0.07
                    )
            )

            if let artwork {

                Image(
                    nsImage:
                        artwork
                )
                .resizable()
                .scaledToFill()

            } else {

                Image(
                    systemName:
                        "music.note"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .frame(
            width:
                50,
            height:
                50
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    10
            )
        )
    }
}
