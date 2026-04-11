/// Единая подпись оборудования для UI: без дублирования «ОПН» + «ОПН-10».
String equipmentDisplayLabel(String equipmentType, String name) {
  final t = equipmentType.trim();
  final n = name.trim();
  if (n.isEmpty) return t.isEmpty ? '—' : t;
  if (t.isEmpty) return n;
  final tl = t.toLowerCase();
  final nl = n.toLowerCase();
  if (nl.startsWith(tl)) return n;
  if (tl.length >= 2 && nl.contains(tl)) return n;
  final firstTok = nl.split(RegExp(r'[\s\-_/]')).firstWhere((s) => s.isNotEmpty, orElse: () => '');
  if (firstTok.isNotEmpty && tl.startsWith(firstTok)) return n;
  return n;
}
