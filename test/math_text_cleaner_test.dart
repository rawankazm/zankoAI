import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/utils/math_text_cleaner.dart';

void main() {
  group('cleanMathAndDollarSigns', () {
    test('removes raw dollar signs and escaped dollar signs', () {
      final input =
          r'بۆ بەشی یەکەم ($3x^2$): frac{d}{dx}(3x^2) = 3 \cdot (2x^{2-1}) =\$$ $$6x';
      final cleaned = cleanMathAndDollarSigns(input);

      expect(cleaned.contains(r'$'), isFalse);
      expect(cleaned.contains(r'\$'), isFalse);
      expect(cleaned.contains(r'$$'), isFalse);
      expect(cleaned, contains('d/dx(3x^2) = 3 · (2x^(2-1)) = 6x'));
      expect(cleaned, contains('(3x^2)'));
    });

    test('cleans the user screenshot exact derivative example', () {
      final input1 = r'* یاسای گشتی: frac{d}{dx}(x^n) = n \cdot\$ $x^{n-1}';
      final cleaned1 = cleanMathAndDollarSigns(input1);
      expect(cleaned1.contains(r'$'), isFalse);
      expect(cleaned1, equals('* یاسای گشتی: d/dx(x^n) = n · x^(n-1)'));

      final input2 =
          r'* بۆ بەشی دووەم ($5x$): frac{d}{dx}(5x) = 5 \cdot (1x^{1-1}) = 5\$$ \cdot x^0 = 5$$';
      final cleaned2 = cleanMathAndDollarSigns(input2);
      expect(cleaned2.contains(r'$'), isFalse);
      expect(
        cleaned2,
        equals('* بۆ بەشی دووەم (5x): d/dx(5x) = 5 · (1x^(1-1)) = 5 · x^0 = 5'),
      );

      final input3 = r'* بۆ بەشی سێیەم ($-2$): frac{d}{dx}(-2) = 0$$\$$';
      final cleaned3 = cleanMathAndDollarSigns(input3);
      expect(cleaned3.contains(r'$'), isFalse);
      expect(cleaned3, equals('* بۆ بەشی سێیەم (-2): d/dx(-2) = 0'));
    });

    test('cleans square roots and fractions', () {
      final input = r'$$\sqrt{x^2 + y^2} = \frac{a + b}{c - d}$$';
      final cleaned = cleanMathAndDollarSigns(input);

      expect(cleaned.contains(r'$'), isFalse);
      expect(cleaned, contains('√(x^2 + y^2)'));
      expect(cleaned, contains('(a + b)/(c - d)'));
    });

    test('cleans common LaTeX math symbols and arrows', () {
      final input = r'x \le 10 \pm 2 \times 5 \div 2 \neq 0 \to \infty';
      final cleaned = cleanMathAndDollarSigns(input);

      expect(cleaned, equals('x ≤ 10 ± 2 × 5 ÷ 2 ≠ 0 → ∞'));
    });

    test('cleans empty or already clean strings gracefully', () {
      expect(cleanMathAndDollarSigns(''), equals(''));
      expect(cleanMathAndDollarSigns('سڵاو هاوڕێ!'), equals('سڵاو هاوڕێ!'));
    });
  });
}
