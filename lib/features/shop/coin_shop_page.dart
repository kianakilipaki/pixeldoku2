import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pixeldoku/models/theme_catalog.dart';
import 'package:pixeldoku/services/ads_service.dart';
import 'package:pixeldoku/services/purchase_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

/// Coin, hint, and rewarded-ad storefront.
class CoinShopPage extends StatefulWidget {
  const CoinShopPage({super.key});

  @override
  State<CoinShopPage> createState() => _CoinShopPageState();
}

class _CoinShopPageState extends State<CoinShopPage> {
  final PurchaseService _purchaseService = PurchaseService();
  String? _removeAdsPrice;
  String? _purchaseMessage;
  bool _loadingRemoveAds = true;
  bool _purchasingRemoveAds = false;

  @override
  void initState() {
    super.initState();
    _loadRemoveAdsOffer();
  }

  Future<void> _loadRemoveAdsOffer() async {
    final price = await _purchaseService.loadRemoveAdsPrice();
    if (!mounted) return;
    setState(() {
      _removeAdsPrice = price;
      _loadingRemoveAds = false;
    });
  }

  Future<void> _purchaseRemoveAds() async {
    if (_purchasingRemoveAds || PurchaseService.gameplayAdsRemoved) return;
    setState(() {
      _purchasingRemoveAds = true;
      _purchaseMessage = null;
    });

    final result = await _purchaseService.purchaseRemoveAds();
    if (!mounted) return;
    setState(() {
      _purchasingRemoveAds = false;
      if (result.purchased) {
        _purchaseMessage = 'Gameplay ads removed. Thank you!';
      } else if (!result.cancelled) {
        _purchaseMessage = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // Show owned themes during testing; release builds list only locked themes.
    final shopThemes = kDebugMode ? ThemeCatalog.themes : appState.lockedThemes;
    return ForestPageShell(
      title: 'Shop',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          _ShopWallet(appState: appState),
          const SizedBox(height: 16),
          ForestSection(
            title: 'Daily Rewards',
            child: Column(
              children: [
                _ShopRow(
                  icon: Image.asset('lib/assets/icons/coin.png', width: 34),
                  title: 'Watch for Coins',
                  subtitle: '10 free coins',
                  buttonText: 'WATCH',
                  onPressed: () => AdsService.showRewardedCoins(appState),
                ),
                _ShopRow(
                  icon: Image.asset('lib/assets/icons/hint.png', width: 34),
                  title: 'Watch for Hints',
                  subtitle: '3 free hints',
                  buttonText: 'WATCH',
                  onPressed: () => AdsService.showRewardedHints(appState),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Ads',
            child: Column(
              children: [
                _ShopRow(
                  icon: Image.asset(
                    'lib/assets/icons/ad.png',
                    width: 34,
                    height: 34,
                    filterQuality: FilterQuality.none,
                  ),
                  title: 'Remove Gameplay Ads',
                  subtitle: PurchaseService.gameplayAdsRemoved
                      ? 'Automatic post-game ads are removed'
                      : 'One-time purchase · reward ads stay available',
                  buttonText: PurchaseService.gameplayAdsRemoved
                      ? 'REMOVED'
                      : _purchasingRemoveAds
                      ? 'BUYING...'
                      : _loadingRemoveAds
                      ? 'LOADING...'
                      : 'BUY ${_removeAdsPrice ?? PurchaseService.suggestedRemoveAdsPrice}',
                  enabled:
                      !PurchaseService.gameplayAdsRemoved &&
                      !_purchasingRemoveAds &&
                      !_loadingRemoveAds,
                  onPressed: _purchaseRemoveAds,
                ),
                if (_purchaseMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _purchaseMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PurchaseService.gameplayAdsRemoved
                          ? forestPanelText
                          : Colors.orangeAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Coin Packs',
            child: Column(
              children: [
                _ShopRow(
                  icon: Image.asset('lib/assets/icons/coin.png', width: 34),
                  title: 'Pile of Coins',
                  subtitle: '100 coins',
                  // Placeholder USD prices until store products are configured.
                  buttonText: r'BUY $0.99',
                  onPressed: () async {
                    await _purchaseService.loadOfferings();
                    await appState.addCoins(100);
                  },
                ),
                _ShopRow(
                  icon: Image.asset(
                    'lib/assets/icons/coins.png',
                    width: 34,
                    height: 34,
                    filterQuality: FilterQuality.none,
                  ),
                  title: 'Stack of Coins',
                  subtitle: '500 coins',
                  buttonText: r'BUY $3.99',
                  enabled: false,
                  onPressed: () {},
                ),
                _ShopRow(
                  icon: Image.asset(
                    'lib/assets/icons/chest.png',
                    width: 34,
                    height: 34,
                    filterQuality: FilterQuality.none,
                  ),
                  title: 'Chest of Coins',
                  subtitle: '1,000 coins',
                  buttonText: r'BUY $6.99',
                  enabled: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Bundles',
            child: Column(
              children: [
                _ShopRow(
                  icon: Image.asset('lib/assets/icons/hint.png', width: 34),
                  title: 'Hint Bundle',
                  subtitle: 'Add 5 hints',
                  buttonText: '75',
                  coinPrice: true,
                  enabled: appState.coins >= 75,
                  onPressed: () async {
                    await appState.spendCoins(75);
                    await appState.addHints(5);
                  },
                ),
                _ShopRow(
                  icon: Image.asset(
                    'lib/assets/icons/heart.png',
                    width: 34,
                    height: 34,
                    filterQuality: FilterQuality.none,
                  ),
                  title: 'Heart Bundle',
                  subtitle: '${appState.spareHearts} available · Add 3 hearts',
                  buttonText: '100',
                  coinPrice: true,
                  enabled: appState.coins >= 100,
                  onPressed: () => appState.buyHeartBundle(),
                ),
              ],
            ),
          ),
          if (shopThemes.isNotEmpty) ...[
            const SizedBox(height: 14),
            ForestSection(
              title: 'Themes',
              child: Column(
                children: [
                  for (final theme in shopThemes)
                    _ShopRow(
                      icon: Image.asset(
                        theme.iconAssets.first,
                        width: 34,
                        height: 34,
                        filterQuality: FilterQuality.none,
                      ),
                      title: theme.name,
                      subtitle: appState.unlockedThemes.contains(theme.id)
                          ? 'Already unlocked'
                          : 'Unlock this theme',
                      buttonText: appState.unlockedThemes.contains(theme.id)
                          ? 'UNLOCKED'
                          : '500',
                      coinPrice: !appState.unlockedThemes.contains(theme.id),
                      enabled:
                          appState.coins >= 500 &&
                          !appState.unlockedThemes.contains(theme.id),
                      onPressed: () => appState.buyTheme(theme.id),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopWallet extends StatelessWidget {
  const _ShopWallet({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: forestSectionBorder, width: 2),
      ),
      child: Row(
        children: [
          _WalletStat(
            asset: 'lib/assets/icons/coin.png',
            value: appState.coins,
            label: 'COINS',
          ),
          const _WalletDivider(),
          _WalletStat(
            asset: 'lib/assets/icons/heart.png',
            value: appState.spareHearts,
            label: 'HEARTS',
          ),
          const _WalletDivider(),
          _WalletStat(
            asset: 'lib/assets/icons/hint.png',
            value: appState.hints,
            label: 'HINTS',
          ),
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({
    required this.asset,
    required this.value,
    required this.label,
  });

  final String asset;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            asset,
            width: 25,
            height: 25,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: forestGold,
                  fontFamily: 'Fira Sans',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletDivider extends StatelessWidget {
  const _WalletDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: forestSectionBorder.withValues(alpha: 0.65),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    this.coinPrice = false,
    this.enabled = true,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final bool coinPrice;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ForestListRow(
      title: title,
      subtitle: subtitle,
      leading: icon,
      trailing: ForestPressBounce(
        enabled: enabled,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF477D20),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color.fromARGB(255, 80, 82, 78),
            disabledForegroundColor: const Color.fromARGB(255, 160, 156, 147),
            side: BorderSide(
              color: enabled
                  ? const Color(0xFF79A32D)
                  : const Color(0xFF7C896D),
              width: 2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          onPressed: enabled ? onPressed : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (coinPrice) ...[
                Image.asset('lib/assets/icons/coin.png', width: 15, height: 15),
                const SizedBox(width: 4),
              ],
              Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
