import 'package:flutter/services.dart';

/// Маска номера опоры: [цифры][буква] / [цифры][буква] / [цифры]
/// Примеры API-строки: `1`, `15а`, `15/1`, `14/12/2`, `14г/1а`
class PoleNumberMask {
  /// Основной номер (только цифры)
  String mainDigits;
  /// Буква после основного номера (кириллица/латиница, одна)
  String letterAfterMain;
  /// Цифры после первого «/» (отпайка / вторая часть)
  String midDigits;
  /// Буква после средней цифровой части
  String letterAfterMid;
  /// Цифры после второго «/»
  String tailDigits;

  PoleNumberMask({
    this.mainDigits = '',
    this.letterAfterMain = '',
    this.midDigits = '',
    this.letterAfterMid = '',
    this.tailDigits = '',
  });

  /// Строка для API / БД (без префикса «Опора »).
  String get apiString {
    final main = '$mainDigits${_normLetter(letterAfterMain)}';
    if (main.isEmpty &&
        midDigits.isEmpty &&
        letterAfterMid.isEmpty &&
        tailDigits.isEmpty) {
      return '';
    }
    if (midDigits.isEmpty &&
        letterAfterMid.isEmpty &&
        tailDigits.isEmpty) {
      return main;
    }
    final mid = '$midDigits${_normLetter(letterAfterMid)}';
    if (tailDigits.isEmpty) {
      return '$main/$mid';
    }
    return '$main/$mid/$tailDigits';
  }

  /// «Опора …»
  String get displayTitle {
    final s = apiString;
    if (s.isEmpty) return 'Опора ';
    return 'Опора $s';
  }

  bool get hasAnyInput =>
      mainDigits.isNotEmpty ||
      letterAfterMain.isNotEmpty ||
      midDigits.isNotEmpty ||
      letterAfterMid.isNotEmpty ||
      tailDigits.isNotEmpty;

  /// Минимум для сохранения: есть основной номер.
  bool get isValidForSave => mainDigits.isNotEmpty;

  static String _normLetter(String s) {
    if (s.isEmpty) return '';
    return s.trim();
  }

  /// Разбор существующего pole_number из БД/API (и строк вида «Опора 15/1»).
  static PoleNumberMask parse(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return PoleNumberMask();
    const prefix = 'Опора ';
    if (t.length > prefix.length && t.toLowerCase().startsWith(prefix.toLowerCase())) {
      t = t.substring(prefix.length).trim();
    }
    if (t.isEmpty) return PoleNumberMask();

    final parts = t.split('/');
    if (parts.isEmpty) return PoleNumberMask();

    final first = parts[0].trim();
    final mainMatch = RegExp(r'^(\d+)(.*)$').firstMatch(first);
    if (mainMatch == null) {
      return PoleNumberMask(mainDigits: first.replaceAll(RegExp(r'\D'), ''));
    }
    final md = mainMatch.group(1) ?? '';
    var rest = (mainMatch.group(2) ?? '').trim();
    String l1 = '';
    if (rest.isNotEmpty) {
      final ch = _firstLetterChar(rest);
      if (ch != null) l1 = ch;
    }

    if (parts.length == 1) {
      return PoleNumberMask(
        mainDigits: md,
        letterAfterMain: l1,
      );
    }

    final second = parts[1].trim();
    final midMatch = RegExp(r'^(\d+)(.*)$').firstMatch(second);
    String midD = '';
    String l2 = '';
    if (midMatch != null) {
      midD = midMatch.group(1) ?? '';
      rest = (midMatch.group(2) ?? '').trim();
      if (rest.isNotEmpty) {
        final ch = _firstLetterChar(rest);
        if (ch != null) l2 = ch;
      }
    } else {
      midD = second.replaceAll(RegExp(r'\D'), '');
    }

    String tail = '';
    if (parts.length >= 3) {
      tail = parts[2].trim().replaceAll(RegExp(r'\D'), '');
    }

    return PoleNumberMask(
      mainDigits: md,
      letterAfterMain: l1,
      midDigits: midD,
      letterAfterMid: l2,
      tailDigits: tail,
    );
  }

