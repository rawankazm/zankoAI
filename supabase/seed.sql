-- ==============================================================================
-- ZankoAI Production Seed Data - Universities, Faculties, Departments
-- ==============================================================================

-- 1. Universities Seed
INSERT INTO public.universities (id, name, name_ku, name_ar, code, city, country)
VALUES 
('a0000000-0000-0000-0000-000000000001', 'Salahaddin University - Erbil', 'زانکۆی سەلاحەدین - هەولێر', 'جامعة صلاح الدين - أربيل', 'SUE', 'Erbil', 'Iraq'),
('a0000000-0000-0000-0000-000000000002', 'University of Sulaimani', 'زانکۆی سلێمانی', 'جامعة السليمانية', 'UOS', 'Sulaymaniyah', 'Iraq'),
('a0000000-0000-0000-0000-000000000003', 'University of Duhok', 'زانکۆی دهۆک', 'جامعة دهوك', 'UOD', 'Duhok', 'Iraq'),
('a0000000-0000-0000-0000-000000000004', 'Erbil Polytechnic University', 'زانکۆی پۆلیتەکنیکی هەولێر', 'جامعة أربيل التقنية', 'EPU', 'Erbil', 'Iraq'),
('a0000000-0000-0000-0000-000000000005', 'Sulaimani Polytechnic University', 'زانکۆی پۆلیتەکنیکی سلێمانی', 'جامعة السليمانية التقنية', 'SPU', 'Sulaymaniyah', 'Iraq'),
('a0000000-0000-0000-0000-000000000006', 'University of Zakho', 'زانکۆی زاخۆ', 'جامعة زاخو', 'UOZ', 'Zakho', 'Iraq')
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    name_ku = EXCLUDED.name_ku,
    name_ar = EXCLUDED.name_ar,
    code = EXCLUDED.code;

-- 2. Faculties Seed (Colleges)
INSERT INTO public.faculties (id, university_id, name, name_ku, name_ar, code)
VALUES
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'College of Science', 'کۆلێژی زانست', 'كلية العلوم', 'SCI'),
('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'College of Engineering', 'کۆلێژی ئەندازیاری', 'كلية الهندسة', 'ENG'),
('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000004', 'Shaqlawa Technical College', 'کۆلێژی تەکنیکی شەقڵاوە', 'الكلية التقنية شقلاوة', 'STC')
ON CONFLICT (id) DO NOTHING;

-- 3. Departments Seed
INSERT INTO public.departments (id, faculty_id, name, name_ku, name_ar, code)
VALUES
('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Computer Science & IT', 'کۆمپیوتەر و تەکنەلۆژیای زانیاری', 'علوم الحاسوب', 'CS'),
('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Software Engineering', 'ئەندازیاری سۆفتوێر', 'هندسة البرمجيات', 'SE'),
('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'Information Technology', 'تەکنەلۆژیای زانیاری', 'تكنولوجيا المعلومات', 'IT')
ON CONFLICT (id) DO NOTHING;
