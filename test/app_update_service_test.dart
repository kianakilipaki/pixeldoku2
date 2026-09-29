import 'package:flutter_test/flutter_test.dart';
import 'package:pixeldoku/services/app_update_service.dart';

void main() {
  test('compares semantic versions and build numbers', () {
    expect(AppUpdateService.compareVersions('0.2.0+1', '0.1.9+99'), 1);
    expect(AppUpdateService.compareVersions('1.0.0+2', '1.0.0+1'), 1);
    expect(AppUpdateService.compareVersions('v1.0.0', '1.0.0+1'), -1);
    expect(AppUpdateService.compareVersions('1.0.0+1', '1.0.0+1'), 0);
  });
}
