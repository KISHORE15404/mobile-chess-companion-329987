import 'package:flutter/material.dart';

import '../app/settings.dart';
import '../chess/engine.dart';

class MoveList extends StatelessWidget {
  final List<PlayedMove> moves;
  final bool isCheckmate;
  final bool isStalemate;

  const MoveList({
    super.key,
    required this.moves,
    required this.isCheckmate,
    required this.isStalemate,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.format_list_bulleted, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                const Text('Moves', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (isCheckmate)
                  const _StatusPill(label: 'Checkmate', color: AppColors.error)
                else if (isStalemate)
                  const _StatusPill(label: 'Stalemate', color: AppColors.secondary),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: (moves.length / 2).ceil(),
              itemBuilder: (context, idx) {
                final int whiteIdx = idx * 2;
                final int blackIdx = whiteIdx + 1;

                final String whiteSan = moves.length > whiteIdx ? moves[whiteIdx].san : '';
                final String blackSan = moves.length > blackIdx ? moves[blackIdx].san : '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('${idx + 1}.', style: const TextStyle(color: AppColors.secondary)),
                      ),
                      Expanded(child: Text(whiteSan, style: const TextStyle(fontFeatures: []))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(blackSan, style: const TextStyle(fontFeatures: []))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
