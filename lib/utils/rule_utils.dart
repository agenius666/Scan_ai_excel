List<String> parseCheckColumns(String input) {
  return input
      .split(RegExp(r'[，,]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
