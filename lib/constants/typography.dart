// The app's type scale - a small, deliberate set of sizes (rather than
// picking a number per widget) so text reads consistently everywhere, the
// same principle iOS/Material's own named scales (caption/body/title/
// headline/display) are built on. Every fontSize in the app should be one
// of these.
class AppFontSize {
  AppFontSize._();

  /// All-caps eyebrow labels and the smallest metadata (e.g. "BOARDING
  /// STOP", status pill text).
  static const double micro = 10;

  /// Chip/tag text, small button labels, minor metadata.
  static const double label = 11;

  /// Secondary/muted text - timestamps, helper copy, captions.
  static const double caption = 12;

  /// Default reading text - the most common size in the app.
  static const double body = 13;

  /// Emphasized body text - list item primary text, form values.
  static const double bodyLarge = 14;

  /// Card/section headers, prominent buttons, tab items.
  static const double titleSmall = 16;

  /// Larger card headers, sub-page headings.
  static const double titleMedium = 18;

  /// Large stat numbers inside cards, sub-page headings.
  static const double titleLarge = 20;

  /// Secondary headline weight (e.g. a smaller screen header).
  static const double headlineSmall = 22;

  /// Primary screen header title (the gradient header on each tab).
  static const double headline = 24;

  /// Auth-screen titles ("Welcome back" / "Create your account") and other
  /// prominent one-off emphasis.
  static const double headlineLarge = 26;

  /// Avatar initials and other big-but-not-hero display text.
  static const double displaySmall = 28;

  /// True hero text - the wordmark, a big seat/fare number, a booking
  /// reference code. Used sparingly, at most once per screen.
  static const double display = 32;
}
