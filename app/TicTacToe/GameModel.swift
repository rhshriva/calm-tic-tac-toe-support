import Combine
import Foundation

enum Mark: String, Equatable, Sendable {
    case x = "X"
    case o = "O"

    var opponent: Mark { self == .x ? .o : .x }
}

enum GameMode: String, CaseIterable, Identifiable {
    case computer = "Vs Computer"
    case twoPlayer = "Two Players"

    var id: Self { self }
}

enum Difficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case unbeatable = "Unbeatable"

    var id: Self { self }
}

enum GameRules {
    static let winningLines = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
    ]

    /// Every completed line on the board, in `winningLines` order.
    /// A single move can complete two lines at once, so this can hold more than one entry.
    static func completedLines(in board: [Mark?]) -> [[Int]] {
        guard board.count == 9 else { return [] }

        return winningLines.filter { line in
            guard let first = board[line[0]] else { return false }
            return board[line[1]] == first && board[line[2]] == first
        }
    }

    static func winningLine(in board: [Mark?]) -> [Int]? {
        completedLines(in: board).first
    }

    static func winner(in board: [Mark?]) -> Mark? {
        guard let line = winningLine(in: board) else { return nil }
        return board[line[0]]
    }

    static func isDraw(_ board: [Mark?]) -> Bool {
        guard board.count == 9 else { return false }
        return board.allSatisfy { $0 != nil } && winner(in: board) == nil
    }
}

enum MinimaxAI {
    static func bestMove(for mark: Mark, on board: [Mark?]) -> Int? {
        guard board.count == 9,
              GameRules.winner(in: board) == nil,
              !GameRules.isDraw(board) else { return nil }

        let available = board.indices.filter { board[$0] == nil }
        guard !available.isEmpty else { return nil }

        var bestScore = Int.min
        var selectedMove = available[0]

        for index in available {
            var candidate = board
            candidate[index] = mark
            let score = minimax(candidate, aiMark: mark, maximizing: false, depth: 0)
            if score > bestScore {
                bestScore = score
                selectedMove = index
            }
        }

        return selectedMove
    }

    private static func minimax(
        _ board: [Mark?],
        aiMark: Mark,
        maximizing: Bool,
        depth: Int
    ) -> Int {
        if let winner = GameRules.winner(in: board) {
            return winner == aiMark ? 10 - depth : depth - 10
        }
        if GameRules.isDraw(board) { return 0 }

        let available = board.indices.filter { board[$0] == nil }
        if maximizing {
            return available.map { index in
                var candidate = board
                candidate[index] = aiMark
                return minimax(candidate, aiMark: aiMark, maximizing: false, depth: depth + 1)
            }.max() ?? 0
        }

        return available.map { index in
            var candidate = board
            candidate[index] = aiMark.opponent
            return minimax(candidate, aiMark: aiMark, maximizing: true, depth: depth + 1)
        }.min() ?? 0
    }
}

@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var board: [Mark?] = Array(repeating: nil, count: 9)
    @Published private(set) var currentTurn: Mark = .x
    @Published private(set) var winner: Mark?
    @Published private(set) var isDraw = false
    /// Every board cell that is part of a completed winning line. Holds more than
    /// three indices when one move completes two lines at once.
    @Published private(set) var winningCells: [Int] = []
    @Published private(set) var isComputerThinking = false
    @Published private(set) var xScore = 0
    @Published private(set) var oScore = 0
    @Published private(set) var draws = 0

    @Published var difficulty: Difficulty = .unbeatable
    @Published var mode: GameMode = .computer {
        didSet {
            guard oldValue != mode else { return }
            // Scores belong to the match, not the mode, so keep them and only
            // clear the board (which also cancels a pending computer move).
            newRound()
        }
    }

    /// How long the computer appears to think before playing. Injectable so
    /// tests can run without waiting.
    private let computerMoveDelay: Duration
    private var computerMoveTask: Task<Void, Never>?

    init(computerMoveDelay: Duration = .milliseconds(450)) {
        self.computerMoveDelay = computerMoveDelay
    }

    var moveCount: Int { board.compactMap { $0 }.count }

    var statusText: String {
        if let winner {
            if mode == .computer {
                return winner == .x ? "You win" : "Computer wins"
            }
            return "\(winner.rawValue) wins"
        }
        if isDraw { return "A thoughtful draw" }
        if mode == .computer {
            return currentTurn == .x ? "Your turn" : "Computer is thinking"
        }
        return "\(currentTurn.rawValue)'s turn"
    }

    func play(at index: Int) {
        guard !isComputerThinking,
              board.indices.contains(index),
              board[index] == nil,
              winner == nil,
              !isDraw else { return }
        if mode == .computer && currentTurn == .o { return }

        place(currentTurn, at: index)
        if mode == .computer && winner == nil && !isDraw {
            scheduleComputerMove()
        }
    }

    func newRound() {
        computerMoveTask?.cancel()
        computerMoveTask = nil
        isComputerThinking = false

        board = Array(repeating: nil, count: 9)
        currentTurn = .x
        winner = nil
        isDraw = false
        winningCells = []
    }

    func resetMatch() {
        xScore = 0
        oScore = 0
        draws = 0
        newRound()
    }

    private func place(_ mark: Mark, at index: Int) {
        board[index] = mark

        let completedLines = GameRules.completedLines(in: board)
        if !completedLines.isEmpty {
            winner = mark
            winningCells = Set(completedLines.flatMap { $0 }).sorted()
            if mark == .x { xScore += 1 } else { oScore += 1 }
        } else if GameRules.isDraw(board) {
            isDraw = true
            draws += 1
        } else {
            currentTurn = mark.opponent
        }
    }

    /// Gives the computer a visible turn: the move lands after `computerMoveDelay`
    /// so the "Computer is thinking" status can render and the move animates on its own.
    private func scheduleComputerMove() {
        computerMoveTask?.cancel()
        isComputerThinking = true

        computerMoveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.computerMoveDelay)
            guard !Task.isCancelled else { return }

            self.isComputerThinking = false
            self.computerMoveTask = nil
            self.makeComputerMove()
        }
    }

    private func makeComputerMove() {
        let emptyCells = board.indices.filter { board[$0] == nil }
        guard !emptyCells.isEmpty else { return }

        let move: Int?
        switch difficulty {
        case .easy:
            move = emptyCells.randomElement()
        case .medium:
            move = Bool.random()
                ? MinimaxAI.bestMove(for: .o, on: board)
                : emptyCells.randomElement()
        case .unbeatable:
            move = MinimaxAI.bestMove(for: .o, on: board)
        }

        if let move { place(.o, at: move) }
    }
}
