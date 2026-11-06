import HydraviaData
import SwiftUI

/// The watch's screen, in two vertical pages: today's water as a ring with
/// the next reminder, then (with Pro) the favourite amounts to pour in one
/// tap, or why there's nothing to tap.
struct TodayView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        NavigationStack {
            // Re-evaluated every minute: midnight resets the count and the
            // reminder line moves on.
            TimelineView(.everyMinute) { context in
                // Before the iPhone's first numbers, the goal would be a
                // made-up one: only the way to set things up.
                if model.hasSnapshot {
                    TabView {
                        ringPage(now: context.date)
                        actionPage(now: context.date)
                    }
                    .tabViewStyle(.verticalPage)
                } else {
                    ScrollView {
                        Note(icon: "iphone", title: Text(.watchSetupTitle), detail: Text(.watchSetupBody))
                            .padding(.top, 8)
                    }
                }
            }
            .navigationTitle(Text(verbatim: "Hydravia"))
            .containerBackground(WatchPalette.background, for: .navigation)
        }
    }

    private func ringPage(now: Date) -> some View {
        VStack(spacing: 10) {
            ProgressRing(
                progress: model.local.progress(at: now),
                consumedMl: model.local.todayMl(at: now),
                goalMl: model.local.state.goalMl
            )
            .frame(maxHeight: .infinity)
            StatusLine(local: model.local, now: now)
        }
        // Clear of the title, which sits over the page's top.
        .padding(.top, 14)
        .padding(.horizontal, 4)
    }

    private func actionPage(now: Date) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                // The count stays in sight while pouring.
                Text(.watchTotal(model.local.todayMl(at: now).formatted(), model.local.state.goalMl.formatted()))
                    .font(.brand(.bold, size: 17, relativeTo: .headline))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(model.local.todayMl(at: now))))
                    .animation(.snappy, value: model.local.todayMl(at: now))
                    .frame(maxWidth: .infinity)
                if model.hasPro {
                    PourButtons(amounts: model.favoritesMl) { model.pour($0) }
                } else {
                    Note(icon: "lock.fill", title: Text(.watchProTitle), detail: Text(.watchProBody))
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
    }
}

/// Today's water against the goal.
private struct ProgressRing: View {
    let progress: Double
    let consumedMl: Int
    let goalMl: Int

    private var reached: Bool { consumedMl >= goalMl }

    private static let lineWidth: CGFloat = 11

    var body: some View {
        // Square, so the ring is as wide as it is tall, and the numbers are
        // kept inside it (they used to run under the stroke).
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ring(side: side)
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.watchProgressLabel(consumedMl.formatted(), goalMl.formatted())))
    }

    private func ring(side: CGFloat) -> some View {
        ZStack {
            Circle().stroke(WatchPalette.track, lineWidth: Self.lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(colors: [WatchPalette.secondaryBlue, WatchPalette.foam], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.05))),
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)

            VStack(spacing: 0) {
                Image(systemName: reached ? "checkmark.circle.fill" : "drop.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WatchPalette.foam)
                    .contentTransition(.symbolEffect(.replace))
                Text(consumedMl.formatted())
                    .font(.brand(.bold, size: 30, relativeTo: .title))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(consumedMl)))
                    .animation(.snappy, value: consumedMl)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(.watchOfGoal(goalMl.formatted()))
                    .font(.brand(.semiBold, size: 13, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            // The widest line that fits inside the stroke, with a margin.
            .frame(width: (side - 2 * Self.lineWidth) * 0.8)
        }
    }
}

/// When the iPhone sends the next reminder, or that today's are done.
private struct StatusLine: View {
    let local: WatchLocalState
    let now: Date

    var body: some View {
        if let text {
            text
                .font(.brand(.semiBold, size: 14, relativeTo: .footnote))
                .foregroundStyle(local.isGoalReached(at: now) ? WatchPalette.foam : .secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var text: Text? {
        guard local.snapshot != nil else { return nil }
        let reached = local.isGoalReached(at: now)
        guard local.state.remindersOn else { return reached ? Text(.watchGoalReached) : nil }
        if reached { return Text(.watchGoalReachedPaused) }
        guard let next = local.nextReminder(after: now) else { return nil }
        let time = next.formatted(date: .omitted, time: .shortened)
        return Calendar.autoupdatingCurrent.isDate(next, inSameDayAs: now)
            ? Text(.watchNextReminder(time))
            : Text(.watchNextReminderTomorrow(time))
    }
}

/// The favourite amounts, one tap each.
private struct PourButtons: View {
    let amounts: [Int]
    let pour: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(amounts, id: \.self) { ml in
                Button { pour(ml) } label: {
                    Label {
                        Text(.watchAdd(ml.formatted()))
                    } icon: {
                        Image(systemName: "drop.fill")
                    }
                    .font(.brand(.bold, size: 16, relativeTo: .body))
                    .foregroundStyle(.white)
                    // Three to a screen, with the count above them: the
                    // system button is too tall for that.
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(WatchPalette.secondaryBlue, in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(PourButtonStyle())
            }
        }
    }
}

/// Sinks a little under the finger.
private struct PourButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Why there's nothing to tap: no iPhone data yet, or no Pro.
private struct Note: View {
    let icon: String
    let title: Text
    let detail: Text

    var body: some View {
        VStack(spacing: 4) {
            Label { title } icon: { Image(systemName: icon) }
                .font(.brand(.bold, size: 15, relativeTo: .headline))
            detail
                .font(.brand(.regular, size: 13, relativeTo: .footnote))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TodayView().environment(WatchModel.shared)
}
