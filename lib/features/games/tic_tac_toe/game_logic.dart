// ─── Game Logic with Minimax AI ──────────────────────────────────────────────

const List<List<int>> _kWinPatterns = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
  [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
  [0, 4, 8], [2, 4, 6],             // diagonals
];

class GameLogic {
  // ─── Win check ─────────────────────────────────────────────────────────────
  static String checkWinner(List<String> board) {
    for (final p in _kWinPatterns) {
      final a = board[p[0]];
      if (a != '' && a == board[p[1]] && a == board[p[2]]) return a;
    }
    if (!board.contains('')) return 'Draw';
    return '';
  }

  // ─── Returns the winning pattern indices, or null ───────────────────────────
  static List<int>? winningPattern(List<String> board) {
    for (final p in _kWinPatterns) {
      final a = board[p[0]];
      if (a != '' && a == board[p[1]] && a == board[p[2]]) return p;
    }
    return null;
  }

  // ─── Minimax – returns best index for given player ──────────────────────────
  static int bestMove(List<String> board, String aiSymbol) {
    final human = aiSymbol == 'O' ? 'X' : 'O';
    int bestScore = -1000;
    int move = -1;

    for (int i = 0; i < 9; i++) {
      if (board[i] == '') {
        board[i] = aiSymbol;
        final score = _minimax(board, 0, false, aiSymbol, human);
        board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          move = i;
        }
      }
    }
    return move;
  }

  static int _minimax(
      List<String> board, int depth, bool isMaximizing, String ai, String human) {
    final winner = checkWinner(board);
    if (winner == ai) return 10 - depth;
    if (winner == human) return depth - 10;
    if (winner == 'Draw') return 0;

    if (isMaximizing) {
      int best = -1000;
      for (int i = 0; i < 9; i++) {
        if (board[i] == '') {
          board[i] = ai;
          best = best > _minimax(board, depth + 1, false, ai, human)
              ? best
              : _minimax(board, depth + 1, false, ai, human);
          board[i] = '';
        }
      }
      return best;
    } else {
      int best = 1000;
      for (int i = 0; i < 9; i++) {
        if (board[i] == '') {
          board[i] = human;
          final val = _minimax(board, depth + 1, true, ai, human);
          if (val < best) best = val;
          board[i] = '';
        }
      }
      return best;
    }
  }
}