  static String? _firstLetterChar(String s) {
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'[a-zA-Zа-яА-ЯёЁ]').hasMatch(c)) return c;
    }
    return null;
  }

  /// Копия с изменениями.
  PoleNumberMask copyWith({
    String? mainDigits,
    String? letterAfterMain,
    String? midDigits,
    String? letterAfterMid,
    String? tailDigits,
  }) {
    return PoleNumberMask(
      mainDigits: mainDigits ?? this.mainDigits,
      letterAfterMain: letterAfterMain ?? this.letterAfterMain,
      midDigits: midDigits ?? this.midDigits,
      letterAfterMid: letterAfterMid ?? this.letterAfterMid,
      tailDigits: tailDigits ?? this.tailDigits,
    );
  }
}

/// Ввод: только цифры, максимум 3 символа.
class PoleDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 3) d = d.substring(0, 3);
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}

/// Одна буква (кириллица или латиница).
class PoleSingleLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var t = newValue.text;
    if (t.isEmpty) {
      return const TextEditingValue();
    }
    for (final r in t.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'[a-zA-Zа-яА-ЯёЁ]').hasMatch(c)) {
        return TextEditingValue(
          text: c,
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
    }
    return oldValue;
  }
}

/// Логика подсказки следующего номера по последним номерам на линии.
class PoleNumberSuggestion {
  PoleNumberSuggestion._();

  /// Кириллица для шага букв (частые в номерах опор).
  static const String _cyrLetters = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';

  /// [recentNewestFirst] — последние номера, **сначала самый новый** (как только что созданные).
  static PoleNumberMask? suggestNext(List<String> recentNewestFirst) {
    if (recentNewestFirst.isEmpty) return null;
    final parsed = recentNewestFirst
        .map(PoleNumberMask.parse)
        .where((m) => m.isValidForSave)
        .toList();
    if (parsed.isEmpty) return null;

    final last = parsed.first;
    if (parsed.length == 1) {
      return _suggestAfterOne(last);
    }

    final prev = parsed[1];
    return _suggestAfterTwo(prev, last);
  }

  static PoleNumberMask? _suggestAfterOne(PoleNumberMask last) {
    // Одна опора: обычно +1 к основному числу, если маска «простая»
    if (last.midDigits.isEmpty &&
        last.letterAfterMid.isEmpty &&
        last.tailDigits.isEmpty) {
      if (last.letterAfterMain.isEmpty) {
        final n = int.tryParse(last.mainDigits);
        if (n != null) return PoleNumberMask(mainDigits: '${n + 1}');
      } else {
        final nextL = _nextLetter(last.letterAfterMain);
        if (nextL != null) {
          return PoleNumberMask(
            mainDigits: last.mainDigits,
            letterAfterMain: nextL,
          );
        }
      }
    }
    // Сложная маска — дублируем структуру, инкремент «последнего изменяемого» сегмента
    return _incrementDeepest(last);
  }

