import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate - particle.startTime
                    let progress = min(elapsed / 3.0, 1.0)
                    let x = particle.x * size.width + sin(particle.wobble + progress * 10) * 20
                    let y = particle.startY + progress * (size.height * 1.2)
                    let opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3
                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 4, y: y - 6, width: 8, height: 12)),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            particles = (0..<80).map { _ in ConfettiParticle() }
        }
    }
}

struct ConfettiParticle {
    let x = Double.random(in: 0...1)
    let startY = Double.random(in: -100...0)
    let wobble = Double.random(in: 0...(.pi * 2))
    let startTime = Date.now.timeIntervalSinceReferenceDate
    let color: Color = [.red, .orange, .yellow, .green, .blue, .purple].randomElement()!
}
