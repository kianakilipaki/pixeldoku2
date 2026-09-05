import 'package:flutter/material.dart';
import 'package:pixeldoku/services/ads_service.dart';
import 'package:pixeldoku/services/purchase_service.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';

/// Coin, hint, and rewarded-ad storefront.
class CoinShopPage extends StatelessWidget {
  CoinShopPage({super.key});

  final PurchaseService _purchaseService = PurchaseService();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ForestPageShell(
      title: 'Shop',
      trailing: ForestCoinBadge(coins: appState.coins),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          ForestSection(
            title: 'Daily Rewards',
            child: Column(
              children: [
                _ShopRow(
                  icon: Image.asset('lib/assets/icons/coin.png', width: 34),
                  title: 'Watch for Coins',
                  subtitle: 'Earn a free coin reward',
                  buttonText: 'WATCH',
                  onPressed: () => AdsService.showRewardedCoins(appState),
                ),
                _ShopRow(
                  icon: Image.asset('lib/assets/icons/hint.png', width: 34),
                  title: 'Watch for Hints',
                  subtitle: '${appState.hints} hints available',
                  buttonText: 'WATCH',
                  onPressed: () => AdsService.showRewardedHints(appState),
                ),
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
                  buttonText: 'BUY',
                  onPressed: () async {
                    await _purchaseService.loadOfferings();
                    await appState.addCoins(100);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForestSection(
            title: 'Power Ups',
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
                  icon: Image.asset('lib/assets/icons/ad.png', width: 34),
                  title: 'Ad Skip',
                  subtitle: 'Skip one advertisement',
                  buttonText: '150',
                  coinPrice: true,
                  enabled: appState.coins >= 150,
                  onPressed: () => appState.spendCoins(150),
                ),
              ],
            ),
          ),
        ],
      ),
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
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF477D20),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black38,
          side: const BorderSide(color: Color(0xFF79A32D), width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
    );
  }
}
