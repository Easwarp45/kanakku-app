class CustomSourceData {
  final String name;

  CustomSourceData({required this.name});

  /// Serialize this custom source into a description token.
  String toToken() {
    return '[CustomSource: name=$name]';
  }

  /// Parse the custom source token from a description string.
  static CustomSourceData? parse(String description) {
    final regExp = RegExp(r'\[CustomSource:\s*name=(.*?)\]');
    final match = regExp.firstMatch(description);
    if (match == null) return null;
    return CustomSourceData(name: match.group(1) ?? '');
  }

  /// Clean the description by stripping the custom source token.
  static String cleanDescription(String description) {
    final regExp = RegExp(r'\[CustomSource:\s*name=(.*?)\]\s*');
    return description.replaceAll(regExp, '').trim();
  }
}
