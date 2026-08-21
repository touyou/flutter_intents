import 'package:app_intents/app_intents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIntentsEntityCacheKey', () {
    test('forEntity builds the codegen default key', () {
      expect(
        AppIntentsEntityCacheKey.forEntity('com.example.taskapp.TaskEntity'),
        'app_intents.entities.com.example.taskapp.TaskEntity',
      );
    });

    test('prefix matches the documented codegen prefix', () {
      // Kept in sync with EntityInfo.effectiveCacheKey (codegen) and
      // AppIntentsEntityCache.defaultCacheKey (Swift).
      expect(AppIntentsEntityCacheKey.prefix, 'app_intents.entities.');
    });
  });
}
