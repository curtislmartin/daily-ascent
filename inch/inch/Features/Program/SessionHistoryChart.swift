import SwiftUI
import Charts

struct SessionHistoryChart: View {
    let history: [SessionSummary]
    let testTarget: Int
    let accentColor: Color

    var body: some View {
        Chart {
            ForEach(history) { session in
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("Reps", session.totalReps)
                )
                .foregroundStyle(accentColor)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", session.date),
                    y: .value("Reps", session.totalReps)
                )
                .foregroundStyle(session.isTest ? Color(.systemBackground) : accentColor)
                .symbolSize(session.isTest ? 80 : 30)
            }

            if testTarget > 0 {
                RuleMark(y: .value("Target", testTarget))
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target \(testTarget)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.trailing, 4)
                    }
            }
        }
        .chartYAxisLabel("Total Reps")
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Session history chart. Shows reps per session across \(history.count) session\(history.count == 1 ? "" : "s").\(testTarget > 0 ? " Target to pass: \(testTarget) reps." : "")")
        .accessibilityHidden(history.isEmpty)
    }
}
