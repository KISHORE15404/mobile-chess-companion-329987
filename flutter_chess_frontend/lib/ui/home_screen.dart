import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/game_controller.dart';
import '../app/settings.dart';
import '../chess/model.dart';
import 'chess_board.dart';
import 'move_list.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showSettings(BuildContext context) {
    final GameController c = context.read<GameController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SettingsSheet(
        settings: c.settings,
        onThemeChanged: (id) {
          c.setTheme(id);
        },
        onFlipChanged: (v) {
          c.setFlipBoard(v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, c, _) {
        final ColorScheme cs = Theme.of(context).colorScheme;

        if (!c.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pos = c.engine.position;
        final bool isMate = c.engine.isCheckmate;
        final bool isStalemate = c.engine.isStalemate;

        final String turnLabel = pos.sideToMove == PieceColor.white ? 'White to move' : 'Black to move';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Chess'),
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surface,
            actions: [
              IconButton(
                onPressed: () => _showSettings(context),
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 700;

                final Widget board = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withAlpha(10)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: pos.sideToMove == PieceColor.white ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black.withAlpha(60)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(turnLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          if (isMate)
                            const _StatusInline(label: 'Checkmate', color: AppColors.error)
                          else if (isStalemate)
                            const _StatusInline(label: 'Stalemate', color: AppColors.secondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ChessBoard(
                      board: pos.board,
                      sideToMove: pos.sideToMove,
                      theme: c.boardTheme,
                      flipBoard: c.settings.flipBoard,
                      selected: c.selected,
                      selectedMoves: c.selectedLegalMoves,
                      lastMove: c.lastMove,
                      onSquareTap: c.tapSquare,
                      canDragFrom: c.canDragFrom,
                      onDragStart: c.beginDrag,
                      onDrop: c.dropOn,
                    ),
                    const SizedBox(height: 12),
                    _ControlsRow(
                      canUndo: c.canUndo,
                      canRedo: c.canRedo,
                      onUndo: c.undo,
                      onRedo: c.redo,
                      onReset: c.resetGame,
                    ),
                  ],
                );

                final Widget moves = SizedBox(
                  height: wide ? double.infinity : 260,
                  child: MoveList(
                    moves: c.moveList(),
                    isCheckmate: isMate,
                    isStalemate: isStalemate,
                  ),
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: board),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: moves),
                    ],
                  );
                }

                return Column(
                  children: [
                    board,
                    const SizedBox(height: 16),
                    Expanded(child: moves),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ControlsRow extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;

  const _ControlsRow({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: canRedo ? onRedo : null,
            icon: const Icon(Icons.redo),
            label: const Text('Redo'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}

class _StatusInline extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusInline({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
