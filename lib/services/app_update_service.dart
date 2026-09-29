import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.message,
    required this.isRequired,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri storeUrl;
  final String message;
  final bool isRequired;
}

class AppUpdateService {
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final package = await PackageInfo.fromPlatform();
      final client = _supabase;
      if (client == null) return null;

      final row = await client
          .from('app_releases')
          .select(
            'latest_version, minimum_version, store_url, message, enabled',
          )
          .eq('platform', 'android')
          .maybeSingle();

      if (row == null || row['enabled'] != true) return null;

      final currentVersion = '${package.version}+${package.buildNumber}';
      final latestVersion = row['latest_version']?.toString().trim() ?? '';
      if (latestVersion.isEmpty ||
          compareVersions(latestVersion, currentVersion) <= 0) {
        return null;
      }

      final minimumVersion =
          row['minimum_version']?.toString().trim() ?? '0.0.0';
      final configuredUrl = row['store_url']?.toString().trim();
      final storeUrl = configuredUrl != null && configuredUrl.isNotEmpty
          ? Uri.tryParse(configuredUrl)
          : null;

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        storeUrl:
            storeUrl ??
            Uri.https('play.google.com', '/store/apps/details', {
              'id': package.packageName,
            }),
        message: row['message']?.toString().trim().isNotEmpty == true
            ? row['message'].toString().trim()
            : 'A new version of PixelDoku is ready to play.',
        isRequired: compareVersions(minimumVersion, currentVersion) > 0,
      );
    } catch (error, stackTrace) {
      AppLogger.error('App update check failed', error, stackTrace);
      return null;
    }
  }

  Future<bool> openStore(AppUpdateInfo update) async {
    try {
      return await launchUrl(
        update.storeUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Opening Play Store failed', error, stackTrace);
      return false;
    }
  }

  @visibleForTesting
  static int compareVersions(String left, String right) {
    final leftVersion = _VersionParts.parse(left);
    final rightVersion = _VersionParts.parse(right);
    final length = leftVersion.core.length > rightVersion.core.length
        ? leftVersion.core.length
        : rightVersion.core.length;

    for (var index = 0; index < length; index++) {
      final leftPart = index < leftVersion.core.length
          ? leftVersion.core[index]
          : 0;
      final rightPart = index < rightVersion.core.length
          ? rightVersion.core[index]
          : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }

    return leftVersion.build.compareTo(rightVersion.build);
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

class _VersionParts {
  const _VersionParts(this.core, this.build);

  final List<int> core;
  final int build;

  factory _VersionParts.parse(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final pieces = normalized.split('+');
    final core = pieces.first
        .split('.')
        .map(
          (part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '') ?? 0,
        )
        .toList();
    final build = pieces.length > 1
        ? int.tryParse(RegExp(r'^\d+').stringMatch(pieces[1]) ?? '') ?? 0
        : 0;
    return _VersionParts(core, build);
  }
}
