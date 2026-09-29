import 'package:flutter/material.dart';
import 'package:pixeldoku/services/purchase_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

/// Game preferences and purchase recovery in the shared forest presentation.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final PurchaseService _purchaseService = PurchaseService();
  bool _isWorking = false;
  String? _errorMessage;

  Future<void> _restorePurchases() async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });
    try {
      await _purchaseService.restorePurchases();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ForestPageShell(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          ForestSection(
            title: 'Preferences',
            child: Column(
              children: [
                _SettingToggle(
                  icon: Icons.music_note,
                  label: 'Music',
                  value: appState.musicOn,
                  onChanged: appState.setMusicOn,
                ),
                _SettingToggle(
                  icon: Icons.volume_up,
                  label: 'Sound Effects',
                  value: appState.sfxOn,
                  onChanged: appState.setSfxOn,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Gameplay',
            child: Column(
              children: [
                _SettingToggle(
                  icon: Icons.grid_view,
                  label: 'Board Highlights',
                  value: appState.boardHighlightsOn,
                  onChanged: appState.setBoardHighlightsOn,
                ),
                ForestListRow(
                  title: 'Daily Theme',
                  subtitle: 'Choose the theme used for Daily puzzles',
                  leading: Image.asset(
                    appState.dailyThemeData.iconAssets.first,
                    width: 30,
                    height: 30,
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: appState.dailyTheme,
                      dropdownColor: const Color(0xFF17212B),
                      style: const TextStyle(color: forestPanelText),
                      iconEnabledColor: forestGold,
                      items: appState.availableThemes
                          .map(
                            (theme) => DropdownMenuItem(
                              value: theme.id,
                              child: Text(theme.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          forestTapHaptic();
                          appState.setDailyTheme(value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Account',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ForestButton(
                  label: _isWorking ? 'Restoring...' : 'Restore Purchases',
                  onPressed: _isWorking ? null : _restorePurchases,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '${appState.statistics['levels_completed'] ?? 0} puzzles completed',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'PIXELDOKU  •  v0.1.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ForestListRow(
      title: label,
      leading: icon == Icons.volume_up
          ? Image.asset(
              'lib/assets/icons/${value ? 'unmute' : 'mute'}.png',
              width: 25,
              height: 25,
              filterQuality: FilterQuality.none,
            )
          : Icon(icon, color: forestGold, size: 25),
      trailing: Switch(
        value: value,
        onChanged: (newValue) {
          forestTapHaptic();
          onChanged(newValue);
        },
        activeThumbColor: Colors.white,
        activeTrackColor: forestGold,
        inactiveThumbColor: Colors.white70,
        inactiveTrackColor: Colors.black54,
      ),
    );
  }
}
