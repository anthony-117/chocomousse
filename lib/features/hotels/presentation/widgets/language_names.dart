/// English names for the language codes Booking.com gives (`en-gb`, `it`). The region is dropped, since staff
/// who speak British or American English both help an English speaker.
const _names = {
  'ar': 'Arabic',
  'bg': 'Bulgarian',
  'ca': 'Catalan',
  'cs': 'Czech',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'en': 'English',
  'es': 'Spanish',
  'fa': 'Persian',
  'fi': 'Finnish',
  'fr': 'French',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hr': 'Croatian',
  'hu': 'Hungarian',
  'hy': 'Armenian',
  'id': 'Indonesian',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'nl': 'Dutch',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sk': 'Slovak',
  'sr': 'Serbian',
  'sv': 'Swedish',
  'th': 'Thai',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
};

/// The language's English name, or the code as given when it isn't known.
String languageName(String code) => _names[code.toLowerCase().split('-').first] ?? code;

/// Names in the order given, without repeats ("en-gb" and "en-us" are both English).
List<String> languageNames(List<String> codes) => codes.map(languageName).toSet().toList();
