import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/data/kurdistan_universities_data.dart';

void main() {
  group('Kurdistan Universities & Departments Data Tests', () {
    test('Universities list should contain all major institutions including colleges & institutes', () {
      final list = KurdistanUniversitiesData.universities;
      expect(list.length, greaterThanOrEqualTo(25));

      final names = list.map((u) => u.nameKu).toList();
      expect(names.any((n) => n.contains('سەلاحەدین')), isTrue);
      expect(names.any((n) => n.contains('سلێمانی')), isTrue);
      expect(names.any((n) => n.contains('دهۆک')), isTrue);
      expect(names.any((n) => n.contains('EPU')), isTrue);
      expect(names.any((n) => n.contains('شەقڵاوە')), isTrue);
      expect(names.any((n) => n.contains('سۆران')), isTrue);
      expect(names.any((n) => n.contains('کۆیە')), isTrue);
      expect(names.any((n) => n.contains('SPU')), isTrue);
      expect(names.any((n) => n.contains('DPU')), isTrue);
      expect(names.any((n) => n.contains('هەولێری پزیشکی')), isTrue);
      expect(names.any((n) => n.contains('تیشک')), isTrue);
      expect(names.any((n) => n.contains('ئەمریکی')), isTrue);
      expect(names.any((n) => n.contains('جیهان')), isTrue);
    });

    test('Every university must have at least 5 departments', () {
      for (final uni in KurdistanUniversitiesData.universities) {
        expect(uni.departments.length, greaterThanOrEqualTo(5),
            reason: '${uni.nameKu} should have at least 5 departments');
        expect(uni.cityKey, isNotEmpty);
        expect(uni.cityNameKu, isNotEmpty);
        expect(uni.type, isNotEmpty);
      }
    });

    test('findUniversity should properly locate university or institute by name', () {
      final uni = KurdistanUniversitiesData.findUniversity('سەلاحەدین');
      expect(uni, isNotNull);
      expect(uni!.id, 'salahaddin_erbil');

      final shaqlawa = KurdistanUniversitiesData.findUniversity('شەقڵاوە');
      expect(shaqlawa, isNotNull);
      expect(shaqlawa!.id, 'epu_shaqlawa_college');

      final epu = KurdistanUniversitiesData.findUniversity('Erbil Technical Engineering');
      expect(epu, isNotNull);
      expect(epu!.id, 'epu_eng_college');
    });

    test('getDepartmentsFor should return real academic majors for institutes', () {
      final shaqlawaDepts = KurdistanUniversitiesData.getDepartmentsFor('کۆلێژی تەکنیکی شەقڵاوە (EPU)');
      expect(shaqlawaDepts.any((d) => d.contains('شیکاری نەخۆشییەکان')), isTrue);
      expect(shaqlawaDepts.any((d) => d.contains('پەرستاری')), isTrue);
      expect(shaqlawaDepts.any((d) => d.contains('تەکنەلۆجیای زانیاری')), isTrue);
      expect(shaqlawaDepts.any((d) => d.contains('کارگێڕی کار')), isTrue);

      final fallback = KurdistanUniversitiesData.getDepartmentsFor('Unknown College');
      expect(fallback.isNotEmpty, isTrue);
    });
  });
}
