
import SwiftUI

struct SmilePlusAlbumWall: View {
    let artwork: UIImage?
    let bpm: Double
    let beatIntensity: Float

    private let spacing: CGFloat = 8
    private let tileSize: CGFloat = 145

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Map BPM to a scrolling speed.
                let normalizedBPM = min(max(bpm, 60), 180)
                let scrollSpeed = 12 + (normalizedBPM - 60) / 120 * 55

                let offset = CGFloat(time * scrollSpeed)
                    .truncatingRemainder(
                        dividingBy: tileSize + spacing
                    )

                // Small visual response to beat intensity.
                let pulse = CGFloat(min(max(beatIntensity, 0), 1))

                ZStack {
                    Color.black

                    if let artwork {
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { row in
                                HStack(spacing: spacing) {
                                    ForEach(0..<9, id: \.self) { _ in
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
                                        * (offset + pulse * 5)
                                )
                            }
                        }
                        .rotationEffect(.degrees(-15))
                        .frame(
                            width: geometry.size.width * 1.8,
                            height: geometry.size.height * 1.8
                        )
                        .scaleEffect(1 + pulse * 0.008)
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
