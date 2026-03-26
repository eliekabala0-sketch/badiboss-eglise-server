class ChurchService {
  static String _churchCode = '';

  static void setChurchCode(String code) {
    _churchCode = code.trim();
  }

  static String getChurchCode() {
    return _churchCode;
  }

  static bool hasChurchCode() {
    return _churchCode.isNotEmpty;
  }

  static void clear() {
    _churchCode = '';
  }
}
