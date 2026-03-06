import 'package:flutter/material.dart';

import '../app/settings.dart';
import '../chess/model.dart';

typedef OnSquareTap = void Function(Square square);
typedef CanDragFrom = bool Function(Square from);
typedef OnDragStart = void Function(Square from);
typedef OnDrop = bool Function(Square to);

class ChessBoard extends StatelessWidget {
  final List<Piece?> board;
  final PieceColor sideToMove;
  final BoardTheme theme;
  final bool flipBoard;

  final Square? selected;
  final List<ChessMove> selectedMoves;
  final ChessMove? lastMove;

  final OnSquareTap onSquareTap;
  final CanDragFrom canDragFrom;
  final OnDragStart onDragStart;
  final OnDrop onDrop;

  const ChessBoard({
    super.key,
    required this.board,
    required this.sideToMove,
    required this.theme,
    required this.flipBoard,
    required this.selected,
    required this.selectedMoves,
    required this.lastMove,
    required this.onSquareTap,
    required this.canDragFrom,
    required this.onDragStart,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double size = constraints.biggest.shortestSide;
          final double squareSize = size / 8;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                _BoardGrid(
                  theme: theme,
                  flipBoard: flipBoard,
                  selected: selected,
                  selectedMoves: selectedMoves,
                  lastMove: lastMove,
                  onSquareTap: onSquareTap,
                ),
                // Pieces as overlay for drag operations
                Positioned.fill(
                  child: _PiecesLayer(
                    board: board,
                    flipBoard: flipBoard,
                    squareSize: squareSize,
                    onSquareTap: onSquareTap,
                    canDragFrom: canDragFrom,
                    onDragStart: onDragStart,
                    onDrop: onDrop,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BoardGrid extends StatelessWidget {
  final BoardTheme theme;
  final bool flipBoard;
  final Square? selected;
  final List<ChessMove> selectedMoves;
  final ChessMove? lastMove;
  final OnSquareTap onSquareTap;

  const _BoardGrid({
    required this.theme,
    required this.flipBoard,
    required this.selected,
    required this.selectedMoves,
    required this.lastMove,
    required this.onSquareTap,
  });

  bool _isDark(int file, int rank) => (file + rank) % 2 == 1;

  Square _displayToSquare(int displayFile, int displayRank) {
    // displayRank 0 at top; actual rank depends on flip.
    final int file = flipBoard ? 7 - displayFile : displayFile;
    final int rank = flipBoard ? displayRank : 7 - displayRank;
    return Square(file, rank);
  }

  bool _isSelectedDest(Square sq) => selectedMoves.any((m) => m.to == sq);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemCount: 64,
      itemBuilder: (context, idx) {
        final int displayRank = idx ~/ 8;
        final int displayFile = idx % 8;
        final Square sq = _displayToSquare(displayFile, displayRank);

        final bool isDark = _isDark(sq.file, sq.rank);
        Color baseColor = isDark ? theme.darkSquare : theme.lightSquare;

        // last move highlight
        if (lastMove != null && (sq == lastMove!.from || sq == lastMove!.to)) {
          baseColor = Color.alphaBlend(theme.lastMove, baseColor);
        }

        // selection highlight
        if (selected != null && sq == selected) {
          baseColor = Color.alphaBlend(theme.highlight, baseColor);
        } else if (_isSelectedDest(sq)) {
          baseColor = Color.alphaBlend(theme.highlight, baseColor);
        }

        // Tap target exists even under pieces (helps empty-square taps)
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSquareTap(sq),
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              border: Border.all(color: Colors.black.withAlpha(15), width: 0.5),
            ),
          ),
        );
      },
    );
  }
}

class _PiecesLayer extends StatelessWidget {
  final List<Piece?> board;
  final bool flipBoard;
  final double squareSize;
  final OnSquareTap onSquareTap;
  final CanDragFrom canDragFrom;
  final OnDragStart onDragStart;
  final OnDrop onDrop;

