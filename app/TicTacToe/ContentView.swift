import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameModel()
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView {
                ViewThatFits(in: .horizontal) {
                    wideContent
                    compactContent
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.moveCount)
    }

    private var compactContent: some View {
        VStack(spacing: 24) {
            header
            controls
            scoreboard
            board
            footer
        }
        .frame(maxWidth: 520)
    }

    private var wideContent: some View {
        HStack(alignment: .center, spacing: 40) {
            VStack(spacing: 24) {
                header
                controls
                scoreboard
            }
            .frame(minWidth: 280, maxWidth: 360)

            VStack(spacing: 24) {
                board
                footer
            }
            .frame(minWidth: 320, maxWidth: 420)
        }
        .frame(maxWidth: 880)
    }

    private var background: LinearGradient {
        let colors: [Color] = colorScheme == .dark
            ? [Color(red: 0.08, green: 0.10, blue: 0.14), Color(red: 0.14, green: 0.18, blue: 0.22)]
            : [Color(red: 0.96, green: 0.94, blue: 0.88), Color(red: 0.84, green: 0.91, blue: 0.91)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Tic Tac Toe")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("A quiet game of strategy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Game mode", selection: $game.mode) {
                ForEach(GameMode.allCases) { mode in
                    Text(mode.rawValue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if game.mode == .computer {
                Picker("Computer difficulty", selection: $game.difficulty) {
                    ForEach(Difficulty.allCases) { difficulty in
                        Text(difficulty.rawValue).tag(difficulty)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var scoreboard: some View {
        HStack(spacing: 12) {
            scoreCard(title: game.mode == .computer ? "You" : "X", score: game.xScore, mark: "X")
            scoreCard(title: "Draws", score: game.draws, mark: "—")
            scoreCard(title: game.mode == .computer ? "Computer" : "O", score: game.oScore, mark: "O")
        }
    }

    private func scoreCard(title: String, score: Int, mark: String) -> some View {
        VStack(spacing: 3) {
            Text(mark)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(mark == "X" ? Color.teal : mark == "O" ? Color.orange : Color.secondary)
            Text("\(score)")
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title == "Draws" ? "Draws, \(score)" : "\(title), \(score) wins")
    }

    private var board: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(game.board.indices, id: \.self) { index in
                cell(at: index)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game board")
    }

    private func cell(at index: Int) -> some View {
        let mark = game.board[index]
        let isWinner = game.winningLine.contains(index)
        let row = index / 3 + 1
        let column = index % 3 + 1

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                game.play(at: index)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isWinner ? Color.green.opacity(0.24) : Color.primary.opacity(0.07))

                if let mark {
                    Text(mark.rawValue)
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(mark == .x ? Color.teal : Color.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(mark != nil || game.winner != nil || game.isDraw)
        .accessibilityLabel("Row \(row), column \(column), \(mark?.rawValue ?? "empty")")
        .accessibilityHint(mark == nil ? "Places \(game.currentTurn.rawValue)" : "")
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Text(game.statusText)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .contentTransition(.numericText())

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    newRoundButton
                    resetScoreButton
                }
                VStack(spacing: 10) {
                    newRoundButton
                    resetScoreButton
                }
            }
        }
    }

    private var newRoundButton: some View {
        Button("New Round", systemImage: "arrow.clockwise") {
            withAnimation { game.newRound() }
        }
        .buttonStyle(.borderedProminent)
    }

    private var resetScoreButton: some View {
        Button("Reset Score", systemImage: "trash") {
            withAnimation { game.resetMatch() }
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    ContentView()
}
