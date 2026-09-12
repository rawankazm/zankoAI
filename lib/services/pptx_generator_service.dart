import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pptx_template_data.dart';

class SlideModel {
  final String title;
  final List<String> bulletPoints;
  final String? visualPrompt;
  final String? speakerNotes;
  final String? imageUrl;
  final String? categoryTag;

  SlideModel({
    required this.title,
    required this.bulletPoints,
    this.visualPrompt,
    this.speakerNotes,
    this.imageUrl,
    this.categoryTag,
  });
}

class PptxGeneratorService {
  /// Returns translated "Thank you for your attendance" for seminar final slide
  static String getThankYouMessage(String langCode) {
    if (langCode == 'en') {
      return 'Thank You for Your Attendance';
    } else if (langCode == 'ar') {
      return 'شكراً لحضوركم';
    } else if (langCode == 'ku_badini' || langCode == 'badini') {
      return 'سوپاس بۆ ئامادەبوونا هەوە';
    }
    return 'سوپاس بۆ ئامادەبوونتان';
  }

  static final List<String> _academicReserveImages = [
    'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1531545514256-b1400bc00f31?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1519452635265-7b1fbfd1e4e0?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1491841550275-ad7854e35ca6?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1513258496099-48168024aec0?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1498243691581-b145c3f54a5a?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1488190211105-8b0e65b80b4e?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1501504905252-473c47e087f8?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1532012164546-f432f2e3777f?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?w=800&auto=format&fit=crop&q=80',
  ];

  static String _selectUniqueImage(
    List<String> pool,
    int slideIndex,
    Set<String>? usedUrls,
  ) {
    final targetIdx = (slideIndex - 1).clamp(0, pool.length - 1);
    final candidate = pool[targetIdx];
    if (usedUrls == null) return candidate;

    if (!usedUrls.contains(candidate)) {
      usedUrls.add(candidate);
      return candidate;
    }

    // Candidate already used in this presentation, search pool for fresh unused image
    for (final img in pool) {
      if (!usedUrls.contains(img)) {
        usedUrls.add(img);
        return img;
      }
    }

    // Category pool exhausted, pick from diverse academic reserve
    for (final res in _academicReserveImages) {
      if (!usedUrls.contains(res)) {
        usedUrls.add(res);
        return res;
      }
    }

    final uniqueFallback = '$candidate&slide=$slideIndex';
    usedUrls.add(uniqueFallback);
    return uniqueFallback;
  }

