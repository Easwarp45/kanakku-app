class CustomCategoryData {
  final String name;

  CustomCategoryData({required this.name});

  /// Serialize this custom category into a description token.
  String toToken() {
    return '[CustomCategory: name=$name]';
  }

  /// Parse the custom category token from a description string.
  static CustomCategoryData? parse(String description) {
    final regExp = RegExp(r'\[CustomCategory:\s*name=(.*?)\]');
    final match = regExp.firstMatch(description);
    if (match == null) return null;
    return CustomCategoryData(name: match.group(1) ?? '');
  }

  /// Clean the description by stripping the custom category token.
  static String cleanDescription(String description) {
    final regExp = RegExp(r'\[CustomCategory:\s*name=(.*?)\]\s*');
    return description.replaceAll(regExp, '').trim();
  }
}
