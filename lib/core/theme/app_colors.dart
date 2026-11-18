import 'package:flutter/painting.dart';

/// Design tokens from the web app's `css/style.css` (`:root` variables).
abstract final class AppColors {
  /// `--pale` / `--canvas`: page background.
  static const canvas = Color(0xFF0B121E);

  /// `--surface` / `--panel`: cards, bars, modals.
  static const surface = Color(0xFF111C2D);

  /// Second stop of the hero panel gradient.
  static const surfaceRaised = Color(0xFF1A293E);

  /// `--blue` / `--olive`: the mint accent.
  static const mint = Color(0xFF00FFC2);

  /// `--olive-dark`: hover/pressed mint.
  static const mintDark = Color(0xFF00D8A5);

  /// Text on top of mint.
  static const onMint = Color(0xFF04131E);

  /// `--accent-orange` / `--alert`: live pill, boundaries, wickets.
  static const orange = Color(0xFFFF5E1E);

  /// `--green` / `--positive`.
  static const green = Color(0xFF10B981);

  /// `--muted`.
  static const muted = Color(0xFF64748B);

  /// `--line`: rgba(100,116,139,.38) borders.
  static const line = Color(0x6164748B);

  /// Subtle fills: rgba(100,116,139,.22).
  static const fill = Color(0x3864748B);

  /// `--yellow`: highlight behind the batters at the crease.
  static const highlight = Color(0x2400FFC2);

  static const white = Color(0xFFFFFFFF);
}

/// Status chip colours (`.status-planned`, `.status-ongoing`, ...).
abstract final class StatusColors {
  static (Color background, Color foreground) of(String status) =>
      switch (status) {
        'ongoing' => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
        'completed' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
        'cancelled' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
        'planned' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
        _ => (const Color(0xFFE2E8F0), const Color(0xFF334155)),
      };
}
