import Foundation

// MARK: - Difficulty

enum MinesweeperDifficulty: String, CaseIterable {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case expert       = "Expert"

    var cols: Int  { switch self { case .beginner: 9;  case .intermediate: 16; case .expert: 30 } }
    var rows: Int  { switch self { case .beginner: 9;  case .intermediate: 16; case .expert: 16 } }
    var mines: Int { switch self { case .beginner: 10; case .intermediate: 40; case .expert: 99 } }
}

// MARK: - Cell

struct MinesweeperCell {
    enum State {
        case covered
        case revealed
        case flagged
        case exploded   // the mine the player clicked
    }

    var isMine: Bool = false
    var adjacentMines: Int = 0
    var state: State = .covered
}

// MARK: - Game state

enum MinesweeperGameState {
    case idle, playing, won, lost
}

// MARK: - Model

@Observable
final class MinesweeperModel {
    private(set) var difficulty: MinesweeperDifficulty
    private(set) var cells: [[MinesweeperCell]]
    private(set) var gameState: MinesweeperGameState = .idle
    private(set) var elapsedSeconds: Int = 0
    private(set) var flagCount: Int = 0
    private(set) var pressingDown: Bool = false

    private var timer: Timer?
    private var minesPlaced = false

    var mineCounter: Int { difficulty.mines - flagCount }
    var cols: Int { difficulty.cols }
    var rows: Int { difficulty.rows }

    init(difficulty: MinesweeperDifficulty = .beginner) {
        self.difficulty = difficulty
        self.cells = Self.blankGrid(cols: difficulty.cols, rows: difficulty.rows)
    }

    // MARK: - Public interface

    func newGame(difficulty: MinesweeperDifficulty? = nil) {
        let d = difficulty ?? self.difficulty
        self.difficulty = d
        cells = Self.blankGrid(cols: d.cols, rows: d.rows)
        gameState = .idle
        elapsedSeconds = 0
        flagCount = 0
        minesPlaced = false
        pressingDown = false
        stopTimer()
    }

    func reveal(col: Int, row: Int) {
        guard gameState == .idle || gameState == .playing else { return }
        guard isValid(col: col, row: row) else { return }
        let cell = cells[row][col]
        guard cell.state == .covered else { return }

        if gameState == .idle {
            placeMines(avoiding: col, row: row)
            gameState = .playing
            startTimer()
        }

        if cells[row][col].isMine {
            cells[row][col].state = .exploded
            revealAllMines()
            gameState = .lost
            stopTimer()
            return
        }

        floodFill(col: col, row: row)
        checkWin()
    }

    func toggleFlag(col: Int, row: Int) {
        guard gameState == .idle || gameState == .playing else { return }
        guard isValid(col: col, row: row) else { return }
        switch cells[row][col].state {
        case .covered:
            cells[row][col].state = .flagged
            flagCount += 1
        case .flagged:
            cells[row][col].state = .covered
            flagCount -= 1
        default:
            break
        }
    }

    func chordReveal(col: Int, row: Int) {
        guard gameState == .playing else { return }
        guard isValid(col: col, row: row) else { return }
        guard cells[row][col].state == .revealed else { return }
        let n = cells[row][col].adjacentMines
        guard n > 0 else { return }
        let neighbors = adjacentCoords(col: col, row: row)
        let flagged = neighbors.filter { cells[$0.row][$0.col].state == .flagged }.count
        guard flagged == n else { return }
        for coord in neighbors where cells[coord.row][coord.col].state == .covered {
            reveal(col: coord.col, row: coord.row)
        }
    }

    func setPressingDown(_ value: Bool) {
        pressingDown = value
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.elapsedSeconds < 999 else { return }
            self.elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private helpers

    private static func blankGrid(cols: Int, rows: Int) -> [[MinesweeperCell]] {
        Array(repeating: Array(repeating: MinesweeperCell(), count: cols), count: rows)
    }

    private func placeMines(avoiding safeCol: Int, row safeRow: Int) {
        let total = difficulty.cols * difficulty.rows
        let mineCount = difficulty.mines

        // Build safe zone: the clicked cell + all its neighbors
        var safeSet = Set<Int>()
        safeSet.insert(safeRow * difficulty.cols + safeCol)
        for coord in adjacentCoords(col: safeCol, row: safeRow) {
            safeSet.insert(coord.row * difficulty.cols + coord.col)
        }

        var indices = Array(0..<total).filter { !safeSet.contains($0) }
        indices.shuffle()
        let mineIndices = Set(indices.prefix(mineCount))

        for row in 0..<difficulty.rows {
            for col in 0..<difficulty.cols {
                cells[row][col].isMine = mineIndices.contains(row * difficulty.cols + col)
            }
        }

        for row in 0..<difficulty.rows {
            for col in 0..<difficulty.cols {
                guard !cells[row][col].isMine else { continue }
                cells[row][col].adjacentMines = adjacentCoords(col: col, row: row)
                    .filter { cells[$0.row][$0.col].isMine }
                    .count
            }
        }

        minesPlaced = true
    }

    private func floodFill(col: Int, row: Int) {
        guard isValid(col: col, row: row) else { return }
        guard cells[row][col].state == .covered else { return }
        guard !cells[row][col].isMine else { return }

        cells[row][col].state = .revealed

        if cells[row][col].adjacentMines == 0 {
            for coord in adjacentCoords(col: col, row: row) {
                floodFill(col: coord.col, row: coord.row)
            }
        }
    }

    private func revealAllMines() {
        for row in 0..<difficulty.rows {
            for col in 0..<difficulty.cols {
                if cells[row][col].isMine && cells[row][col].state != .exploded
                    && cells[row][col].state != .flagged {
                    cells[row][col].state = .revealed
                }
            }
        }
    }

    private func checkWin() {
        let allSafeCellsRevealed = (0..<difficulty.rows).allSatisfy { row in
            (0..<difficulty.cols).allSatisfy { col in
                let c = cells[row][col]
                return c.isMine || c.state == .revealed
            }
        }
        if allSafeCellsRevealed {
            gameState = .won
            stopTimer()
        }
    }

    private func isValid(col: Int, row: Int) -> Bool {
        row >= 0 && row < difficulty.rows && col >= 0 && col < difficulty.cols
    }

    private func adjacentCoords(col: Int, row: Int) -> [(col: Int, row: Int)] {
        var result: [(col: Int, row: Int)] = []
        for dr in -1...1 {
            for dc in -1...1 {
                guard dr != 0 || dc != 0 else { continue }
                let nr = row + dr
                let nc = col + dc
                if isValid(col: nc, row: nr) { result.append((nc, nr)) }
            }
        }
        return result
    }
}
