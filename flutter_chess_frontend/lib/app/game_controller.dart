import 'dart:async';

import 'package:flutter/foundation.dart';

import '../chess/engine.dart';
import '../chess/model.dart';
import 'persistence.dart';
import 'settings.dart';

class GameController extends ChangeNotifier {
  final AppPersistence _persistence;

  ChessEngine _engine;
  AppSettings _settings;

  Square? _selected;
  List<ChessMove> _selectedLegalMoves = <ChessMove>[];
  ChessMove? _lastMove;

  bool _isLoaded = false;

  GameController({required AppPersistence persistence})
      : _persistence = persistence,
        _engine = ChessEngine(),
        _settings = AppSettings.defaultSettings;

  bool get isLoaded => _isLoaded;

  ChessEngine get engine => _engine;
  AppSettings get settings => _settings;

  Square? get selected => _selected;
  List<ChessMove> get selectedLegalMoves => List<ChessMove>.unmodifiable(_selectedLegalMoves);
  ChessMove? get lastMove => _lastMove;

  BoardTheme get boardTheme => BoardThemes.byId(_settings.themeId);

  bool get canUndo => _engine.canUndo;
  bool get canRedo => _engine.canRedo;

  // PUBLIC_INTERFACE
  Future<void> load() async {
    /// Load settings and game state from persistence.
    final AppSettings loadedSettings = await _persistence.loadSettings();
    final ChessEngine? loadedGame = await _persistence.loadGame();

    _settings = loadedSettings;
    if (loadedGame != null) {
      _engine = loadedGame;
    } else {
      _engine = ChessEngine();
    }

    _selected = null;
    _selectedLegalMoves = <ChessMove>[];
    _lastMove = _engine.playedMoves.isEmpty ? null : _engine.playedMoves.last.move;

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveDebounced() async {
    // Save without blocking UI; best-effort.
    unawaited(_persistence.saveSettings(_settings));
    unawaited(_persistence.saveGame(_engine));
  }

  // PUBLIC_INTERFACE
  void setTheme(String themeId) {
    /// Update board theme and persist.
    _settings = _settings.copyWith(themeId: themeId);
    notifyListeners();
    unawaited(_persistence.saveSettings(_settings));
  }

  // PUBLIC_INTERFACE
  void setFlipBoard(bool flip) {
    /// Update board orientation and persist.
    _settings = _settings.copyWith(flipBoard: flip);
    notifyListeners();
    unawaited(_persistence.saveSettings(_settings));
  }

  // PUBLIC_INTERFACE
  void resetGame() {
    /// Reset game state to initial.
    _engine.reset();
    _selected = null;
    _selectedLegalMoves = <ChessMove>[];
    _lastMove = null;
    notifyListeners();
    unawaited(_persistence.clearGame());
  }

  // PUBLIC_INTERFACE
  void undo() {
    /// Undo one move (if possible).
    if (_engine.undo()) {
      _selected = null;
      _selectedLegalMoves = <ChessMove>[];
      _lastMove = _engine.playedMoves.isEmpty ? null : _engine.playedMoves.last.move;
      notifyListeners();
      unawaited(_persistence.saveGame(_engine));
    }
  }

  // PUBLIC_INTERFACE
  void redo() {
    /// Redo one move (if possible).
    if (_engine.redo()) {
      _selected = null;
      _selectedLegalMoves = <ChessMove>[];
      _lastMove = _engine.playedMoves.isEmpty ? null : _engine.playedMoves.last.move;
      notifyListeners();
      unawaited(_persistence.saveGame(_engine));
    }
  }

  // PUBLIC_INTERFACE
  void tapSquare(Square sq) {
    /// Handle tap-to-move interaction.
    final Piece? piece = _engine.position.pieceAt(sq);

    // If selecting own piece: select and show legal moves
    if (piece != null && piece.color == _engine.position.sideToMove) {
      _selected = sq;
      _selectedLegalMoves = _engine.legalMovesFrom(sq);
      notifyListeners();
      return;
    }

    // If we have a selection: try move to tapped square
    if (_selected != null) {
      final Square from = _selected!;
      final ChessMove? candidate = _selectedLegalMoves.cast<ChessMove?>().firstWhere(
            (m) => m != null && m.to == sq,
            orElse: () => null,
          );
      if (candidate != null) {
        _playMoveWithPromotionDefault(candidate);
        return;
      }
    }

    // Otherwise clear selection
    _selected = null;
    _selectedLegalMoves = <ChessMove>[];
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  bool canDragFrom(Square from) {
    /// Whether a piece can be dragged from this square (side to move only).
    final Piece? piece = _engine.position.pieceAt(from);
    return piece != null && piece.color == _engine.position.sideToMove;
  }

  // PUBLIC_INTERFACE
  void beginDrag(Square from) {
    /// Called when drag begins to show possible destinations.
    final Piece? piece = _engine.position.pieceAt(from);
    if (piece == null || piece.color != _engine.position.sideToMove) return;
    _selected = from;
    _selectedLegalMoves = _engine.legalMovesFrom(from);
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  bool dropOn(Square to) {
    /// Attempt to drop currently dragged/selected piece onto [to].
    if (_selected == null) return false;
    final ChessMove? candidate = _selectedLegalMoves.cast<ChessMove?>().firstWhere(
          (m) => m != null && m.to == to,
          orElse: () => null,
        );
    if (candidate == null) return false;
    return _playMoveWithPromotionDefault(candidate);
  }

  bool _playMoveWithPromotionDefault(ChessMove move) {
    // If promotion, default to queen for quick UX (can be expanded later).
    final ChessMove toPlay = (move.promotion != null) ? move : move;
    final MoveApplyResult? res = _engine.tryPlayMove(toPlay);
    if (res == null) return false;

    _lastMove = res.playedMove!.move;
    _selected = null;
    _selectedLegalMoves = <ChessMove>[];
    notifyListeners();
    unawaited(_persistence.saveGame(_engine));
    return true;
  }

  // PUBLIC_INTERFACE
  List<PlayedMove> moveList() {
    /// Return played moves up to current cursor (for UI).
    return _engine.playedMoves;
  }
}
