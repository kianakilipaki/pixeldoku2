import 'package:flutter/material.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

enum _ThemeFilter { all, unlocked, locked }

/// Browse theme progress and choose any unlocked theme.
class ThemesPage extends StatefulWidget {
  const ThemesPage({super.key});

  @override
  State<ThemesPage> createState() => _ThemesPageState();
}

class _ThemesPageState extends State<ThemesPage> {
  _ThemeFilter _filter = _ThemeFilter.all;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final themes = ThemeCatalog.themes.where((theme) {
      final unlocked = appState.unlockedThemes.contains(theme.id);
      return switch (_filter) {
        _ThemeFilter.all => true,
        _ThemeFilter.unlocked => unlocked,
        _ThemeFilter.locked => !unlocked,
      };
    }).toList();

    return ForestPageShell(
      title: 'Themes',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          _ThemeFilters(
            selected: _filter,
            onSelected: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: 8),
          ForestSection(
            title: 'Theme Collection',
            child: Column(
              children: themes
                  .map((theme) => _ThemeRow(theme: theme, appState: appState))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeFilters extends StatelessWidget {
  const _ThemeFilters({required this.selected, required this.onSelected});

  final _ThemeFilter selected;
  final ValueChanged<_ThemeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _ThemeFilter.values.map((filter) {
        final active = selected == filter;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                backgroundColor: active
                    ? const Color(0xFF2D210B).withValues(alpha: 0.92)
                    : const Color(0xFF111820).withValues(alpha: 0.8),
                foregroundColor: active ? forestGold : Colors.white70,
                side: BorderSide(
                  color: active ? forestGold : const Color(0xFF68431E),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              onPressed: () => onSelected(filter),
              child: Text(filter.name.toUpperCase()),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.theme, required this.appState});

  final PixelDokuTheme theme;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final unlocked = appState.unlockedThemes.contains(theme.id);
    final active = appState.activeTheme == theme.id;
    final completed = appState.completedPuzzlesForTheme(theme.id);
    final total = theme.iconAssets.length;
    final shownCompleted = completed.clamp(0, total);
    final progress = shownCompleted / total;

    return ForestListRow(
      title: theme.name,
      subtitle: unlocked
          ? active
                ? 'Active • $shownCompleted/$total puzzles completed'
                : '$shownCompleted/$total puzzles completed • Tap to use'
          : 'Unlocks at level ${theme.unlockLevel}',
      onTap: unlocked ? () => appState.setActiveTheme(theme.id) : null,
      leading: Opacity(
        opacity: unlocked ? 1 : 0.42,
        child: Image.asset(theme.iconAssets.first, width: 38, height: 38),
      ),
      trailing: SizedBox(
        width: 74,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  active
                      ? Icons.check_circle
                      : unlocked
                      ? Icons.star
                      : Icons.lock,
                  color: active
                      ? Colors.lightGreenAccent
                      : unlocked
                      ? forestGold
                      : Colors.white54,
                  size: 17,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: forestPanelText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.black54,
                valueColor: AlwaysStoppedAnimation(
                  unlocked ? forestGold : const Color(0xFF1985DF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
