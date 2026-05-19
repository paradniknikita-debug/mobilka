/// Имя файла из заголовка Content-Disposition (filename / filename* UTF-8).
String? filenameFromContentDisposition(String? header) {
  if (header == null || header.trim().isEmpty) return null;
  final star = RegExp(r"filename\*\s*=\s*UTF-8''([^;\s]+)", caseSensitive: false)
      .firstMatch(header);
  if (star != null) {
    try {
      return Uri.decodeComponent(star.group(1)!.replaceAll('+', ' '));
    } catch (_) {
      return star.group(1);
    }
  }
  final plain = RegExp(r'filename\s*=\s*"([^"]+)"', caseSensitive: false)
          .firstMatch(header) ??
      RegExp(r'filename\s*=\s*([^;\s]+)', caseSensitive: false).firstMatch(header);
  if (plain != null) {
    var name = plain.group(1) ?? '';
    if (name.startsWith('"') && name.endsWith('"')) {
      name = name.substring(1, name.length - 1);
    }
    return name.trim().isEmpty ? null : name.trim();
  }
  return null;
}
