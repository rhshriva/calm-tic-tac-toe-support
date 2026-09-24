import XCTest
@testable import TicTacToe

final class GameRulesTests: XCTestCase {
    func testDetectsRowWin() {
        let board: [Mark?] = [.x, .x, .x, nil, .o, nil, .o, nil, nil]

        XCTAssertEqual(GameRules.winner(in: board), .x)
        XCTAssertEqual(GameRules.winningLine(in: board), [0, 1, 2])
    }

    func testDetectsDiagonalWin() {
        let board: [Mark?] = [.o, .x, .x, nil, .o, nil, nil, nil, .o]

        XCTAssertEqual(GameRules.winner(in: board), .o)
        XCTAssertEqual(GameRules.winningLine(in: board), [0, 4, 8])
    }

    func testDetectsDraw() {
        let board: [Mark?] = [.x, .o, .x, .x, .o, .o, .o, .x, .x]

        XCTAssertTrue(GameRules.isDraw(board))
        XCTAssertNil(GameRules.winner(in: board))
    }

    func testAIChoosesWinningMove() {
        let board: [Mark?] = [.o, .o, nil, .x, .x, nil, nil, nil, nil]

        XCTAssertEqual(MinimaxAI.bestMove(for: .o, on: board), 2)
    }

    func testAIBlocksOpponentWin() {
        let board: [Mark?] = [.x, .x, nil, .o, nil, nil, nil, nil, nil]

        XCTAssertEqual(MinimaxAI.bestMove(for: .o, on: board), 2)
    }

    func testDetectsEveryWinningLineForBothMarks() {
        for mark in [Mark.x, .o] {
            for line in GameRules.winningLines {
                var board = Array<Mark?>(repeating: nil, count: 9)
                line.forEach { board[$0] = mark }

                XCTAssertEqual(GameRules.winner(in: board), mark)
                XCTAssertEqual(GameRules.winningLine(in: board), line)
            }
        }
    }

    func testDoesNotReportIncompleteLineAsWinOrDraw() {
        let board: [Mark?] = [.x, .x, nil, .o, nil, nil, nil, nil, nil]

        XCTAssertNil(GameRules.winner(in: board))
        XCTAssertNil(GameRules.winningLine(in: board))
        XCTAssertFalse(GameRules.isDraw(board))
    }

    func testAIReturnsNilWhenBoardIsFull() {
        let board: [Mark?] = [.x, .o, .x, .x, .o, .o, .o, .x, .x]

        XCTAssertNil(MinimaxAI.bestMove(for: .o, on: board))
    }

    func testMalformedBoardsFailSafely() {
        let shortBoard: [Mark?] = [.x, .x, .x]
        let longBoard = Array<Mark?>(repeating: nil, count: 10)

        XCTAssertNil(GameRules.winningLine(in: shortBoard))
        XCTAssertNil(GameRules.winner(in: shortBoard))
        XCTAssertNil(MinimaxAI.bestMove(for: .o, on: shortBoard))
        XCTAssertNil(GameRules.winningLine(in: longBoard))
        XCTAssertNil(MinimaxAI.bestMove(for: .o, on: longBoard))
    }

    func testIsDrawIsFalseForMalformedBoards() {
        // A short board that is actually a win must never be reported as a draw.
        XCTAssertFalse(GameRules.isDraw([.x, .x, .x]))
        XCTAssertFalse(GameRules.isDraw([nil, nil, nil]))
        XCTAssertFalse(GameRules.isDraw(Array(repeating: .x, count: 10)))

        // The genuine nine-cell draw still reports true.
        XCTAssertTrue(GameRules.isDraw([.x, .o, .x, .x, .o, .o, .o, .x, .x]))
    }

    func testAIReturnsNilAfterGameHasBeenWon() {
        let board: [Mark?] = [.x, .x, .x, .o, .o, nil, nil, nil, nil]

        XCTAssertNil(MinimaxAI.bestMove(for: .o, on: board))
    }

    func testAIAlwaysChoosesAnOpenCellForEveryLegalOTurn() {
        let stateCount = 19_683

        for encodedState in 0..<stateCount {
            let board = decodeBoard(encodedState)
            let xCount = board.filter { $0 == .x }.count
            let oCount = board.filter { $0 == .o }.count
            let isOTurn = xCount == oCount + 1
            let isOngoing = GameRules.winner(in: board) == nil && !GameRules.isDraw(board)

            guard isOTurn, isOngoing else { continue }

            let move = MinimaxAI.bestMove(for: .o, on: board)
            XCTAssertNotNil(move, "AI returned no move for board: \(board)")
            if let move {
                XCTAssertNil(board[move], "AI chose occupied cell \(move) for board: \(board)")
            }
        }
    }