  const _PiecesLayer({
    required this.board,
    required this.flipBoard,
    required this.squareSize,
    required this.onSquareTap,
    required this.canDragFrom,
    required this.onDragStart,
    required this.onDrop,
  });

  Square _displayToSquare(int displayFile, int displayRank) {
    final int file = flipBoard ? 7 - displayFile : displayFile;
    final int rank = flipBoard ? displayRank : 7 - displayRank;
    return Square(file, rank);
  }

  Offset _squareTopLeft(Square sq) {
    final int displayFile = flipBoard ? 7 - sq.file : sq.file;
    final int displayRank = flipBoard ? sq.rank : 7 - sq.rank;
    return Offset(displayFile * squareSize, displayRank * squareSize);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];

    for (int displayRank = 0; displayRank < 8; displayRank++) {
      for (int displayFile = 0; displayFile < 8; displayFile++) {
        final Square sq = _displayToSquare(displayFile, displayRank);
        final Piece? piece = board[sq.rank * 8 + sq.file];
        if (piece == null) continue;

        final Offset tl = _squareTopLeft(sq);
        final String symbol = _pieceSymbol(piece);

        children.add(
          Positioned(
            left: tl.dx,
            top: tl.dy,
            width: squareSize,
            height: squareSize,
            child: _SquareDropTarget(
              square: sq,
              onDrop: onDrop,
              child: _DraggablePiece(
                square: sq,
                symbol: symbol,
                canDrag: canDragFrom(sq),
                onTap: () => onSquareTap(sq),
                onDragStart: () => onDragStart(sq),
                size: squareSize,
              ),
            ),
          ),
        );
      }
    }

    // Add empty-square drop targets too (so you can drop on empty squares)
    for (int displayRank = 0; displayRank < 8; displayRank++) {
      for (int displayFile = 0; displayFile < 8; displayFile++) {
        final Square sq = _displayToSquare(displayFile, displayRank);
        final Piece? piece = board[sq.rank * 8 + sq.file];
        if (piece != null) continue;
        final Offset tl = _squareTopLeft(sq);
        children.add(
          Positioned(
            left: tl.dx,
            top: tl.dy,
            width: squareSize,
            height: squareSize,
            child: _SquareDropTarget(
              square: sq,
              onDrop: onDrop,
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
    }

    return Stack(children: children);
  }

  String _pieceSymbol(Piece p) {
    // Unicode chess symbols
    return switch (p.color) {
      PieceColor.white => switch (p.type) {
          PieceType.king => '♔',
          PieceType.queen => '♕',
          PieceType.rook => '♖',
          PieceType.bishop => '♗',
          PieceType.knight => '♘',
          PieceType.pawn => '♙',
        },
      PieceColor.black => switch (p.type) {
          PieceType.king => '♚',
          PieceType.queen => '♛',
          PieceType.rook => '♜',
          PieceType.bishop => '♝',
          PieceType.knight => '♞',
          PieceType.pawn => '♟',
        },
    };
  }
}

class _DraggablePiece extends StatelessWidget {
  final Square square;
  final String symbol;
  final bool canDrag;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final double size;

  const _DraggablePiece({
    required this.square,
    required this.symbol,
    required this.canDrag,
    required this.onTap,
    required this.onDragStart,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final Text pieceText = Text(
      symbol,
      style: TextStyle(fontSize: size * 0.72, height: 1.0),
      textAlign: TextAlign.center,
    );

    final Widget content = Center(child: pieceText);

    final Widget tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );

    if (!canDrag) return tappable;

    return Draggable<Square>(
      data: square,
      onDragStarted: onDragStart,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: size, height: size, child: content),
      ),
      childWhenDragging: const SizedBox.expand(),
      child: tappable,
    );
  }
}

class _SquareDropTarget extends StatelessWidget {
  final Square square;
  final OnDrop onDrop;
  final Widget child;

  const _SquareDropTarget({
    required this.square,
    required this.onDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Square>(
      builder: (context, candidateData, rejectedData) => child,
      onWillAcceptWithDetails: (details) => details.data != square,
      onAcceptWithDetails: (details) {
        onDrop(square);
      },
    );
  }
}
