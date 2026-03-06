import 'dart:math';

import 'model.dart';

/// Result of a played move with SAN notation and metadata (check/checkmate).
class PlayedMove {
  final ChessMove move;
  final String san;

  const PlayedMove({required this.move, required this.san});

  Map<String, dynamic> toJson() => {'m': move.toJson(), 'san': san};

  static PlayedMove fromJson(Map<String, dynamic> json) =>
      PlayedMove(move: ChessMove.fromJson(json['m'] as Map<String, dynamic>), san: json['san'] as String);
}

/// A full chess position and rules implementation (local two-player).
class ChessPosition {
  final List<Piece?> board; // 64 squares: index = rank*8 + file
  final PieceColor sideToMove;
  final CastlingRights castlingRights;
  final Square? enPassantTarget; // square behind pawn that moved two
  final int halfmoveClock;
  final int fullmoveNumber;

  const ChessPosition({
    required this.board,
    required this.sideToMove,
    required this.castlingRights,
    required this.enPassantTarget,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  static int indexOf(Square sq) => sq.rank * 8 + sq.file;

  Piece? pieceAt(Square sq) => board[indexOf(sq)];

  ChessPosition copyWith({
    List<Piece?>? board,
    PieceColor? sideToMove,
    CastlingRights? castlingRights,
    Square? enPassantTarget,
    bool clearEnPassantTarget = false,
    int? halfmoveClock,
    int? fullmoveNumber,
  }) {
    return ChessPosition(
      board: board ?? this.board,
      sideToMove: sideToMove ?? this.sideToMove,
      castlingRights: castlingRights ?? this.castlingRights,
      enPassantTarget: clearEnPassantTarget ? null : (enPassantTarget ?? this.enPassantTarget),
      halfmoveClock: halfmoveClock ?? this.halfmoveClock,
      fullmoveNumber: fullmoveNumber ?? this.fullmoveNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'b': board.map((p) => p?.toJson()).toList(),
        'stm': sideToMove.name,
        'c': castlingRights.toJson(),
        'ep': enPassantTarget?.algebraic,
        'hmc': halfmoveClock,
        'fmn': fullmoveNumber,
      };

  static ChessPosition fromJson(Map<String, dynamic> json) {
    final List<dynamic> b = json['b'] as List<dynamic>;
    return ChessPosition(
      board: b.map((e) => e == null ? null : Piece.fromJson(e as Map<String, dynamic>)).toList(),
      sideToMove: PieceColor.values.firstWhere((e) => e.name == json['stm']),
      castlingRights: CastlingRights.fromJson(json['c'] as Map<String, dynamic>),
      enPassantTarget: (json['ep'] as String?) == null ? null : Square.tryParse(json['ep'] as String),
      halfmoveClock: (json['hmc'] as num).toInt(),
      fullmoveNumber: (json['fmn'] as num).toInt(),
    );
  }

  /// Initial chess position.
  static ChessPosition initial() {
    final List<Piece?> b = List<Piece?>.filled(64, null);

    void setPiece(String sq, Piece piece) {
      final s = Square.tryParse(sq)!;
      b[indexOf(s)] = piece;
    }

    // White pieces
    setPiece('a1', const Piece(type: PieceType.rook, color: PieceColor.white));
    setPiece('b1', const Piece(type: PieceType.knight, color: PieceColor.white));
    setPiece('c1', const Piece(type: PieceType.bishop, color: PieceColor.white));
    setPiece('d1', const Piece(type: PieceType.queen, color: PieceColor.white));
    setPiece('e1', const Piece(type: PieceType.king, color: PieceColor.white));
    setPiece('f1', const Piece(type: PieceType.bishop, color: PieceColor.white));
    setPiece('g1', const Piece(type: PieceType.knight, color: PieceColor.white));
    setPiece('h1', const Piece(type: PieceType.rook, color: PieceColor.white));
    for (int f = 0; f < 8; f++) {
      b[indexOf(Square(f, 1))] = const Piece(type: PieceType.pawn, color: PieceColor.white);
    }

    // Black pieces
    setPiece('a8', const Piece(type: PieceType.rook, color: PieceColor.black));
    setPiece('b8', const Piece(type: PieceType.knight, color: PieceColor.black));
    setPiece('c8', const Piece(type: PieceType.bishop, color: PieceColor.black));
    setPiece('d8', const Piece(type: PieceType.queen, color: PieceColor.black));
    setPiece('e8', const Piece(type: PieceType.king, color: PieceColor.black));
    setPiece('f8', const Piece(type: PieceType.bishop, color: PieceColor.black));
    setPiece('g8', const Piece(type: PieceType.knight, color: PieceColor.black));
    setPiece('h8', const Piece(type: PieceType.rook, color: PieceColor.black));
    for (int f = 0; f < 8; f++) {
      b[indexOf(Square(f, 6))] = const Piece(type: PieceType.pawn, color: PieceColor.black);
    }

    return ChessPosition(
      board: b,
      sideToMove: PieceColor.white,
      castlingRights: const CastlingRights(
        whiteKingSide: true,
        whiteQueenSide: true,
        blackKingSide: true,
        blackQueenSide: true,
      ),
      enPassantTarget: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
    );
  }
}

class _AttackInfo {
  final bool inCheck;
  final Set<Square> attackers;

  const _AttackInfo({required this.inCheck, required this.attackers});
}

/// Main rules engine: generate legal moves, apply moves, SAN.
class ChessEngine {
  ChessPosition position;

  ChessEngine({ChessPosition? initial}) : position = initial ?? ChessPosition.initial();

  // Move history for undo/redo
  final List<_HistoryEntry> _history = <_HistoryEntry>[];
  int _historyCursor = 0; // number of applied moves

  List<PlayedMove> get playedMoves => _history.take(_historyCursor).map((e) => e.playedMove).toList();

  bool get canUndo => _historyCursor > 0;
  bool get canRedo => _historyCursor < _history.length;

  /// Returns true if side to move has no legal moves and is in check.
  bool get isCheckmate {
    final inCheck = isKingInCheck(position, position.sideToMove);
    if (!inCheck) return false;
    return generateLegalMoves().isEmpty;
  }

  /// Returns true if side to move has no legal moves and is NOT in check.
  bool get isStalemate {
    final inCheck = isKingInCheck(position, position.sideToMove);
    if (inCheck) return false;
    return generateLegalMoves().isEmpty;
  }

  // PUBLIC_INTERFACE
  void reset() {
    /// Reset engine to initial position and clear history.
    position = ChessPosition.initial();
    _history.clear();
    _historyCursor = 0;
  }

  // PUBLIC_INTERFACE
  bool undo() {
    /// Undo last move if possible. Returns whether successful.
    if (!canUndo) return false;
    final _HistoryEntry entry = _history[_historyCursor - 1];
    position = entry.before;
    _historyCursor -= 1;
    return true;
  }

  // PUBLIC_INTERFACE
  bool redo() {
    /// Redo next move if possible. Returns whether successful.
    if (!canRedo) return false;
    final _HistoryEntry entry = _history[_historyCursor];
    position = entry.after;
    _historyCursor += 1;
    return true;
  }

  // PUBLIC_INTERFACE
  List<ChessMove> legalMovesFrom(Square from) {
    /// Returns all legal moves originating from [from] in the current position.
    return generateLegalMoves().where((m) => m.from == from).toList();
  }

  // PUBLIC_INTERFACE
  List<ChessMove> generateLegalMoves() {
    /// Generate all legal moves for the side to move.
    final List<ChessMove> pseudo = _generatePseudoLegalMoves(position);
    final List<ChessMove> legal = <ChessMove>[];
    for (final m in pseudo) {
      final ChessPosition next = _applyMoveToPosition(position, m, generateSan: false).position;
      if (!isKingInCheck(next, position.sideToMove)) {
        legal.add(m);
      }
    }
    return legal;
  }

  // PUBLIC_INTERFACE
  MoveApplyResult? tryPlayMove(ChessMove move) {
    /// Attempt to play [move] if legal.
    ///
    /// Returns details (SAN, resulting position) when successful, otherwise null.
    final List<ChessMove> legals = generateLegalMoves();
    final ChessMove? match = legals.cast<ChessMove?>().firstWhere(
          (m) => m == move || (m != null && _sameMoveIgnoringPromotion(m, move)),
          orElse: () => null,
        );
    if (match == null) return null;

    final before = position;
    final applied = _applyMoveToPosition(position, match, generateSan: true);
    final after = applied.position;

    // if we had undone moves, truncate redo part
    if (_historyCursor < _history.length) {
      _history.removeRange(_historyCursor, _history.length);
    }

    _history.add(_HistoryEntry(before: before, after: after, playedMove: applied.playedMove!));
    _historyCursor += 1;
    position = after;
    return applied;
  }

  bool _sameMoveIgnoringPromotion(ChessMove a, ChessMove b) =>
      a.from == b.from &&
      a.to == b.to &&
      a.isEnPassant == b.isEnPassant &&
      a.isCastleKingSide == b.isCastleKingSide &&
      a.isCastleQueenSide == b.isCastleQueenSide;

  // PUBLIC_INTERFACE
  bool isKingInCheck(ChessPosition pos, PieceColor color) {
    /// Return whether [color]'s king is in check in [pos].
    final Square? kingSq = _findKing(pos, color);
    if (kingSq == null) return false;
    final _AttackInfo info = _attackInfo(pos, kingSq, _opponent(color));
    return info.inCheck;
  }

  Square? _findKing(ChessPosition pos, PieceColor color) {
    for (int i = 0; i < 64; i++) {
      final p = pos.board[i];
      if (p != null && p.color == color && p.type == PieceType.king) {
        return Square(i % 8, i ~/ 8);
      }
    }
    return null;
  }

  PieceColor _opponent(PieceColor c) => c == PieceColor.white ? PieceColor.black : PieceColor.white;

  _AttackInfo _attackInfo(ChessPosition pos, Square target, PieceColor byColor) {
    final attackers = <Square>{};
    bool inCheck = false;

    bool considerAttacker(Square from) {
      attackers.add(from);
      inCheck = true;
      return true;
    }

    // Knight attacks
    const knightDeltas = <Point<int>>[
      Point(1, 2),
      Point(2, 1),
      Point(2, -1),
      Point(1, -2),
      Point(-1, -2),
      Point(-2, -1),
      Point(-2, 1),
      Point(-1, 2),
    ];
    for (final d in knightDeltas) {
      final s = Square(target.file + d.x, target.rank + d.y);
      if (!s.isValid) continue;
      final p = pos.pieceAt(s);
      if (p != null && p.color == byColor && p.type == PieceType.knight) {
        considerAttacker(s);
      }
    }

    // Pawn attacks (byColor pawns attack forward)
    final int pawnDir = byColor == PieceColor.white ? 1 : -1;
    for (final df in const [-1, 1]) {
      final s = Square(target.file + df, target.rank - pawnDir);
      if (!s.isValid) continue;
      final p = pos.pieceAt(s);
      if (p != null && p.color == byColor && p.type == PieceType.pawn) {
        considerAttacker(s);
      }
    }

    // King adjacency
    for (int dr = -1; dr <= 1; dr++) {
      for (int df = -1; df <= 1; df++) {
        if (dr == 0 && df == 0) continue;
        final s = Square(target.file + df, target.rank + dr);
        if (!s.isValid) continue;
        final p = pos.pieceAt(s);
        if (p != null && p.color == byColor && p.type == PieceType.king) {
          considerAttacker(s);
        }
      }
    }

    // Sliding attacks
    void ray(List<Point<int>> deltas, Set<PieceType> types) {
      for (final d in deltas) {
        int f = target.file + d.x;
        int r = target.rank + d.y;
        while (f >= 0 && f < 8 && r >= 0 && r < 8) {
          final s = Square(f, r);
          final p = pos.pieceAt(s);
          if (p != null) {
            if (p.color == byColor && types.contains(p.type)) {
              considerAttacker(s);
            }
            break;
          }
          f += d.x;
          r += d.y;
        }
      }
    }

    ray(const [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)], {PieceType.rook, PieceType.queen});
    ray(const [Point(1, 1), Point(-1, 1), Point(1, -1), Point(-1, -1)], {PieceType.bishop, PieceType.queen});

    return _AttackInfo(inCheck: inCheck, attackers: attackers);
  }

  List<ChessMove> _generatePseudoLegalMoves(ChessPosition pos) {
    final List<ChessMove> moves = <ChessMove>[];
    for (int i = 0; i < 64; i++) {
      final p = pos.board[i];
      if (p == null || p.color != pos.sideToMove) continue;
      final from = Square(i % 8, i ~/ 8);
      moves.addAll(_pseudoMovesForPiece(pos, from, p));
    }
    // add castling (requires not in check and squares not attacked and empty)
    moves.addAll(_pseudoCastlingMoves(pos));
    return moves;
  }

  List<ChessMove> _pseudoCastlingMoves(ChessPosition pos) {
    final List<ChessMove> moves = <ChessMove>[];
    final PieceColor c = pos.sideToMove;
    final Square kingFrom = c == PieceColor.white ? const Square(4, 0) : const Square(4, 7);
    final Piece? king = pos.pieceAt(kingFrom);
    if (king == null || king.type != PieceType.king) return moves;

    final bool inCheck = isKingInCheck(pos, c);
    if (inCheck) return moves;

    bool squaresNotAttacked(List<Square> squares) {
      for (final s in squares) {
        if (_attackInfo(pos, s, _opponent(c)).inCheck) return false;
      }
      return true;
    }

    if (c == PieceColor.white && pos.castlingRights.whiteKingSide) {
      final path = [const Square(5, 0), const Square(6, 0)];
      if (path.every((s) => pos.pieceAt(s) == null) && squaresNotAttacked(path)) {
        moves.add(const ChessMove(from: Square(4, 0), to: Square(6, 0), isCastleKingSide: true));
      }
    }
    if (c == PieceColor.white && pos.castlingRights.whiteQueenSide) {
      final empties = [const Square(3, 0), const Square(2, 0), const Square(1, 0)];
      final pass = [const Square(3, 0), const Square(2, 0)];
      if (empties.every((s) => pos.pieceAt(s) == null) && squaresNotAttacked(pass)) {
        moves.add(const ChessMove(from: Square(4, 0), to: Square(2, 0), isCastleQueenSide: true));
      }
    }
    if (c == PieceColor.black && pos.castlingRights.blackKingSide) {
      final path = [const Square(5, 7), const Square(6, 7)];
      if (path.every((s) => pos.pieceAt(s) == null) && squaresNotAttacked(path)) {
        moves.add(const ChessMove(from: Square(4, 7), to: Square(6, 7), isCastleKingSide: true));
      }
    }
    if (c == PieceColor.black && pos.castlingRights.blackQueenSide) {
      final empties = [const Square(3, 7), const Square(2, 7), const Square(1, 7)];
      final pass = [const Square(3, 7), const Square(2, 7)];
      if (empties.every((s) => pos.pieceAt(s) == null) && squaresNotAttacked(pass)) {
        moves.add(const ChessMove(from: Square(4, 7), to: Square(2, 7), isCastleQueenSide: true));
      }
    }

    return moves;
  }

  List<ChessMove> _pseudoMovesForPiece(ChessPosition pos, Square from, Piece piece) {
    return switch (piece.type) {
      PieceType.pawn => _pawnMoves(pos, from, piece),
      PieceType.knight => _knightMoves(pos, from, piece),
      PieceType.bishop => _slidingMoves(pos, from, piece, const [Point(1, 1), Point(-1, 1), Point(1, -1), Point(-1, -1)]),
      PieceType.rook => _slidingMoves(pos, from, piece, const [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)]),
      PieceType.queen => _slidingMoves(pos, from, piece, const [
          Point(1, 1),
          Point(-1, 1),
          Point(1, -1),
          Point(-1, -1),
          Point(1, 0),
          Point(-1, 0),
          Point(0, 1),
          Point(0, -1),
        ]),
      PieceType.king => _kingMoves(pos, from, piece),
    };
  }

  List<ChessMove> _pawnMoves(ChessPosition pos, Square from, Piece piece) {
    final List<ChessMove> moves = <ChessMove>[];
    final int dir = piece.color == PieceColor.white ? 1 : -1;
    final int startRank = piece.color == PieceColor.white ? 1 : 6;
    final int promoRank = piece.color == PieceColor.white ? 7 : 0;

    Square one = Square(from.file, from.rank + dir);
    if (one.isValid && pos.pieceAt(one) == null) {
      if (one.rank == promoRank) {
        for (final pt in const [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
          moves.add(ChessMove(from: from, to: one, promotion: pt));
        }
      } else {
        moves.add(ChessMove(from: from, to: one));
      }

      Square two = Square(from.file, from.rank + 2 * dir);
      if (from.rank == startRank && pos.pieceAt(two) == null) {
        moves.add(ChessMove(from: from, to: two));
      }
    }

    for (final int df in const [-1, 1]) {
      final Square cap = Square(from.file + df, from.rank + dir);
      if (!cap.isValid) continue;
      final Piece? target = pos.pieceAt(cap);
      if (target != null && target.color != piece.color) {
        if (cap.rank == promoRank) {
          for (final pt in const [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
            moves.add(ChessMove(from: from, to: cap, promotion: pt));
          }
        } else {
          moves.add(ChessMove(from: from, to: cap));
        }
      }

      // en-passant capture: pawn moves diagonally to enPassantTarget
      if (pos.enPassantTarget != null && pos.enPassantTarget == cap) {
        moves.add(ChessMove(from: from, to: cap, isEnPassant: true));
      }
    }

    return moves;
  }

  List<ChessMove> _knightMoves(ChessPosition pos, Square from, Piece piece) {
    final List<ChessMove> moves = <ChessMove>[];
    const deltas = <Point<int>>[
      Point(1, 2),
      Point(2, 1),
      Point(2, -1),
      Point(1, -2),
      Point(-1, -2),
      Point(-2, -1),
      Point(-2, 1),
      Point(-1, 2),
    ];
    for (final d in deltas) {
      final Square to = Square(from.file + d.x, from.rank + d.y);
      if (!to.isValid) continue;
      final Piece? target = pos.pieceAt(to);
      if (target == null || target.color != piece.color) {
        moves.add(ChessMove(from: from, to: to));
      }
    }
    return moves;
  }

  List<ChessMove> _slidingMoves(ChessPosition pos, Square from, Piece piece, List<Point<int>> deltas) {
    final List<ChessMove> moves = <ChessMove>[];
    for (final d in deltas) {
      int f = from.file + d.x;
      int r = from.rank + d.y;
      while (f >= 0 && f < 8 && r >= 0 && r < 8) {
        final Square to = Square(f, r);
        final Piece? target = pos.pieceAt(to);
        if (target == null) {
          moves.add(ChessMove(from: from, to: to));
        } else {
          if (target.color != piece.color) {
            moves.add(ChessMove(from: from, to: to));
          }
          break;
        }
        f += d.x;
        r += d.y;
      }
    }
    return moves;
  }

  List<ChessMove> _kingMoves(ChessPosition pos, Square from, Piece piece) {
    final List<ChessMove> moves = <ChessMove>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int df = -1; df <= 1; df++) {
        if (dr == 0 && df == 0) continue;
        final Square to = Square(from.file + df, from.rank + dr);
        if (!to.isValid) continue;
        final Piece? target = pos.pieceAt(to);
        if (target == null || target.color != piece.color) {
          moves.add(ChessMove(from: from, to: to));
        }
      }
    }
    return moves;
  }

  MoveApplyResult _applyMoveToPosition(ChessPosition pos, ChessMove move, {required bool generateSan}) {
    final List<Piece?> b = List<Piece?>.from(pos.board);
    final Piece? moving = b[ChessPosition.indexOf(move.from)];
    if (moving == null) {
      return MoveApplyResult(position: pos);
    }

    Piece? captured = b[ChessPosition.indexOf(move.to)];
    Square? epTarget;
    bool pawnMoveOrCapture = moving.type == PieceType.pawn;

    // Castling handling
    if (move.isCastleKingSide || move.isCastleQueenSide) {
      final bool kingSide = move.isCastleKingSide;
      final int rank = moving.color == PieceColor.white ? 0 : 7;
      final Square rookFrom = kingSide ? Square(7, rank) : Square(0, rank);
      final Square rookTo = kingSide ? Square(5, rank) : Square(3, rank);

      // move king
      b[ChessPosition.indexOf(move.from)] = null;
      b[ChessPosition.indexOf(move.to)] = moving;

      // move rook
      final Piece? rook = b[ChessPosition.indexOf(rookFrom)];
      b[ChessPosition.indexOf(rookFrom)] = null;
      b[ChessPosition.indexOf(rookTo)] = rook;

      // update castling rights: remove for that color
      final CastlingRights cr = _updateCastlingRightsAfterKingMove(pos.castlingRights, moving.color);

      final ChessPosition next = pos.copyWith(
        board: b,
        sideToMove: _opponent(pos.sideToMove),
        castlingRights: cr,
        clearEnPassantTarget: true,
        halfmoveClock: pos.halfmoveClock + 1,
        fullmoveNumber: pos.sideToMove == PieceColor.black ? pos.fullmoveNumber + 1 : pos.fullmoveNumber,
      );

      final PlayedMove? pm = generateSan ? PlayedMove(move: move, san: kingSide ? 'O-O' : 'O-O-O') : null;
      final String? withSuffix = generateSan ? _appendCheckSuffix(next, pm!.san) : null;
      return MoveApplyResult(
        position: next,
        playedMove: generateSan ? PlayedMove(move: move, san: withSuffix!) : null,
      );
    }

    // En-passant capture removes pawn behind target square
    if (move.isEnPassant) {
      final int dir = moving.color == PieceColor.white ? 1 : -1;
      final Square capturedPawnSq = Square(move.to.file, move.to.rank - dir);
      captured = b[ChessPosition.indexOf(capturedPawnSq)];
      b[ChessPosition.indexOf(capturedPawnSq)] = null;
      pawnMoveOrCapture = true;
    }

    // Move piece
    b[ChessPosition.indexOf(move.from)] = null;
    Piece movedPiece = moving;
    if (moving.type == PieceType.pawn && move.promotion != null) {
      movedPiece = Piece(type: move.promotion!, color: moving.color);
    }
    b[ChessPosition.indexOf(move.to)] = movedPiece;

    // En-passant target on double pawn move
    if (moving.type == PieceType.pawn && (move.to.rank - move.from.rank).abs() == 2) {
      final int dir = moving.color == PieceColor.white ? 1 : -1;
      epTarget = Square(move.from.file, move.from.rank + dir);
    }

    // Update castling rights if king/rook moved or rook captured.
    CastlingRights cr = pos.castlingRights;
    if (moving.type == PieceType.king) {
      cr = _updateCastlingRightsAfterKingMove(cr, moving.color);
    } else if (moving.type == PieceType.rook) {
      cr = _updateCastlingRightsAfterRookMove(cr, move.from, moving.color);
    }
    if (captured != null && captured.type == PieceType.rook) {
      cr = _updateCastlingRightsAfterRookCapture(cr, move.to, captured.color);
    }

    // halfmove clock resets on pawn move or capture
    final int nextHalfmove = (pawnMoveOrCapture || captured != null) ? 0 : pos.halfmoveClock + 1;

    final ChessPosition next = pos.copyWith(
      board: b,
      sideToMove: _opponent(pos.sideToMove),
      castlingRights: cr,
      enPassantTarget: epTarget,
      clearEnPassantTarget: epTarget == null,
      halfmoveClock: nextHalfmove,
      fullmoveNumber: pos.sideToMove == PieceColor.black ? pos.fullmoveNumber + 1 : pos.fullmoveNumber,
    );

    final PlayedMove? pm = generateSan ? PlayedMove(move: move, san: _sanForMove(pos, move, moving, captured)) : null;
    final String? withSuffix = generateSan ? _appendCheckSuffix(next, pm!.san) : null;

    return MoveApplyResult(
      position: next,
      playedMove: generateSan ? PlayedMove(move: move, san: withSuffix!) : null,
    );
  }

  CastlingRights _updateCastlingRightsAfterKingMove(CastlingRights cr, PieceColor color) {
    if (color == PieceColor.white) {
      return cr.copyWith(whiteKingSide: false, whiteQueenSide: false);
    }
    return cr.copyWith(blackKingSide: false, blackQueenSide: false);
  }

  CastlingRights _updateCastlingRightsAfterRookMove(CastlingRights cr, Square rookFrom, PieceColor color) {
    if (color == PieceColor.white) {
      if (rookFrom == const Square(0, 0)) return cr.copyWith(whiteQueenSide: false);
      if (rookFrom == const Square(7, 0)) return cr.copyWith(whiteKingSide: false);
    } else {
      if (rookFrom == const Square(0, 7)) return cr.copyWith(blackQueenSide: false);
      if (rookFrom == const Square(7, 7)) return cr.copyWith(blackKingSide: false);
    }
    return cr;
  }

  CastlingRights _updateCastlingRightsAfterRookCapture(CastlingRights cr, Square rookTo, PieceColor rookColor) {
    // rook captured on its initial square removes corresponding right
    return _updateCastlingRightsAfterRookMove(cr, rookTo, rookColor);
  }

  String _appendCheckSuffix(ChessPosition after, String baseSan) {
    final PieceColor justMoved = _opponent(after.sideToMove);
    final bool oppInCheck = isKingInCheck(after, after.sideToMove);
    if (!oppInCheck) return baseSan;

    // Determine if checkmate
    final ChessEngine tmp = ChessEngine(initial: after);
    final bool mate = tmp.generateLegalMoves().isEmpty;
    return '$baseSan${mate ? '#' : '+'}';
  }

  String _sanForMove(ChessPosition before, ChessMove move, Piece moving, Piece? captured) {
    // Castling already handled elsewhere.
    final bool isCapture = captured != null || move.isEnPassant;

    if (moving.type == PieceType.pawn) {
      final String fileLetter = String.fromCharCode('a'.codeUnitAt(0) + move.from.file);
      final String capturePart = isCapture ? '${fileLetter}x' : '';
      final String promo = move.promotion == null ? '' : '=${_sanPieceLetter(move.promotion!)}';
      return '$capturePart${move.to.algebraic}$promo';
    }

    final String pieceLetter = _sanPieceLetter(moving.type);

    // Disambiguation: if another same-type piece can also move to destination, include file or rank (or both).
    final String disambig = _disambiguation(before, move, moving);

    final String captureMark = isCapture ? 'x' : '';
    return '$pieceLetter$disambig$captureMark${move.to.algebraic}';
  }

  String _sanPieceLetter(PieceType type) {
    return switch (type) {
      PieceType.king => 'K',
      PieceType.queen => 'Q',
      PieceType.rook => 'R',
      PieceType.bishop => 'B',
      PieceType.knight => 'N',
      PieceType.pawn => '',
    };
  }

  String _disambiguation(ChessPosition before, ChessMove move, Piece moving) {
    final List<ChessMove> pseudo = _generatePseudoLegalMoves(before)
        .where((m) => m.to == move.to && m.from != move.from)
        .toList();
    final List<ChessMove> samePieceMoves = <ChessMove>[];
    for (final m in pseudo) {
      final Piece? p = before.pieceAt(m.from);
      if (p != null && p.color == moving.color && p.type == moving.type) {
        // must also be legal (not leaving king in check) to require disambiguation
        final ChessPosition next = _applyMoveToPosition(before, m, generateSan: false).position;
        if (!isKingInCheck(next, moving.color)) {
          samePieceMoves.add(m);
        }
      }
    }
    if (samePieceMoves.isEmpty) return '';

    final bool needFile = samePieceMoves.any((m) => m.from.file == move.from.file) == false;
    final bool needRank = samePieceMoves.any((m) => m.from.rank == move.from.rank) == false;
    if (needFile) {
      return String.fromCharCode('a'.codeUnitAt(0) + move.from.file);
    }
    if (needRank) {
      return '${move.from.rank + 1}';
    }
    // both
    return move.from.algebraic;
  }

  // Serialization of whole engine for persistence (position + history + cursor).
  Map<String, dynamic> toJson() => {
        'pos': position.toJson(),
        'hist': _history.map((e) => e.toJson()).toList(),
        'cur': _historyCursor,
      };

  static ChessEngine fromJson(Map<String, dynamic> json) {
    final engine = ChessEngine(initial: ChessPosition.fromJson(json['pos'] as Map<String, dynamic>));
    final List<dynamic> hist = (json['hist'] as List<dynamic>);
    engine._history
      ..clear()
      ..addAll(hist.map((e) => _HistoryEntry.fromJson(e as Map<String, dynamic>)));
    engine._historyCursor = (json['cur'] as num).toInt();
    if (engine._historyCursor > 0) {
      engine.position = engine._history[engine._historyCursor - 1].after;
    }
    return engine;
  }
}

class MoveApplyResult {
  final ChessPosition position;
  final PlayedMove? playedMove;

  const MoveApplyResult({required this.position, this.playedMove});

  Map<String, dynamic> toJson() => {
        'pos': position.toJson(),
        'pm': playedMove?.toJson(),
      };
}

class _HistoryEntry {
  final ChessPosition before;
  final ChessPosition after;
  final PlayedMove playedMove;

  const _HistoryEntry({required this.before, required this.after, required this.playedMove});

  Map<String, dynamic> toJson() => {'b': before.toJson(), 'a': after.toJson(), 'pm': playedMove.toJson()};

  static _HistoryEntry fromJson(Map<String, dynamic> json) => _HistoryEntry(
        before: ChessPosition.fromJson(json['b'] as Map<String, dynamic>),
        after: ChessPosition.fromJson(json['a'] as Map<String, dynamic>),
        playedMove: PlayedMove.fromJson(json['pm'] as Map<String, dynamic>),
      );
}
