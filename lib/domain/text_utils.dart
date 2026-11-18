/// Case-insensitive name comparison, approximating JavaScript's
/// `a.localeCompare(b)` used by the web app for sorting teams and players.
int compareNames(String a, String b) {
  final byLower = a.toLowerCase().compareTo(b.toLowerCase());
  return byLower != 0 ? byLower : a.compareTo(b);
}
