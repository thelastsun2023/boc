class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  String? username;
  String? role;
  String? storeCode;
  String? token;
  bool mallEnabled = false;
  bool get canAccessMall => isAdmin || mallEnabled;
  String uiLanguage = 'ZH';
  List<String> allowedCategoryCodes = const [];

  bool get isLoggedIn => username != null && username!.trim().isNotEmpty;
  bool get isAdmin => role == 'ADMIN';
  bool get isEnglish => uiLanguage.toUpperCase() == 'EN';

  void setSession({
    required String username,
    required String role,
    String? storeCode,
    String? token,
    String uiLanguage = 'ZH',
    bool mallEnabled = false,
    required List<String> allowedCategoryCodes,
  }) {
    this.username = username;
    this.role = role;
    this.token = token;
    this.mallEnabled = mallEnabled;
    this.storeCode = storeCode?.trim().isEmpty == true
        ? null
        : storeCode?.trim();
    this.uiLanguage = uiLanguage.toUpperCase() == 'EN' ? 'EN' : 'ZH';
    this.allowedCategoryCodes = List<String>.from(allowedCategoryCodes);
  }

  bool canAccessCategory(String? categoryCode) {
    if (isAdmin) {
      return true;
    }

    final normalized = categoryCode?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return allowedCategoryCodes.contains(normalized);
  }

  void clear() {
    username = null;
    role = null;
    token = null;
    mallEnabled = false;
    storeCode = null;
    uiLanguage = 'ZH';
    allowedCategoryCodes = const [];
  }
}