    func testUnbeatableAICannotLoseAgainstAnyPlayerSequence() {
        let emptyBoard = Array<Mark?>(repeating: nil, count: 9)

        XCTAssertFalse(playerCanForceWin(on: emptyBoard))
    }

    @MainActor
    func testTwoPlayerScoringAndRoundResets() {
        let model = GameModel()
        model.mode = .twoPlayer

        [0, 3, 1, 4, 2].forEach { model.play(at: $0) }

        XCTAssertEqual(model.winner, .x)
        XCTAssertEqual(model.winningCells, [0, 1, 2])
        XCTAssertEqual(model.xScore, 1)

        model.newRound()
        XCTAssertEqual(model.board, Array<Mark?>(repeating: nil, count: 9))
        XCTAssertEqual(model.xScore, 1)

        model.resetMatch()
        XCTAssertEqual(model.xScore, 0)
        XCTAssertEqual(model.oScore, 0)
        XCTAssertEqual(model.draws, 0)
    }

    @MainActor
    func testOneMoveCompletingTwoLinesReportsEveryWinningCell() {
        let model = GameModel()
        model.mode = .twoPlayer

        // X takes 1, 3, 5, 7 and then 4, completing both (3,4,5) and (1,4,7).
        [1, 0, 3, 2, 5, 6, 7, 8, 4].forEach { model.play(at: $0) }

        XCTAssertEqual(model.winner, .x)
        XCTAssertEqual(model.winningCells, [1, 3, 4, 5, 7])
    }

    @MainActor
    func testSwitchingModeKeepsTheScoreButStartsANewRound() {
        let model = GameModel()
        model.mode = .twoPlayer
        [0, 3, 1, 4, 2].forEach { model.play(at: $0) }
        XCTAssertEqual(model.xScore, 1)

        model.mode = .computer

        XCTAssertEqual(model.xScore, 1, "Switching mode must not wipe the scoreboard")
        XCTAssertEqual(model.oScore, 0)
        XCTAssertEqual(model.draws, 0)
        XCTAssertEqual(model.board, Array<Mark?>(repeating: nil, count: 9))
        XCTAssertEqual(model.currentTurn, .x)
        XCTAssertNil(model.winner)
    }

    @MainActor
    func testComputerMoveIsDelayedCancellableAndVisible() async throws {
        let model = GameModel(computerMoveDelay: .milliseconds(50))
        model.mode = .computer
        model.difficulty = .easy

        model.play(at: 0)

        XCTAssertEqual(model.moveCount, 1, "The computer must not reply synchronously")
        XCTAssertTrue(model.isComputerThinking)
        XCTAssertEqual(model.statusText, "Computer is thinking")

        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.moveCount, 2, "The computer should have replied")
        XCTAssertFalse(model.isComputerThinking)
        XCTAssertEqual(model.statusText, "Your turn")

        // Starting a new round must cancel a move that is still pending.
        let emptyCell = try XCTUnwrap(model.board.firstIndex(of: nil))
        model.play(at: emptyCell)
        XCTAssertTrue(model.isComputerThinking)

        model.newRound()
        try await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(model.moveCount, 0, "A cancelled computer move must not land on the new board")
        XCTAssertFalse(model.isComputerThinking)
    }

    @MainActor
    func testInvalidAndOccupiedMovesAreIgnored() {
        let model = GameModel()
        model.mode = .twoPlayer

        model.play(at: -1)
        model.play(at: 9)
        XCTAssertEqual(model.moveCount, 0)

        model.play(at: 0)
        model.play(at: 0)
        XCTAssertEqual(model.moveCount, 1)
        XCTAssertEqual(model.board[0], .x)
        XCTAssertEqual(model.currentTurn, .o)
    }

    private func decodeBoard(_ encodedState: Int) -> [Mark?] {
        var value = encodedState
        return (0..<9).map { _ in
            defer { value /= 3 }
            switch value % 3 {
            case 1: return .x
            case 2: return .o
            default: return nil
            }
        }
    }

    private func playerCanForceWin(on board: [Mark?]) -> Bool {
        if GameRules.winner(in: board) == .x { return true }
        if GameRules.winner(in: board) == .o || GameRules.isDraw(board) { return false }

        let xCount = board.filter { $0 == .x }.count
        let oCount = board.filter { $0 == .o }.count

        if xCount == oCount {
            return board.indices
                .filter { board[$0] == nil }
                .contains { index in
                    var candidate = board
                    candidate[index] = .x
                    return playerCanForceWin(on: candidate)
                }
        }

        guard let move = MinimaxAI.bestMove(for: .o, on: board) else { return false }
        var candidate = board
        candidate[move] = .o
        return playerCanForceWin(on: candidate)
    }
}