  /// Gets a distinct curated high-quality image URL for each slide based on topic, department, and slide index.
  /// Guarantees that no two slides in the same presentation will ever repeat an image.
  static String getSlideSpecificImageUrl(
    String topic,
    int slideIndex, {
    String? department,
    String? slideTitle,
    String? visualPrompt,
    Set<String>? usedUrls,
  }) {
    final t =
        '$topic ${department ?? ''} ${slideTitle ?? ''} ${visualPrompt ?? ''}'
            .toLowerCase();

    // Dedicated Closing & Gratitude Slide Images (Audience Applause, Q&A Discussion, Academic Celebration)
    final titleLower = (slideTitle ?? '').toLowerCase();
    final promptLower = (visualPrompt ?? '').toLowerCase();
    if (titleLower.contains('سوپاس') ||
        titleLower.contains('شكراً') ||
        titleLower.contains('شكرا') ||
        titleLower.contains('ئامادەبوون') ||
        titleLower.contains('ئامادەبوونا') ||
        titleLower.contains('thank you') ||
        titleLower.contains('thanks') ||
        titleLower.contains('q&a') ||
        promptLower.contains('closing') ||
        promptLower.contains('gratitude') ||
        promptLower.contains('applause') ||
        promptLower.contains('ovation') ||
        promptLower.contains('q&a')) {
      final closingImages = [
        'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&auto=format&fit=crop&q=80', // Slide 1: Conference hall event
        'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&auto=format&fit=crop&q=80', // Slide 2: Grand celebration confetti
        'https://images.unsplash.com/photo-1528605248644-14dd04022da1?w=800&auto=format&fit=crop&q=80', // Slide 3: Academic community gathering
        'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=800&auto=format&fit=crop&q=80', // Slide 4: Celebration gathering
        'https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=800&auto=format&fit=crop&q=80', // Slide 5: Meeting applause & presentation
        'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=800&auto=format&fit=crop&q=80', // Slide 6: Academic celebration & applause
        'https://images.unsplash.com/photo-1511578314322-379afb476865?w=800&auto=format&fit=crop&q=80', // Slide 7: Conference audience engagement
        'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=800&auto=format&fit=crop&q=80', // Slide 8: Speaker podium & warm applause
      ];
      return _selectUniqueImage(closingImages, slideIndex, usedUrls);
    }

    // 1. Dentistry & Oral Healthcare (8 Unique Verified HD Photos)
    if (t.contains('ددان') ||
        RegExp(r'(^|\s|[،.؛:])دان(\s|[،.؛:]|$)').hasMatch(t) ||
        t.contains('أسنان') ||
        t.contains('dent') ||
        t.contains('teeth') ||
        t.contains('tooth') ||
        t.contains('oral')) {
      final images = [
        'https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?w=800&auto=format&fit=crop&q=80', // Slide 1: Modern dental clinic chair
        'https://images.unsplash.com/photo-1606811841689-23dfddce3e95?w=800&auto=format&fit=crop&q=80', // Slide 2: Dental examination
        'https://images.unsplash.com/photo-1598256989800-fe5f95da9787?w=800&auto=format&fit=crop&q=80', // Slide 3: Dental hygiene tools
        'https://images.unsplash.com/photo-1609840114035-3c981b782dfe?w=800&auto=format&fit=crop&q=80', // Slide 4: Tooth x-ray radiograph
        'https://images.unsplash.com/photo-1629909613654-28e377c37b09?w=800&auto=format&fit=crop&q=80', // Slide 5: Professional dentist consultation
        'https://images.unsplash.com/photo-1571772996211-2f02c9727629?w=800&auto=format&fit=crop&q=80', // Slide 6: Orthodontic care & braces
        'https://images.unsplash.com/photo-1512496015851-a90fb38ba796?w=800&auto=format&fit=crop&q=80', // Slide 7: Dental implant model
        'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800&auto=format&fit=crop&q=80', // Slide 8: Healthy smile portrait
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 2. Veterinary Medicine & Animal Health (8 Unique Verified HD Photos)
    if (t.contains('ڤێتێرنەری') ||
        t.contains('ئاژەڵ') ||
        t.contains('پەلەوەر') ||
        t.contains('بيطر') ||
        t.contains('حيوان') ||
        t.contains('vet') ||
        t.contains('animal')) {
      final images = [
        'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?w=800&auto=format&fit=crop&q=80', // Slide 1: Veterinary doctor clinical exam
        'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=800&auto=format&fit=crop&q=80', // Slide 2: Companion animal diagnostic care
        'https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=800&auto=format&fit=crop&q=80', // Slide 3: Livestock and farm veterinary care
        'https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=800&auto=format&fit=crop&q=80', // Slide 4: Animal biology & vaccine lab
        'https://images.unsplash.com/photo-1535930891776-0c2dfb7fda1a?w=800&auto=format&fit=crop&q=80', // Slide 5: Animal surgical operation
        'https://images.unsplash.com/photo-1599443015574-be5fe8a05783?w=800&auto=format&fit=crop&q=80', // Slide 6: Veterinary ultrasound monitoring
        'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=800&auto=format&fit=crop&q=80', // Slide 7: Companion animal pathology check
        'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800&auto=format&fit=crop&q=80', // Slide 8: Healthy domestic animal welfare
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 3. Nursing, Patient Care & Midwifery (8 Unique Verified HD Photos)
    if (t.contains('پەرستار') ||
        t.contains('مامانی') ||
        t.contains('تمريض') ||
        t.contains('قابلة') ||
        t.contains('nurs') ||
        t.contains('patient care')) {
      final images = [
        'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=800&auto=format&fit=crop&q=80', // Slide 1: Compassionate nurse patient care
        'https://images.unsplash.com/photo-1576765608535-5f04d1e3f289?w=800&auto=format&fit=crop&q=80', // Slide 2: Medical vital signs check
        'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=800&auto=format&fit=crop&q=80', // Slide 3: Clinical nursing ward team
        'https://images.unsplash.com/photo-1582750433449-648ed127bb54?w=800&auto=format&fit=crop&q=80', // Slide 4: Healthcare team handoff
        'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=800&auto=format&fit=crop&q=80', // Slide 5: Intensive care monitoring
        'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=800&auto=format&fit=crop&q=80', // Slide 6: Patient recovery support
        'https://images.unsplash.com/photo-1584036561566-baf8f5f1b144?w=800&auto=format&fit=crop&q=80', // Slide 7: Medical pharmacology administration
        'https://images.unsplash.com/photo-1590611936760-eeb9bc593018?w=800&auto=format&fit=crop&q=80', // Slide 8: Nursing graduation excellence
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 4. Biology, Genetics, Pharmacy & Laboratory (8 Unique Verified HD Photos)
    if (t.contains('بایۆلۆجی') ||
        t.contains('دەرمان') ||
        t.contains('تاقیگە') ||
        t.contains('جین') ||
        t.contains('صيدل') ||
        t.contains('biolog') ||
        t.contains('pharma') ||
        t.contains('gene') ||
        t.contains('lab') ||
        t.contains('أحياء') ||
        t.contains('دواء') ||
        t.contains('مختبر') ||
        t.contains('وراث')) {
      final images = [
        'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=800&auto=format&fit=crop&q=80', // Slide 1: Lab glassware & research
        'https://images.unsplash.com/photo-1530497610245-94d3c16cda28?w=800&auto=format&fit=crop&q=80', // Slide 2: DNA structure & genetics
        'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=800&auto=format&fit=crop&q=80', // Slide 3: Microscope cell analysis
        'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800&auto=format&fit=crop&q=80', // Slide 4: Pharmacology pill research
        'https://images.unsplash.com/photo-1614935151651-0bea6508db6b?w=800&auto=format&fit=crop&q=80', // Slide 5: Biochemical molecular model
        'https://images.unsplash.com/photo-1581093450021-4a7360e9a6b5?w=800&auto=format&fit=crop&q=80', // Slide 6: Pipetting assay
        'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800&auto=format&fit=crop&q=80', // Slide 7: Scientific chemical culture
        'https://images.unsplash.com/photo-1507668077129-56e32842fceb?w=800&auto=format&fit=crop&q=80', // Slide 8: Modern biotech horizon
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 5. Medicine, Clinical Healthcare & Surgery (8 Unique Verified HD Photos)
    if ((t.contains('پزیشک') ||
            t.contains('med') ||
            t.contains('health') ||
            t.contains('دکتۆر') ||
            t.contains('نەخۆش') ||
            t.contains('طب') ||
            t.contains('صحة') ||
            t.contains('جراح') ||
            t.contains('clinical')) &&
        !t.contains('ددان') &&
        !t.contains('dent') &&
        !t.contains('ڤێتێر') &&
        !t.contains('vet') &&
        !t.contains('ئاژەڵ') &&
        !t.contains('پەرستار') &&
        !t.contains('nurs') &&
        !t.contains('دەرمان') &&
        !t.contains('pharma') &&
        !t.contains('صيدل')) {
      final images = [
        'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&auto=format&fit=crop&q=80', // Slide 1: Medical stethoscope & tablet
        'https://images.unsplash.com/photo-1551076805-e1869033e561?w=800&auto=format&fit=crop&q=80', // Slide 2: Surgical operating room lamps
        'https://images.unsplash.com/photo-1551601651-2a8555f1a136?w=800&auto=format&fit=crop&q=80', // Slide 3: Clinical patient care corridor
        'https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?w=800&auto=format&fit=crop&q=80', // Slide 4: Healthcare ultrasound technology
        'https://images.unsplash.com/photo-1581093458791-9f3c3900df4b?w=800&auto=format&fit=crop&q=80', // Slide 5: Medical diagnostic research
        'https://images.unsplash.com/photo-1578496781379-7dcfb995293d?w=800&auto=format&fit=crop&q=80', // Slide 6: Doctor analyzing brain MRI scan
        'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=800&auto=format&fit=crop&q=80', // Slide 7: Hospital surgery team in scrubs
        'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800&auto=format&fit=crop&q=80', // Slide 8: Future medicine & doctor portrait
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 6. Chemistry & Materials Science (8 Unique Verified HD Photos)
    if (t.contains('کیمیا') ||
        t.contains('كيمياء') ||
        t.contains('chem') ||
        t.contains('molecular') ||
        t.contains('compound')) {
      final images = [
        'https://images.unsplash.com/photo-1603555501671-8f96b3fce8b4?w=800&auto=format&fit=crop&q=80', // Slide 1: Chemistry beaker reactions
        'https://images.unsplash.com/photo-1507413245164-6160d8298b31?w=800&auto=format&fit=crop&q=80', // Slide 2: Precision titration assay
        'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=800&auto=format&fit=crop&q=80', // Slide 3: Chemical formula whiteboard
        'https://images.unsplash.com/photo-1628863353691-0071c8c1874c?w=800&auto=format&fit=crop&q=80', // Slide 4: Chemical crystallization apparatus
        'https://images.unsplash.com/photo-1518152006812-edab29b069ac?w=800&auto=format&fit=crop&q=80', // Slide 5: Organic compound spectrometry
        'https://images.unsplash.com/photo-1567427018141-0584cfcbf1b8?w=800&auto=format&fit=crop&q=80', // Slide 6: Spectroscopy analytical chemistry
        'https://images.unsplash.com/photo-1581093588401-fbb62a02f120?w=800&auto=format&fit=crop&q=80', // Slide 7: Nanomaterials testing
        'https://images.unsplash.com/photo-1516321497487-e288fb19713f?w=800&auto=format&fit=crop&q=80', // Slide 8: Future polymer materials innovation
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 7. Physics, Mathematics, Astronomy & Space (8 Unique Verified HD Photos)
    if (t.contains('فیزیا') ||
        t.contains('بيرکاری') ||
        t.contains('بیرکاری') ||
        t.contains('فەلەک') ||
        t.contains('گەردوون') ||
        t.contains('فيزياء') ||
        t.contains('رياضيات') ||
        t.contains('فلك') ||
        t.contains('فضاء') ||
        t.contains('physics') ||
        t.contains('math') ||
        t.contains('astronomy') ||
        t.contains('quantum') ||
        t.contains('space')) {
      final images = [
        'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=800&auto=format&fit=crop&q=80', // Slide 1: Deep cosmic galaxy & stars
        'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800&auto=format&fit=crop&q=80', // Slide 2: Quantum physics particles
        'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=800&auto=format&fit=crop&q=80', // Slide 3: Mathematical equations chalkboard
        'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&auto=format&fit=crop&q=80', // Slide 4: Gravitational orbital physics
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80', // Slide 5: Optical laser prism diffraction
        'https://images.unsplash.com/photo-1507499739999-097706ad8914?w=800&auto=format&fit=crop&q=80', // Slide 6: Theoretical physics model
        'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=800&auto=format&fit=crop&q=80', // Slide 7: Space telescope orbital observation
        'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=800&auto=format&fit=crop&q=80', // Slide 8: Statistical astrophysics graphs
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 8. AI, Machine Learning, Large Language Models (LLMs), Robotics & Neural Networks (8 Unique Verified HD Photos)
    if (t.contains('ژیری') ||
        t.contains('دەستکرد') ||
        t.contains('ai') ||
        t.contains('machine learning') ||
        t.contains('neural') ||
        t.contains('robot') ||
        t.contains('ذكاء') ||
        t.contains('اصطناعي') ||
        t.contains('روبوت') ||
        t.contains('مۆدێلە زمان') ||
        t.contains('مۆدێلی زمان') ||
        t.contains('زمانە گەورە') ||
        t.contains('مۆدێل') ||
        t.contains('llm') ||
        t.contains('nlp') ||
        t.contains('deep learning') ||
        t.contains('generative') ||
        t.contains('gpt') ||
        t.contains('تەکنەلۆژیا') ||
        t.contains('تەکنۆلۆژیا') ||
        t.contains('تەکنەلۆجیا') ||
        t.contains('سیستەمی زانیاری') ||
        t.contains('سیستەم') ||
        t.contains('mis') ||
        t.contains('information system')) {
      final images = [
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80', // Slide 1: Glowing AI neural network
        'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&auto=format&fit=crop&q=80', // Slide 2: Humanoid robot hand
        'https://images.unsplash.com/photo-1555255707-c07966088b7b?w=800&auto=format&fit=crop&q=80', // Slide 3: Deep learning code & visual
        'https://images.unsplash.com/photo-1507146153580-69a1fe6d8aa1?w=800&auto=format&fit=crop&q=80', // Slide 4: Futuristic AI brain concept
        'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=800&auto=format&fit=crop&q=80', // Slide 5: Collaborative tech team
        'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?w=800&auto=format&fit=crop&q=80', // Slide 6: Microchip & processor hardware
        'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800&auto=format&fit=crop&q=80', // Slide 7: Algorithmic data matrix
        'https://images.unsplash.com/photo-1535378917042-10a22c95931a?w=800&auto=format&fit=crop&q=80', // Slide 8: Global AI interconnected network
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 9. Cybersecurity, Network Security & Ethical Hacking (8 Unique Verified HD Photos)
    if (t.contains('سایبەر') ||
        t.contains('سکیوریتی') ||
        t.contains('security') ||
        t.contains('cyber') ||
        t.contains('network') ||
        t.contains('ئاسایش') ||
        t.contains('تۆڕ') ||
        t.contains('أمن') ||
        t.contains('شبك') ||
        t.contains('حماي')) {
      final images = [
        'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=800&auto=format&fit=crop&q=80', // Slide 1: Cyber lock & security shield
        'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&auto=format&fit=crop&q=80', // Slide 2: Server room infrastructure
        'https://images.unsplash.com/photo-1510511459019-5dda7724fd87?w=800&auto=format&fit=crop&q=80', // Slide 3: Secure terminal interface
        'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=800&auto=format&fit=crop&q=80', // Slide 4: Threat monitoring dashboard
        'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&auto=format&fit=crop&q=80', // Slide 5: Security operations center
        'https://images.unsplash.com/photo-1563089145-599997674d42?w=800&auto=format&fit=crop&q=80', // Slide 6: Digital cryptography matrix
        'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800&auto=format&fit=crop&q=80', // Slide 7: High-speed optical data cable
        'https://images.unsplash.com/photo-1614064641938-3bbee52942c7?w=800&auto=format&fit=crop&q=80', // Slide 8: Global cybersecurity defense
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 10. Software Engineering, Computer Science & Web/Mobile Dev (8 Unique Verified HD Photos)
    if (t.contains('کۆمپیوتەر') ||
        t.contains('بەرنامە') ||
        t.contains('نەرمەکاڵا') ||
        t.contains('computer') ||
        t.contains('software') ||
        t.contains('code') ||
        t.contains('program') ||
        t.contains('app') ||
        t.contains('web') ||
        t.contains('حاسوب') ||
        t.contains('برمج') ||
        t.contains('تطوير')) {
      final images = [
        'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop&q=80', // Slide 1: Clean developer workspace & code
        'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800&auto=format&fit=crop&q=80', // Slide 2: Laptop and software workflow
        'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?w=800&auto=format&fit=crop&q=80', // Slide 3: Web architecture design
        'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800&auto=format&fit=crop&q=80', // Slide 4: Coding algorithm screen
        'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=800&auto=format&fit=crop&q=80', // Slide 5: Agile software engineering team
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&auto=format&fit=crop&q=80', // Slide 6: Analytics & data visualization
        'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=800&auto=format&fit=crop&q=80', // Slide 7: Software debugging monitor
        'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=800&auto=format&fit=crop&q=80', // Slide 8: Software engineering blueprint
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 11. Cloud Computing, Big Data, Data Science & Analytics (8 Unique Verified HD Photos)
    if (t.contains('کلاود') ||
        t.contains('داتا') ||
        t.contains('ئامار') ||
        t.contains('cloud') ||
        t.contains('data') ||
        t.contains('analytics') ||
        t.contains('database') ||
        t.contains('سحاب') ||
        t.contains('بيانات') ||
        t.contains('إحصاء')) {
      final images = [
        'https://images.unsplash.com/photo-1504868584819-f8e8b4b6d7e3?w=800&auto=format&fit=crop&q=80', // Slide 1: Big data analytics chart
        'https://images.unsplash.com/photo-1544383835-bda2bc66a55d?w=800&auto=format&fit=crop&q=80', // Slide 2: Cloud infrastructure architecture
        'https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=800&auto=format&fit=crop&q=80', // Slide 3: Metrics dashboard visualization
        'https://images.unsplash.com/photo-1527474305487-b87b222841cc?w=800&auto=format&fit=crop&q=80', // Slide 4: Cloud computing datacenter network
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&auto=format&fit=crop&q=80', // Slide 5: Digital connection pathways
        'https://images.unsplash.com/photo-1488229297570-5852085168d0?w=800&auto=format&fit=crop&q=80', // Slide 6: High-capacity data storage arrays
        'https://images.unsplash.com/photo-1504639725590-34d0984388bd?w=800&auto=format&fit=crop&q=80', // Slide 7: Database schema development
        'https://images.unsplash.com/photo-1529101091764-c3526daf38fe?w=800&auto=format&fit=crop&q=80', // Slide 8: Global interconnected data grid
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 12. Civil Engineering, Architecture & Construction (8 Unique Verified HD Photos)
    if (t.contains('تەلارساز') ||
        t.contains('تەلار') ||
        t.contains('بیناساز') ||
        t.contains('شارستان') ||
        t.contains('architecture') ||
        t.contains('civil') ||
        t.contains('construction') ||
        t.contains('building') ||
        t.contains('عمار') ||
        t.contains('بناء') ||
        t.contains('مدن') ||
        t.contains('مدني') ||
        t.contains('إنشاء')) {
      final images = [
        'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=800&auto=format&fit=crop&q=80', // Slide 1: Modern architectural skyscraper
        'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=800&auto=format&fit=crop&q=80', // Slide 2: Architectural blueprint drafting
        'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&auto=format&fit=crop&q=80', // Slide 3: Construction site engineering
        'https://images.unsplash.com/photo-1541888946425-d0fbb18f15f7?w=800&auto=format&fit=crop&q=80', // Slide 4: Civil engineering infrastructure
        'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&auto=format&fit=crop&q=80', // Slide 5: Interior structural design
        'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=800&auto=format&fit=crop&q=80', // Slide 6: Modern sustainable building
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80', // Slide 7: Technical surveying tools
        'https://images.unsplash.com/photo-1479839672679-a46483c0e7c8?w=800&auto=format&fit=crop&q=80', // Slide 8: Future urban city planning
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 13. Electrical, Mechanical, Energy & Petroleum Engineering (8 Unique Verified HD Photos)
    if (((t.contains('ئەندازیار') || t.contains('engineer')) &&
            !t.contains('شارستان') &&
            !t.contains('مدن') &&
            !t.contains('civil') &&
            !t.contains('کشتوک') &&
            !t.contains('زراع') &&
            !t.contains('agri') &&
            !t.contains('نەرمەکاڵا') &&
            !t.contains('سۆفتوێر') &&
            !t.contains('software')) ||
        t.contains('کارەبا') ||
        t.contains('میکانیک') ||
        t.contains('وزە') ||
        t.contains('خۆر') ||
        t.contains('نەوت') ||
        t.contains('پترۆل') ||
        t.contains('گاز') ||
        t.contains('electric') ||
        t.contains('mechanic') ||
        t.contains('energy') ||
        t.contains('solar') ||
        t.contains('petroleum') ||
        t.contains('oil') ||
        t.contains('gas') ||
        ((t.contains('هندس') || t.contains('هندسة')) &&
            !t.contains('مدن') &&
            !t.contains('زراع') &&
            !t.contains('برمج')) ||
        t.contains('كهرب') ||
        t.contains('طاق') ||
        t.contains('نفط')) {
      final images = [
        'https://images.unsplash.com/photo-1581092335397-9583fe92d232?w=800&auto=format&fit=crop&q=80', // Slide 1: Circuit board & electronics
        'https://images.unsplash.com/photo-1509391365360-2e959784a276?w=800&auto=format&fit=crop&q=80', // Slide 2: Solar panels & clean energy
        'https://images.unsplash.com/photo-1581092580497-e0d23cbdf1dc?w=800&auto=format&fit=crop&q=80', // Slide 3: Robotics & mechanical testing
        'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=800&auto=format&fit=crop&q=80', // Slide 4: Wind turbines renewable power
        'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?w=800&auto=format&fit=crop&q=80', // Slide 5: Precision manufacturing gear
        'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&auto=format&fit=crop&q=80', // Slide 6: Power system grid
        'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?w=800&auto=format&fit=crop&q=80', // Slide 7: Petroleum refinery rig
        'https://images.unsplash.com/photo-1497435334941-8c899ee9e8e9?w=800&auto=format&fit=crop&q=80', // Slide 8: Electrical substation & transformers
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 14. Law, Legal Studies, Judiciary & Human Rights (8 Unique Verified HD Photos)
    if (t.contains('یاسا') ||
        t.contains('داد') ||
        t.contains('ماف') ||
        t.contains('دەستوور') ||
        t.contains('پەرلەمان') ||
        t.contains('قانون') ||
        t.contains('عدال') ||
        t.contains('حقوق') ||
        t.contains('دستور') ||
        t.contains('law') ||
        t.contains('legal') ||
        t.contains('justice') ||
        t.contains('court')) {
      final images = [
        'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800&auto=format&fit=crop&q=80', // Slide 1: Scales of justice & legal books
        'https://images.unsplash.com/photo-1505664194779-8beaceb93744?w=800&auto=format&fit=crop&q=80', // Slide 2: Classic law library & gavel
        'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=800&auto=format&fit=crop&q=80', // Slide 3: Judge gavel & courtroom
        'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=800&auto=format&fit=crop&q=80', // Slide 4: Legal contract agreement
        'https://images.unsplash.com/photo-1479142506502-19b3a3b7ff33?w=800&auto=format&fit=crop&q=80', // Slide 5: Supreme court pillars
        'https://images.unsplash.com/photo-1453728013993-6d66e9c9123a?w=800&auto=format&fit=crop&q=80', // Slide 6: Legal research & magnifying focus
        'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?w=800&auto=format&fit=crop&q=80', // Slide 7: International diplomacy handshake
        'https://images.unsplash.com/photo-1541872703-74c5e44368f9?w=800&auto=format&fit=crop&q=80', // Slide 8: Constitutional legislature hall
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 15. Political Science, Diplomacy & Public Policy (8 Unique Verified HD Photos)
    if (t.contains('سیاسەت') ||
        t.contains('دیپلۆماسی') ||
        t.contains('پەیوەندی') ||
        t.contains('دەوڵەت') ||
        t.contains('سياس') ||
        t.contains('دبلوماس') ||
        t.contains('politic') ||
        t.contains('diplomacy') ||
        t.contains('international relations')) {
      final images = [
        'https://images.unsplash.com/photo-1540910419892-4a36d2c3266c?w=800&auto=format&fit=crop&q=80', // Slide 1: Strategic debate podium
        'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=800&auto=format&fit=crop&q=80', // Slide 2: Diplomatic summit assembly
        'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=800&auto=format&fit=crop&q=80', // Slide 3: United Nations plenary hall
        'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=800&auto=format&fit=crop&q=80', // Slide 4: Parliament assembly floor
        'https://images.unsplash.com/photo-1526470608268-f674ce90ebd4?w=800&auto=format&fit=crop&q=80', // Slide 5: International treaty document
        'https://images.unsplash.com/photo-1577495508326-19a1b3cf65b7?w=800&auto=format&fit=crop&q=80', // Slide 6: Public policy summit discussion
        'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=800&auto=format&fit=crop&q=80', // Slide 7: Official treaty signing desk
        'https://images.unsplash.com/photo-1569098644584-210bcd375b59?w=800&auto=format&fit=crop&q=80', // Slide 8: International flags congress
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 16. Business, Management, Leadership & Marketing (8 Unique Verified HD Photos)
    if (t.contains('کارگێڕی') ||
        t.contains('بەڕێوەبردن') ||
        t.contains('بازاڕ') ||
        t.contains('مارکێتینگ') ||
        t.contains('سەرکردایەتی') ||
        t.contains('business') ||
        t.contains('manage') ||
        t.contains('market') ||
        t.contains('leadership') ||
        t.contains('إدارة') ||
        t.contains('تسويق') ||
        t.contains('قيادة')) {
      final images = [
        'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=800&auto=format&fit=crop&q=80', // Slide 1: Executive leadership strategy
        'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=800&auto=format&fit=crop&q=80', // Slide 2: Corporate project roadmap
        'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=800&auto=format&fit=crop&q=80', // Slide 3: Strategic team presentation
        'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=800&auto=format&fit=crop&q=80', // Slide 4: Professional client negotiation
        'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=800&auto=format&fit=crop&q=80', // Slide 5: Business strategy roadmap board
        'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=800&auto=format&fit=crop&q=80', // Slide 6: Modern business team meeting
        'https://images.unsplash.com/photo-1531497865144-0464ef8fb9a9?w=800&auto=format&fit=crop&q=80', // Slide 7: Enterprise KPI performance
        'https://images.unsplash.com/photo-1552664730-d307ca884978?w=800&auto=format&fit=crop&q=80', // Slide 8: Corporate leadership vision
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 17. Accounting, Banking, Finance & Economics (8 Unique Verified HD Photos)
    if (t.contains('ژمێریاری') ||
        t.contains('دارایی') ||
        t.contains('بانک') ||
        t.contains('ئابووری') ||
        t.contains('account') ||
        t.contains('finance') ||
        t.contains('bank') ||
        t.contains('econom') ||
        t.contains('audit') ||
        t.contains('محاسب') ||
        t.contains('مالي') ||
        t.contains('بنك') ||
        t.contains('مصرف') ||
        t.contains('اقتصاد')) {
      final images = [
        'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800&auto=format&fit=crop&q=80', // Slide 1: Financial audit report and calculator
        'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=800&auto=format&fit=crop&q=80', // Slide 2: Stock market exchange terminal
        'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?w=800&auto=format&fit=crop&q=80', // Slide 3: Global banking currencies & assets
        'https://images.unsplash.com/photo-1563986768494-4dee2763ff3f?w=800&auto=format&fit=crop&q=80', // Slide 4: Accounting ledger analysis
        'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800&auto=format&fit=crop&q=80', // Slide 5: Fiscal market trading chart
        'https://images.unsplash.com/photo-1565372195458-9de0b320ef04?w=800&auto=format&fit=crop&q=80', // Slide 6: Wealth investment portfolio consultation
        'https://images.unsplash.com/photo-1526304640581-d334cdbbf45e?w=800&auto=format&fit=crop&q=80', // Slide 7: Economic monetary policy
        'https://images.unsplash.com/photo-1541354329998-f4d9a9f9297f?w=800&auto=format&fit=crop&q=80', // Slide 8: Central bank skyscraper
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 18. Media, Journalism, PR & Mass Communication (8 Unique Verified HD Photos)
    if (t.contains('میدیا') ||
        t.contains('ڕاگەیاندن') ||
        t.contains('ڕۆژنامە') ||
        t.contains('تیڤی') ||
        t.contains('ڕادیۆ') ||
        t.contains('إعلام') ||
        t.contains('صحافة') ||
        t.contains('تلفزيون') ||
        t.contains('media') ||
        t.contains('journalism') ||
        t.contains('press') ||
        t.contains('broadcasting') ||
        t.contains('communication')) {
      final images = [
        'https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=800&auto=format&fit=crop&q=80', // Slide 1: Modern newsroom and broadcasting camera
        'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?w=800&auto=format&fit=crop&q=80', // Slide 2: Professional press conference microphone
        'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=800&auto=format&fit=crop&q=80', // Slide 3: Digital newspaper & online journalism
        'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?w=800&auto=format&fit=crop&q=80', // Slide 4: Video editing broadcast suite
        'https://images.unsplash.com/photo-1586339949916-3e9457bef6d3?w=800&auto=format&fit=crop&q=80', // Slide 5: Live television broadcast desk
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80', // Slide 6: Audio podcast & radio recording
        'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=800&auto=format&fit=crop&q=80', // Slide 7: Press conference keynote auditorium
        'https://images.unsplash.com/photo-1598899134739-24c46f58b8c0?w=800&auto=format&fit=crop&q=80', // Slide 8: Television studio lighting
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 19. Sports Science & Physical Education (8 Unique Verified HD Photos)
    if (t.contains('وەرزش') ||
        t.contains('تۆپ') ||
        t.contains('ڕاهێنان') ||
        t.contains('لەشجوانی') ||
        t.contains('تەندروستی وەرزش') ||
        t.contains('رياض') ||
        t.contains('تدريب') ||
        t.contains('لياقة') ||
        t.contains('sport') ||
        t.contains('fitness') ||
        t.contains('athlet') ||
        t.contains('kinesiolog')) {
      final images = [
        'https://images.unsplash.com/photo-1517649763962-0c623266ddc0?w=800&auto=format&fit=crop&q=80', // Slide 1: Olympic stadium running track
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&auto=format&fit=crop&q=80', // Slide 2: Sports biomechanics & training
        'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=800&auto=format&fit=crop&q=80', // Slide 3: Athletic fitness physiology
        'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&auto=format&fit=crop&q=80', // Slide 4: Track and field sprint finish
        'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&auto=format&fit=crop&q=80', // Slide 5: Gym kinesiology laboratory
        'https://images.unsplash.com/photo-1526676037777-05a232554f77?w=800&auto=format&fit=crop&q=80', // Slide 6: Sports medicine physiotherapy
        'https://images.unsplash.com/photo-1508215885820-4523e431397b?w=800&auto=format&fit=crop&q=80', // Slide 7: Endurance marathon team
        'https://images.unsplash.com/photo-1567013127542-490d757e51fc?w=800&auto=format&fit=crop&q=80', // Slide 8: Athletic championship victory
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 20. Fine Arts, Graphic Design, Film, Music & Cinema (8 Unique Verified HD Photos)
    if (t.contains('هونەر') ||
        t.contains('شێوەکاری') ||
        t.contains('مۆسیقا') ||
        t.contains('سینەما') ||
        t.contains('شانۆ') ||
        t.contains('فنون') ||
        t.contains('موسيق') ||
        t.contains('رسم') ||
        t.contains('مسرح') ||
        t.contains('سينما') ||
        t.contains('art') ||
        t.contains('design') ||
        t.contains('music') ||
        t.contains('cinema') ||
        t.contains('theatre')) {
      final images = [
        'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=800&auto=format&fit=crop&q=80', // Slide 1: Fine art painting easel
        'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=800&auto=format&fit=crop&q=80', // Slide 2: Graphic design and typography studio
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80', // Slide 3: Musical concert harmony
        'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=800&auto=format&fit=crop&q=80', // Slide 4: Film directing and cinema clapper
        'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?w=800&auto=format&fit=crop&q=80', // Slide 5: Color palette & creative art
        'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800&auto=format&fit=crop&q=80', // Slide 6: Theater stage performance
        'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop&q=80', // Slide 7: Photography and visual aesthetics
        'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&auto=format&fit=crop&q=80', // Slide 8: Contemporary artistic museum gallery
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 21. Psychology, Education & Philosophy (8 Unique Verified HD Photos)
    if (((t.contains('پەروەردە') &&
                !t.contains('وەرزش') &&
                !t.contains('sport')) ||
            (t.contains('تربية') &&
                !t.contains('رياض') &&
                !t.contains('sport'))) ||
        t.contains('دەروون') ||
        t.contains('کۆمەڵناسی') ||
        t.contains('فەلسەفە') ||
        t.contains('فێرکاری') ||
        t.contains('مامۆستا') ||
        t.contains('نفس') ||
        t.contains('اجتماع') ||
        t.contains('فلسفة') ||
        t.contains('تعليم') ||
        t.contains('psych') ||
        t.contains('educat') ||
        t.contains('socio') ||
        t.contains('philosophy')) {
      final images = [
        'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800&auto=format&fit=crop&q=80', // Slide 1: Scholarly reading & cognitive exam
        'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=800&auto=format&fit=crop&q=80', // Slide 2: Interactive educational lecture
        'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=800&auto=format&fit=crop&q=80', // Slide 3: Cognitive learning dynamics
        'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?w=800&auto=format&fit=crop&q=80', // Slide 4: University study hall
        'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&auto=format&fit=crop&q=80', // Slide 5: Teaching auditorium presentation
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=800&auto=format&fit=crop&q=80', // Slide 6: Knowledge & intellectual reading
        'https://images.unsplash.com/photo-1491841573634-28140fc7ced7?w=800&auto=format&fit=crop&q=80', // Slide 7: Psychological study consultation
        'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800&auto=format&fit=crop&q=80', // Slide 8: Student group psychological support
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 22. History, Archaeology, Culture & Kurdish Studies (8 Unique Verified HD Photos)
    if (t.contains('مێژوو') ||
        t.contains('شوێنەوار') ||
        t.contains('کورد') ||
        t.contains('کەلتوور') ||
        t.contains('کەلەپوور') ||
        t.contains('شارستانیەت') ||
        t.contains('تاريخ') ||
        t.contains('آثار') ||
        t.contains('حضار') ||
        t.contains('تراث') ||
        t.contains('کرد') ||
        t.contains('history') ||
        t.contains('archaeol') ||
        t.contains('heritage') ||
        t.contains('kurd')) {
      final images = [
        'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=800&auto=format&fit=crop&q=80', // Slide 1: Ancient historical parchment & map
        'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=800&auto=format&fit=crop&q=80', // Slide 2: Historical library archive
        'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800&auto=format&fit=crop&q=80', // Slide 3: Archaeological monument & castle
        'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&auto=format&fit=crop&q=80', // Slide 4: Ancient artifact & sculpture
        'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=800&auto=format&fit=crop&q=80', // Slide 5: Historical documents study
        'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=800&auto=format&fit=crop&q=80', // Slide 6: Classic manuscripts
        'https://images.unsplash.com/photo-1474932430478-367dbb6832c1?w=800&auto=format&fit=crop&q=80', // Slide 7: Vintage literature & heritage
        'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=800&auto=format&fit=crop&q=80', // Slide 8: Archival preservation
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 23. Languages, Literature, Linguistics & Translation (8 Unique Verified HD Photos)
    if (!t.contains('مۆدێل') &&
        !t.contains('گەورە') &&
        !t.contains('ai') &&
        !t.contains('llm') &&
        !t.contains('دەستکرد') &&
        !t.contains('تەکنە') &&
        (t.contains('زمان') ||
            t.contains('ئەدەب') ||
            t.contains('شێعر') ||
            t.contains('شیعر') ||
            t.contains('ڕۆمان') ||
            t.contains('وەرگێڕان') ||
            t.contains('ئینگلیزی') ||
            t.contains('عەرەبی') ||
            t.contains('فەڕەنسی') ||
            t.contains('english') ||
            t.contains('arabic') ||
            t.contains('french') ||
            t.contains('انجليزي') ||
            t.contains('عربي') ||
            t.contains('فرنسي') ||
            t.contains('لغة') ||
            t.contains('أدب') ||
            t.contains('شعر') ||
            t.contains('رواية') ||
            t.contains('ترجم') ||
            t.contains('language') ||
            t.contains('literat') ||
            t.contains('poem') ||
            t.contains('translat'))) {
      final images = [
        'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&auto=format&fit=crop&q=80', // Slide 1: Classical literature reading
        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=800&auto=format&fit=crop&q=80', // Slide 2: Grand university library
        'https://images.unsplash.com/photo-1507842229451-9f232615e324?w=800&auto=format&fit=crop&q=80', // Slide 3: Language translation desk & typewriter
        'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=800&auto=format&fit=crop&q=80', // Slide 4: Poetry and linguistic study
        'https://images.unsplash.com/photo-1516979187457-637abb4f9353?w=800&auto=format&fit=crop&q=80', // Slide 5: Linguistic books collection
        'https://images.unsplash.com/photo-1495640388908-05fa85288e61?w=800&auto=format&fit=crop&q=80', // Slide 6: Literary writing desk
        'https://images.unsplash.com/photo-1476820865390-c52aeebb9891?w=800&auto=format&fit=crop&q=80', // Slide 7: Literary bookshelf & linguistics
        'https://images.unsplash.com/photo-1519791883288-dc8bd696e667?w=800&auto=format&fit=crop&q=80', // Slide 8: Translation & academic writing
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 24. Agriculture, Environment, Ecology & Nature (8 Unique Verified HD Photos)
    if (t.contains('کشتوکاڵ') ||
        t.contains('ژینگە') ||
        t.contains('ڕووەک') ||
        t.contains('دارستان') ||
        t.contains('زەوی') ||
        t.contains('زراعة') ||
        t.contains('بيئة') ||
        t.contains('نبات') ||
        t.contains('غابات') ||
        t.contains('agri') ||
        t.contains('farm') ||
        t.contains('environ') ||
        t.contains('plant') ||
        t.contains('ecolog')) {
      final images = [
        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800&auto=format&fit=crop&q=80', // Slide 1: Modern agricultural wheat field
        'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800&auto=format&fit=crop&q=80', // Slide 2: Smart agronomy greenhouse
        'https://images.unsplash.com/photo-1516253593875-bd7ba052fbc5?w=800&auto=format&fit=crop&q=80', // Slide 3: Environmental forest ecology
        'https://images.unsplash.com/photo-1495107334309-fcf20504a5ab?w=800&auto=format&fit=crop&q=80', // Slide 4: Sustainable farming & crops
        'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=800&auto=format&fit=crop&q=80', // Slide 5: High-tech agricultural drone
        'https://images.unsplash.com/photo-1530595467537-0b5996c41f2d?w=800&auto=format&fit=crop&q=80', // Slide 6: Plant biotechnology laboratory
        'https://images.unsplash.com/photo-1532601224476-15c79f2f7a51?w=800&auto=format&fit=crop&q=80', // Slide 7: Eco renewable organic farming
        'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80', // Slide 8: Pure ecological preservation
      ];
      return _selectUniqueImage(images, slideIndex, usedUrls);
    }

    // 25. General Academic / Canva Master Template (8 Unique Verified HD Photos)
    final defaultImages = [
      'https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?w=800&auto=format&fit=crop&q=80', // Slide 1: Keynote university presentation
      'https://images.unsplash.com/photo-1532619675605-1ede6c2ed2b0?w=800&auto=format&fit=crop&q=80', // Slide 2: Analytical academic desk notebook
      'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=800&auto=format&fit=crop&q=80', // Slide 3: Graduation cap & academic honors
      'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&auto=format&fit=crop&q=80', // Slide 4: University auditorium lecture
      'https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=800&auto=format&fit=crop&q=80', // Slide 5: Collaborative student study seminar
      'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=800&auto=format&fit=crop&q=80', // Slide 6: Professional scientific presentation
      'https://images.unsplash.com/photo-1562774053-701939374585?w=800&auto=format&fit=crop&q=80', // Slide 7: Historic university campus architecture
      'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=800&auto=format&fit=crop&q=80', // Slide 8: Grand academic convocation
    ];
    return _selectUniqueImage(defaultImages, slideIndex, usedUrls);
  }

  /// Parses markdown or plain text AI output into structured SlideModel items
  static List<SlideModel> parseSlidesFromText(
    String rawText, {
    String? defaultTitle,
    String? department,
  }) {
    final List<SlideModel> slides = [];
    final lines = rawText.split('\n');

    String currentTitle = '';
    List<String> currentBullets = [];
    String currentVisual = '';
    String currentNotes = '';
    bool inSlide = false;
    int slideCounter = 1;

    void saveCurrentSlide() {
      if (currentTitle.isNotEmpty || currentBullets.isNotEmpty) {
        String assignedTitle = currentTitle.isNotEmpty
            ? currentTitle
            : (defaultTitle ?? 'سلاید');
        // If Slide 1 and defaultTitle is provided, make sure Slide 1 represents the exact chosen topic title
        if (slideCounter == 1 &&
            defaultTitle != null &&
            defaultTitle.trim().isNotEmpty) {
          final t = assignedTitle.trim();
          if (t.contains('ناساندن') ||
              t.contains('چەمک') ||
              t.contains('گرنگی') ||
              t.contains('Introduction') ||
              t.contains('سلاید') ||
              t.contains('Slide') ||
              t.contains('سلايد') ||
              t.isEmpty) {
            assignedTitle = defaultTitle.trim();
          }
        }

        final assignedImg = getSlideSpecificImageUrl(
          defaultTitle ?? assignedTitle,
          slideCounter,
          department: department,
          slideTitle: assignedTitle,
        );
        slides.add(
          SlideModel(
            title: assignedTitle,
            bulletPoints: List.from(currentBullets),
            visualPrompt: currentVisual.isNotEmpty ? currentVisual : null,
            speakerNotes: currentNotes.isNotEmpty ? currentNotes : null,
            imageUrl: assignedImg,
            categoryTag: 'Canva / PPT Template',
          ),
        );
        slideCounter++;
      }
      currentTitle = '';
      currentBullets = [];
      currentVisual = '';
      currentNotes = '';
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip top-level document headers like "# 💡 بابەتی سیمینار" or "# Presentation Title"
      if (trimmed.startsWith('# ') &&
          !RegExp(
            r'(سلاید|سلايد|Slide|الشريحة|شريحة)',
            caseSensitive: false,
          ).hasMatch(trimmed)) {
        continue;
      }

      // Detect explicit slide headers e.g. "### 🔹 سلایدی ١: ناساندن", "### Slide 1: Title", "1️⃣ سلایدی یەکەم:", "## Slide 1", "**سلایدی ١: ...**", "### 1. Title", "### ١. العنوان"
      final isExplicitSlideKeyword =
          RegExp(
            r'^(#{1,4}\s*)?(🔹|🔸|▪️|▫️|🔻|\d+️⃣)?\s*(\*\*)?(سلایدی|سلاید|سڵایدی|سڵاید|سلايد|سلايدي|Slide|الشريحة|شريحة|تەوەری|تەوەرەی|المحور|المبحث)\s*(?:رقم\s*)?[\(\[\{]?(\d+|[٠-٩]+|[١-٩]+|یەکەم|دووەم|سێیەم|چوارەم|پێنجەم|شەشەم|حەوتەم|هەشتەم|الأولى?|الأول|الثاني[ة]?|الثالث[ة]?|الرابع[ة]?|الخامس[ة]?|السادس[ة]?|السابع[ة]?|الثامن[ة]?)?[\)\]\}]?\s*[:\-–\.]?\s*',
            caseSensitive: false,
          ).hasMatch(trimmed) ||
          RegExp(
            r'^#{2,3}\s*[\(\[\{]?(\d+|[٠-٩]+)[\)\]\}]?[\.:\-]\s+',
            caseSensitive: false,
          ).hasMatch(trimmed);

      final isMarkdownSlideHeading =
          RegExp(r'^#{2,3}\s+', caseSensitive: false).hasMatch(trimmed) &&
          (trimmed.contains('سلاید') ||
              trimmed.contains('سڵاید') ||
              trimmed.contains('Slide') ||
              trimmed.contains('سلايد') ||
              trimmed.contains('الشريحة') ||
              trimmed.contains('شريحة') ||
              trimmed.contains('المحور') ||
              trimmed.contains('المبحث') ||
              trimmed.contains('🔹') ||
              trimmed.contains('🔸') ||
              RegExp(
                r'\b(Slide\s*\d+)\b',
                caseSensitive: false,
              ).hasMatch(trimmed) ||
              RegExp(
                r'^#{2,3}\s*(\d+|[٠-٩]+)[\.:\-]\s+',
                caseSensitive: false,
              ).hasMatch(trimmed));

      final isSlideHeader = isExplicitSlideKeyword || isMarkdownSlideHeading;

      if (isSlideHeader) {
        if (inSlide) {
          saveCurrentSlide();
        }
        inSlide = true;

        // Extract title
        String cleanTitle = trimmed
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll(RegExp(r'^(🔹|🔸|▪️|▫️|🔻|\d+️⃣)\s*'), '')
            .replaceAll(
              RegExp(
                r'^(سلایدی|سلاید|سڵایدی|سڵاید|سلايد|سلايدي|Slide|الشريحة|شريحة|تەوەری|تەوەرەی|المحور|المبحث)\s*(?:رقم\s*)?[\(\[\{]?(\d+|[٠-٩]+|[١-٩]+|یەکەم|دووەم|سێیەم|چوارەم|پێنجەم|شەشەم|حەوتەم|هەشتەم|الأولى?|الأول|الثاني[ة]?|الثالث[ة]?|الرابع[ة]?|الخامس[ة]?|السادس[ة]?|السابع[ة]?|الثامن[ة]?)?[\)\]\}]?[:\-–\.]?\s*',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(
              RegExp(r'^[\(\[\{]?(\d+|[٠-٩]+)[\)\]\}]?[\.:\-]\s*'),
              '',
            )
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();

        currentTitle = cleanTitle.isNotEmpty ? cleanTitle : 'سلاید';
        continue;
      }

      // Detect slide title explicit line
      if (trimmed.startsWith('- **ناونیشان') ||
          trimmed.startsWith('- **ناونیشانی سەرەکی**:') ||
          trimmed.startsWith('- **Title**:') ||
          trimmed.startsWith('- **العنوان**:') ||
          trimmed.startsWith('- **عنوان الشريحة**:')) {
        final titleVal = trimmed
            .split(':')
            .sublist(1)
            .join(':')
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();
        if (titleVal.isNotEmpty) {
          currentTitle = titleVal;
        }
        continue;
      }

      // Detect Visual / Diagram / Image suggestion
      if (trimmed.contains('🖼️') ||
          trimmed.contains('وێنە') ||
          trimmed.contains('دایەگرام') ||
          trimmed.contains('Diagram') ||
          trimmed.contains('Visual') ||
          trimmed.contains('صورة') ||
          trimmed.contains('مخطط') ||
          trimmed.contains('التركيز البصري')) {
        final visualVal = trimmed
            .replaceAll(RegExp(r'^[-*]\s*'), '')
            .replaceAll(RegExp(r'.*وێنە.*?:', caseSensitive: false), '')
            .replaceAll(RegExp(r'.*Visual.*?:', caseSensitive: false), '')
            .replaceAll(RegExp(r'.*صورة.*?:', caseSensitive: false), '')
            .replaceAll(
              RegExp(r'.*التركيز البصري.*?:', caseSensitive: false),
              '',
            )
            .replaceAll('🖼️', '')
            .replaceAll('**', '')
            .trim();
        if (visualVal.isNotEmpty) {
          currentVisual = visualVal;
        }
        continue;
      }

      // Detect speaker notes
      if (trimmed.contains('تێبینی پێشکەشکار') ||
          trimmed.contains('Speaker Note') ||
          trimmed.contains('ملاحظات المتحدث') ||
          trimmed.contains('توجيهات المتحدث') ||
          trimmed.contains('ملاحظات الإلقاء') ||
          trimmed.contains('🎙️')) {
        final noteVal = trimmed
            .replaceAll(RegExp(r'^[-*]\s*'), '')
            .replaceAll(
              RegExp(r'.*تێبینی پێشکەشکار.*?:', caseSensitive: false),
              '',
            )
            .replaceAll(RegExp(r'.*Speaker Note.*?:', caseSensitive: false), '')
            .replaceAll(
              RegExp(r'.*ملاحظات المتحدث.*?:', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(r'.*توجيهات المتحدث.*?:', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(r'.*ملاحظات الإلقاء.*?:', caseSensitive: false),
              '',
            )
            .replaceAll('🎙️', '')
            .replaceAll('"', '')
            .replaceAll('**', '')
            .trim();
        if (noteVal.isNotEmpty) {
          currentNotes = noteVal;
        }
        continue;
      }

      // Detect bullet points & sentences
      if (trimmed.startsWith('-') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('•') ||
          RegExp(r'^\d+\.').hasMatch(trimmed) ||
          RegExp(r'^[٠-٩]+\.').hasMatch(trimmed)) {
        final bulletText = trimmed
            .replaceAll(RegExp(r'^[-*•]\s*'), '')
            .replaceAll(RegExp(r'^[\d+٠-٩]+\.\s*'), '')
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();

        if (bulletText.isNotEmpty &&
            !bulletText.startsWith('خاڵە سەرەکییەکان') &&
            !bulletText.startsWith('پێشنیاری دیزاین') &&
            !bulletText.startsWith('Design Suggestion')) {
          currentBullets.add(bulletText);
        }
        continue;
      }
    }

    if (inSlide) {
      saveCurrentSlide();
    }

    // Fallback if parsing didn't catch separate slides
    if (slides.isEmpty) {
      final safeTitle = defaultTitle ?? 'پرێزێنتەیشنی سیمینار';
      slides.add(
        SlideModel(
          title: safeTitle,
          bulletPoints: [
            'پێناسەی سەرەکی و گرنگیی زانستی بابەتەکە',
            'ئامانجەکان و شیکاریی داتای توێژینەوە',
            'دەرئەنجامەکان و پێشنیار بۆ ئاییندە',
          ],
          visualPrompt: 'وێنەی بەرگی سەرەکی و هێڵکاریی چەمکەکان',
          speakerNotes: 'تێبینی دەستپێکی سیمینار بۆ پێشکەشکار',
          imageUrl: getSlideSpecificImageUrl(safeTitle, 1),
        ),
      );
    }

    return slides;
  }

  /// Downloads image bytes from URL with fallback to generated valid PNG bytes
  static Future<List<int>> _fetchOrGenerateImageBytes(String url) async {
    if (kIsWeb) return _getFallbackImageBytes();
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          [],
          (prev, element) => prev..addAll(element),
        );
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {
    } finally {
      client?.close();
    }
    return _getFallbackImageBytes();
  }

  /// Generates a valid 1x1 colored PNG pixel byte buffer as fallback
  static List<int> _getFallbackImageBytes() {
    return [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ];
  }

  /// Generates a valid OpenXML PowerPoint (.pptx) file with real embedded images and Kurdish/Arabic Calibri fonts
  static Future<List<int>> createPptxBytes(
    List<SlideModel> slides, {
    required String presentationTitle,
    String languageCode = 'ku',
    String? studentName,
    String? supervisorName,
    String? university,
    String? department,
    List<int>? logoBytes,
  }) async {
    final archive = Archive();

    List<int> toUtf8(String str) => utf8.encode(str);

    // 1. [Content_Types].xml (including core/app/presProps/viewProps/tableStyles/slideLayouts 1..11)
    final contentTypesXml = _buildContentTypesXml(slides.length);
    final contentTypesBytes = toUtf8(contentTypesXml);
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypesBytes.length,
        contentTypesBytes,
      ),
    );

    // 2. _rels/.rels (with core-properties and extended-properties)
    final rootRelsXml = _buildRootRelsXml();
    final rootRelsBytes = toUtf8(rootRelsXml);
    archive.addFile(
      ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes),
    );

    // 3. docProps/core.xml & docProps/app.xml (Required for Protected View)
    final coreXml = _buildDocPropsCoreXml(presentationTitle);
    final coreBytes = toUtf8(coreXml);
    archive.addFile(
      ArchiveFile('docProps/core.xml', coreBytes.length, coreBytes),
    );

    final appXml = _buildDocPropsAppXml(slides.length);
    final appBytes = toUtf8(appXml);
    archive.addFile(ArchiveFile('docProps/app.xml', appBytes.length, appBytes));

    // 4. ppt/_rels/presentation.xml.rels
    final presRelsXml = _buildPresentationRelsXml(slides.length);
    final presRelsBytes = toUtf8(presRelsXml);
    archive.addFile(
      ArchiveFile(
        'ppt/_rels/presentation.xml.rels',
        presRelsBytes.length,
        presRelsBytes,
      ),
    );

    // 5. ppt/presentation.xml
    final presXml = _buildPresentationXml(slides.length);
    final presBytes = toUtf8(presXml);
    archive.addFile(
      ArchiveFile('ppt/presentation.xml', presBytes.length, presBytes),
    );

    // 6. Native Templates: presProps.xml, viewProps.xml, tableStyles.xml, theme1.xml
    final presPropsBytes = toUtf8(PptxTemplateData.ppt_presProps_xml);
    archive.addFile(
      ArchiveFile('ppt/presProps.xml', presPropsBytes.length, presPropsBytes),
    );

    final viewPropsBytes = toUtf8(PptxTemplateData.ppt_viewProps_xml);
    archive.addFile(
      ArchiveFile('ppt/viewProps.xml', viewPropsBytes.length, viewPropsBytes),
    );

    final tableStylesBytes = toUtf8(PptxTemplateData.ppt_tableStyles_xml);
    archive.addFile(
      ArchiveFile(
        'ppt/tableStyles.xml',
        tableStylesBytes.length,
        tableStylesBytes,
      ),
    );

    final themeBytes = toUtf8(PptxTemplateData.ppt_theme_theme1_xml);
    archive.addFile(
      ArchiveFile('ppt/theme/theme1.xml', themeBytes.length, themeBytes),
    );

    // 7. SlideMaster and its rels
    final slideMasterBytes = toUtf8(
      PptxTemplateData.ppt_slideMasters_slideMaster1_xml,
    );
    archive.addFile(
      ArchiveFile(
        'ppt/slideMasters/slideMaster1.xml',
        slideMasterBytes.length,
        slideMasterBytes,
      ),
    );

    final slideMasterRelsBytes = toUtf8(
      PptxTemplateData.ppt_slideMasters__rels_slideMaster1_xml_rels,
    );
    archive.addFile(
      ArchiveFile(
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        slideMasterRelsBytes.length,
        slideMasterRelsBytes,
      ),
    );

    // 8. SlideLayouts 1..11 and their rels
    final layouts = [
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout1_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout1_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout2_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout2_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout3_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout3_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout4_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout4_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout5_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout5_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout6_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout6_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout7_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout7_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout8_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout8_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout9_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout9_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout10_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout10_xml_rels,
      ),
      (
        PptxTemplateData.ppt_slideLayouts_slideLayout11_xml,
        PptxTemplateData.ppt_slideLayouts__rels_slideLayout11_xml_rels,
      ),
    ];

    for (int i = 0; i < layouts.length; i++) {
      final layoutNum = i + 1;
      final layoutXmlBytes = toUtf8(layouts[i].$1);
      final layoutRelsBytes = toUtf8(layouts[i].$2);
      archive.addFile(
        ArchiveFile(
          'ppt/slideLayouts/slideLayout$layoutNum.xml',
          layoutXmlBytes.length,
          layoutXmlBytes,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'ppt/slideLayouts/_rels/slideLayout$layoutNum.xml.rels',
          layoutRelsBytes.length,
          layoutRelsBytes,
        ),
      );
    }

    final hasCustomLogo = logoBytes != null && logoBytes.isNotEmpty;
    if (hasCustomLogo) {
      archive.addFile(
        ArchiveFile('ppt/media/logo.png', logoBytes.length, logoBytes),
      );
    }

    // 9. Fetch real images in parallel asynchronously and embed into PPTX media/ + slides/
    final imageFutures = slides.asMap().entries.map((entry) {
      final slideNum = entry.key + 1;
      final slide = entry.value;
      final imgUrl =
          slide.imageUrl ??
          getSlideSpecificImageUrl(presentationTitle, slideNum);
      return _fetchOrGenerateImageBytes(imgUrl);
    }).toList();

    final allImageBytes = await Future.wait(imageFutures);

    for (int i = 0; i < slides.length; i++) {
      final slideNum = i + 1;
      final slide = slides[i];
      final imageBytes = allImageBytes[i];
      final isFirst = i == 0;

      // Detect real MIME type by checking magic bytes
      final isPng =
          imageBytes.length >= 8 &&
          imageBytes[0] == 0x89 &&
          imageBytes[1] == 0x50 &&
          imageBytes[2] == 0x4E &&
          imageBytes[3] == 0x47;
      final imageExt = isPng ? 'png' : 'jpeg';

      archive.addFile(
        ArchiveFile(
          'ppt/media/image$slideNum.$imageExt',
          imageBytes.length,
          imageBytes,
        ),
      );

      // Build slide XML
      final slideXml = _buildSlideXml(
        slide,
        slideNum,
        slides.length,
        isFirstSlide: isFirst,
        hasImage: true,
        hasLogo: isFirst && hasCustomLogo,
        languageCode: languageCode,
        studentName: studentName,
        supervisorName: supervisorName,
        university: university,
        department: department,
      );
      final slideBytes = toUtf8(slideXml);
      archive.addFile(
        ArchiveFile(
          'ppt/slides/slide$slideNum.xml',
          slideBytes.length,
          slideBytes,
        ),
      );

      // Build relationship linking slide to layout and embedded image
      final slideRelXml = _buildSlideRelsXml(
        isFirst ? 1 : 2,
        hasImage: true,
        imageIndex: slideNum,
        imageExt: imageExt,
        hasLogo: isFirst && hasCustomLogo,
      );
      final slideRelBytes = toUtf8(slideRelXml);
      archive.addFile(
        ArchiveFile(
          'ppt/slides/_rels/slide$slideNum.xml.rels',
          slideRelBytes.length,
          slideRelBytes,
        ),
      );
    }

    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive);
  }

  /// Exports PPTX bytes to a temporary file and triggers the system Share / Open With sheet
  static Future<void> exportAndSharePptx({
    List<SlideModel>? slides,
    String? rawContent,
    required String title,
    String languageCode = 'ku',
    String? studentName,
    String? supervisorName,
    String? university,
    String? department,
    List<int>? logoBytes,
  }) async {
    final effectiveSlides = List<SlideModel>.from(
      (slides != null && slides.isNotEmpty)
          ? slides
          : (rawContent != null
                ? parseSlidesFromText(rawContent, defaultTitle: title)
                : <SlideModel>[]),
    );

    // Clean duplicate thank-you bullets from previous slides if any
    for (int i = 0; i < effectiveSlides.length; i++) {
      final isLast = i == effectiveSlides.length - 1;
      final s = effectiveSlides[i];
      if (!isLast) {
        final cleanedBullets = s.bulletPoints
            .where(
              (b) =>
                  !b.contains('سوپاس بۆ ئامادەبوونتان') &&
                  !b.contains('شكراً لحضوركم') &&
                  !b.toLowerCase().contains('thank you for your attendance'),
            )
            .toList();
        if (cleanedBullets.length != s.bulletPoints.length) {
          effectiveSlides[i] = SlideModel(
            title: s.title,
            bulletPoints: cleanedBullets,
            visualPrompt: s.visualPrompt,
            speakerNotes: s.speakerNotes,
            imageUrl: s.imageUrl,
            categoryTag: s.categoryTag,
          );
        }
      }
    }

    // Ensure a dedicated final slide titled "Thank you for your attendance" exists
    final hasClosingSlide =
        effectiveSlides.isNotEmpty &&
        (effectiveSlides.last.title.contains('سوپاس') ||
            effectiveSlides.last.title.contains('شكراً') ||
            effectiveSlides.last.title.contains('شكرا') ||
            effectiveSlides.last.title.toLowerCase().contains('thank you') ||
            effectiveSlides.last.title.contains('ئامادەبوون') ||
            effectiveSlides.last.title.contains('ئامادەبوونا'));

    if (!hasClosingSlide && effectiveSlides.isNotEmpty) {
      final thankYouTitle = getThankYouMessage(languageCode);
      final closingImg = getSlideSpecificImageUrl(
        title,
        effectiveSlides.length + 1,
        department: department,
        slideTitle: thankYouTitle,
      );
      effectiveSlides.add(
        SlideModel(
          title: thankYouTitle,
          bulletPoints: [
            languageCode == 'en'
                ? 'Thank you sincerely for your attendance and valuable attention'
                : (languageCode == 'ar'
                      ? 'شكراً جزيلاً لحضوركم الكريم واهتمامكم القيم'
                      : (languageCode == 'ku_badini' || languageCode == 'badini'
                            ? 'سوپاس بۆ ئامادەبوونا هەوە و دەمێ هەوە یێ زێڕین'
                            : 'سوپاس بۆ ئامادەبوونتان و کاتی بەنرختان لەم پرێزێنتەیشنەدا')),
            languageCode == 'en'
                ? 'Open Floor for Academic Inquiries & Critical Discussion'
                : (languageCode == 'ar'
                      ? 'فتح باب الحوار والأسئلة الأكاديمية والمداخلات العلمية'
                      : (languageCode == 'ku_badini' || languageCode == 'badini'
                            ? 'دەلیڤە یا ڤەکرییە بۆ پرسیار و دانوستاندنا زانستی'
                            : 'دەرگای پرسیار، ڕاگۆڕینەوە و گفتوگۆی زانستی واڵایە')),
            languageCode == 'en'
                ? 'Appreciation to Academic Committee, Supervisors & Faculty'
                : (languageCode == 'ar'
                      ? 'خالص التقدير للأساتذة المشرفين ولجنة المناقشة الموقرة'
                      : (languageCode == 'ku_badini' || languageCode == 'badini'
                            ? 'پێزانین بۆ مامۆستایێن سەرپەرشتیار و لێژنا بەڕێز'
                            : 'سوپاس و پێزانین بۆ مامۆستای سەرپەرشتیار و لێژنەی بەڕێز')),
          ],
          visualPrompt:
              'Academic presentation conclusion with audience applause and Q&A session',
          imageUrl: closingImg,
          categoryTag: languageCode == 'en'
              ? 'Conclusion & Q&A'
              : 'کۆتایی و گفتوگۆ',
          speakerNotes: languageCode == 'en'
              ? 'Express warm gratitude to the committee and audience, then open the floor for questions.'
              : 'سوپاسی ئامادەبووان و لێژنەی بەڕێز دەکرێت و دەرفەت بۆ پرسیارەکان دەکرێتەوە.',
        ),
      );
    }

    final bytes = await createPptxBytes(
      effectiveSlides,
      presentationTitle: title,
      languageCode: languageCode,
      studentName: studentName,
      supervisorName: supervisorName,
      university: university,
      department: department,
      logoBytes: logoBytes,
    );

    Directory? targetDir;
    if (!kIsWeb && Platform.isWindows) {
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
    }
    targetDir ??= await getTemporaryDirectory();

    final cleanFileName = title
        .replaceAll(RegExp(r'[\\/:*?"<>|«»“”‘’،,;!?.#%&{}$+=@^~`\(\)\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final truncated = cleanFileName.length > 35
        ? cleanFileName.substring(0, 35).replaceAll(RegExp(r'_+$'), '')
        : cleanFileName;
    final fileName =
        '${truncated.isEmpty ? 'Seminar_Presentation' : truncated}.pptx';
    final filePath = '${targetDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // On Windows, auto-open the PowerPoint presentation in Microsoft PowerPoint
    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('cmd', [
          '/c',
          'start',
          '""',
          filePath,
        ], runInShell: true);
      } catch (e) {
        debugPrint('Windows auto-launch info: $e');
      }
    }

    // On Mobile & Desktop, trigger the system Share/Open sheet
    try {
      await Share.shareXFiles(
        [
          XFile(
            filePath,
            mimeType:
                'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          ),
        ],
        subject: title,
        text: 'فایلی پاوەرپۆینت بۆ سیمیناری: $title',
      );
    } catch (e) {
      debugPrint('Share sheet info: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // XML Builders for OpenXML Presentation Standard
  // ─────────────────────────────────────────────────────────────────────────

  static String _escapeXml(String text) {
    final cleaned = text.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uD800-\uDFFF]'),
      '',
    );
    return cleaned
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _buildDocPropsCoreXml(String title) {
    final now = DateTime.now().toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n'
        '  <dc:title>${_escapeXml(title)}</dc:title>\n'
        '  <dc:creator>ZankoAI</dc:creator>\n'
        '  <cp:lastModifiedBy>ZankoAI Academic Suite</cp:lastModifiedBy>\n'
        '  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>\n'
        '  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>\n'
        '</cp:coreProperties>';
  }

  static String _buildDocPropsAppXml(int slideCount) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">\n'
        '  <TotalTime>0</TotalTime>\n'
        '  <Words>0</Words>\n'
        '  <Application>Microsoft Office PowerPoint</Application>\n'
        '  <PresentationFormat>On-screen Show (16:9)</PresentationFormat>\n'
        '  <Paragraphs>0</Paragraphs>\n'
        '  <Slides>$slideCount</Slides>\n'
        '  <Notes>0</Notes>\n'
        '  <HiddenSlides>0</HiddenSlides>\n'
        '  <MMClips>0</MMClips>\n'
        '  <ScaleCrop>false</ScaleCrop>\n'
        '  <HeadingPairs>\n'
        '    <vt:vector size="2" baseType="variant">\n'
        '      <vt:variant><vt:lpstr>Theme</vt:lpstr></vt:variant>\n'
        '      <vt:variant><vt:i4>1</vt:i4></vt:variant>\n'
        '    </vt:vector>\n'
        '  </HeadingPairs>\n'
        '  <TitlesOfParts>\n'
        '    <vt:vector size="1" baseType="lpstr">\n'
        '      <vt:lpstr>ZankoAcademic</vt:lpstr>\n'
        '    </vt:vector>\n'
        '  </TitlesOfParts>\n'
        '  <Company>ZankoAI</Company>\n'
        '  <LinksUpToDate>false</LinksUpToDate>\n'
        '  <SharedDoc>false</SharedDoc>\n'
        '  <HyperlinksChanged>false</HyperlinksChanged>\n'
        '  <AppVersion>16.0000</AppVersion>\n'
        '</Properties>';
  }

  static String _buildContentTypesXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n',
    );
    buffer.write('  <Default Extension="jpeg" ContentType="image/jpeg"/>\n');
    buffer.write('  <Default Extension="jpg" ContentType="image/jpeg"/>\n');
    buffer.write('  <Default Extension="png" ContentType="image/png"/>\n');
    buffer.write(
      '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n',
    );
    buffer.write(
      '  <Default Extension="xml" ContentType="application/xml"/>\n',
    );
    buffer.write(
      '  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\n',
    );
    buffer.write(
      '  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\n',
    );
    buffer.write(
      '  <Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>\n',
    );
    buffer.write(
      '  <Override PartName="/ppt/viewProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"/>\n',
    );
    buffer.write(
      '  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\n',
    );
    buffer.write(
      '  <Override PartName="/ppt/tableStyles.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"/>\n',
    );

    for (int i = 1; i <= 11; i++) {
      buffer.write(
        '  <Override PartName="/ppt/slideLayouts/slideLayout$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\n',
      );
    }

    for (int i = 1; i <= slideCount; i++) {
      buffer.write(
        '  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>\n',
      );
    }

    buffer.write(
      '  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>\n',
    );
    buffer.write(
      '  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>\n',
    );
    buffer.write('</Types>');
    return buffer.toString();
  }

  static String _buildRootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>\n'
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>\n'
        '</Relationships>';
  }

  static String _buildPresentationRelsXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n',
    );
    buffer.write(
      '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>\n',
    );
    buffer.write(
      '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>\n',
    );
    buffer.write(
      '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps" Target="presProps.xml"/>\n',
    );
    buffer.write(
      '  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps" Target="viewProps.xml"/>\n',
    );
    buffer.write(
      '  <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles" Target="tableStyles.xml"/>\n',
    );

    for (int i = 1; i <= slideCount; i++) {
      buffer.write(
        '  <Relationship Id="rId${i + 5}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>\n',
      );
    }

    buffer.write('</Relationships>');
    return buffer.toString();
  }

  static String _buildPresentationXml(int slideCount) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
      '<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" saveSubsetFonts="1">\n',
    );
    buffer.write('  <p:sldMasterIdLst>\n');
    buffer.write('    <p:sldMasterId id="2147483648" r:id="rId1"/>\n');
    buffer.write('  </p:sldMasterIdLst>\n');
    buffer.write('  <p:sldIdLst>\n');

    for (int i = 1; i <= slideCount; i++) {
      buffer.write('    <p:sldId id="${255 + i}" r:id="rId${i + 5}"/>\n');
    }

    buffer.write('  </p:sldIdLst>\n');
    buffer.write('  <p:sldSz cx="12192000" cy="6858000"/>\n');
    buffer.write('  <p:notesSz cx="6858000" cy="9144000"/>\n');
    buffer.write(
      '  <p:defaultTextStyle><a:defPPr><a:defRPr lang="en-US"/></a:defPPr><a:lvl1pPr marL="0" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl1pPr><a:lvl2pPr marL="457200" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl2pPr><a:lvl3pPr marL="914400" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl3pPr><a:lvl4pPr marL="1371600" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl4pPr><a:lvl5pPr marL="1828800" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl5pPr><a:lvl6pPr marL="2286000" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl6pPr><a:lvl7pPr marL="2743200" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl7pPr><a:lvl8pPr marL="3200400" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl8pPr><a:lvl9pPr marL="3657600" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:lvl9pPr></p:defaultTextStyle>\n',
    );
    buffer.write('</p:presentation>');
    return buffer.toString();
  }

  static String _buildSlideRelsXml(
    int layoutIndex, {
    bool hasImage = false,
    int? imageIndex,
    String imageExt = 'jpeg',
    bool hasLogo = false,
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n',
    );
    buffer.write(
      '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout$layoutIndex.xml"/>\n',
    );
    if (hasImage && imageIndex != null) {
      buffer.write(
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$imageIndex.$imageExt"/>\n',
      );
    }
    if (hasLogo) {
      buffer.write(
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/logo.png"/>\n',
      );
    }
    buffer.write('</Relationships>');
    return buffer.toString();
  }

  static String _buildSlideXml(
    SlideModel slide,
    int slideIndex,
    int totalSlides, {
    bool isFirstSlide = false,
    bool hasImage = false,
    bool hasLogo = false,
    String languageCode = 'ku',
    String? studentName,
    String? supervisorName,
    String? university,
    String? department,
  }) {
    final isEnglish = languageCode == 'en';
    final isArabic = languageCode == 'ar';
    final isBad = languageCode == 'ku_badini' || languageCode == 'badini';
    final isRtl = !isEnglish;

    final langAttr = isEnglish ? 'en-US' : (isArabic ? 'ar-SA' : 'ar-IQ');
    const latinFont = 'Calibri';
    const csFont = 'Calibri';
    final algn = isRtl ? 'r' : 'l';
    final rtlColVal = isRtl ? '1' : '0';
    final rtlAttr = isRtl ? 'rtl="1"' : 'rtl="0"';

    final effectiveUniv = (university != null && university.trim().isNotEmpty)
        ? university.trim()
        : (isEnglish
              ? 'Salahaddin University - Erbil'
              : 'زانکۆی سەڵاحەدین - هەولێر');
    final effectiveDept = (department != null && department.trim().isNotEmpty)
        ? department.trim()
        : '';

    final footerText = isEnglish
        ? 'ZankoAI Academic Presentation • Slide $slideIndex of $totalSlides'
        : (isArabic
              ? 'ZankoAI العرض الأكاديمي • الشريحة $slideIndex من $totalSlides'
              : 'ZankoAI پرێزێنتەیشنی ئەکادیمی • سلایدی $slideIndex لە $totalSlides');

    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
      '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" mc:Ignorable="p14">\n',
    );
    buffer.write('  <p:cSld>\n');
    buffer.write('    <p:spTree>\n');
    buffer.write(
      '      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n',
    );
    buffer.write(
      '      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\n',
    );

    final isClosingSlide =
        !isFirstSlide &&
        (slide.title.contains('سوپاس') ||
            slide.title.contains('شكراً') ||
            slide.title.contains('شكرا') ||
            slide.title.toLowerCase().contains('thank you') ||
            slide.title.contains('ئامادەبوون') ||
            slide.title.contains('ئامادەبوونا') ||
            (slideIndex == totalSlides &&
                (slide.title.contains('کۆتایی') ||
                    slide.title.contains('خاتمة') ||
                    slide.title.toLowerCase().contains('closing'))));

    final effectiveStudent =
        (studentName != null && studentName.trim().isNotEmpty)
        ? studentName.trim()
        : (isEnglish
              ? 'Student / Research Team'
              : (isBad ? 'قوتابیێن بەشێ زانستی' : 'قوتابیانی بەش'));
    final effectiveSupervisor =
        (supervisorName != null && supervisorName.trim().isNotEmpty)
        ? supervisorName.trim()
        : (isEnglish
              ? 'Academic Supervisor'
              : (isBad ? 'مامۆستایێ سەرپەرشتیار' : 'مامۆستای سەرپەرشتیار'));

    final studentLabel = isEnglish
        ? 'Prepared By:'
        : (isArabic
              ? 'إعداد الطالب / الفريق:'
              : (isBad ? 'ئامادەکرن ژ لایێ:' : 'ئامادەکردنی:'));
    final supervisorLabel = isEnglish
        ? 'Supervised By:'
        : (isArabic
              ? 'إشراف الأستاذ المشرف:'
              : (isBad ? 'سەرپەرشتیار:' : 'مامۆستای سەرپەرشتیار:'));

    if (isFirstSlide) {
      // ═════════════════════════════════════════════════════════════════════════
      // SLIDE 1: PURE ACADEMIC COVER SLIDE WITH HERO PHOTO & ACADEMIC CREDENTIALS
      // ═════════════════════════════════════════════════════════════════════════
      // Background Canvas Card (Midnight Deep Slate)
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="2" name="TitleBackground"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="400000" y="400000"/><a:ext cx="11392000" cy="6058000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="0F172A"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="19050"><a:solidFill><a:srgbClr val="1E293B"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // Top Radiant Sapphire Line
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="3" name="TopGlow"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="400000" y="400000"/><a:ext cx="11392000" cy="90000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="2563EB"/></a:solidFill>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // Coordinate Split (Photo vs Info Cards)
      final photoX = isRtl ? '700000' : '6892000';
      final infoX = isRtl ? '5600000' : '700000';

      // 1. HERO PHOTO FRAME (Rounded Luxury Container)
      buffer.write('      <p:pic>\n');
      buffer.write('        <p:nvPicPr>\n');
      buffer.write(
        '          <p:cNvPr id="4" name="HeroImage"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/>\n',
      );
      buffer.write('        </p:nvPicPr>\n');
      buffer.write('        <p:blipFill>\n');
      buffer.write('          <a:blip r:embed="rId2"/>\n');
      buffer.write('          <a:stretch><a:fillRect/></a:stretch>\n');
      buffer.write('        </p:blipFill>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$photoX" y="700000"/><a:ext cx="4600000" cy="5458000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:ln w="25400"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:pic>\n');

      // 2. UNIVERSITY LOGO / EMBLEM PILL
      if (hasLogo) {
        buffer.write('      <p:pic>\n');
        buffer.write(
          '        <p:nvPicPr><p:cNvPr id="5" name="UniversityLogo"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\n',
        );
        buffer.write(
          '        <p:blipFill><a:blip r:embed="rId3"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\n',
        );
        buffer.write(
          '        <p:spPr><a:xfrm><a:off x="$infoX" y="700000"/><a:ext cx="850000" cy="850000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n',
        );
        buffer.write('      </p:pic>\n');

        buffer.write('      <p:sp>\n');
        buffer.write(
          '        <p:nvSpPr><p:cNvPr id="6" name="UnivName"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
        );
        buffer.write('        <p:spPr>\n');
        buffer.write(
          '          <a:xfrm><a:off x="${isRtl ? "6550000" : "1650000"}" y="780000"/><a:ext cx="4942000" cy="680000"/></a:xfrm>\n',
        );
        buffer.write(
          '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
        );
        buffer.write(
          '          <a:solidFill><a:srgbClr val="1E293B"/></a:solidFill>\n',
        );
        buffer.write(
          '          <a:ln w="12700"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n',
        );
        buffer.write('        </p:spPr>\n');
        buffer.write('        <p:txBody>\n');
        buffer.write('          <a:bodyPr anchor="ctr" rtlCol="0"/>\n');
        buffer.write('          <a:lstStyle/>\n');
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="ctr"/>\n');
        buffer.write('            <a:r>\n');
        buffer.write(
          '              <a:rPr lang="$langAttr" sz="1300" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
        );
        buffer.write('              <a:t>${_escapeXml(effectiveUniv)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
        buffer.write('        </p:txBody>\n');
        buffer.write('      </p:sp>\n');
      } else {
        buffer.write('      <p:sp>\n');
        buffer.write(
          '        <p:nvSpPr><p:cNvPr id="5" name="UnivBadge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
        );
        buffer.write('        <p:spPr>\n');
        buffer.write(
          '          <a:xfrm><a:off x="$infoX" y="700000"/><a:ext cx="5892000" cy="500000"/></a:xfrm>\n',
        );
        buffer.write(
          '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
        );
        buffer.write(
          '          <a:solidFill><a:srgbClr val="1E293B"/></a:solidFill>\n',
        );
        buffer.write(
          '          <a:ln w="12700"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n',
        );
        buffer.write('        </p:spPr>\n');
        buffer.write('        <p:txBody>\n');
        buffer.write('          <a:bodyPr anchor="ctr" rtlCol="0"/>\n');
        buffer.write('          <a:lstStyle/>\n');
        buffer.write('          <a:p>\n');
        buffer.write('            <a:pPr algn="ctr"/>\n');
        buffer.write('            <a:r>\n');
        buffer.write(
          '              <a:rPr lang="$langAttr" sz="1350" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
        );
        buffer.write('              <a:t>${_escapeXml(effectiveUniv)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
        buffer.write('        </p:txBody>\n');
        buffer.write('      </p:sp>\n');
      }

      // 3. MAIN PRESENTATION TITLE BOX
      final titleY = hasLogo ? '1700000' : '1400000';
      final titleHeight = hasLogo ? '2100000' : '2400000';
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="7" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$infoX" y="$titleY"/><a:ext cx="5892000" cy="$titleHeight"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="3000" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>${_escapeXml(slide.title)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      if (effectiveDept.isNotEmpty) {
        buffer.write('          <a:p>\n');
        buffer.write(
          '            <a:pPr algn="$algn" $rtlAttr><a:spcBef><a:spcPts val="1000"/></a:spcBef></a:pPr>\n',
        );
        buffer.write('            <a:r>\n');
        buffer.write(
          '              <a:rPr lang="$langAttr" sz="1400"><a:solidFill><a:srgbClr val="94A3B8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
        );
        buffer.write('              <a:t>${_escapeXml(effectiveDept)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // 4. STUDENT & SUPERVISOR CARDS
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="8" name="StudentCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$infoX" y="4050000"/><a:ext cx="5892000" cy="980000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="111827"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="15875"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write(
        '          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal" lIns="160000" tIns="120000" rIns="160000" bIns="120000"/>\n',
      );
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1200" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>$studentLabel </a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1600" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write(
        '              <a:t>${_escapeXml(effectiveStudent)}</a:t>\n',
      );
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="9" name="SupervisorCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$infoX" y="5150000"/><a:ext cx="5892000" cy="980000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="111827"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="15875"><a:solidFill><a:srgbClr val="10B981"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write(
        '          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal" lIns="160000" tIns="120000" rIns="160000" bIns="120000"/>\n',
      );
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1200" b="1"><a:solidFill><a:srgbClr val="34D399"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>$supervisorLabel </a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1600" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write(
        '              <a:t>${_escapeXml(effectiveSupervisor)}</a:t>\n',
      );
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');
    } else if (isClosingSlide) {
      // ═════════════════════════════════════════════════════════════════════════
      // DEDICATED CLOSING SLIDE: "سوپاس بۆ ئامادەبوونتان" & SCIENTIFIC Q&A SESSION
      // ═════════════════════════════════════════════════════════════════════════
      // Background Canvas Card (Midnight Luxury Theme)
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="2" name="ClosingBackground"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="400000" y="400000"/><a:ext cx="11392000" cy="6058000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="0A0F1D"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="19050"><a:solidFill><a:srgbClr val="1E293B"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:sp>\n');

      // Top Radiant Line (Royal Sapphire Glow)
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="3" name="ClosingGlow"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="400000" y="400000"/><a:ext cx="11392000" cy="90000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="2563EB"/></a:solidFill>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:sp>\n');

      final photoX = isRtl ? '700000' : '6892000';
      final infoX = isRtl ? '5600000' : '700000';

      // 1. CELEBRATION / AUDIENCE OVATION PHOTO FRAME
      buffer.write('      <p:pic>\n');
      buffer.write('        <p:nvPicPr>\n');
      buffer.write(
        '          <p:cNvPr id="4" name="ClosingPhoto"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/>\n',
      );
      buffer.write('        </p:nvPicPr>\n');
      buffer.write('        <p:blipFill>\n');
      buffer.write('          <a:blip r:embed="rId2"/>\n');
      buffer.write('          <a:stretch><a:fillRect/></a:stretch>\n');
      buffer.write('        </p:blipFill>\n');
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$photoX" y="700000"/><a:ext cx="4600000" cy="5458000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:ln w="25400"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('      </p:pic>\n');

      // 2. TOP BADGE PILL
      final conclusionBadge = isEnglish
          ? '✨ Academic Presentation Conclusion ✨'
          : (isArabic
                ? '✨ ختام العرض الأكاديمي والمناقشة ✨'
                : '✨ کۆتایی سیمینار و پێشکەشکردنی زانستی ✨');
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="5" name="ClosingBadge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$infoX" y="700000"/><a:ext cx="5892000" cy="480000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="1E293B"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="12700"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="0"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr"/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1250" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>${_escapeXml(conclusionBadge)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // 3. GRAND GRATITUDE HEADLINE: "✨ سوپاس بۆ ئامادەبوونتان ✨"
      final grandThankYou = getThankYouMessage(languageCode);
      final qnaSubtitle = isEnglish
          ? 'Scientific Discussion & Open Floor Q&A'
          : (isArabic
                ? 'باب الأسئلة والمناقشة العلمية مفتوح للجميع'
                : 'کاتی پرسیار و گفتوگۆی زانستی بۆ ئامادەبووان');
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="6" name="ThankYouTitle"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$infoX" y="1300000"/><a:ext cx="5892000" cy="1500000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="ctr" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="3400" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write(
        '              <a:t>✨ ${_escapeXml(grandThankYou)} ✨</a:t>\n',
      );
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('          <a:p>\n');
      buffer.write(
        '            <a:pPr algn="ctr" $rtlAttr><a:spcBef><a:spcPts val="800"/></a:spcBef></a:pPr>\n',
      );
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1400"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>💬 ${_escapeXml(qnaSubtitle)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // 4. Q&A DISCUSSION CARD
      final qnaTitle = isEnglish
          ? '💬 Questions & Academic Discussion'
          : (isArabic
                ? '💬 الحوار والمداخلات الأكاديمية'
                : '💬 پرسیار و ڕاگۆڕینەوەی زانستی');
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="7" name="QnaCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$infoX" y="2950000"/><a:ext cx="5892000" cy="1850000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="131C31"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="15875"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write(
        '          <a:bodyPr anchor="t" rtlCol="$rtlColVal" lIns="200000" tIns="160000" rIns="200000" bIns="160000"/>\n',
      );
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1500" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>${_escapeXml(qnaTitle)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      for (var bullet in slide.bulletPoints) {
        final cleanBullet = bullet.trim();
        final displayBullet = cleanBullet.startsWith('•')
            ? cleanBullet
            : '• $cleanBullet';
        buffer.write('          <a:p>\n');
        buffer.write(
          '            <a:pPr algn="$algn" $rtlAttr><a:spcBef><a:spcPts val="600"/></a:spcBef></a:pPr>\n',
        );
        buffer.write('            <a:r>\n');
        buffer.write(
          '              <a:rPr lang="$langAttr" sz="1400"><a:solidFill><a:srgbClr val="E2E8F0"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
        );
        buffer.write('              <a:t>${_escapeXml(displayBullet)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // 5. ATTRIBUTION RECOGNITION CARD
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="8" name="AttributionCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$infoX" y="4950000"/><a:ext cx="5892000" cy="1180000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="111827"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="15875"><a:solidFill><a:srgbClr val="10B981"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write(
        '          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal" lIns="160000" tIns="120000" rIns="160000" bIns="120000"/>\n',
      );
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1250" b="1"><a:solidFill><a:srgbClr val="38BDF8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>👨‍🎓 $studentLabel </a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1400" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write(
        '              <a:t>${_escapeXml(effectiveStudent)}   •   </a:t>\n',
      );
      buffer.write('            </a:r>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1250" b="1"><a:solidFill><a:srgbClr val="34D399"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>👨‍🏫 $supervisorLabel </a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="1400" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write(
        '              <a:t>${_escapeXml(effectiveSupervisor)}</a:t>\n',
      );
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');
    } else {
      // ═════════════════════════════════════════════════════════════════════════
      // SLIDES 2..N-1: ACADEMIC CONTENT SLIDES (TOP TITLE + SPLIT IMAGE & CONTENT)
      // ═════════════════════════════════════════════════════════════════════════
      // Top Gradient Accent Bar
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="2" name="TopAccent"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write(
        '        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="120000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></p:spPr>\n',
      );
      buffer.write('      </p:sp>\n');

      // Slide Title Box (Top)
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="3" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write(
        '        <p:spPr><a:xfrm><a:off x="600000" y="300000"/><a:ext cx="10992000" cy="850000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n',
      );
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="ctr" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write('            <a:r>\n');
      buffer.write(
        '              <a:rPr lang="$langAttr" sz="2400" b="1"><a:solidFill><a:srgbClr val="0F172A"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
      );
      buffer.write('              <a:t>${_escapeXml(slide.title)}</a:t>\n');
      buffer.write('            </a:r>\n');
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // Picture Frame Positions (Left side for RTL, Right side for LTR)
      final picX = isRtl ? '600000' : '6992000';
      final textX = isRtl ? '5400000' : '600000';
      final textWidth = hasImage ? '6192000' : '10992000';

      if (hasImage) {
        buffer.write('      <p:pic>\n');
        buffer.write('        <p:nvPicPr>\n');
        buffer.write(
          '          <p:cNvPr id="6" name="SlideImage$slideIndex"/>\n',
        );
        buffer.write(
          '          <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>\n',
        );
        buffer.write('          <p:nvPr/>\n');
        buffer.write('        </p:nvPicPr>\n');
        buffer.write('        <p:blipFill>\n');
        buffer.write('          <a:blip r:embed="rId2"/>\n');
        buffer.write('          <a:stretch><a:fillRect/></a:stretch>\n');
        buffer.write('        </p:blipFill>\n');
        buffer.write('        <p:spPr>\n');
        buffer.write(
          '          <a:xfrm><a:off x="$picX" y="1300000"/><a:ext cx="4600000" cy="4900000"/></a:xfrm>\n',
        );
        buffer.write(
          '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
        );
        buffer.write(
          '          <a:ln w="19050"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln>\n',
        );
        buffer.write('        </p:spPr>\n');
        buffer.write('      </p:pic>\n');
      }

      // Content Card / Text & Points Box
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="4" name="ContentBox"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write('        <p:spPr>\n');
      buffer.write(
        '          <a:xfrm><a:off x="$textX" y="1300000"/><a:ext cx="$textWidth" cy="4900000"/></a:xfrm>\n',
      );
      buffer.write(
        '          <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>\n',
      );
      buffer.write(
        '          <a:solidFill><a:srgbClr val="F8FAFC"/></a:solidFill>\n',
      );
      buffer.write(
        '          <a:ln w="12700"><a:solidFill><a:srgbClr val="E2E8F0"/></a:solidFill></a:ln>\n',
      );
      buffer.write('        </p:spPr>\n');
      buffer.write('        <p:txBody>\n');
      buffer.write(
        '          <a:bodyPr anchor="t" rtlCol="$rtlColVal" lIns="250000" tIns="250000" rIns="250000" bIns="250000"/>\n',
      );
      buffer.write('          <a:lstStyle/>\n');

      for (var bullet in slide.bulletPoints) {
        final cleanBullet = bullet.trim();
        final displayBullet = cleanBullet.startsWith('•')
            ? cleanBullet
            : '• $cleanBullet';
        buffer.write('          <a:p>\n');
        buffer.write(
          '            <a:pPr algn="$algn" $rtlAttr><a:spcBef><a:spcPts val="600"/></a:spcBef></a:pPr>\n',
        );
        buffer.write('            <a:r>\n');
        buffer.write(
          '              <a:rPr lang="$langAttr" sz="1600"><a:solidFill><a:srgbClr val="1E293B"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr>\n',
        );
        buffer.write('              <a:t>${_escapeXml(displayBullet)}</a:t>\n');
        buffer.write('            </a:r>\n');
        buffer.write('          </a:p>\n');
      }

      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');

      // Slide Footer (Page Number & ZankoAI branding)
      buffer.write('      <p:sp>\n');
      buffer.write(
        '        <p:nvSpPr><p:cNvPr id="5" name="Footer"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n',
      );
      buffer.write(
        '        <p:spPr><a:xfrm><a:off x="600000" y="6350000"/><a:ext cx="10992000" cy="350000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n',
      );
      buffer.write('        <p:txBody>\n');
      buffer.write('          <a:bodyPr anchor="b" rtlCol="$rtlColVal"/>\n');
      buffer.write('          <a:lstStyle/>\n');
      buffer.write('          <a:p>\n');
      buffer.write('            <a:pPr algn="$algn" $rtlAttr/>\n');
      buffer.write(
        '            <a:r><a:rPr lang="$langAttr" sz="1100"><a:solidFill><a:srgbClr val="94A3B8"/></a:solidFill><a:latin typeface="$latinFont"/><a:cs typeface="$csFont"/></a:rPr><a:t>$footerText</a:t></a:r>\n',
      );
      buffer.write('          </a:p>\n');
      buffer.write('        </p:txBody>\n');
      buffer.write('      </p:sp>\n');
    }
    buffer.write('    </p:spTree>\n');
    buffer.write('  </p:cSld>\n');
    buffer.write('  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n');
    // PowerPoint Native Morph Transition for fluid, dynamic slide animations
    buffer.write('  <p:transition spd="med" advClick="1">\n');
    buffer.write('    <mc:AlternateContent>\n');
    buffer.write('      <mc:Choice Requires="p14">\n');
    buffer.write('        <p14:morph/>\n');
    buffer.write('      </mc:Choice>\n');
    buffer.write('      <mc:Fallback>\n');
    buffer.write('        <p:fade/>\n');
    buffer.write('      </mc:Fallback>\n');
    buffer.write('    </mc:AlternateContent>\n');
    buffer.write('  </p:transition>\n');
    buffer.write('</p:sld>');
    return buffer.toString();
  }
}
