/// Cricket number formatting, ported from the small helpers repeated across
/// the web app's JavaScript files (`overs`, `rate`, `economy`, `ordinal`).
abstract final class Fmt {
  /// Legal balls -> overs notation: 20 balls = `3.2`.
  static String overs(int balls) {
    final safe = balls < 0 ? 0 : balls;
    return '${safe ~/ 6}.${safe % 6}';
  }

  /// Strike rate (runs per 100 balls) with two decimals.
  static String strikeRate(int runs, int balls) =>
      balls > 0 ? (runs / balls * 100).toStringAsFixed(2) : '0.00';

  /// Economy (runs per over) with two decimals.
  static String economy(int runs, int legalBalls) =>
      legalBalls > 0 ? (runs / (legalBalls / 6)).toStringAsFixed(2) : '0.00';

  /// Run rate, same maths as [economy] but for a team total.
  static String runRate(int runs, int legalBalls) => economy(runs, legalBalls);

  /// `1st`, `2nd`, `3rd`, `4th`...
  static String ordinal(int n) => switch (n) {
    1 => '1st',
    2 => '2nd',
    3 => '3rd',
    _ => '${n}th',
  };

  /// Net run rate with an explicit sign and three decimals: `+0.512`.
  static String nrr(double value) {
    final normalized = value == 0 ? 0.0 : value; // avoid "-0.000"
    final text = normalized.toStringAsFixed(3);
    return normalized > 0 ? '+$text' : text;
  }

  /// Plural helper: `plural(1, 'run')` -> `1 run`, `plural(3, 'run')` -> `3 runs`.
  static String plural(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';
}
