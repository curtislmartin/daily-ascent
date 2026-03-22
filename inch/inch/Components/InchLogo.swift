import SwiftUI

/// The Daily Ascent brand mark — a ruler tick mark rendered as a SwiftUI shape.
/// Draws a left vertical spine with five horizontal marks of graduated width:
/// full (top), short (1/4), medium (1/2), short (3/4), full (bottom/base).
struct InchLogo: View {
    var size: CGFloat = 80
    var color: Color = Color(hex: "#7DD3A8") ?? .green

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width
            let path = tickMarkPath(in: s)
            ctx.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: max(2, s * 0.06),
                    lineCap: .square,
                    lineJoin: .miter
                )
            )
        }
        .frame(width: size, height: size)
    }

    private func tickMarkPath(in s: CGFloat) -> Path {
        Path { p in
            let spineX = s * 0.22
            let yTop   = s * 0.09
            let yBot   = s * 0.91
            let fullR  = s * 0.78
            let medR   = s * 0.60
            let shortR = s * 0.44
            let span   = yBot - yTop

            // Vertical spine
            p.move(to: CGPoint(x: spineX, y: yTop))
            p.addLine(to: CGPoint(x: spineX, y: yBot))

            // Top mark — full width
            p.move(to: CGPoint(x: spineX, y: yTop))
            p.addLine(to: CGPoint(x: fullR, y: yTop))

            // 1/4 mark — short
            p.move(to: CGPoint(x: spineX, y: yTop + span * 0.25))
            p.addLine(to: CGPoint(x: shortR, y: yTop + span * 0.25))

            // 1/2 mark — medium
            p.move(to: CGPoint(x: spineX, y: yTop + span * 0.50))
            p.addLine(to: CGPoint(x: medR, y: yTop + span * 0.50))

            // 3/4 mark — short
            p.move(to: CGPoint(x: spineX, y: yTop + span * 0.75))
            p.addLine(to: CGPoint(x: shortR, y: yTop + span * 0.75))

            // Bottom mark — full width (base)
            p.move(to: CGPoint(x: spineX, y: yBot))
            p.addLine(to: CGPoint(x: fullR, y: yBot))
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "#111113") ?? .black
        VStack(spacing: 16) {
            InchLogo(size: 120)
            Text("Daily Ascent")
                .font(.system(size: 28, weight: .light, design: .default))
                .foregroundStyle(Color(hex: "#7DD3A8") ?? .green)
        }
    }
    .ignoresSafeArea()
}