  static PoleNumberMask? _suggestAfterTwo(PoleNumberMask older, PoleNumberMask newer) {
    // «Чистая» магистраль: два целых числа без слэшей и букв
    if (_isPlainMainOnly(older) && _isPlainMainOnly(newer)) {
      final a = int.tryParse(older.mainDigits);
      final b = int.tryParse(newer.mainDigits);
      if (a != null && b != null) {
        if (b > a) {
          return PoleNumberMask(mainDigits: '${b + 1}');
        }
        if (b < a) {
          // Два подряд убывающих — продолжаем вниз
          return PoleNumberMask(mainDigits: '${b - 1}');
        }
      }
    }

    // Шаблон  N / M / … одинаковый префикс
    if (older.mainDigits == newer.mainDigits &&
        older.letterAfterMain == newer.letterAfterMain) {
      // 1/1 → 1/2
      if (older.midDigits.isNotEmpty &&
          newer.midDigits.isNotEmpty &&
          older.letterAfterMid.isEmpty &&
          newer.letterAfterMid.isEmpty &&
          older.tailDigits.isEmpty &&
          newer.tailDigits.isEmpty) {
        final o = int.tryParse(older.midDigits);
        final n = int.tryParse(newer.midDigits);
        if (o != null && n != null) {
          if (n > o) {
            return newer.copyWith(midDigits: '${n + 1}');
          }
          if (n < o) {
            return newer.copyWith(midDigits: '${n - 1}');
          }
        }
      }
      // 1/1а → 1/1б
      if (older.midDigits == newer.midDigits &&
          older.midDigits.isNotEmpty &&
          older.letterAfterMid.isNotEmpty &&
          newer.letterAfterMid.isNotEmpty) {
        final nl = _nextLetter(newer.letterAfterMid);
        if (nl != null) {
          return newer.copyWith(letterAfterMid: nl);
        }
      }
    }

    return _incrementDeepest(newer);
  }

  static bool _isPlainMainOnly(PoleNumberMask m) {
    return m.midDigits.isEmpty &&
        m.letterAfterMain.isEmpty &&
        m.letterAfterMid.isEmpty &&
        m.tailDigits.isEmpty &&
        m.mainDigits.isNotEmpty &&
        int.tryParse(m.mainDigits) != null;
  }

  static PoleNumberMask? _incrementDeepest(PoleNumberMask m) {
    if (m.tailDigits.isNotEmpty) {
      final t = int.tryParse(m.tailDigits);
      if (t != null) return m.copyWith(tailDigits: '${t + 1}');
    }
    if (m.letterAfterMid.isNotEmpty) {
      final nl = _nextLetter(m.letterAfterMid);
      if (nl != null) return m.copyWith(letterAfterMid: nl);
    }
    if (m.midDigits.isNotEmpty) {
      final n = int.tryParse(m.midDigits);
      if (n != null) return m.copyWith(midDigits: '${n + 1}');
    }
    if (m.letterAfterMain.isNotEmpty) {
      final nl = _nextLetter(m.letterAfterMain);
      if (nl != null) {
        return m.copyWith(letterAfterMain: nl);
      }
    }
    if (m.mainDigits.isNotEmpty) {
      final n = int.tryParse(m.mainDigits);
      if (n != null) return m.copyWith(mainDigits: '${n + 1}');
    }
    return null;
  }

  static String? _nextLetter(String ch) {
    if (ch.isEmpty) return null;
    final c = ch.toLowerCase();
    final i = _cyrLetters.indexOf(c);
    if (i >= 0 && i + 1 < _cyrLetters.length) {
      return _preserveCase(ch, _cyrLetters[i + 1]);
    }
    if (c.length == 1) {
      final code = c.codeUnitAt(0);
      if (code >= 0x0430 && code <= 0x044f) {
        // а..я
        if (code < 0x044f) {
          return _preserveCase(ch, String.fromCharCode(code + 1));
        }
      }
      if (code >= 0x0410 && code <= 0x042f) {
        if (code < 0x042f) {
          return String.fromCharCode(code + 1);
        }
      }
      // латиница a-z A-Z
      if (c == 'z') return 'a';
      if (c == 'Z') return 'A';
      if (RegExp(r'[a-y]').hasMatch(c)) {
        return _preserveCase(ch, String.fromCharCode(code + 1));
      }
    }
    return null;
  }

  static String _preserveCase(String original, String lowerNew) {
    if (original.isEmpty) return lowerNew;
    if (original == original.toUpperCase() && original != original.toLowerCase()) {
      return lowerNew.toUpperCase();
    }
    return lowerNew;
  }
}
