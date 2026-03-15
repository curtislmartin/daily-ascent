import SwiftUI
import Charts

struct WeeklyVolumeChart: View {
    let weeklyData: [HistoryViewModel.WeeklyData]

    private var colorMapping: [String: Color] {
        var mapping: [String: Color] = [:]
        for week in weeklyData {
            for exercise in week.exerciseBreakdown {
                if mapping[exercise.name] == nil {
                    mapping[exercise.name] = Color(hex: exercise.color) ?? .accentColor
                }
            }
        }
        return mapping
    }

    var body: some View {
        Chart {
            ForEach(weeklyData) { week in
                ForEach(week.exerciseBreakdown) { exercise in
                    BarMark(
                        x: .value("Week", week.id, unit: .weekOfYear),
                        y: .value("Reps", exercise.totalReps)
                    )
                    .foregroundStyle(by: .value("Exercise", exercise.name))
                }
            }
        }
        .chartForegroundStyleScale { name in
            colorMapping[name] ?? .accentColor
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .frame(height: 180)
    }
}
