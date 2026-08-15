class KurdishArabicReshaper {
  // Glyph forms: [Isolated, Final, Initial, Medial]
  static final Map<int, List<int>> _glyphForms = {
    0x0621: [0xFE80, 0xFE80, 0xFE80, 0xFE80], // ء
    0x0622: [0xFE81, 0xFE82, 0xFE81, 0xFE82], // آ
    0x0623: [0xFE83, 0xFE84, 0xFE83, 0xFE84], // أ
    0x0624: [0xFE85, 0xFE86, 0xFE85, 0xFE86], // ؤ
    0x0625: [0xFE87, 0xFE88, 0xFE87, 0xFE88], // إ
    0x0626: [0xFE89, 0xFE8A, 0xFE8B, 0xFE8C], // ئ
    0x0627: [0xFE8D, 0xFE8E, 0xFE8D, 0xFE8E], // ا
    0x0628: [0xFE8F, 0xFE90, 0xFE91, 0xFE92], // ب
    0x067E: [0xFB56, 0xFB57, 0xFB58, 0xFB59], // پ
    0x062A: [0xFE95, 0xFE96, 0xFE97, 0xFE98], // ت
    0x062B: [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // ث
    0x062C: [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // ج
    0x0686: [0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D], // چ
    0x062D: [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // ح
    0x062E: [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // خ
    0x062F: [0xFEA9, 0xFEAA, 0xFEA9, 0xFEAA], // د
    0x0630: [0xFEAB, 0xFEAC, 0xFEAB, 0xFEAC], // ذ
    0x0631: [0xFEAD, 0xFEAE, 0xFEAD, 0xFEAE], // ر
    0x0695: [0xFB8C, 0xFB8D, 0xFB8C, 0xFB8D], // ڕ
    0x0632: [0xFEAF, 0xFEB0, 0xFEAF, 0xFEB0], // ز
    0x0698: [0xFB8A, 0xFB8B, 0xFB8A, 0xFB8B], // ژ
    0x0633: [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // س
    0x0634: [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // ش
    0x0635: [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // ص
    0x0636: [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // ض
    0x0637: [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // ط
    0x0638: [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // ظ
    0x0639: [0xFEC9, 0xFECA, 0xFECB, 0xFECC], // ع
    0x063A: [0xFECD, 0xFECE, 0xFECF, 0xFED0], // غ
    0x0641: [0xFED1, 0xFED2, 0xFED3, 0xFED4], // ف
    0x06A4: [0xFB6A, 0xFB6B, 0xFB6C, 0xFB6D], // ڤ
    0x0642: [0xFED5, 0xFED6, 0xFED7, 0xFED8], // ق
    0x0643: [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // ك
    0x06A9: [0xFB8E, 0xFB8F, 0xFB90, 0xFB91], // ک (Kurdish/Farsi Kaf)
    0x06AF: [0xFB92, 0xFB93, 0xFB94, 0xFB95], // گ
    0x0644: [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // ل
    0x06B5: [0xFB9E, 0xFB9F, 0xFB9E, 0xFBA0], // ڵ (Kurdish Ll)
    0x0645: [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // م
    0x0646: [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // ن
    0x0647: [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // ه (Arabic Heh)
    0x06BE: [0xFBAA, 0xFBAB, 0xFBAC, 0xFBAD], // ھ (Kurdish Heh Do-Chashmee)
    0x06D5: [0x06D5, 0xFEEA, 0x06D5, 0xFEEA], // ە (Kurdish Ae)
    0x0629: [0xFE93, 0xFE94, 0xFE93, 0xFE94], // ة (Ta Marbuta)
    0x0648: [0xFEED, 0xFEEE, 0xFEED, 0xFEEE], // و
    0x06C6: [0xFBD9, 0xFBDA, 0xFBD9, 0xFBDA], // ۆ (Kurdish Oe)
    0x06C7: [0xFBD7, 0xFBD8, 0xFBD7, 0xFBD8], // ۇ
    0x0649: [0xFEEF, 0xFEF0, 0xFBE8, 0xFBE9], // ى
    0x064A: [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // ي
    0x06CC: [0xFBFC, 0xFBFD, 0xFBFE, 0xFBFF], // ی (Kurdish/Farsi Yeh)
    0x06CE: [0xFBE4, 0xFBE5, 0xFBE6, 0xFBE7], // ێ (Kurdish Yeh with V)
    0x06D0: [0xFBE4, 0xFBE5, 0xFBE6, 0xFBE7], // ێ (Alternative Kurdish Yeh)
  };

  // Letters that DO NOT connect to the NEXT (left) character
  static const Set<int> _rightJoinersOnly = {
    0x0621, // ء
    0x0622, // آ
    0x0623, // أ
    0x0624, // ؤ
    0x0625, // إ
    0x0627, // ا
    0x062F, // د
    0x0630, // ذ
    0x0631, // ر
    0x0695, // ڕ
    0x0632, // ز
    0x0698, // ژ
    0x0648, // و
    0x06C6, // ۆ
    0x06C7, // ۇ
    0x06D5, // ە
    0x0629, // ة
  };

  static bool _isArabicOrKurdish(int code) {
    return _glyphForms.containsKey(code) || (code >= 0x0600 && code <= 0x06FF) || (code >= 0xFB50 && code <= 0xFDFF) || (code >= 0xFE70 && code <= 0xFEFF);
  }

  static bool _connectsToNext(int code) {
    return _glyphForms.containsKey(code) && !_rightJoinersOnly.contains(code);
  }

  static bool _connectsToPrev(int code) {
    return _glyphForms.containsKey(code) && code != 0x0621;
  }

  /// Shapes Arabic & Kurdish connected letters into their presentation forms
  static String shape(String text) {
    if (text.isEmpty) return text;

    final runes = text.runes.toList();
    final shaped = <int>[];

    for (int i = 0; i < runes.length; i++) {
      final current = runes[i];

      // Handle Lam-Alef Ligatures (لا, لآ, لأ, لإ)
      if (current == 0x0644 && i + 1 < runes.length) {
        final next = runes[i + 1];
        int? ligature;
        final prevConnects = i > 0 && _connectsToNext(runes[i - 1]);

        if (next == 0x0622) {
          ligature = prevConnects ? 0xFEF6 : 0xFEF5; // لآ
        } else if (next == 0x0623) {
          ligature = prevConnects ? 0xFEF8 : 0xFEF7; // لأ
        } else if (next == 0x0625) {
          ligature = prevConnects ? 0xFEFA : 0xFEF9; // لإ
        } else if (next == 0x0627) {
          ligature = prevConnects ? 0xFEFC : 0xFEFB; // لا
        }

        if (ligature != null) {
          shaped.add(ligature);
          i++; // Skip the alef
          continue;
        }
      }

      if (!_glyphForms.containsKey(current)) {
        shaped.add(current);
        continue;
      }

      final prevConnects = i > 0 && _connectsToNext(runes[i - 1]);
      final nextConnects = i + 1 < runes.length && _connectsToPrev(runes[i + 1]);

      final forms = _glyphForms[current]!;
      int glyph;

      if (prevConnects && nextConnects && _connectsToNext(current)) {
        glyph = forms[3]; // Medial
      } else if (prevConnects) {
        glyph = forms[1]; // Final
      } else if (nextConnects && _connectsToNext(current)) {
        glyph = forms[2]; // Initial
      } else {
        glyph = forms[0]; // Isolated
      }

      shaped.add(glyph);
    }

    return String.fromCharCodes(shaped);
  }

  /// Shapes and applies bidirectional (BiDi) reordering so PDF canvas renders RTL text correctly
  static String shapeAndReorder(String text) {
    if (text.isEmpty) return text;

    final lines = text.split('\n');
    final processedLines = <String>[];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        processedLines.add('');
        continue;
      }

      // Check if line contains RTL characters
      final hasRtl = line.runes.any(_isArabicOrKurdish);
      if (!hasRtl) {
        processedLines.add(line);
        continue;
      }

      // Shape the full line
      final shapedLine = shape(line);

      // BiDi Reorder: Split into words / directional tokens and reverse for RTL
      final reordered = _bidiReorderLine(shapedLine);
      processedLines.add(reordered);
    }

    return processedLines.join('\n');
  }

  static String _bidiReorderLine(String shapedText) {
    final tokens = <_TextToken>[];
    final runes = shapedText.runes.toList();

    int i = 0;
    while (i < runes.length) {
      final code = runes[i];

      // Number or English / LTR sequence
      if (_isLtrChar(code)) {
        final start = i;
        while (i < runes.length && _isLtrChar(runes[i])) {
          i++;
        }
        tokens.add(_TextToken(String.fromCharCodes(runes.sublist(start, i)), false));
      } else if (code == 0x0020) {
        // Space
        tokens.add(_TextToken(' ', false, isSpace: true));
        i++;
      } else {
        // RTL Arabic / Kurdish / Punctuation
        final start = i;
        while (i < runes.length && !_isLtrChar(runes[i]) && runes[i] != 0x0020) {
          i++;
        }
        tokens.add(_TextToken(String.fromCharCodes(runes.sublist(start, i)), true));
      }
    }

    // Build the visual line by reversing RTL tokens and reversing the overall token order
    final buffer = StringBuffer();
    for (int t = tokens.length - 1; t >= 0; t--) {
      final token = tokens[t];
      if (token.isRtl) {
        // Reverse characters in RTL token
        final chars = token.text.runes.toList().reversed;
        buffer.write(String.fromCharCodes(chars));
      } else {
        // Keep LTR token as is (e.g. "12", "2025 - 2026", "AI", "PDF")
        buffer.write(token.text);
      }
    }

    return buffer.toString();
  }

  static bool _isLtrChar(int code) {
    // Digits, Latin letters, brackets
    return (code >= 0x0030 && code <= 0x0039) || // 0-9
        (code >= 0x0041 && code <= 0x005A) || // A-Z
        (code >= 0x0061 && code <= 0x007A) || // a-z
        code == 0x002B || // +
        code == 0x0025 || // %
        code == 0x002F || // /
        code == 0x002D; // -
  }
}

class _TextToken {
  final String text;
  final bool isRtl;
  final bool isSpace;

  _TextToken(this.text, this.isRtl, {this.isSpace = false});
}
