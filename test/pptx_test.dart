import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/services/pptx_generator_service.dart';

void main() {
  test('PPTX generation test', () async {
    final rawText = '''
# 💡 بابەتی سیمینار
### 🔹 سلایدی ١: ناساندنی سیمینار
- ناونیشانی سەرەکی: تەکنەلۆجیای زیرەک
- خاڵە سەرەکییەکان: پێناسە و مێژوو
- 🎙️ تێبینی پێشکەشکار: بەخێربێن

### 🔹 سلایدی ٢: کێشەی توێژینەوە
- ناونیشانی سەرەکی: ئاستەنگەکان
- کێشە نەریتییەکان لە کارگێڕیدا
''';

    final slides = PptxGeneratorService.parseSlidesFromText(rawText, defaultTitle: 'سیمینار');
    expect(slides.isNotEmpty, true);
    expect(slides.length, 2);

    final bytes = await PptxGeneratorService.createPptxBytes(slides, presentationTitle: 'سیمینار');
    expect(bytes.isNotEmpty, true);
    print('Generated PPTX bytes length: ${bytes.length}');
  });
}
