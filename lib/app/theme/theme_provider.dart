import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';

const _kThemeModeKey = 'app_theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadPersistedMode();
    return ThemeMode.system;
  }

  void _loadPersistedMode() async {
    try {
      final saved = await ref.read(secureStorageProvider).read(_kThemeModeKey);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      }
    } catch (_) {
      // Storage unavailable — keep default ThemeMode.system
    }
  }

  Future<void> toggle(Brightness currentBrightness) async {
    final isDark = state == ThemeMode.dark ||
        (state == ThemeMode.system && currentBrightness == Brightness.dark);
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    try {
      await ref.read(secureStorageProvider).write(
        _kThemeModeKey,
        next == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
