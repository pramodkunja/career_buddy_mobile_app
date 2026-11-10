import 'package:career_buddy_lms/app/theme/theme_provider.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/core/storage/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorageService extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
}

ProviderContainer _buildContainer(_FakeStorageService storage) {
  final container = ProviderContainer(
    overrides: [secureStorageProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ThemeModeNotifier', () {
    test('initial state is ThemeMode.system', () {
      final container = _buildContainer(_FakeStorageService());

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('toggle in light (Brightness.light) → ThemeMode.dark', () async {
      final container = _buildContainer(_FakeStorageService());

      await container.read(themeModeProvider.notifier).toggle(Brightness.light);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('toggle in dark (Brightness.dark) → ThemeMode.light', () async {
      final container = _buildContainer(_FakeStorageService());

      await container.read(themeModeProvider.notifier).toggle(Brightness.dark);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('double toggle returns to the starting explicit mode', () async {
      final container = _buildContainer(_FakeStorageService());

      await container.read(themeModeProvider.notifier).toggle(Brightness.light); // → dark
      await container.read(themeModeProvider.notifier).toggle(Brightness.dark);  // → light

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('toggle persists the new mode to storage', () async {
      final storage = _FakeStorageService();
      final container = _buildContainer(storage);

      await container.read(themeModeProvider.notifier).toggle(Brightness.light);

      expect(await storage.read('app_theme_mode'), 'dark');
    });

    test('toggle from system+dark uses platform brightness to determine direction', () async {
      final container = _buildContainer(_FakeStorageService());
      // Initial state is ThemeMode.system; simulate dark platform brightness
      await container.read(themeModeProvider.notifier).toggle(Brightness.dark);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });
}
