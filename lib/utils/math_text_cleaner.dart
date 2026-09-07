/// Math and Text Cleaner for ZankoAI.
/// Strips LaTeX delimiters ($, $$, \$), cleans raw LaTeX math notation into
/// beautiful Unicode/plain-text math, and ensures RTL-safe rendering without stray symbols.
library;

/// Cleans raw LaTeX math formatting and removes all dollar signs ($)
/// so that mathematics render cleanly in Kurdish and right-to-left UI.
String cleanMathAndDollarSigns(String text) {
  if (text.isEmpty) return text;

  String result = text;

  // 1. Normalize escaped dollar signs and multi-dollar signs
  result = result.replaceAll(r'\$$', '');
  result = result.replaceAll(r'$$', '');
  result = result.replaceAll(r'\$', '');

  // 2. Clean LaTeX fractions: \frac{a}{b} or frac{a}{b} (with optional whitespace between braces)
  result = result.replaceAllMapped(
    RegExp(r'\\?frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}', multiLine: true),
    (match) {
      final num = match.group(1)?.trim() ?? '';
      final den = match.group(2)?.trim() ?? '';
      if (num.length <= 4 && den.length <= 4) {
        return '$num/$den';
      }
      return '($num)/($den)';
    },
  );

  // 3. Clean LaTeX square roots: \sqrt{x} or sqrt{x}
  result = result.replaceAllMapped(
    RegExp(r'\\?sqrt\s*\{([^{}]+)\}'),
    (match) => '√(${match.group(1)?.trim() ?? ''})',
  );

  // 4. Clean LaTeX math symbols to Unicode
  result = result.replaceAll(r'\cdot', '·');
  result = result.replaceAll(r'\times', '×');
  result = result.replaceAll(r'\div', '÷');
  result = result.replaceAll(r'\pm', '±');
  result = result.replaceAll(r'\mp', '∓');
  result = result.replaceAll(r'\leq', '≤');
  result = result.replaceAll(r'\le', '≤');
  result = result.replaceAll(r'\geq', '≥');
  result = result.replaceAll(r'\ge', '≥');
  result = result.replaceAll(r'\neq', '≠');
  result = result.replaceAll(r'\ne', '≠');
  result = result.replaceAll(r'\approx', '≈');
  result = result.replaceAll(r'\sim', '~');
  result = result.replaceAll(r'\infty', '∞');
  result = result.replaceAll(r'\int', '∫');
  result = result.replaceAll(r'\iint', '∬');
  result = result.replaceAll(r'\iiint', '∭');
  result = result.replaceAll(r'\partial', '∂');
  result = result.replaceAll(r'\nabla', '∇');
  result = result.replaceAll(r'\sum', '∑');
  result = result.replaceAll(r'\prod', '∏');
  result = result.replaceAll(r'\pi', 'π');
  result = result.replaceAll(r'\theta', 'θ');
  result = result.replaceAll(r'\alpha', 'α');
  result = result.replaceAll(r'\beta', 'β');
  result = result.replaceAll(r'\gamma', 'γ');
  result = result.replaceAll(r'\delta', 'δ');
  result = result.replaceAll(r'\lambda', 'λ');
  result = result.replaceAll(r'\mu', 'μ');
  result = result.replaceAll(r'\sigma', 'σ');
  result = result.replaceAll(r'\omega', 'ω');
  result = result.replaceAll(r'\Delta', 'Δ');
  result = result.replaceAll(r'\in', '∈');
  result = result.replaceAll(r'\notin', '∉');
  result = result.replaceAll(r'\subset', '⊂');
  result = result.replaceAll(r'\subseteq', '⊆');
  result = result.replaceAll(r'\cup', '∪');
  result = result.replaceAll(r'\cap', '∩');
  result = result.replaceAll(r'\forall', '∀');
  result = result.replaceAll(r'\exists', '∃');
  result = result.replaceAll(r'\to', '→');
  result = result.replaceAll(r'\rightarrow', '→');
  result = result.replaceAll(r'\leftarrow', '←');
  result = result.replaceAll(r'\Rightarrow', '⇒');
  result = result.replaceAll(r'\Leftarrow', '⇐');
  result = result.replaceAll(r'\iff', '⇔');
  result = result.replaceAll(r'\Leftrightarrow', '⇔');

  // 5. Clean exponent brackets: ^{n-1} -> ^(n-1), ^{2} -> ^2
  result = result.replaceAllMapped(
    RegExp(r'\^\{([^{}]+)\}'),
    (match) {
      final inner = match.group(1)?.trim() ?? '';
      if (inner.length == 1) return '^$inner';
      return '^($inner)';
    },
  );

  // 6. Clean subscript brackets: _{i} -> _i, _{1} -> _1
  result = result.replaceAllMapped(
    RegExp(r'_\{([^{}]+)\}'),
    (match) {
      final inner = match.group(1)?.trim() ?? '';
      if (inner.length == 1) return '_$inner';
      return '_($inner)';
    },
  );

  // 7. Clean \text{...}, \mathrm{...}, \mathbf{...}, \mathit{...}, etc.
  result = result.replaceAllMapped(
    RegExp(r'\\(text|mathrm|mathbf|mathit|textbf|textit)\{([^{}]+)\}'),
    (match) => match.group(2) ?? '',
  );

  // 8. Clean isolated LaTeX delimiters like \( and \) or \[ and \]
  result = result.replaceAll(r'\(', '(');
  result = result.replaceAll(r'\)', ')');
  result = result.replaceAll(r'\[', '[');
  result = result.replaceAll(r'\]', ']');

  // 9. Remove all remaining dollar signs ($) unconditionally
  result = result.replaceAll(r'$', '');

  // 10. Clean any double spaces created by delimiter stripping (preserving line breaks)
  result = result.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

  return result;
}
