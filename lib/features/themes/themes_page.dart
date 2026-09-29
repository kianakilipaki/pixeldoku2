import 'package:flutter/material.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/models/title_catalog.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

enum _ThemeFilter { all, unlocked, locked }

/// Browse theme collections, choose a Daily theme, and explore player titles.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key, this.revealTitle});

  final String? revealTitle;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  _ThemeFilter _filter = _ThemeFilter.all;
  final Map<String, GlobalKey> _titleKeys = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.revealTitle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealTitle());
    }
  }

  Future<void> _revealTitle() async {
    for (var attempt = 0; attempt < 5 && mounted; attempt++) {
      final target = _titleKeys[widget.revealTitle]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
        return;
      }
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      title: 'Collections',
      child: ListView(
        controller: _scrollController,
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
              children: [
                const Text(
                  'Select an unlocked theme to use for daily puzzles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: forestPanelText,
                    fontFamily: 'Fira Sans',
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                for (final theme in themes)
                  _ThemeRow(theme: theme, appState: appState),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ForestSection(
            title: 'Achievements',
            child: _AchievementProgress(
              appState: appState,
              revealTitle: widget.revealTitle,
              titleKeys: _titleKeys,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementProgress extends StatelessWidget {
  const _AchievementProgress({
    required this.appState,
    required this.revealTitle,
    required this.titleKeys,
  });

  final AppState appState;
  final String? revealTitle;
  final Map<String, GlobalKey> titleKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: TitleCategory.values.map((category) {
        final titles = TitleCatalog.byCategory(category);
        if (titles.isEmpty) return const SizedBox.shrink();

        final unlocked = titles
            .where((title) => title.isUnlocked(appState))
            .length;

        return ExpansionTile(
          key: PageStorageKey(category),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          iconColor: forestGold,
          collapsedIconColor: forestGold,
          textColor: forestPanelText,
          collapsedTextColor: forestPanelText,
          shape: const Border(),
          collapsedShape: const Border(),
          initiallyExpanded:
              revealTitle != null &&
              TitleCatalog.byName(revealTitle!).category == category,
          title: Text(
            TitleCatalog.categoryName(category),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '$unlocked of ${titles.length} titles unlocked',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Fira Sans',
              fontSize: 13,
            ),
          ),
          leading: Image.asset(
            'lib/assets/icons/trophy.png',
            width: 28,
            height: 28,
            filterQuality: FilterQuality.none,
          ),
          children: [
            for (final title in titles)
              ForestListRow(
                key: titleKeys.putIfAbsent(title.name, GlobalKey.new),
                title: title.name,
                subtitle: category == TitleCategory.secret
                    ? 'Secret title · ${title.isUnlocked(appState) ? 'Unlocked' : 'Locked'}'
                    : '${title.isUnlocked(appState) ? 'Unlocked' : 'Locked'} · ${title.unlockText}',
                leading: Image.asset(
                  title.isUnlocked(appState)
                      ? 'lib/assets/icons/star.png'
                      : 'lib/assets/icons/lock.png',
                  width: 26,
                  height: 26,
                  filterQuality: FilterQuality.none,
                ),
              ),
          ],
        );
      }).toList(),
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
            child: ForestPressBounce(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(filter.name.toUpperCase(), maxLines: 1),
                ),
              ),
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
    final active = appState.dailyTheme == theme.id;
    final completed = appState.completedPuzzlesForTheme(theme.id);
    final total = theme.iconAssets.length;
    final shownCompleted = completed.clamp(0, total);
    final progress = shownCompleted / total;

    return ForestListRow(
      title: theme.name,
      subtitle: unlocked
          ? active
                ? 'Daily theme • $shownCompleted/$total puzzles completed'
                : '$shownCompleted/$total puzzles completed • Use for Daily'
          : 'Unlocks at level ${theme.unlockLevel}',
      onTap: unlocked ? () => appState.setDailyTheme(theme.id) : null,
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
