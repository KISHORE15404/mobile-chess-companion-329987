import 'package:flutter/material.dart';

import '../app/settings.dart';

class SettingsSheet extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<bool> onFlipChanged;

  const SettingsSheet({
    super.key,
    required this.settings,
    required this.onThemeChanged,
    required this.onFlipChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.black.withAlpha(15), borderRadius: BorderRadius.circular(999)),
            ),
            Row(
              children: [
                const Icon(Icons.settings, color: AppColors.secondary),
                const SizedBox(width: 10),
                const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withAlpha(10)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: settings.flipBoard,
                    onChanged: onFlipChanged,
                    title: const Text('Flip board'),
                    subtitle: const Text('Show Black pieces at the bottom'),
                    secondary: const Icon(Icons.flip),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Board theme'),
                    subtitle: Text(BoardThemes.byId(settings.themeId).name),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: BoardThemes.all.map((t) {
                        final bool selected = t.id == settings.themeId;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(t.name),
                          onSelected: (_) => onThemeChanged(t.id),
                          labelStyle: TextStyle(
                            color: selected ? AppColors.text : AppColors.secondary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                          selectedColor: AppColors.primary.withAlpha(25),
                          backgroundColor: cs.surface,
                          side: BorderSide(color: selected ? AppColors.primary.withAlpha(120) : Colors.black.withAlpha(10)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
