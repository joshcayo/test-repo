
import SwiftUI

struct SmilePlusAlbumWall: View {
    let artwork: UIImage?

    private let spacing: CGFloat = 8
    private let tileSize: CGFloat = 145

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let offset = CGFloat(time * 22)
                    .truncatingRemainder(
                        dividingBy: tileSize + spacing
                    )

                ZStack {
                    Color.black

                    if let artwork {
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { row in
                                HStack(spacing: spacing) {
                                    ForEach(0..<9, id: \.self) { column in
                                        Image(uiImage: artwork)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(
                                                width: tileSize,
                                                height: tileSize
                                            )
                                            .clipped()
                                    }
                                }
                                .offset(
                                    x: CGFloat(row % 2 == 0 ? 1 : -1)
                                        * offset
                                )
                            }
                        }
                        .rotationEffect(.degrees(-15))
                        .frame(
                            width: geometry.size.width * 1.8,
                            height: geometry.size.height * 1.8
                        )
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
            }
        }
        .ignoresSafeArea()
    }
}
