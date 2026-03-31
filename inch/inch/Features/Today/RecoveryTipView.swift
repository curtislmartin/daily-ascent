import SwiftUI

struct RecoveryTipView: View {
    private static let tips: [String] = [
        "Muscle protein synthesis peaks 24–48 hours after your last session. Your rest day is doing real work.",
        "Light movement like a walk improves blood flow to recovering muscles without adding training stress.",
        "Sleep is when most muscle repair happens. Prioritise 7–9 hours tonight.",
        "Your nervous system recovers on rest days too — pushing through fatigue accumulates neural debt.",
        "Consistent rest is what makes progressive overload work. The gains happen during recovery, not training.",
        "Staying hydrated on rest days supports nutrient delivery to recovering muscles.",
        "Mental rest matters too — lower training stress today supports motivation tomorrow.",
        "Your body rebuilds muscle fibres stronger than before. Rest is the stimulus response.",
        "Active recovery like stretching keeps joints mobile without taxing your muscles.",
        "Training adaptation is a two-part process: the workout creates the signal, recovery delivers the result.",
    ]

    private var todaysTip: String {
        let dayOfYear = (Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1)
        return Self.tips[dayOfYear % Self.tips.count]
    }

    var body: some View {
        Text(todaysTip)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
