import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { kurdish, kurdishBadini, arabic, english }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.kurdish;

  LanguageProvider() {
    _loadLanguageFromPrefs();
  }

  AppLanguage get currentLanguage => _currentLanguage;
  
  String get languageCode {
    switch (_currentLanguage) {
      case AppLanguage.kurdish:
        return 'ku';
      case AppLanguage.kurdishBadini:
        return 'badini';
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.english:
        return 'en';
    }
  }

  TextDirection get textDirection {
    return _currentLanguage == AppLanguage.english
        ? TextDirection.ltr
        : TextDirection.rtl;
  }

  bool get isRtl => _currentLanguage != AppLanguage.english;

  /// Returns the appropriate font family for the current language.
  /// Kurdish (Sorani & Badini) and Arabic use DroidKufi (فۆنتی کوفی), English uses default Plus Jakarta Sans.
  String? get fontFamily {
    switch (_currentLanguage) {
      case AppLanguage.kurdish:
      case AppLanguage.kurdishBadini:
      case AppLanguage.arabic:
        return 'DroidKufi';
      case AppLanguage.english:
        return null;
    }
  }

  Future<void> _loadLanguageFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = prefs.getString('app_language');
    if (langStr != null) {
      if (langStr == 'ku') _currentLanguage = AppLanguage.kurdish;
      if (langStr == 'badini') _currentLanguage = AppLanguage.kurdishBadini;
      if (langStr == 'ar') _currentLanguage = AppLanguage.arabic;
      if (langStr == 'en') _currentLanguage = AppLanguage.english;
      notifyListeners();
    } else {
      _currentLanguage = AppLanguage.kurdish;
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
  }

  String translate(String key) {
    final translations = _localizedValues[key];
    if (translations == null) return key;
    
    switch (_currentLanguage) {
      case AppLanguage.kurdish:
        return translations['ku'] ?? key;
      case AppLanguage.kurdishBadini:
        return translations['badini'] ?? translations['ku'] ?? key;
      case AppLanguage.arabic:
        return translations['ar'] ?? key;
      case AppLanguage.english:
        return translations['en'] ?? key;
    }
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    // Auth & Navigation
    'login': {'ku': 'چوونەژوورەوە', 'badini': 'چوونا ژوورێ', 'ar': 'تسجيل الدخول', 'en': 'Log In'},
    'register': {'ku': 'دروستکردنی هەژمار', 'badini': 'چێکرنا هەژمارێ', 'ar': 'إنشاء حساب', 'en': 'Register'},
    'email': {'ku': 'ئیمەیڵ', 'badini': 'ئیمەیڵ', 'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'password': {'ku': 'وشەی نهێنی', 'badini': 'پەیڤا نهێنی', 'ar': 'كلمة المرور', 'en': 'Password'},
    'google_login': {'ku': 'چوونەژوورەوە بە گووگڵ', 'badini': 'چوونا ژوورێ ب گووگڵ', 'ar': 'الدخول بواسطة Google', 'en': 'Google Sign-In'},
    'slogan': {'ku': 'یارمەتیدەری زیرەکی خوێندکاران', 'badini': 'هاریکارێ زیرەک بۆ قوتابیان', 'ar': 'المساعد الذكي للطلاب', 'en': 'Smart Student Assistant'},
    'has_account': {'ku': 'هەژمارت هەیە؟ چوونەژوورەوە', 'badini': 'هەژمارا تە هەیە؟ چوونا ژوورێ', 'ar': 'لديك حساب؟ تسجيل الدخول', 'en': 'Have an account? Log In'},
    'no_account': {'ku': 'هەژمارت نییە؟ دروستکردنی هەژمار', 'badini': 'هەژمارا تە نینە؟ چێکرنا هەژمارێ', 'ar': 'ليس لديك حساب؟ إنشاء حساب', 'en': 'No account? Register'},
    'guest_login': {'ku': 'بەردەوامبوون وەک مێوان', 'badini': 'بەردەوامبوون وەک مێڤان', 'ar': 'المتابعة كزائر', 'en': 'Continue as Guest'},
    'guest': {'ku': 'مێوان', 'badini': 'مێڤان', 'ar': 'زائر', 'en': 'Guest'},
    'guest_account': {'ku': 'هەژماری مێوان', 'badini': 'هەژمارا مێڤان', 'ar': 'حساب زائر', 'en': 'Guest Account'},
    'edit_profile': {'ku': 'دەستکاریکردنی پڕۆفایل', 'badini': 'دەستکاریکرنا پرۆفایلی', 'ar': 'تعديل الملف الشخصي', 'en': 'Edit Profile'},
    'skip_guest': {'ku': 'تێپەڕاندن (مێوان)', 'badini': 'دەربازکرن (مێڤان)', 'ar': 'تخطي (زائر)', 'en': 'Skip (Guest)'},
    'full_name': {'ku': 'ناوی تەواو', 'badini': 'ناڤێ تەمام', 'ar': 'الاسم الكامل', 'en': 'Full Name'},
    'full_name_hint': {'ku': 'نموونە: ئاراس ئەحمەد', 'badini': 'نموونە: ئاراس ئەحمەد', 'ar': 'مثال: أراس أحمد', 'en': 'e.g. Aras Ahmed'},
    'confirm_password': {'ku': 'دووبارەکردنەوەی وشەی نهێنی', 'badini': 'دووبارەکرنا پەیڤا نهێنی', 'ar': 'تأكيد كلمة المرور', 'en': 'Confirm Password'},
    'terms_agree': {'ku': 'ڕەزامەندم لەسەر مەرجەکانی بەکارهێنان', 'badini': 'ئەز ڕازی مە ل سەر مەرجێن بەکارهێنانێ', 'ar': 'أوافق على الشروط والأحكام', 'en': 'I agree to the Terms & Conditions'},
    'select_profile_image': {'ku': 'وێنەی پرۆفایل دیاریبکە', 'badini': 'وێنەیێ پرۆفایلی هەلبژێرە', 'ar': 'اختر صورة الملف الشخصي', 'en': 'Select Profile Image'},
    'select_university': {'ku': 'زانکۆ یان کۆلێژ', 'badini': 'زانکۆ یان کۆلێژ', 'ar': 'الجامعة أو الكلية', 'en': 'University or College'},
    'select_department': {'ku': 'بەش یان پسپۆڕی', 'badini': 'پشک یان پسپۆڕی', 'ar': 'القسم أو التخصص', 'en': 'Department or Major'},
    'select_city': {'ku': 'شار / شوێن', 'badini': 'باژێر / شوێن', 'ar': 'المدينة / الموقع', 'en': 'City / Location'},
    'city_erbil': {'ku': 'هەولێر', 'badini': 'هەولێر', 'ar': 'أربيل', 'en': 'Erbil'},
    'city_slemani': {'ku': 'سلێمانی', 'badini': 'سلێمانی', 'ar': 'السليمانية', 'en': 'Slemani'},
    'city_duhok': {'ku': 'دهۆک', 'badini': 'دهۆک', 'ar': 'دهوك', 'en': 'Duhok'},
    'city_karkuk': {'ku': 'کەرکووک', 'badini': 'کەرکووک', 'ar': 'كركوك', 'en': 'Karkuk'},
    'city_halabja': {'ku': 'هەڵەبجە', 'badini': 'هەڵەبجە', 'ar': 'حلبجة', 'en': 'Halabja'},
    'logout': {'ku': 'چوونەدەرەوە', 'badini': 'دەرکەوتن', 'ar': 'تسجيل الخروج', 'en': 'Log Out'},
    'logout_desc': {'ku': 'چوونەدەرەوە لە هەژمار', 'badini': 'دەرکەوتن ژ هەژمارێ', 'ar': 'تسجيل الخروج من الحساب', 'en': 'Log out of account'},
    'upload_pdf_title': {
      'ku': 'بارکردنی فایلی PDF',
      'badini': 'بارکرنا فایلا PDF',
      'ar': 'رفع ملف PDF',
      'en': 'Upload PDF File'
    },
    'pdf_title': {
      'ku': 'شیکەرەوەی فایلی PDF',
      'badini': 'شیکارکەرێ فایلا PDF',
      'ar': 'محلل ملفات PDF',
      'en': 'PDF Document Analyzer'
    },
    'upload_area_title': {
      'ku': 'فایلی PDF یان دەق باربکە',
      'badini': 'فایلا PDF یان دەق باربکە',
      'ar': 'ارفع ملف PDF أو نص',
      'en': 'Upload PDF or Text File'
    },
    'upload_area_desc': {
      'ku': 'فایلەکەت ڕابکێشە یان کلیک بکە بۆ هەڵبژاردن',
      'badini': 'فایلێ ڕابکێشە یان کلیک بکە بۆ هەلبژارتنێ',
      'ar': 'اسحب الملف أو انقر للاختيار',
      'en': 'Drag or click to browse file'
    },
    'pick_file': {
      'ku': 'هەڵبژاردنی فایل',
      'badini': 'هەلبژارتنا فایلێ',
      'ar': 'اختيار ملف',
      'en': 'Pick File'
    },
    'analysis_result': {
      'ku': 'ئەنجامی شیکاریی AI',
      'badini': 'ئەنجامێن شیکاریا AI',
      'ar': 'نتائج تحليل AI',
      'en': 'AI Analysis Results'
    },
    'pdf_summary_card': {
      'ku': 'پۆختەی سەرەکی فایلی PDF',
      'badini': 'پوختەیا سەرەکی یا PDF',
      'ar': 'الملخص الرئيسي للملف',
      'en': 'Main Document Summary'
    },
    'key_points_card': {
      'ku': 'خاڵە سەرەکییەکانی فایلی PDF',
      'badini': 'خالێن سەرەکی یێن PDF',
      'ar': 'النقاط الرئيسية للملف',
      'en': 'Key Points & Takeaways'
    },
    'translation_card': {
      'ku': 'وەرگێڕان و مانا بە ئینگلیزی',
      'badini': 'وەرگێڕان و مانا ب ئینگلیزی',
      'ar': 'الترجمة والمعنى بالإنجليزية',
      'en': 'English Translation & Summary'
    },
    'upload_pdf_subtitle': {
      'ku': 'داگرە بۆ هەڵبژاردنی فایلی PDFی فێرکاری لە مۆبایلەکەتەوە',
      'badini': 'کلیت بکە بۆ هەلبژارتنا فایلا PDF یا فێرکاری ژ مۆبایلا خۆ',
      'ar': 'اضغط لاختيار ملف PDF التعليمي من جهازك',
      'en': 'Tap to pick an educational PDF file from your device'
    },
    'active_document': {
      'ku': 'فایلی دیاریکراو (PDF)',
      'badini': 'فایلا دیاریکری (PDF)',
      'ar': 'الملف المحدد (PDF)',
      'en': 'Active Document (PDF)'
    },
    'ai_pdf_actions': {
      'ku': 'مۆدەکانی ژیری دەستکرد بۆ PDF',
      'badini': 'مۆدێن ژیرییا دەستکرد بۆ PDF',
      'ar': 'أدوات الذكاء الاصطناعي لـ PDF',
      'en': 'AI Tools for PDF'
    },
    'quiz': {
      'ku': 'تاقیکردنەوە و پرسیار',
      'badini': 'تاقیکرن و پرسیار',
      'ar': 'اختبار وأسئلة',
      'en': 'Generate Quiz & Questions'
    },

    'guest_banner_title': {'ku': 'تۆ وەک مێوان لە بەرنامەکەیدایت', 'badini': 'تۆ وەک مێڤان ل بەرنامەیی', 'ar': 'أنت تستخدم التطبيق كزائر', 'en': 'You are using the app as a Guest'},
    'guest_banner_sub': {'ku': 'چوونەژوورەوە یان هەژمار دروستبکە بۆ پاشەکەوتکردنی پێشکەوتنەکانت', 'badini': 'چوونا ژوورێ بکە یان هەژمارەکێ چێبکە بۆ پاشەکەوتکرنا پێشکەوتنا خۆ', 'ar': 'سجّل الدخول أو أنشئ حساباً لحفظ تقدمك', 'en': 'Log in or create an account to save your study progress'},
    'login_or_register': {'ku': 'چوونەژوورەوە / دروستکردنی هەژمار', 'badini': 'چوونا ژوورێ / چێکرنا هەژمارێ', 'ar': 'تسجيل الدخول / إنشاء حساب', 'en': 'Log In / Create Account'},
    'login_register_desc': {'ku': 'بچۆرە ژوورەوە یان هەژماری نوێ دروستبکە', 'badini': 'بچە ژوورێ یان هەژمارەکا نوو چێبکە', 'ar': 'قم بتسجيل الدخول أو إنشاء حساب جديد', 'en': 'Log in or register a new account'},
    'version': {'ku': 'وەشانی v1.0.0', 'badini': 'وەشانا v1.0.0', 'ar': 'الإصدار v1.0.0', 'en': 'Version v1.0.0'},
    'daily_reminders': {'ku': 'ئاگاداری ڕۆژانە', 'badini': 'بیرئینانێن ڕۆژانە', 'ar': 'التذكيرات اليومية', 'en': 'Daily Reminders'},
    'zankoline': {'ku': 'زانکۆلاین', 'badini': 'زانکۆلاین', 'ar': 'زانكولاين', 'en': 'ZankoLine'},
    'zankoline_subtitle': {'ku': 'سیستەمی وەرگرتنی قوتابییان و ڕاوێژکاری زانکۆلاین', 'badini': 'سیستەمێ وەرگرتنا قوتابیان و ڕاوێژکاریا زانکۆلاین', 'ar': 'نظام القبول الجامعي والاستشارات', 'en': 'KRG University Admission System & Calculator'},
    'zankoline_calculator': {'ku': 'ئەژمارکردنی نمرەی پۆلی ۱۲', 'badini': 'ژمارتنا نمرەیا پۆلا ۱۲', 'ar': 'حساب معدل السادس الإعدادي', 'en': '12th Grade Mark Calculator'},
    'zankoline_portal': {'ku': 'ماڵپەڕی فەرمی زانکۆلاین', 'badini': 'ماڵپەڕێ فەرمی یێ زانکۆلاین', 'ar': 'بوابة زانكولاين الرسمية', 'en': 'Official ZankoLine Portal'},
    'department_matcher': {'ku': 'دۆزینەوەی بەشە گونجاوەکان', 'badini': 'دیتنا پشکێن گونجای', 'ar': 'البحث عن التخصصات المناسبة', 'en': 'Matching Departments'},
    'zankoline_avg_label': {
      'ku': 'تێکڕای نمرەی پۆلی ۱۲',
      'badini': 'تێکڕایا نمرەیا پۆلا ۱۲',
      'ar': 'معدل الصف 12 الإعدادي',
      'en': '12th Grade Average Mark'
    },
    'zankoline_avg_desc': {
      'ku': 'دیاریکردنی بەشە شایستەکان بەپێی نمرەکەت',
      'badini': 'دیاریکرنا پشکێن شایستە ب دووڤ نمرەیا تە',
      'ar': 'حساب الكليات والتخصصات المتاحة حسب معدلك',
      'en': 'Calculate eligible departments by mark'
    },
    'zankoline_track_scientific': {
      'ku': 'پۆلی زانستی',
      'badini': 'پۆلا زانستی',
      'ar': 'الفرع العلمي',
      'en': 'Scientific Track'
    },
    'zankoline_track_literary': {
      'ku': 'پۆلی وێژەیی',
      'badini': 'پۆلا وێژەیی',
      'ar': 'الفرع الأدبي',
      'en': 'Literary Track'
    },
    'zankoline_mode_general': {
      'ku': 'خوێندنی گشتی',
      'badini': 'خوێندنا گشتی',
      'ar': 'القبول العام',
      'en': 'General'
    },
    'zankoline_mode_parallel': {
      'ku': 'پاڕاڵێڵ',
      'badini': 'پاڕاڵێڵ',
      'ar': 'الموازي',
      'en': 'Parallel'
    },
    'zankoline_input_hint': {
      'ku': 'تێکڕای نمرەکەت داخڵ بکە (%):',
      'badini': 'تێکڕایا نمرەیا خۆ داخڵ بکە (%):',
      'ar': 'أدخل معدلك النهائي (%):',
      'en': 'Enter your average mark (%):'
    },
    'zankoline_search_btn_general': {
      'ku': 'دۆزینەوەی بەشەکان (خوێندنی گشتی)',
      'badini': 'دیتنا پشکان (خوێندنا گشتی)',
      'ar': 'البحث عن التخصصات (القبول العام)',
      'en': 'Find Departments (General Admission)'
    },
    'zankoline_search_btn_parallel': {
      'ku': 'دۆزینەوەی بەشەکان (سیستەمی پاڕاڵێڵ)',
      'badini': 'دیتنا پشکان (سیستەمێ پاڕاڵێڵ)',
      'ar': 'البحث عن التخصصات (النظام الموازي)',
      'en': 'Find Departments (Parallel Admission)'
    },
    'zankoline_find_btn': {
      'ku': 'دۆزینەوەی بەشەکان',
      'badini': 'دیتنا پشکان',
      'ar': 'البحث عن الأقسام',
      'en': 'Find Departments'
    },
    'zankoline_ai_advice_btn': {
      'ku': 'ڕاوێژی ژیری دەستکرد',
      'badini': 'ڕاوێژا زیرەکیا دەستکرد',
      'ar': 'استشارة AI',
      'en': 'AI Advice'
    },
    'departments': {
      'ku': 'بەشەکان',
      'badini': 'پشکەکان',
      'ar': 'الأقسام',
      'en': 'Departments'
    },
    'view_departments': {
      'ku': 'بینینی بەشە شایستەکان',
      'badini': 'دیتنا پشکێن شایستە',
      'ar': 'عرض الأقسام المتاحة',
      'en': 'View Eligible Departments'
    },
    'regenerate_advice': {
      'ku': 'نوێکردنەوەی ڕاوێژ',
      'badini': 'نویکرنا ڕاوێژێ',
      'ar': 'تحديث الاستشارة',
      'en': 'Regenerate Advice'
    },
    'ai_analyzing': {
      'ku': 'ڕاوێژکاری زیرەک سەرقاڵی شیکردنەوەی هەلەکانە...',
      'badini': 'ڕاوێژکارێ زیرەک مژویلی شیکارکرنا دەرفەتانە...',
      'ar': 'المستشار الذكي يحلل الفرص المتاحة لمعدلك...',
      'en': 'AI Advisor is analyzing opportunities for your grade...'
    },
    'zankoai_student_role': {
      'ku': 'قوتابی ZankoAI',
      'badini': 'قوتابیێ ZankoAI',
      'ar': 'طالب ZankoAI',
      'en': 'ZankoAI Student',
    },
    'zankoline_ai_advisor_title': {
      'ku': 'ڕاوێژکاری زیرەکی زانکۆلاین (AI Advisor)',
      'badini': 'ڕاوێژکارێ زیرەکێ زانکۆلاین (AI Advisor)',
      'ar': 'مستشار زانكولاين الذكي (AI Advisor)',
      'en': 'ZankoLine Smart AI Advisor'
    },
    'zankoline_ai_card_header_general': {
      'ku': 'شیکاری و پێشنیاری مامۆستا AI',
      'badini': 'شیکاری و پێشنیارێن مامۆستایێ AI',
      'ar': 'تحليل وتوصيات معلم الذكاء الاصطناعي',
      'en': 'AI Teacher Analysis & Guidance'
    },
    'zankoline_ai_card_header_parallel': {
      'ku': 'شیکاری پاڕاڵێڵ و پێشنیاری مامۆستا AI',
      'badini': 'شیکاریا پاڕاڵێڵ و پێشنیارێن مامۆستایێ AI',
      'ar': 'تحليل النظام الموازي وتوصيات AI',
      'en': 'Parallel AI Analysis & Guidance'
    },
    'zankoline_city_all': {'ku': 'سەرجەم شارەکان', 'badini': 'هەموو باژێر', 'ar': 'جميع المدن', 'en': 'All Cities'},
    'zankoline_matched_count': {'ku': 'بەشی گونجاو', 'badini': 'پشکێن گونجای', 'ar': 'التخصصات المناسبة', 'en': 'Matched Departments'},
    'zankoline_fee_discount_tag': {
      'ku': 'تێچووی ساڵانەی پاڕاڵێڵ',
      'badini': 'تێچووا ساڵانە یا پاڕاڵێڵ',
      'ar': 'القسط السنوي الموازي',
      'en': 'Yearly Parallel Fee'
    },
    'zankoline_discount_note': {
      'ku': '(دوای %40 داشکاندن)',
      'badini': '(پشتی %40 داشکاندنێ)',
      'ar': '(بعد خصم 40%)',
      'en': '(40% Discount Applied)'
    },
    'enter_valid_mark': {
      'ku': 'تکایە نمرەیەکی دروست داخڵ بکە (لە نێوان 0 بۆ 100)',
      'badini': 'تکایە نمرەکا دروست داخڵ بکە (دناڤبەرا 0 تا 100)',
      'ar': 'يرجى إدخال معدل صحيح (بين 0 و 100)',
      'en': 'Please enter a valid mark (between 0 and 100)',
    },
    'no_departments_found': {
      'ku': 'هیچ بەشێک نەدۆزرایەوە بۆ ئەم نمرەیە',
      'badini': 'چ پشک نەهاتنە دیتن بۆ ڤێ نمرەیێ',
      'ar': 'لم يتم العثور على تخصصات لهذا المعدل',
      'en': 'No departments found for this mark',
    },
    'try_another_mark_or_parallel': {
      'ku': 'تکایە نمرەیەکی تر تاقی بکەرەوە یان دۆخی پاڕاڵێڵ چالاک بکە',
      'badini': 'تکایە نمرەکا دی تاقی بکە یان سیستەمێ پاڕاڵێڵ کارا بکە',
      'ar': 'يرجى تجربة معدل آخر أو تفعيل النظام الموازي',
      'en': 'Please try another mark or switch to Parallel admission mode',
    },
    'min_mark_label': {
      'ku': 'نمرەی وەرگرتن',
      'badini': 'نمرەیا وەرگرتنێ',
      'ar': 'معدل القبول',
      'en': 'Admission Cutoff',
    },
    'parallel_label': {
      'ku': 'پاڕاڵێڵ',
      'badini': 'پاڕاڵێڵ',
      'ar': 'موازي',
      'en': 'Parallel',
    },
    'general_label': {
      'ku': 'گشتی',
      'badini': 'گشتی',
      'ar': 'عام',
      'en': 'General',
    },
    'krg_admissions_tag': {
      'ku': 'KRG Admissions • زانکۆلاین',
      'badini': 'KRG Admissions • زانکۆلاین',
      'ar': 'القبول المركزي لجامعات إقليم كوردستان',
      'en': 'KRG Higher Education Admissions',
    },

    // Bottom Navigation
    'nav_home': {'ku': 'سەرەکی', 'badini': 'سەرەکی', 'ar': 'الرئيسية', 'en': 'Home'},
    'nav_courses': {'ku': 'وانەکان', 'badini': 'وانە', 'ar': 'المواد', 'en': 'Courses'},

    'add_course': {'ku': 'زیادکردنی وانەی نوێ', 'badini': 'زێدەکرنا وانەکا نوو', 'ar': 'إضافة مادة جديدة', 'en': 'Add New Course'},
    'edit_course': {'ku': 'دەستکاریکردنی وانە', 'badini': 'دەستکاریکرنا وانێ', 'ar': 'تعديل المادة', 'en': 'Edit Course'},
    'delete_course': {'ku': 'سڕینەوەی وانە', 'badini': 'ژێبرنا وانێ', 'ar': 'حذف المادة', 'en': 'Delete Course'},

    // Exam Countdown
    'midterm_exam': {'ku': 'تاقیکردنەوەی میدترم', 'badini': 'تاقیکرنا میدترم', 'ar': 'امتحان الميدتيرم', 'en': 'Midterm Exam'},
    'final_exam': {'ku': 'تاقیکردنەوەی فایناڵ', 'badini': 'تاقیکرنا فایناڵ', 'ar': 'الامتحان النهائي', 'en': 'Final Exam'},
    'exam_countdown': {'ku': 'ژێرمێژووی تاقیکردنەوەکان', 'badini': 'ژێرمێژوویا تاقیکرنان', 'ar': 'العد التنازلي للامتحانات', 'en': 'Exam Countdown'},
    'select_midterm_date': {'ku': 'ڕێکەوتی تاقیکردنەوەی میدترم', 'badini': 'ڕێکەفتا تاقیکرنا میدترم', 'ar': 'تاريخ امتحان الميدتيرم', 'en': 'Midterm Exam Date'},
    'select_final_date': {'ku': 'ڕێکەوتی تاقیکردنەوەی فایناڵ', 'badini': 'ڕێکەفتا تاقیکرنا فایناڵ', 'ar': 'تاريخ الامتحان النهائي', 'en': 'Final Exam Date'},
    'days_left': {'ku': 'ڕۆژی ماوە', 'badini': 'ڕۆژێن مایین', 'ar': 'أيام متبقية', 'en': 'days left'},
    'hours_left': {'ku': 'کاتژمێری ماوە', 'badini': 'دەژمێرێن مایین', 'ar': 'ساعات متبقية', 'en': 'hours left'},
    'today_exam': {'ku': 'ئەمڕۆ تاقیکردنەوەیە!', 'badini': 'ئەڤڕۆ تاقیکرنە!', 'ar': 'الامتحان اليوم!', 'en': 'Exam Today!'},
    'exam_completed': {'ku': 'تەواوبوو', 'badini': 'تەمام بوو', 'ar': 'مكتمل', 'en': 'Completed'},
    'no_exam_date': {'ku': 'دیاری نەکراوە', 'badini': 'دیاری نەکریە', 'ar': 'غير محدد', 'en': 'Not set'},
    'edit_midterm_duration': {'ku': 'دیاریکردن و دەستکاریکردنی ماوەی میدترم', 'badini': 'دیاریکرن و دەستکاریکرنا ماوێ میدترم', 'ar': 'تحديد وتعديل مدة الميدتيرم', 'en': 'Edit Midterm Period & Date'},
    'set_by_days': {'ku': 'دیاریکردنی ماوە بە ڕۆژ', 'badini': 'دیاریکرنا ماوەی ب ڕۆژ', 'ar': 'تحديد المدة بالأيام', 'en': 'Set period in days'},
    'days_from_now': {'ku': 'ڕۆژ لەمڕۆوە', 'badini': 'ڕۆژ ژ ئەڤڕۆ و پێدا', 'ar': 'أيام من اليوم', 'en': 'days from today'},
    'custom_date_picker': {'ku': 'هەڵبژاردنی ڕێکەوتی دیاریکراو', 'badini': 'هەلبژارتنا ڕێکەفتا دیاریکری', 'ar': 'اختيار تاريخ محدد', 'en': 'Pick Exact Date'},

    'nav_gpa': {'ku': 'کۆنمرە (GPA)', 'badini': 'کۆنمرە (GPA)', 'ar': 'المعدل (GPA)', 'en': 'GPA'},
    'nav_ai_teacher': {'ku': 'مامۆستا AI', 'badini': 'مامۆستا AI', 'ar': 'معلم AI', 'en': 'AI Tutor'},

    'nav_quiz': {'ku': 'کویز', 'badini': 'کویز', 'ar': 'اختبار', 'en': 'Quiz'},
    'quiz_title': {'ku': 'ئەنجامی کویز', 'badini': 'ئەنجامێ کویزی', 'ar': 'نتيجة الاختبار', 'en': 'Quiz Results'},
    'quiz_completed': {'ku': 'تاقیکردنەوەکە تەواو بوو!', 'badini': 'تاقیکرن تەمام بوو!', 'ar': 'اكتمل الاختبار!', 'en': 'Quiz Completed!'},
    'your_score': {'ku': 'نمرەکەت', 'badini': 'نمرەیا تە', 'ar': 'درجتك', 'en': 'Your Score'},
    'score_good': {'ku': 'زۆر باشە! ئەنجامێکی بەرزە 👏', 'badini': 'گۆڕەپانا تەیا گەشە! ئەنجامەکێ بەرزە 👏', 'ar': 'ممتاز! نتيجة رائعة 👏', 'en': 'Great Job! Excellent result 👏'},
    'back_to_quiz_home': {'ku': 'دووبارەکردنەوەی کویز', 'badini': 'دووبارەکرنا کویزی', 'ar': 'إعادة الاختبار', 'en': 'Retake Quiz'},
    'nav_pdf_chat': {'ku': 'پەڕەی PDF', 'badini': 'پەڕا PDF', 'ar': 'ملف PDF', 'en': 'PDF Chat'},

    'nav_progress': {'ku': 'پێشکەوتن', 'badini': 'پێشکەفتن', 'ar': 'التقدم', 'en': 'Progress'},
    'nav_profile': {'ku': 'پڕۆفایل', 'badini': 'پرۆفایل', 'ar': 'الملف', 'en': 'Profile'},

    // Home / Dashboard Header & Search
    'greeting': {'ku': 'بەیانیت باش', 'badini': 'سپێدەیا تە باش', 'ar': 'صباح الخير', 'en': 'Good morning'},
    'greeting_morning': {'ku': 'بەیانیت باش', 'badini': 'سپێدەیا تە باش', 'ar': 'صباح الخير', 'en': 'Good morning'},
    'greeting_afternoon': {'ku': 'ڕۆژ باش', 'badini': 'ڕۆژ باش', 'ar': 'مساء الخير', 'en': 'Good afternoon'},
    'greeting_evening': {'ku': 'ئێوارەت باش', 'badini': 'ئێڤاریا تە باش', 'ar': 'مساء الخير', 'en': 'Good evening'},
    'greeting_night': {'ku': 'شەو باش', 'badini': 'شەڤا تە باش', 'ar': 'مساء الخير', 'en': 'Good evening'},
    'ask_ai_anything': {'ku': 'پرسیار لە AI بکه...', 'badini': 'پرسیارێ ژ AI بکە...', 'ar': 'اسأل الذكاء الاصطناعي...', 'en': 'Ask AI anything...'},
    'ai_tutor': {'ku': 'مامۆستای زیرەک', 'badini': 'مامۆستایێ زیرەک', 'ar': 'المعلم الذكي', 'en': 'AI Tutor'},
    'type_message': {'ku': 'پەیامەکەت بنووسە...', 'badini': 'پەیاما خۆ بنڤێسە...', 'ar': 'اكتب رسالتك...', 'en': 'Type a message...'},
    'ai_typing': {'ku': 'مامۆستا خەریکی وەڵامدانەوەیە...', 'badini': 'مامۆستا مژویلی وەڵامدانێ یە...', 'ar': 'المعلم يكتب الآن...', 'en': 'AI Tutor is typing...'},
    'ai_welcome': {
      'ku': 'سڵاو! من مامۆستای زیرەکی ZankoAIـم. چۆن دەتوانم یارمەتیدەرت بم لە خوێندنەکەتدا؟',
      'badini': 'سڵاڤ! ئەز مامۆستایێ زیرەکێ ZankoAI مە. چەوا دشێم هەڤکاریا تە بکەم د خوێندنا تە دا؟',
      'ar': 'مرحباً! أنا معلمك الذكي في ZankoAI. كيف يمكنني مساعدتك اليوم؟',
      'en': 'Hello! I am your ZankoAI Tutor. How can I help you learn today?'
    },
    'enter_api_key': {'ku': 'تۆمارکردنی کلیلی Gemini API', 'badini': 'تۆمارکرنا کلیلا Gemini API', 'ar': 'إدخال مفتاح Gemini API', 'en': 'Enter Gemini API Key'},
    'schedule_title': {'ku': 'خشتەی وانەکان', 'badini': 'خشتەیێ وانان', 'ar': 'جدول المحاضرات', 'en': 'Lesson Schedule'},
    'add_lecture': {'ku': 'زیادکردنی وانە', 'badini': 'زێدەکرنا وانێ', 'ar': 'إضافة محاضرة', 'en': 'Add Lecture'},
    'edit_lecture': {'ku': 'دەستکاریکردنی وانە', 'badini': 'دەستکاریکرنا وانێ', 'ar': 'تعديل المحاضرة', 'en': 'Edit Lecture'},
    'update_lecture': {'ku': 'نوێکردنەوەی وانە', 'badini': 'نویکرنا وانێ', 'ar': 'تحديث المحاضرة', 'en': 'Update Lecture'},
    'lecture_name': {'ku': 'ناوی وانە', 'badini': 'ناڤێ وانێ', 'ar': 'اسم المحاضرة', 'en': 'Lecture / Subject Name'},
    'lecture_name_hint': {'ku': 'بۆ نموونە: داتابەیس، بیرکاری، تۆڕەکان...', 'badini': 'بۆ نموونە: داتابەیس، بیرکاری، تۆڕ...', 'ar': 'مثال: قواعد البيانات، الرياضيات، الشبكات...', 'en': 'e.g. Database, Mathematics, Networks...'},
    'lecture_time': {'ku': 'کاتی وانە', 'badini': 'دەمێ وانێ', 'ar': 'وقت المحاضرة', 'en': 'Lecture Time'},
    'lecture_location': {'ku': 'شوێنی وانە (هۆڵ یان تاقیگە)', 'badini': 'جهێ وانێ (هۆل یان تاقیگەهـ)', 'ar': 'مكان المحاضرة (قاعة أو مختبر)', 'en': 'Location (Hall / Lab)'},
    'lecture_location_hint': {'ku': 'بۆ نموونە: هۆڵی ٣، تاقیگەی ٥...', 'badini': 'بۆ نموونە: هۆلا ٣، تاقیگەها ٥...', 'ar': 'مثال: قاعة 3، مختبر 5...', 'en': 'e.g. Hall 3, Lab 5...'},
    'lecture_teacher': {'ku': 'ناوی مامۆستا', 'badini': 'ناڤێ مامۆستای', 'ar': 'اسم الأستاذ', 'en': 'Instructor / Teacher'},
    'lecture_teacher_hint': {'ku': 'ناوی مامۆستای وانەکە...', 'badini': 'ناڤێ مامۆستایێ وانێ...', 'ar': 'اسم أستاذ المادة...', 'en': 'Instructor name...'},
    'lecture_save_success': {'ku': 'وانەکە بەسەرکەوتوویی تۆمار کرا', 'badini': 'وانە ب سەرکەفتیانە هاتە تۆمارکرن', 'ar': 'تم حفظ المحاضرة بنجاح', 'en': 'Lecture saved successfully'},
    'lecture_delete_success': {'ku': 'وانەکە بە سەرکەوتوویی سڕایەوە', 'badini': 'وانە ب سەرکەفتیانە هاتە ژێبرن', 'ar': 'تم حذف المحاضرة بنجاح', 'en': 'Lecture deleted successfully'},
    'delete_lecture_title': {'ku': 'سڕینەوەی وانە', 'badini': 'ژێبرنا وانێ', 'ar': 'حذف المحاضرة', 'en': 'Delete Lecture'},
    'delete_lecture_confirm': {'ku': 'ئایا دڵنیایت لە سڕینەوەی ئەم وانەیە لە خشتەکەتدا؟', 'badini': 'ئەرێ تو پشتڕاستی ژ ژێبرنا ڤێ وانێ ژ خشتەیێ خۆ؟', 'ar': 'هل أنت متأكد من حذف هذه المحاضرة من جدولك؟', 'en': 'Are you sure you want to delete this lecture from your schedule?'},
    'today': {'ku': 'ئەمڕۆ', 'badini': 'ئەڤرۆ', 'ar': 'اليوم', 'en': 'Today'},
    'day_off_title': {'ku': 'پشووە و هیچ وانەیەکت نییە 🎉', 'badini': 'بێهنڤەدانە و چ وانە نینن 🎉', 'ar': 'عطلة ولا توجد أي محاضرات اليوم 🎉', 'en': 'No lectures today! Enjoy your break 🎉'},
    'day_off_sub': {'ku': 'کاتێکی گونجاوە بۆ پشوودان یان پێداچوونەوە بە وانەکانتدا ✨', 'badini': 'دەمەکێ باشە بۆ بێهنڤەدانێ یان زڤڕاندنا وانان ✨', 'ar': 'وقت رائع للاسترخاء أو مراجعة الدروس السابقة ✨', 'en': 'Great time to relax or review your study materials ✨'},
    'lectures_today_count': {'ku': 'وانەت هەیە بۆ ئەمڕۆ 📚', 'badini': 'وانە هەنە بۆ ئەڤرۆ 📚', 'ar': 'محاضرات مجدولة لديك اليوم 📚', 'en': 'lectures scheduled for today 📚'},
    'no_lectures_day': {'ku': 'هیچ وانەیەک بۆ ئەم ڕۆژە نییە', 'badini': 'چ وانە بۆ ڤێ ڕۆژێ نینن', 'ar': 'لا توجد محاضرات لهذا اليوم', 'en': 'No lectures for this day'},
    'no_lectures_for_day': {'ku': 'هیچ وانەیەک تۆمار نەکراوە بۆ', 'badini': 'چ وانە نەهاتینە تۆمارکرن بۆ', 'ar': 'لا توجد محاضرات مسجلة ليوم', 'en': 'No lectures scheduled for'},
    'tap_to_add_lecture_desc': {'ku': 'کلیک لە دوگمەی خوارەوە بکە بۆ زیادکردنی وانە و کاتەکان', 'badini': 'کلیت بکە ل دوکما خوارێ بۆ زێدەکرنا وانە و دەمان', 'ar': 'اضغط على الزر أدناه لإضافة المحاضرات والأوقات', 'en': 'Tap the button below to add your lectures and times'},
    'schedule_view_daily': {'ku': 'بینینی ڕۆژانە', 'badini': 'دیتنا ڕۆژانە', 'ar': 'عرض يومي', 'en': 'Daily View'},
    'schedule_view_weekly': {'ku': 'بینینی هەفتانە', 'badini': 'دیتنا حەفتیانە', 'ar': 'عرض أسبوعي', 'en': 'Weekly View'},
    'select_day': {'ku': 'ڕۆژی وانە', 'badini': 'ڕۆژا وانێ', 'ar': 'يوم المحاضرة', 'en': 'Lecture Day'},
    'quick_time_slots': {'ku': 'کاتە باوەکان', 'badini': 'دەمێن بەربڵاڤ', 'ar': 'أوقات شائعة', 'en': 'Common Time Slots'},
    'custom_time': {'ku': 'دیاریکردنی کات', 'badini': 'دەستنیشانکرنا دەمی', 'ar': 'تحديد الوقت', 'en': 'Pick Custom Time'},
    'not_specified': {'ku': 'دیارینەکراوە', 'badini': 'نەهاتیە دیارکرن', 'ar': 'غير محدد', 'en': 'Not specified'},
    'default_teacher': {'ku': 'مامۆستای وانە', 'badini': 'مامۆستایێ وانێ', 'ar': 'أستاذ المادة', 'en': 'Instructor'},
    'all_week': {'ku': 'تەواوی هەفتە', 'badini': 'هەمی حەفتی', 'ar': 'كامل الأسبوع', 'en': 'Full Week'},
    'search_lectures': {'ku': 'گەڕان لە وانەکان، مامۆستا یان هۆڵ...', 'badini': 'لێگەڕیان د واناندا، مامۆستا یان هۆل...', 'ar': 'البحث في المحاضرات، الأساتذة أو القاعات...', 'en': 'Search courses, teachers, or halls...'},
    'ongoing_now': {'ku': 'ئێستا بەردەوامە', 'badini': 'نوکە بەردەوامە', 'ar': 'جارية الآن', 'en': 'Ongoing Now'},
    'upcoming_next': {'ku': 'وانەی داهاتوو', 'badini': 'وانا بهێت', 'ar': 'المحاضرة القادمة', 'en': 'Upcoming Next'},
    'ai_tutor_subtitle': {
      'ku': 'هەموو پرسیارێک بکە، ڕوونکردنەوەی ڕوون وەربگرە و باشتر فێربە لەگەڵ AI.',
      'badini': 'هەمی پرسیارەکێ بکە، ڕوونکردنا ڕوون وەربگرە و چێتر فێرببە دگەل AI.',
      'ar': 'اسأل أي شيء، احصل على شروحات واضحة وتعلم بشكل أفضل مع الذكاء الاصطناعي.',
      'en': 'Ask anything, get clear explanations and learn better with AI.'
    },
    'ai_tutor_hero_title': {
      'ku': 'یارمەتیدەری زیرەکی\nخوێندنی تایبەتیت',
      'badini': 'هاریکارێ زیرەکێ\nخوێندنا تە یا تایبەت',
      'ar': 'مساعدك الشخصي\nللتعلم الذكي',
      'en': 'Your personal\nlearning assistant'
    },
    'ready_to_continue': {
      'ku': 'ئامادەیت بۆ بەردەوامبوون لە خوێندن؟',
      'badini': 'ئامادەی بۆ بەردەوامبوونێ د خوێندنێ دا؟',
      'ar': 'هل أنت مستعد لمتابعة تعلمك؟',
      'en': 'Ready to continue your learning?'
    },
    'today_progress': {
      'ku': 'پێشکەوتنی ئەمڕۆ',
      'badini': 'پێشکەفتنا ئەڤرۆ',
      'ar': 'تقدم اليوم',
      'en': "Today's progress"
    },
    'upcoming_tasks': {
      'ku': 'ئەرکەکانی داهاتوو',
      'badini': 'ئەرکێن بهێت',
      'ar': 'المهام القادمة',
      'en': 'Upcoming tasks'
    },
    'view_details': {
      'ku': 'بینینی وردەکاری',
      'badini': 'دیتنا هویرکاریان',
      'ar': 'عرض التفاصيل',
      'en': 'View details'
    },
    'lessons_completed': {
      'ku': 'وانە تەواوکراوەکان',
      'badini': 'وانێن تەمامکری',
      'ar': 'الدروس المكتملة',
      'en': 'Lessons completed'
    },
    'study_time_today': {
      'ku': 'کاتی خوێندنی ئەمڕۆ',
      'badini': 'دەمێ خوێندنا ئەڤرۆ',
      'ar': 'وقت الدراسة اليوم',
      'en': 'Study time Today'
    },
    'day_streak': {
      'ku': 'ڕۆژ بەردەوامی',
      'badini': 'ڕۆژێن بەردەوام',
      'ar': 'أيام متتالية',
      'en': 'Day streak'
    },
    'see_all': {
      'ku': 'هەمووی ببینە',
      'badini': 'هەمیێ ببینە',
      'ar': 'عرض الكل',
      'en': 'See all'
    },
    'high_priority': {
      'ku': 'گرنگیی باڵا',
      'badini': 'گرنگیا بلند',
      'ar': 'أولوية عالية',
      'en': 'High Priority'
    },
    'medium_priority': {
      'ku': 'گرنگیی مامناوەند',
      'badini': 'گرنگیا ناڤین',
      'ar': 'أولوية متوسطة',
      'en': 'Medium'
    },
    'start_learning': {'ku': 'دەستپێکردنی فێربوون', 'badini': 'دەستپێکرنا فێربوونێ', 'ar': 'ابدأ التعلم', 'en': 'Start Learning'},
    'explain': {'ku': 'ڕوونکردنەوە', 'badini': 'ڕوونکردن', 'ar': 'شرح', 'en': 'Explain'},
    'summarize': {'ku': 'کورتکردنەوە', 'badini': 'کورتکرن', 'ar': 'تلخيص', 'en': 'Summarize'},
    'voice_tutor': {'ku': 'تۆماری دەنگی', 'badini': 'تۆمارا دەنگی', 'ar': 'تسجيل المحاضرات', 'en': 'Voice Record'},
    'voice_tutor_sub': {'ku': 'تۆمار و پوختەی دەنگی وانە', 'badini': 'تۆمار و کورتیا دەنگی یا وانێ', 'ar': 'تسجيل وتلخيص المحاضرات', 'en': 'Record & summarize audio'},
    'pdf_chat': {'ku': 'چاتی PDF', 'badini': 'چات ب PDF', 'ar': 'محادثة PDF', 'en': 'PDF Chat'},
    'pdf_chat_sub': {'ku': 'گفتوگۆ لەگەڵ مەلزەمە و فایل', 'badini': 'چات دگەل مەلزەمە و پەڕان', 'ar': 'محادثة وتلخيص الملفات', 'en': 'Chat with study files'},
    'gpa_sub': {'ku': 'کۆنمرە و پێشبینی پلە', 'badini': 'کۆنمرە و پێشبینیا پلێ', 'ar': 'حساب وتوقع المعدل', 'en': 'Calculate & forecast'},
    'quiz_sub': {'ku': 'کویزی زیرەک و تاقیکردنەوە', 'badini': 'کویزا زیرەک و تاقیکرن', 'ar': 'اختبارات وامتحانات ذكية', 'en': 'Smart quiz & practice'},
    'flashcards': {'ku': 'فلاش کارت', 'badini': 'فلاش کارت', 'ar': 'البطاقات التعليمية', 'en': 'Flashcards'},
    'flashcards_sub': {'ku': 'پێداچوونەوە و بەهێزکردنی یادگە', 'badini': 'دووبارەکرن و بهێزکرنا بیرێ', 'ar': 'مراجعة وتثبيت المعلومات', 'en': 'Spaced repetition revision'},
    'pomodoro_focus': {'ku': 'فۆکەس و کات', 'badini': 'فۆکەس و دەم', 'ar': 'مؤقت التركيز', 'en': 'Pomodoro Focus'},
    'pomodoro_sub': {'ku': 'بەڕێوەبردنی کات و خوێندن', 'badini': 'ڕێڤەبرنا دەمی و خواندنێ', 'ar': 'تنظيم الوقت والتركيز', 'en': 'Study timer & intervals'},
    'academic_dictionary': {'ku': 'فەرهەنگی ئەکادیمی', 'badini': 'فەرهەنگا ئەکادیمی', 'ar': 'القاموس الأكاديمي', 'en': 'Academic Dictionary'},
    'academic_dictionary_sub': {'ku': 'زاراوە و پێناسەی زانستی', 'badini': 'زاراوە و پێناسێن زانستی', 'ar': 'مصطلحات وتعريفات علمية', 'en': 'Terms & definitions'},
    'seminar_thesis_assistant': {'ku': 'تێز و سیمینار', 'badini': 'تێز و سیمینار', 'ar': 'مساعد البحوث', 'en': 'Seminar & Thesis'},
    'seminar_thesis_sub': {'ku': 'پلانی سیمینار، تێز و سلاید', 'badini': 'پلان دانان بۆ سیمینار و تێزان', 'ar': 'إعداد البحوث والسلايدات', 'en': 'Research outline & slides'},

    // Cards
    'current_gpa': {'ku': 'کۆنمرەی گشتی (GPA)', 'badini': 'کۆنمرەیا گشتی (GPA)', 'ar': 'المعدل التراكمي', 'en': 'Current GPA'},
    'excellent': {'ku': 'زۆر باشە', 'badini': 'گەلەک باشە', 'ar': 'ممتاز', 'en': 'Excellent'},
    'continue_learning': {'ku': 'بەردەوامبوون لە خوێندن', 'badini': 'بەردەوامبوون ل سەر خوێندنێ', 'ar': 'متابعة التعلم', 'en': 'Continue Learning'},
    'continue': {'ku': 'بەردەوامبە', 'badini': 'بەردەوامبە', 'ar': 'متابعة', 'en': 'Continue'},
    'quick_ai_tools': {'ku': 'ئامرازە خێراکانی AI', 'badini': 'ئامرازێن خێرا یێن AI', 'ar': 'أدوات الذكاء الاصطناعي', 'en': 'Quick AI Tools'},
    'all_ai_tools_subtitle': {'ku': 'هەموو ئامرازەکان لێرەن', 'badini': 'هەموو ئامرازێن لێرین', 'ar': 'جميع الأدوات في متناول يدك', 'en': 'All your AI tools in one place'},
    'recommended_courses': {'ku': 'وانە پێشنیارکراوەکان', 'badini': 'وانێن پێشنیارکری', 'ar': 'المواد المقترحة', 'en': 'Recommended Courses'},

    // Settings & Profile
    'settings_profile': {'ku': 'ڕێکخستنەکان و پرۆفایل', 'badini': 'ڕێکخستن و پرۆفایل', 'ar': 'الإعدادات والملف الشخصي', 'en': 'Settings & Profile'},
    'official_student_verification': {'ku': 'پشکنینی فەرمی قوتابی', 'badini': 'پشکنینا فەرمی یا قوتابی', 'ar': 'التحقق الرسمي من الطالب', 'en': 'Official Student Verification'},
    'learning_stats': {'ku': 'ئامارەکانی فێربوون', 'badini': 'ئامارێن فێربوونێ', 'ar': 'إحصائيات التعلم', 'en': 'Learning Stats'},
    'study_time': {'ku': 'کاتی خوێندن', 'badini': 'دەمیێ خوێندنێ', 'ar': 'وقت الدراسة', 'en': 'Study Time'},
    'quizzes': {'ku': 'کویز و تاقیکردنەوەکان', 'badini': 'کویز و تاقیکردنەڤە', 'ar': 'الاختبارات والامتحانات', 'en': 'Quizzes & Exams'},
    'gpa': {'ku': 'نمرەی ١٠٠', 'badini': 'نمرە (100)', 'ar': 'درجة 100', 'en': 'Grade 100'},
    'reset_stats': {'ku': 'سفرکردنەوەی ئامارەکان', 'badini': 'سفرکرنا ئاماران', 'ar': 'إعادة ضبط الإحصائيات', 'en': 'Reset Stats'},

    // Leaderboard & Gamification
    'leaderboard_title': {'ku': '🏆 ڕیزبەندی و دەستکەوتەکان', 'badini': '🏆 ڕیزبەندی و دەستکەوت', 'ar': '🏆 لوحة الصدارة والإنجازات', 'en': 'Leaderboard & Badges'},
    'all_departments': {'ku': 'هەموو بەشەکان (گشتی)', 'badini': 'هەموو پشک (گشتی)', 'ar': 'جميع الأقسام (عام)', 'en': 'All Departments'},
    'by_department': {'ku': 'بەپێی بەشەکان', 'badini': 'لپەی پشکان', 'ar': 'حسب القسم', 'en': 'By Department'},
    'my_rank': {'ku': 'ڕیزبەندیی تۆ', 'badini': 'ڕیزبەندیا تە', 'ar': 'ترتيبك', 'en': 'Your Rank'},
    'streak_days': {'ku': 'ڕۆژ بەردەوام', 'badini': 'ڕۆژ بێ پچڕان', 'ar': 'أيام متتالية', 'en': 'Days Streak'},
    'earned_badges': {'ku': 'مەدالیا بەدەستهاتووەکان', 'badini': 'مەدالیێن بەدەستهاتی', 'ar': 'الأوسمة المكتسبة', 'en': 'Earned Badges'},
    'xp_points': {'ku': 'خاڵی XP', 'badini': 'خالێن XP', 'ar': 'نقاط XP', 'en': 'XP Points'},

    // Offline Archive & Downloads
    'offline_archive': {'ku': '💾 ناوەندی ئەرشیفی ئۆفلاین', 'badini': '💾 نەواشا ئەرشیفێ ئۆفلاین', 'ar': '💾 مركز الأرشيف بدون إنترنت', 'en': 'Offline Archive Center'},
    'download_offline': {'ku': 'داگرتن بۆ ئۆفلاین 📥', 'badini': 'داگرتن بۆ ئۆفلاین 📥', 'ar': 'تنزيل للأوفلاين 📥', 'en': 'Download for Offline 📥'},
    'saved_offline': {'ku': 'بە سەرکەوتوویی بۆ ئۆفلاین پاشەکەوت کرا! ✅', 'badini': 'ب سەرکەفتیانە بۆ ئۆفلاین هاتە پاشەکەفتکرن! ✅', 'ar': 'تم الحفظ للاوفلاين بنجاح! ✅', 'en': 'Saved for offline revision! ✅'},
    'offline_flashcards': {'ku': 'فلاش کارتەکان', 'badini': 'فلاش کارت', 'ar': 'البطاقات التعليمية', 'en': 'Flashcards'},
    'offline_summaries': {'ku': 'کورتکراوەی PDF', 'badini': 'کورتیا PDF', 'ar': 'ملخصات PDF', 'en': 'PDF Summaries'},
    'offline_quizzes': {'ku': 'کویز و تاقیکردنەوەکان', 'badini': 'کویز و تاقیکردنەڤە', 'ar': 'الاختبارات والتطبيقات', 'en': 'Quizzes & Exams'},
    'no_offline_items': {'ku': 'هیچ بابەتێکی داگیراو نەدۆزرایەوە', 'badini': 'هیچ تشتەکێ داگری نەهاتە لێگەڕیان', 'ar': 'لا توجد عناصر محفوظة أوفلاين', 'en': 'No offline items downloaded yet'},

    // Smart AI Study Roadmap
    'study_roadmap': {'ku': '📅 نەخشەڕێگای زیرەکی تاقیکردنەوە', 'badini': '📅 نەخشەڕێگا ژیرییا تاقیکرنەڤێ', 'ar': '📅 خريطة طريق الدراسة الذكية', 'en': 'Smart Study Roadmap'},
    'create_roadmap': {'ku': 'دروستکردنی نەخشەڕێگا', 'badini': 'چێکرنا نەخشەڕێگایێ', 'ar': 'إنشاء خريطة طريق', 'en': 'Create Roadmap'},
    'subject_name': {'ku': 'ناوی وانە / بابەت', 'badini': 'ناوێ وانێ', 'ar': 'اسم المادة', 'en': 'Subject Name'},
    'total_chapters': {'ku': 'ژمارەی بەشەکان (Chapters)', 'badini': 'ژمارا پشکان', 'ar': 'عدد الفصول', 'en': 'Total Chapters'},
    'roadmap_days_left': {'ku': 'ڕۆژانی ماوە بۆ تاقیکردنەوە', 'badini': 'ڕۆژێن مای بۆ تاقیکرنەڤێ', 'ar': 'الأيام المتبقية للاختبار', 'en': 'Days Until Exam'},
    'hours_per_day': {'ku': 'کاتژمێری خوێندن لە ڕۆژێکدا', 'badini': 'دەژمێرێن خوێندنێ ل ڕۆژەکێدا', 'ar': 'ساعات الدراسة يومياً', 'en': 'Study Hours per Day'},
    'generate_roadmap': {'ku': 'داڕشتنی پلانی خوێندن 🪄', 'badini': 'چێکرنا پلانا خوێندنێ 🪄', 'ar': 'توليد خريطة الدراسة 🪄', 'en': 'Generate AI Roadmap 🪄'},
    'preferences': {'ku': 'هەڵبژاردنەکان', 'badini': 'هەلبژارتن', 'ar': 'التفضيلات', 'en': 'Preferences'},
    'dark_mode': {'ku': 'باری تاریک', 'badini': 'مۆدێ تاریک', 'ar': 'الوضع الداكن', 'en': 'Dark Mode'},
    'app_language': {'ku': 'زمانی ئەپڵیکەیشن', 'badini': 'زمانێ ئەپلیکەیشنێ', 'ar': 'لغة التطبيق', 'en': 'App Language'},
    'notifications': {'ku': 'ئاگادارییەکان', 'badini': 'ئاگاداری', 'ar': 'الإشعارات', 'en': 'Notifications'},
    'privacy_security': {'ku': 'تایبەتمەندی و ئاسایش', 'badini': 'تایبەتمەندی و ئاسایش', 'ar': 'الخصوصية والأمان', 'en': 'Privacy & Security'},
    'about_zanko': {'ku': 'دەربارەی ZankoAI', 'badini': 'دەربارەی ZankoAI', 'ar': 'عن ZankoAI', 'en': 'About ZankoAI'},

    // Courses & Lessons
    'all_courses': {'ku': 'وانەکانم', 'badini': 'وانێت من', 'ar': 'موادي الدراسية', 'en': 'My Courses'},
    'search_courses': {'ku': 'گەڕان لە وانەکاندا...', 'badini': 'لێگەڕیان د وانان دا...', 'ar': 'البحث في المواد...', 'en': 'Search courses...'},
    'search_course_hint': {'ku': 'گەڕان لە وانەکاندا...', 'badini': 'گەڕیان د واناندا...', 'ar': 'البحث في المواد الدراسية...', 'en': 'Search courses...'},
    'filter_in_progress': {'ku': 'لە خوێندندایە', 'badini': 'د خواندنێدایە', 'ar': 'قيد الدراسة', 'en': 'In Progress'},
    'filter_completed': {'ku': 'تەواوکراو', 'badini': 'تەمامکری', 'ar': 'مكتملة', 'en': 'Completed'},
    'add_new_course': {'ku': 'زیادکردنی وانە', 'badini': 'زێدەکرنا وانێ', 'ar': 'إضافة مادة', 'en': 'Add Course'},
    'no_courses_found': {'ku': 'هیچ وانەیەک نەدۆزرایەوە', 'badini': 'چ وانە نەهاتنە دیتن', 'ar': 'لم يتم العثور على مواد', 'en': 'No courses found'},
    'upcoming_exams': {'ku': 'تاقیکردنەوەکان', 'badini': 'ئەزموون', 'ar': 'الامتحانات', 'en': 'Upcoming Exams'},
    'course_progress': {'ku': 'تێکڕای پێشکەوتن', 'badini': 'تێکڕایێ پێشکەفتنێ', 'ar': 'معدل الإنجاز', 'en': 'Avg Progress'},
    'active_courses_count': {'ku': 'وانە چالاکەکان', 'badini': 'وانێت چالاک', 'ar': 'المواد النشطة', 'en': 'Active Courses'},
    'continue_studying': {'ku': 'بەردەوامبە لە خوێندن', 'badini': 'بەردەوامبە د خواندنێدا', 'ar': 'متابعة الدراسة', 'en': 'Continue Studying'},
    'resume_learning': {'ku': 'دەستپێکردنەوە', 'badini': 'دەستپێکرنەڤە', 'ar': 'استئناف', 'en': 'Resume'},
    'lessons': {'ku': 'وانە', 'badini': 'وانە', 'ar': 'دروس', 'en': 'Lessons'},

    // Quiz Maker
    'quiz_maker': {'ku': 'دروستکەری کویز بە AI', 'badini': 'چێکەرێ کویزی ب AI', 'ar': 'منشئ الاختبارات', 'en': 'AI Quiz Maker'},
    'select_course': {'ku': 'وانەکە هەڵبژێرە', 'badini': 'وانێ هەلبژێرە', 'ar': 'اختر المادة', 'en': 'Select Course'},
    'select_topic': {'ku': 'بابەتەکە هەڵبژێرە', 'badini': 'بابەتی هەلبژێرە', 'ar': 'اختر الموضوع', 'en': 'Select Topic'},
    'generate_quiz': {'ku': 'دروستکردنی کویز', 'badini': 'چێکرنا کویزی', 'ar': 'إنشاء الاختبار', 'en': 'Generate Quiz'},
    'generate_quiz_title': {'ku': 'دروستکردنی کویزی خێرا بە AI', 'badini': 'چێکرنا کویزێ خێرا ب AI', 'ar': 'إنشاء اختبار سريع بالذكاء الاصطناعي', 'en': 'AI Quick Quiz Generator'},
    'generate_quiz_desc': {
      'ku': 'وانەیەک یان فایلێکی PDF باربکە تا AI ڕاستەوخۆ کویزی زانستیت لەسەر ناوەڕۆکەکەی بۆ دروست بکات.',
      'badini': 'وانەکێ یان فایلا PDF باربکە دا کو AI ڕاستەوخۆ کویزەکێ زانستی بۆ تە چێکەت.',
      'ar': 'قم بجهوز ملف PDF أو اختر مادة ليقوم الذكاء الاصطناعي بإنشاء اختبار من المحتوى.',
      'en': 'Upload a PDF file or pick a course topic to generate an instant AI quiz from content.'
    },
    'course_name_field': {'ku': 'ناوی وانە / بەش', 'badini': 'ناڤێ وانێ / پشکێ', 'ar': 'اسم المادة / القسم', 'en': 'Course / Subject Name'},
    'topic_field': {'ku': 'بابەت / تەوەر', 'badini': 'بابەت / تەوەر', 'ar': 'الموضوع / المحور', 'en': 'Topic / Section'},
    'generate_quiz_btn': {'ku': 'دروستکردنی کویز بە AI 🚀', 'badini': 'چێکرنا کویزی ب AI 🚀', 'ar': 'إنشاء الاختبار 🚀', 'en': 'Generate AI Quiz 🚀'},
    'previous_quizzes': {'ku': 'کویزەکانی پێشوو', 'badini': 'کویزێن بەرێ', 'ar': 'الاختبارات السابقة', 'en': 'Previous Quizzes'},

    'notes_title': {'ku': 'تێبینییەکانم', 'badini': 'تێبینیێن من', 'ar': 'ملاحظاتي', 'en': 'My Notes'},
    'search_notes': {'ku': 'گەڕان لە تێبینییەکاندا...', 'badini': 'لێگەڕیان د تێبینیان دا...', 'ar': 'البحث في الملاحظات...', 'en': 'Search notes...'},
    'new_note': {'ku': 'تێبینی نوێ', 'badini': 'تێبینییا نوو', 'ar': 'ملاحظة جديدة', 'en': 'New Note'},

    // Common Actions
    'edit': {'ku': 'دەستکاری', 'badini': 'دەستکاریکرن', 'ar': 'تعديل', 'en': 'Edit'},
    'delete': {'ku': 'سڕینەوە', 'badini': 'ژێبرن', 'ar': 'حذف', 'en': 'Delete'},
    'cancel': {'ku': 'هەڵوەشاندنەوە', 'badini': 'پاشگەزبوون', 'ar': 'إلغاء', 'en': 'Cancel'},
    'ok': {'ku': 'باشە', 'badini': 'باشە', 'ar': 'حسناً', 'en': 'OK'},
    'save': {'ku': 'خەزنکردن', 'badini': 'پاراستن / خەزنکرن', 'ar': 'حفظ', 'en': 'Save'},
    'clear': {'ku': 'سڕینەوە', 'badini': 'ژێبرن', 'ar': 'مسح', 'en': 'Clear'},
    
    // Common Errors/Messages
    'error': {'ku': 'هەڵەیەک ڕوویدا', 'badini': 'خەلەتیەک چێبوو', 'ar': 'حدث خطأ', 'en': 'Error'},
    'failed_to_load': {'ku': 'نەتوانرا باربکرێت', 'badini': 'نەهاتە بارکرن', 'ar': 'فشل التحميل', 'en': 'Failed to load'},
    'empty_record': {'ku': 'سجلەکە چۆڵە', 'badini': 'تۆمار بەتالە', 'ar': 'السجل فارغ', 'en': 'Empty record'},
    'scan_error': {'ku': 'هەڵە لە سکانکەر', 'badini': 'شاشی د سکانکەری دا', 'ar': 'خطأ في المسح', 'en': 'Scan Error'},
    
    // File / Chat
    'add_pdf': {'ku': 'زیادکردنی PDF', 'badini': 'زێدەکرنا PDF', 'ar': 'إضافة PDF', 'en': 'Add PDF'},
    'gemini_api_key': {'ku': 'کلیلێ APIی Gemini', 'badini': 'کلیلا Gemini API', 'ar': 'مفتاح Gemini API', 'en': 'Gemini API Key'},
    'save_key': {'ku': 'خەزنکردنی کلیل', 'badini': 'پاراستنا کلیلێ', 'ar': 'حفظ المفتاح', 'en': 'Save Key'},
    'clear_chat_history': {'ku': 'سڕینەوەی مێژووی چات؟', 'badini': 'ژێبرنا مێژوویا چاتی؟', 'ar': 'مسح سجل الدردشة؟', 'en': 'Clear Chat History?'},
    'clear_chat_desc': {'ku': 'ئەمە چاتە خەزنکراوەکان دەسڕێتەوە.', 'badini': 'ئەڤ چاتێن خەزنکری دێ هێنە ژێبرن.', 'ar': 'سيؤدي هذا إلى حذف المحادثات المحفوظة.', 'en': 'This will delete saved conversations.'},
    'please_enter_topic': {'ku': 'تکایە سەرەتا بابەتێک بنووسە.', 'badini': 'تکایە بەراهیێ بابەتەکێ بنڤێسە.', 'ar': 'يرجى إدخال موضوع أولاً.', 'en': 'Please enter a topic first.'},
    'please_enter_notes': {'ku': 'تکایە سەرەتا تێبینییەکان بنووسە یان فایلێک بەرزبکەرەوە.', 'badini': 'تکایە بەراهیێ تێبینیان بنڤێسە یان فایلەکێ گواستنەوە.', 'ar': 'يرجى إدخال ملاحظات أو رفع ملف أولاً.', 'en': 'Please enter notes or upload a file first.'},
    'note_saved': {'ku': 'تێبینییەکە بە سەرکەوتوویی خەزنکرا!', 'badini': 'تێبینی ب سەرکەفتن هاتە پاراستن!', 'ar': 'تم حفظ الملاحظة بنجاح!', 'en': 'Note saved successfully!'},
    'note_deleted': {'ku': 'تێبینییەکە سڕایەوە', 'badini': 'تێبینی هاتە ژێبرن', 'ar': 'تم حذف الملاحظة', 'en': 'Note deleted'},
    'provide_title_content': {'ku': 'تکایە هەم ناونیشان و هەم ناوەڕۆک دابین بکە', 'badini': 'تکایە سەر دێڕ و ناوەڕۆکێ ب دەی', 'ar': 'يرجى تقديم كل من العنوان والمحتوى', 'en': 'Please provide both title and content'},
    
    // Stats / Profile Extras
    'english_us': {'ku': 'English', 'badini': 'English', 'ar': 'English', 'en': 'English'},
    'kurdish_name': {'ku': 'کوردی (سۆرانی)', 'badini': 'کوردی (سۆرانی)', 'ar': 'الكردية (السورانية)', 'en': 'Kurdish (Sorani)'},
    'kurdish_desc': {'ku': 'زمانی کوردیی سۆرانی', 'badini': 'زمانی کوردیی سۆرانی', 'ar': 'اللغة الكردية السورانية', 'en': 'Central Kurdish (Sorani)'},
    'badini_name': {'ku': 'کوردی (بادینی)', 'badini': 'کوردی (بادینی)', 'ar': 'الكردية (البادينية)', 'en': 'Kurdish (Badini)'},
    'badini_desc': {'ku': 'زمانی کوردیی بادینی', 'badini': 'زمانی کوردیی بادینی', 'ar': 'اللغة الكردية البادينية', 'en': 'Northern Kurdish (Badini)'},
    'arabic_name': {'ku': 'العربية', 'badini': 'العربية', 'ar': 'العربية', 'en': 'العربية'},
    'arabic_desc': {'ku': 'اللغة العربية الفصحى', 'badini': 'اللغة العربية الفصحى', 'ar': 'اللغة العربية الفصحى', 'en': 'اللغة العربية الفصحى'},
    
    // Labels
    'questions_label': {'ku': 'پرسیارەکان', 'badini': 'پرسیار', 'ar': 'الأسئلة', 'en': 'Questions'},
    'accuracy_label': {'ku': 'ووردی', 'badini': 'درستی', 'ar': 'الدقة', 'en': 'Accuracy'},
    'courses_label': {'ku': 'کۆرسەکان', 'badini': 'کۆرس', 'ar': 'المواد', 'en': 'Courses'},
    'target_gpa': {'ku': 'کۆنمرەی ئامانج', 'badini': 'کۆنمرەیا ئارمانج', 'ar': 'المعدل المستهدف', 'en': 'Target GPA'},
    'remaining_semesters': {'ku': 'وەرزی ماوە', 'badini': 'وەرزێن مایین', 'ar': 'الفصول المتبقية', 'en': 'Remaining Semesters'},
    'task_subject_label': {'ku': 'ناوی ئەرکەکە / بابەت', 'badini': 'ناڤێ ئەرکی / بابەت', 'ar': 'اسم المهمة / الموضوع', 'en': 'Task / Subject Name'},
    'course_name_label': {'ku': 'ناوی وانە / کۆرس', 'badini': 'ناڤێ وانێ', 'ar': 'اسم المادة / الدورة', 'en': 'Course Name'},
    
    // Badges
    'ai_scholar': {'ku': 'زانای AI', 'badini': 'زانایێ AI', 'ar': 'عالم AI', 'en': 'AI Scholar'},
    'quiz_master': {'ku': 'پاڵەوانی کویز', 'badini': 'پاڵەوانێ کویزی', 'ar': 'بطل الاختبارات', 'en': 'Quiz Master'},
    'focus_guru': {'ku': 'پسپۆڕی تەرکیز', 'badini': 'پسپۆڕێ تەرکیزێ', 'ar': 'خبير التركيز', 'en': 'Focus Guru'},
    'deep_reader': {'ku': 'خوێنەری زیرەک', 'badini': 'خوێنەرێ زیرەک', 'ar': 'القارئ المتعمق', 'en': 'Deep Reader'},

    // Notifications
    'notif_ai_summary': {'ku': 'کورتەی AI ئامادەیە', 'badini': 'پوختەیا AI ئامادەیە', 'ar': 'ملخص AI جاهز', 'en': 'AI Summary Ready'},
    'notif_quiz_high': {'ku': 'ئاستێکی بەرزی کویز!', 'badini': 'ئاستەکێ بەرز د کویزی دا!', 'ar': 'أداء عالي في الاختبار!', 'en': 'Quiz Performance High!'},
    'notif_assignment': {'ku': 'بیرخستنەوەی کاتی کۆتایی ئەرک', 'badini': 'بیرئینانا دەمێ دوماهیێ سەربارەی ئەرکی', 'ar': 'تذكير بموعد التسليم', 'en': 'Assignment Deadline Reminder'},
    'notif_new_material': {'ku': 'ماددەی نوێی وانە بەردەستە', 'badini': 'بابەتێن نوو یێن وانان بەردەستن', 'ar': 'مواد دراسية جديدة متاحة', 'en': 'New Course Material Available'},
    'notif_gpa_update': {'ku': 'نوێکردنەوەی کۆنمرە', 'badini': 'نووکرنا کۆنمرەیێ', 'ar': 'تحديث المعدل', 'en': 'GPA Update Calculated'},

    // Hints & Tooltips
    'type_answer': {'ku': 'وەڵامەکە بنووسە...', 'badini': 'وەڵامی بنڤێسە...', 'ar': 'اكتب الإجابة...', 'en': 'Type answer...'},
    'note_title_hint': {'ku': 'ناونیشانی تێبینی...', 'badini': 'سەردێڕێ تێبینیێ...', 'ar': 'عنوان الملاحظة...', 'en': 'Note Title...'},
    'note_content_hint': {'ku': 'ناوەڕۆکی تێبینییەکە بنووسە یان بڵێ...', 'badini': 'ناوەڕۆکا تێبینیێ بنڤێسە یان بێژە...', 'ar': 'اكتب أو أملِ محتوى الملاحظة...', 'en': 'Write or dictate note content...'},
    'planner_hint_exam': {'ku': 'نموونە: تاقیکردنەوەی کۆتایی سیستمەکانی کارپێکردن', 'badini': 'نموونە: تاقیکرنا دوماهیێ یا سیستەمێن کارپێکرنێ', 'ar': 'مثال: الامتحان النهائي لأنظمة التشغيل', 'en': 'e.g. Operating Systems Final Exam'},
    'flashcards_hint': {'ku': 'نموونە: چینی مۆدێلی OSI', 'badini': 'نموونە: تەقنێن مۆدێلا OSI', 'ar': 'مثال: طبقات نموذج OSI', 'en': 'e.g. OSI model layers, CPU execution cycle'},
    'toggle_view': {'ku': 'گۆڕینی بینین', 'badini': 'گۆڕینا دیتنێ', 'ar': 'تغيير العرض', 'en': 'Toggle View'},
    'dictate_voice_note': {'ku': 'نووسین بە دەنگی کوردی', 'badini': 'نڤێسین ب دەنگێ کوردی', 'ar': 'الإملاء الصوتي', 'en': 'Dictate Kurdish Voice Note'},
    'scan_qr_deck': {'ku': 'سکانکردنی کارتی QR', 'badini': 'سکانکرنا کارتا QR', 'ar': 'مسح بطاقة QR', 'en': 'Scan QR Deck'},
    'share_qr_deck': {'ku': 'هاوبەشکردنی کارتی QR', 'badini': 'بهەڤبارکرنا کارتا QR', 'ar': 'مشاركة بطاقة QR', 'en': 'Share QR Deck'},
    'tts_tooltip': {'ku': 'خوێندنەوە بە دەنگ', 'badini': 'خوێندن ب دەنگی', 'ar': 'قراءة صوتية', 'en': 'Text to Speech'},
    'clear_chat_tooltip': {'ku': 'سڕینەوەی چات', 'badini': 'ژێبرنا چاتی', 'ar': 'مسح الدردشة', 'en': 'Clear Chat'},
    'config_api_key_tooltip': {'ku': 'ڕێکخستنی کلیلێ API', 'badini': 'ڕێکخستنا کلیلا API', 'ar': 'إعداد مفتاح API', 'en': 'Configure API Key'},
    'email_hint': {'ku': 'نموونە@zanko.edu', 'badini': 'نموونە@zanko.edu', 'ar': 'مثال@zanko.edu', 'en': 'example@zanko.edu'},

    // Notifications Screen
    'no_notifications': {'ku': 'هیچ ئاگادارییەک نییە', 'badini': 'چ ئاگاداری نینن', 'ar': 'لا توجد إشعارات', 'en': 'No Notifications'},
    'all_caught_up': {'ku': 'هەموو شتێکت خوێندووەتەوە!', 'badini': 'تە هەموو تشت خواندیە!', 'ar': 'أنت على اطلاع تام!', 'en': "You're all caught up!"},
    'mark_read': {'ku': 'نیشانەکردن بە خوێنراو', 'badini': 'دیاریکرن وەک خواندی', 'ar': 'تحديد كمقروء', 'en': 'Mark Read'},
    'filter_all': {'ku': 'هەموو', 'badini': 'هەموو', 'ar': 'الكل', 'en': 'All'},
    'filter_unread': {'ku': 'نەخوێنراو', 'badini': 'نەخواندی', 'ar': 'غير مقروء', 'en': 'Unread'},
    'filter_ai_tutor': {'ku': 'مامۆستای AI', 'badini': 'مامۆستایێ AI', 'ar': 'معلم AI', 'en': 'AI Tutor'},
    'filter_course': {'ku': 'وانە', 'badini': 'وانە', 'ar': 'المادة', 'en': 'Course'},
    'filter_quiz': {'ku': 'کویز', 'badini': 'کویز', 'ar': 'اختبار', 'en': 'Quiz'},
    'filter_reminder': {'ku': 'بیرخستنەوە', 'badini': 'بیرئینان', 'ar': 'تذكير', 'en': 'Reminder'},

    // Focus Screen
    'focus_timer_title': {'ku': 'کاتژمێری تەرکیزکردن', 'badini': 'دەژمێرێ تەرکیزێ', 'ar': 'مؤقت التركيز', 'en': 'Pomodoro Focus Timer'},
    'focus_session': {'ku': 'خولی تەرکیزکردن', 'badini': 'خولیا تەرکیزێ', 'ar': 'جلسة التركيز', 'en': 'Study Focus Session'},
    'break_session': {'ku': 'خولی پشوودان', 'badini': 'خولیا بێنڤەدانێ', 'ar': 'وقت الاستراحة', 'en': 'Relax Break Session'},
    'switch_to_focus': {'ku': 'بگۆڕە بۆ تەرکیز', 'badini': 'بگۆڕە بۆ تەرکیزێ', 'ar': 'التبديل للدراسة', 'en': 'Switch to Focus'},
    'switch_to_break': {'ku': 'بگۆڕە بۆ پشوو', 'badini': 'بگۆڕە بۆ بێنڤەدانێ', 'ar': 'التبديل للاستراحة', 'en': 'Switch to Break'},
    'focus_complete': {'ku': 'تەرکیز تەواو بوو!', 'badini': 'تەرکیز تەمام بوو!', 'ar': 'انتهت جلسة التركيز!', 'en': 'Focus Complete!'},
    'break_complete': {'ku': 'پشوو تەواو بوو!', 'badini': 'بێنڤەدان تەمام بوو!', 'ar': 'انتهت الاستراحة!', 'en': 'Break Complete!'},
    'focus_label': {'ku': 'تەرکیز', 'badini': 'تەرکیز', 'ar': 'تركيز', 'en': 'FOCUS'},
    'break_label': {'ku': 'پشوو', 'badini': 'بێنڤەدان', 'ar': 'استراحة', 'en': 'BREAK'},

    // Notes Screen
    'no_notes_found': {'ku': 'هیچ تێبینییەک نەدۆزرایەوە', 'badini': 'چ تێبینی نەهاتنە دیتن', 'ar': 'لم يتم العثور على ملاحظات', 'en': 'No Notes Found'},
    'recording_voice_note': {'ku': 'تۆمارکردنی تێبینی دەنگی', 'badini': 'تۆمارکرنا تێبینییا دەنگی', 'ar': 'تسجيل ملاحظة صوتية', 'en': 'Recording Voice Note'},
    'ai_organizing_note': {'ku': 'AI ئەو تێبینییە ڕیکدەخات...', 'badini': 'AI مژویلی ڕێکخستنا تێبینیێ یە...', 'ar': 'الذكاء الاصطناعي ينظم الملاحظة...', 'en': 'AI is polishing & organizing note...'},
    'general': {'ku': 'گشتی', 'badini': 'گشتی', 'ar': 'عام', 'en': 'General'},
    'save_note': {'ku': 'خەزنکردنی تێبینی', 'badini': 'پاراستنا تێبینیێ', 'ar': 'حفظ الملاحظة', 'en': 'Save Note'},

    // Stats / Achievement labels
    'stat_organized_notes': {'ku': 'کەمێک تێبینی AI ڕیکخست', 'badini': 'تێبینیێن AI ڕێکخستن', 'ar': 'نظّم ملاحظات AI', 'en': 'Organized 2+ AI Notes'},
    'stat_completed_quiz': {'ku': 'تاقیکردنەوەی کویز تەواو کرد', 'badini': 'تاقیکرنا کویزی تەمام کر', 'ar': 'أكمل اختبارات', 'en': 'Completed 1+ Quiz tests'},
    'stat_completed_pomodoro': {'ku': 'پۆمۆدۆرۆ تەواو کرد', 'badini': 'پۆمۆدۆرۆ تەمام کر', 'ar': 'أكمل جلسات بومودورو', 'en': 'Completed 1+ Pomodoros'},
    'stat_extracted_pdf': {'ku': 'تێبینی PDF دەرکرد', 'badini': 'تێبینییا PDF دەرخست', 'ar': 'استخرج ملاحظات PDF', 'en': 'Extracted 1+ PDF notes'},

    // Profile Screen
    'university_email': {'ku': 'ئیمەیلی زانکۆ', 'badini': 'ئیمەیڵێ زانکۆیێ', 'ar': 'البريد الإلكتروني الجامعي', 'en': 'University Email'},
    'university': {'ku': 'زانکۆ', 'badini': 'زانکۆ', 'ar': 'الجامعة', 'en': 'University'},
    'faculty_major': {'ku': 'فاکەڵتی و پسپۆڕی', 'badini': 'کۆلێژ و پسپۆڕی', 'ar': 'الكلية والتخصص', 'en': 'Faculty & Major'},
    'academic_stage': {'ku': 'قۆناغی ئەکادیمی', 'badini': 'قۆناغا ئەکادیمی', 'ar': 'المرحلة الأكاديمية', 'en': 'Academic Stage'},
    'campus_status': {'ku': 'بارودۆخی کامپس', 'badini': 'بارودۆخێ ل کامپسی', 'ar': 'الحالة في الحرم الجامعي', 'en': 'Campus Status'},
    'select_app_language': {'ku': 'زمانی ئەپڵیکەیشن دیاری بکە', 'badini': 'زمانێ ئەپلیکەیشنێ هەلبژێرە', 'ar': 'اختر لغة التطبيق', 'en': 'Select App Language'},
    'digital_id': {'ku': 'ناسنامەی دیجیتاڵ', 'badini': 'ناسنامەیا دیجیتاڵی', 'ar': 'الهوية الرقمية', 'en': 'DIGITAL ID'},
    'tap_for_campus_qr': {'ku': 'دەست بدە بۆ کۆدی QR', 'badini': 'کلیت بکە بۆ کۆدێ QR یێ زانکۆیێ', 'ar': 'اضغط لرمز QR الجامعي', 'en': 'Tap for Campus QR & Details'},
    'valid_until': {'ku': 'VALID 2024 - 2026', 'badini': 'VALID 2024 - 2026', 'ar': 'VALID 2024 - 2026', 'en': 'VALID 2024 - 2026'},
    'done': {'ku': 'تەواو', 'badini': 'تەمام', 'ar': 'تم', 'en': 'Done'},

    // Onboarding Screen
    'onboarding_welcome': {'ku': 'بەخێربێن بۆ ZankoAI', 'badini': 'بەخێر بێی بۆ ZankoAI', 'ar': 'مرحباً بك في ZankoAI', 'en': 'Welcome to ZankoAI'},
    'onboarding_subtitle': {'ku': 'هاوکارت بۆ خوێندن بە هێزی AI', 'badini': 'هاریکارێ تە بۆ خوێندنێ ب هێزا AI', 'ar': 'مساعدك الذكي للدراسة الجامعية', 'en': 'Your all-in-one AI-powered study companion designed for university students.'},
    'onboarding_summarize': {'ku': 'کورتکردنەوەی وانەکانت', 'badini': 'کورتکرنا وانێن تە', 'ar': 'لخّص موادك الدراسية', 'en': 'Summarize Your Courses'},
    'onboarding_plan': {'ku': 'ئامادەکردنی پلانی خوێندن', 'badini': 'چێکرنا پلانا خوێندنێ', 'ar': 'خطط لأسبوعك الدراسي', 'en': 'Plan Your Study Week'},
    'onboarding_plan_sub': {'ku': 'AI پلانی ڕۆژانەی تایبەتی بۆ تاقیکردنەوەکانت ئامادە دەکات.', 'badini': 'AI پلانەکا ڕۆژانە یا تایبەت بۆ تاقیکرنێن تە دارێژێت.', 'ar': 'الذكاء الاصطناعي يبني خطة دراسية مخصصة يوماً بيوم.', 'en': 'AI builds a personalized day-by-day study plan for your exams.'},
    'onboarding_test': {'ku': 'خۆت تاقی بکەرەوە', 'badini': 'خۆ تاقی بکە', 'ar': 'اختبر نفسك', 'en': 'Test Yourself'},
    'onboarding_test_sub': {'ku': 'کویز، کارتی فلاش، و پرسیاری تاقیکردنەوە بە AI دروستبکە.', 'badini': 'کویز، فلاشکارت و پرسیارێن تاقیکرنێ ب AI چێبکە.', 'ar': 'أنشئ اختبارات وبطاقات تعليمية وأسئلة متوقعة بالذكاء الاصطناعي.', 'en': 'Generate quizzes, flashcards, and predicted exam questions with AI.'},
    'onboarding_ready': {'ku': 'ئامادەی دەستپێکردن؟', 'badini': 'ئامادەی بۆ دەستپێکرنێ؟', 'ar': 'مستعد للبدء؟', 'en': 'Ready to Start?'},
    'onboarding_ready_sub': {'ku': 'کلیلێ Gemini API لە ئەکاونتی Google AI Studio دابگرە.', 'badini': 'کلیلا Gemini API ژ لاپەڕێ سەرەکی داخڵ بکە.', 'ar': 'أدخل مفتاح Gemini API من الصفحة الرئيسية لفتح ميزات الذكاء الاصطناعي.', 'en': 'Set your Gemini API key from the home screen to unlock all AI features.'},

    // Course Detail Screen
    'no_pdf_uploaded': {'ku': 'هیچ PDF ئەپلۆد نەکراوە', 'badini': 'چ فایلا PDF نەهاتیە ئەپلۆدکرن', 'ar': 'لم يتم رفع ملفات PDF', 'en': 'No PDF Lectures Uploaded'},
    'upload_pdf_desc': {'ku': 'سلایدەکانی وانەت یان تێبینییەکانت ئەپلۆد بکە بۆ چات بەکارهێنانی AI و دروستکردنی کورتە.', 'badini': 'سلایدێن وانێ یان تێبینیێن خۆ ئەپلۆد بکە بۆ چاتکرنێ ب AI و چێکرنا کورتیا وان.', 'ar': 'ارفع شرائح المحاضرة أو ملاحظاتك للدردشة مع AI وإنشاء الملخصات.', 'en': 'Upload your lecture slides or notes to chat with AI and generate summaries.'},
    'chat_with_ai': {'ku': 'چاتی AI', 'badini': 'چاتکرن ب AI', 'ar': 'محادثة AI', 'en': 'Chat with AI'},
    'ai_summary': {'ku': 'کورتەی AI', 'badini': 'کورتیا AI', 'ar': 'ملخص AI', 'en': 'AI Summary'},
    'lecture_title_hint': {'ku': 'نموونە: تێبینییەکانی بابی 3', 'badini': 'نموونە: تێبینیێن بەشێ 3', 'ar': 'مثال: ملاحظات الفصل 3', 'en': 'Enter Lecture Title (e.g. Chapter 3 Notes)'},
    'yesterday': {'ku': 'دوێنێ', 'badini': 'دوحی', 'ar': 'أمس', 'en': 'Yesterday'},
    'just_now': {'ku': 'ئێستا', 'badini': 'نوکە', 'ar': 'الآن', 'en': 'Just now'},

    // Home Screen
    'todays_progress': {'ku': 'پێشکەوتنی ئەمڕۆ', 'badini': 'پێشکەوتنا ئەڤڕۆ', 'ar': 'تقدم اليوم', 'en': "Today's Progress"},
    'todays_breakdown': {'ku': 'وردەکاری فێربوونی ئەمڕۆ', 'badini': 'وردەکاریێن فێربوونا ئەڤڕۆ', 'ar': 'تفاصيل تعلم اليوم', 'en': "Today's Learning Breakdown"},
    'recommended_for_you': {'ku': 'پێشنیارکراو بۆ تۆ', 'badini': 'پێشنیارکری بۆ تە', 'ar': 'موصى به لك', 'en': 'Recommended for You'},
    'student_role': {'ku': 'قوتابی', 'badini': 'قوتابی', 'ar': 'طالب', 'en': 'Student'},
    'goal_2_hours': {'ku': 'ئامانج: ٢ کاتژمێر', 'badini': 'ئارمانج: ٢ دەژمێر', 'ar': 'الهدف: ساعتان', 'en': 'Goal: 2 hours'},
    'goal_30': {'ku': 'ئامانج: ٣٠', 'badini': 'ئارمانج: ٣٠', 'ar': 'الهدف: 30', 'en': 'Goal: 30'},
    'top_5_percent': {'ku': 'تاپ ٥٪ی پۆل', 'badini': 'سەرەکیا ٥٪ یا پۆلێ', 'ar': 'أعلى 5% من الصف', 'en': 'Top 5% of class'},

    // PDF / Summary Screen
    'no_text_extracted': {'ku': 'هیچ دەقێک دەرنەکرا.', 'badini': 'چ دەق نەهاتە دەرخستن.', 'ar': 'لم يتم استخراج نص.', 'en': 'No text could be extracted.'},
    'document': {'ku': 'بەڵگەنامە', 'badini': 'بەڵگەنامە', 'ar': 'مستند', 'en': 'Document'},

    // QR Share Sheet
    'invalid_qr_format': {'ku': 'فۆرماتی کۆدی QR نادروستە.', 'badini': 'فۆرماتێ کۆدێ QR نەدروستە.', 'ar': 'تنسيق رمز QR غير صالح.', 'en': 'Invalid QR code format for ZankoAI.'},
    'qr_data_too_large': {'ku': 'داتای کارتەکان زۆر گەورەیە بۆ QR.', 'badini': 'داتا کورتە کارت گەلەک مەزنە بۆ QR.', 'ar': 'بيانات البطاقات كبيرة جدًا لرمز QR.', 'en': 'Flashcard data too large for QR.'},

    // Teacher screens
    'general_topics': {'ku': 'بابەتە گشتییەکان', 'badini': 'بابەتێن گشتی', 'ar': 'مواضيع عامة', 'en': 'General Topics'},

    // failed_to_generate
    'failed_to_generate': {'ku': 'شکستی هێنا لە دروستکردن', 'badini': 'نەشیا چێبکەت', 'ar': 'فشل في الإنشاء', 'en': 'Failed to generate'},

    // Study planner
    'study_planner_title': {'ku': 'پلانی خوێندنم', 'badini': 'پلانا خوێندنا من', 'ar': 'خطة دراستي', 'en': 'My Study Plan'},

    // GPA tracker hints
    'gpa_hint_375': {'ku': 'نموونە: ٣.٧٥', 'badini': 'نموونە: ٣.٧٥', 'ar': 'مثال: 3.75', 'en': 'e.g. 3.75'},
    'gpa_hint_38': {'ku': 'نموونە: ٣.٨', 'badini': 'نموونە: ٣.٨', 'ar': 'مثال: 3.8', 'en': 'e.g. 3.8'},
    'gpa_hint_3': {'ku': 'نموونە: ٣', 'badini': 'نموونە: ٣', 'ar': 'مثال: 3', 'en': 'e.g. 3'},
    'schedule_time_hint': {'ku': 'نموونە: ١٠:١٥ - ١١:٤٥', 'badini': 'نموونە: ١٠:١٥ - ١١:٤٥', 'ar': 'مثال: 10:15 - 11:45', 'en': 'e.g. 10:15 - 11:45'},

    // Flashcards screen
    'flashcards_title': {'ku': 'فلاشکاردی خوێندنەوە', 'badini': 'فلاشکارتێن خواندنێ', 'ar': 'بطاقات المراجعة الذكية', 'en': 'AI Study Flashcards'},
    'flashcards_input_label': {'ku': 'بابەتێک بنووسە یان دەقێک لێرە دابنێ', 'badini': 'بابەتەکێ بنڤێسە یان دەقەکێ لێرە دانە', 'ar': 'اكتب الموضوع أو انسخ النص', 'en': 'Enter topic or copy text'},
    'flashcards_generate_btn': {'ku': 'دروستکردنی فلاشکارد', 'badini': 'چێکرنا فلاشکارتان', 'ar': 'إنشاء البطاقات', 'en': 'Generate Flashcards'},
    'flashcards_empty_state': {'ku': 'تا ئێستا هیچ فلاشکاردێک دروست نەکراوە.', 'badini': 'تا نوکە چ فلاشکارت نەهاتینە چێکرن.', 'ar': 'لا توجد بطاقات مراجعة منشأة حالياً.', 'en': 'No flashcards generated yet.'},
    'flashcards_tap_to_flip': {'ku': 'کلیک بکە بۆ گۆڕینی لای کارتەکە', 'badini': 'کلیت بکە بۆ چەقاندنا کارتێ', 'ar': 'اضغط لقلب البطاقة', 'en': 'Tap to Flip card'},

    // Exam Predictor
    'exam_predictor_title': {'ku': 'پێشبینیکەری تاقیکردنەوە', 'badini': 'پێشبینیکەرێ تاقیکرنێ', 'ar': 'مستشار الامتحان الذكي', 'en': 'Exam Predictor'},
    'exam_predictor_input_label': {'ku': 'تێبینییەکانی خوێندن یان دەقی بابەتەکە لێرە دابنێ', 'badini': 'تێبینیێن خوێندنێ یان دەقێ بابەتی لێرە دانە', 'ar': 'الصق ملاحظات الدراسة أو محتوى الدرس', 'en': 'Paste your study notes or lesson contents'},
    'exam_predictor_or_label': {'ku': 'یاخود', 'badini': 'یان ژی', 'ar': 'أو', 'en': 'OR'},
    'exam_predictor_upload_btn': {'ku': 'بارکردنی فایلی دەقی (Text/Markdown)', 'badini': 'بارکرنا فایلا دەقی (Text/Markdown)', 'ar': 'تحميل ملف نصي (Text/Markdown)', 'en': 'Upload Text/Markdown File'},
    'exam_predictor_predict_btn': {'ku': 'پێشبینیکردنی پرسیارەکان', 'badini': 'پێشبینیکرنا پرسیاران', 'ar': 'توقع أسئلة الامتحان', 'en': 'Predict Exam Questions'},
    'exam_predictor_result_label': {'ku': 'پرسیارە پێشبینیکراوەکان و ڕێنماییەکان', 'badini': 'پرسیارێن پێشبینیکری و ڕێنمایی', 'ar': 'الأسئلة المتوقعة والنصائح', 'en': 'Predicted Questions & Tips'},
    'exam_predictor_loading': {'ku': 'ژیری دەستکرد خەریکی شیکردنەوەی تێبینییەکان و پێشبینیکردنی پرسیارەکانە...', 'badini': 'ژیرییا دەستکرد مژویلی شیکارکرنا تێبینیان و پێشبینیکرنا پرسیارانە...', 'ar': 'يقوم الذكاء الاصطناعي بتحليل الملاحظات وتوقع الأسئلة...', 'en': 'AI is analyzing your notes & predicting questions...'},
    'exam_predictor_info': {'ku': 'تێبینییەکانی وانەکەت یان دەستپێکی بەشەکە بنووسە بۆ ئەوەی ژیری دەستکرد پێشبینی ئەو پرسیارانە بکات کە ئەگەری زۆرە لە تاقیکردنەوەدا بێنەوە.', 'badini': 'تێبینیێن وانەیا خۆ بنڤێسە دا ژیرییا دەستکرد پرسیارێن تاقیکرنێ پێشبینی بکەت.', 'ar': 'أدخل ملاحظات المحاضرة أو المنهج ليقوم الذكاء الاصطناعي بتوقع الأسئلة المتوقعة في الامتحان.', 'en': 'Enter your lectures notes, syllabus, or content to let Gemini AI predict what is likely to show up in your exam.'},
    'exam_predictor_hint': {'ku': 'لێرە بنووسە یان کۆپی بکە...', 'badini': 'لێرە بنڤێسە یان کۆپی بکە...', 'ar': 'اكتب أو الصق هنا...', 'en': 'Type or paste here...'},

    // Mind Map
    'mind_map_title': {'ku': 'نەخشەی مێشکی زیرەک', 'badini': 'نەخشەیا مێشکی یا زیرەک', 'ar': 'خريطة المفاهيم الذكية', 'en': 'AI Mind Map'},
    'mind_map_placeholder': {'ku': 'بابەتێک بنووسە (بۆ نموونە: بیرۆکەی کۆمپیوتەر)', 'badini': 'بابەتەکێ بنڤێسە (نموونە: بیرۆکا کۆمپیوتەری)', 'ar': 'أدخل موضوع الخريطة (مثال: إدارة الذاكرة)', 'en': 'Enter topic (e.g. Memory Management)'},
    'mind_map_empty': {'ku': 'نەخشەیەکی بینراو دروست بکە بۆ تێگەیشتن لە چەمکەکان.', 'badini': 'نەخشەیەکا دیتنێ چێبکە بۆ تێگەهشتنا چەمکان.', 'ar': 'أنشئ خريطة بصرية لربط موضوعات دراستك.', 'en': 'Generate a visual map to connect study topics.'},
    'mind_map_no_desc': {'ku': 'هیچ ڕوونکردنەوەیەک نییە.', 'badini': 'چ ڕوونکردن نینە.', 'ar': 'لا يوجد وصف.', 'en': 'No description available.'},

    // Audio to Text (گۆڕینی دەنگ بۆ نووسین)
    'audio_summarizer_title': {'ku': 'گۆڕینی دەنگ بۆ نووسین', 'badini': 'گوهۆڕینا دەنگی بۆ دەقی', 'ar': 'تحويل الصوت إلى نص', 'en': 'Audio to Text'},
    'audio_summarizer_info': {'ku': 'دەنگەکەت تۆمار بکە یان فایلێکی دەنگی باربکە تاوەکو ڕاستەوخۆ دەنگەکە بکرێتە دەق و نووسین.', 'badini': 'دەنگێ خۆ تۆماربکە یان فایلەکێ دەنگی باربکە دا ب بیتە دەق.', 'ar': 'سجل صوتك أو ارفع ملفاً صوتياً لتحويله مباشرة إلى نص مكتوب.', 'en': 'Record your voice or upload an audio file to convert it directly to text.'},
    'audio_summarizer_upload_btn': {'ku': 'بارکردنی فایلی دەنگی', 'badini': 'بارکرنا فایلا دەنگی', 'ar': 'تحميل ملف صوتي', 'en': 'Upload Audio File'},
    'audio_summarizer_result_label': {'ku': 'دەقی وەرگێڕدراوی دەنگەکە', 'badini': 'دەقێ دەنگی', 'ar': 'النص المفرغ من الصوت', 'en': 'Transcribed Text'},
    'audio_summarizer_loading': {'ku': 'خەریکی گۆڕینی دەنگەکەیە بۆ نووسین...', 'badini': 'خەریکی گوهۆڕینا دەنگی یە بۆ دەقی...', 'ar': 'جاري تحويل الصوت إلى نص مكتوب...', 'en': 'Converting audio to text...'},
    'audio_summarizer_tap_record': {'ku': 'کلیک بکە بۆ دەستپێکردنی تۆمارکردن', 'badini': 'کلیت بکە بۆ دەستپێکرنا تۆمارکرنێ', 'ar': 'اضغط لبدء التسجيل', 'en': 'Tap to start recording'},

    // Stats Screen
    'stats_title': {'ku': 'ئاماری خوێندن و دەستکەوتەکانم', 'badini': 'ئامارێن خوێندنێ و دەستکەفتێن من', 'ar': 'إحصائيات الدراسة والإنجازات', 'en': 'Study Statistics & Achievements'},
    'stats_weekly_activity': {'ku': 'چالاکییەکانی خوێندنم', 'badini': 'چالاکیێن خوێندنێ', 'ar': 'النشاط الأسبوعي', 'en': 'Weekly Activity'},
    'stats_badges': {'ku': 'میدالیا و دەستکەوتەکانم', 'badini': 'میدالیا و دەستکەفتێن من', 'ar': 'الشارات والميداليات المستحقة', 'en': 'Earned Badges'},
    'stats_pomodoros': {'ku': 'خولەکانی تەرکیز', 'badini': 'خولێن تەرکیزێ', 'ar': 'جلسات بومودورو', 'en': 'Pomodoros'},
    'stats_quizzes_done': {'ku': 'کویزە تەواوکراوەکان', 'badini': 'کویزێن تەمامکری', 'ar': 'الاختبارات المنجزة', 'en': 'Quizzes Done'},
    'stats_cards_flipped': {'ku': 'فلاشکاردەکان', 'badini': 'فلاشکارت', 'ar': 'البطاقات المراجعة', 'en': 'Cards Flipped'},
    'stats_notes_kept': {'ku': 'تێبینییە ڕێکخراوەکان', 'badini': 'تێبینیێن ڕێکخستی', 'ar': 'الملاحظات المحفوظة', 'en': 'Notes Kept'},

    // GPA Tracker
    'gpa_title': {'ku': 'خەمڵاندنی نمرە و نەخشەی GPA', 'badini': 'حسابکرنا نمرەیان و نەخشەیا GPA', 'ar': 'حساب المعدل ومخطط التقدم', 'en': 'GPA Calculator & Progress Chart'},
    'gpa_total': {'ku': 'کۆنمرەی گشتی (GPA)', 'badini': 'کۆنمرەیا گشتی (GPA)', 'ar': 'المعدل التراكمي العام', 'en': 'Total Cumulative GPA'},
    'gpa_chart_header': {'ku': 'نەخشەی پێشکەوتنی وەرزەکان', 'badini': 'نەخشەیا پێشکەوتنا وەرزی', 'ar': 'مخطط تقدم الفصول الدراسية', 'en': 'Semester Progress Chart'},
    'gpa_add_label': {'ku': 'نمرەی وەرزێکی نوێ زیاد بکە (0.0 - 4.0)', 'badini': 'نمرەیا وەرزەکێ نوو زێدە بکە (0.0 - 4.0)', 'ar': 'أضف معدل فصل دراسي (0.0 - 4.0)', 'en': 'Add Semester GPA (0.0 - 4.0)'},
    'gpa_add_btn': {'ku': 'زیادکردن', 'badini': 'زێدەکرن', 'ar': 'إضافة', 'en': 'Add'},
    'gpa_list_header': {'ku': 'سجلی نمرەکانی پێشوو', 'badini': 'سجلێ نمرەیێن بەرێ', 'ar': 'سجل الفصول الدراسية', 'en': 'Semester History'},
    'gpa_semester_label': {'ku': 'وەرز', 'badini': 'وەرز', 'ar': 'فصل دراسي', 'en': 'Semester'},

    // Study Planner
    'study_planner_card_title': {'ku': 'پلانێکی نوێ داڕێژە', 'badini': 'پلانەکا نوو دارێژە', 'ar': 'إنشاء جدول دراسة جديد', 'en': 'Create Study Schedule'},
    'study_planner_topic_label': {'ku': 'ناوی بابەت یان تاقیکردنەوە', 'badini': 'ناڤێ بابەتی یان تاقیکرنێ', 'ar': 'المادة أو موضوع الامتحان', 'en': 'Course / Exam Topic'},
    'study_planner_days_label': {'ku': 'ڕۆژەکانی ماوە بۆ تاقیکردنەوە', 'badini': 'ڕۆژێن مایین بۆ تاقیکرنێ', 'ar': 'الأيام المتبقية', 'en': 'Days Remaining'},
    'study_planner_generate_btn': {'ku': 'پلانی خوێندن داڕێژە', 'badini': 'پلانا خوێندنێ چێبکە', 'ar': 'توليد خطة الدراسة', 'en': 'Generate Study Plan'},
    'study_planner_empty': {'ku': 'پلانەکەت لێرەدا نیشان دەدرێت.', 'badini': 'پلانا تە دێ لێرە دیار بیت.', 'ar': 'ستظهر خطتك الدراسية المقترحة هنا.', 'en': 'Your generated study schedule will appear here.'},

    // Reminders
    'reminders_title': {'ku': 'ئەرک و یاددەهێنەرەکانم', 'badini': 'ئەرک و بیرئینانێن من', 'ar': 'المهام والتذكيرات الدراسية', 'en': 'Task & Homework Reminders'},
    'reminders_active': {'ku': 'ئەرکە چالاکەکان', 'badini': 'ئەرکێن چالاک', 'ar': 'المهام النشطة', 'en': 'Active Tasks'},
    'reminders_completed': {'ku': 'تەواوکراوەکان', 'badini': 'تەمامکری', 'ar': 'المهام المكتملة', 'en': 'Completed'},
    'reminders_no_tasks': {'ku': 'هیچ یاددەهێنەرێکی چالاک نییە.', 'badini': 'چ بیرئینانێن چالاک نینن.', 'ar': 'لا توجد تذكيرات نشطة حالياً.', 'en': 'No active reminders.'},
    'reminders_add_title': {'ku': 'یاددەهێنەر یان ئەرکی نوێ زیاد بکە', 'badini': 'بیرئینان یان ئەرکەکێ نوو زێدە بکە', 'ar': 'إضافة مهمة أو تذكير جديد', 'en': 'Add New Task or Reminder'},
    'reminders_passed': {'ku': 'وادەکەی بەسەرچوو', 'badini': 'دەمێ وێ بەسەرچوو', 'ar': 'انتهى الوقت', 'en': 'Passed / Completed'},
    'reminders_time_left': {'ku': 'ماوە بۆ جێبەجێکردن: {days} ڕۆژ، {hours} سەعات', 'badini': 'مایی بۆ جێبەجێکرنێ: {days} ڕۆژ، {hours} دەژمێر', 'ar': 'المتبقي: {days} يوم، {hours} ساعة', 'en': 'Time left: {days} days, {hours} hrs'},
    'reminders_no_deadline': {'ku': 'هیچ وادەیەک دیاری نەکراوە', 'badini': 'چ وادە دیاری نەکریە', 'ar': 'لم يتم تحديد موعد', 'en': 'No deadline set'},
    'close': {'ku': 'داخستن', 'badini': 'داخستن', 'ar': 'إغلاق', 'en': 'Close'},

    // Schedule
    'schedule_lectures_count': {'ku': 'وانە', 'badini': 'وانە', 'ar': 'محاضرات', 'en': 'lectures'},

    // General snackbar / dialog translations
    'snackbar_enter_topic': {'ku': 'تکایە بابەتێک بنووسە.', 'badini': 'تکایە بابەتەکێ بنڤێسە.', 'ar': 'يرجى كتابة موضوع.', 'en': 'Please enter a topic.'},
    'snackbar_fill_all_fields': {'ku': 'تکایە هەموو خانەکان پڕبکەرەوە.', 'badini': 'تکایە هەموو خانەیان پربکە.', 'ar': 'يرجى ملء جميع الحقول.', 'en': 'Please fill in all fields.'},
    'snackbar_enter_subject': {'ku': 'تکایە ناوی بابەتەکە بنووسە.', 'badini': 'تکایە ناڤێ بابەتی بنڤێسە.', 'ar': 'يرجى كتابة اسم الموضوع.', 'en': 'Please enter the subject name.'},

    // AI Teacher
    'ai_teacher_voice_active': {'ku': 'خوێندنەوەی دەنگی چالاکە 🔊', 'badini': 'خوێندنا دەنگی چالاکە 🔊', 'ar': 'القراءة الصوتية نشطة 🔊', 'en': 'Voice Reading Active 🔊'},
    'ai_teacher_voice_stop': {'ku': 'وەستان / Stop', 'badini': 'ڕاوەستان / Stop', 'ar': 'إيقاف / Stop', 'en': 'Stop / إيقاف'},
    'ai_teacher_read_aloud': {'ku': 'Read Aloud', 'badini': 'Read Aloud', 'ar': 'القراءة بصوت عال', 'en': 'Read Aloud'},

    // Onboarding - additional keys
    'onboarding_summarize_sub': {'ku': 'PDF باربکە یان دەق بنووسە — دەستبەجێ کورتکراوە و وەرگێڕان وەربگرە.', 'badini': 'فایلا PDF باربکە یان دەق بنڤێسە — دەستبەجێ کورتکراوە و وەرگێڕانێ وەربگرە.', 'ar': 'ارفع ملفات PDF أو الصق النص للحصول على ملخصات فورية.', 'en': 'Upload PDFs or paste text — get instant AI summaries and translations.'},
    'onboarding_skip': {'ku': 'تێپەڕکردن', 'badini': 'دەربازکرن', 'ar': 'تخطي', 'en': 'Skip'},
    'onboarding_next': {'ku': 'دواتر →', 'badini': 'پاشتر →', 'ar': 'التالي →', 'en': 'Next →'},
    'onboarding_lets_go': {'ku': 'با بچینە ناو! 🚀', 'badini': 'دەی با دەستپێبکەین! 🚀', 'ar': 'هيا نبدأ! 🚀', 'en': "Let's Go! 🚀"},

    // Shared buttons
    'add': {'ku': 'زیادکردن', 'badini': 'زێدەکرن', 'ar': 'إضافة', 'en': 'Add'},

    // QR Share
    'qr_share_title': {'ku': 'هاوبەشکردنی فلاشکاردەکان', 'badini': 'بهەڤبارکرنا فلاشکارتان', 'ar': 'مشاركة مجموعة الكروت', 'en': 'Share Deck'},
    'qr_share_desc': {'ku': 'با هاوڕێکەت ئەم کۆدی QRە سکان بکات بۆ ئەوەی فلاشکاردەکانت وەربگرێت!', 'badini': 'با هەڤالێ تە ئەڤی کۆدێ QR سکان بکەت دا کو فلاشکارتێن تە وەربگریت!', 'ar': 'دع صديقك يمسح هذا الكود لاستيراد الكروت فوراً!', 'en': 'Let your friend scan this QR code to import this deck instantly!'},
    'qr_scan_instructions': {'ku': 'کۆدی QR لە ناو چوارگۆشەکە دابنێ', 'badini': 'کۆدێ QR ل ناو چوارگۆشەیێ دانە', 'ar': 'ضع رمز QR داخل المربع للمسح', 'en': 'Align QR code inside the box to scan'},
    'calculate': {'ku': 'هەژمارکردن', 'badini': 'ژمارتن', 'ar': 'حساب', 'en': 'Calculate'},
    'target_planner_title': {'ku': 'دیاریکردنی ئامانجی کۆنمرە', 'badini': 'دیاریکرنا ئارمانجا کۆنمرەیێ', 'ar': 'مخطط المعدل المستهدف', 'en': 'Target GPA Planner'},
    'planner_input_error': {'ku': 'تکایە خانەکان بە دروستی پڕبکەرەوە.', 'badini': 'تکایە خانەیان ب دروستی پربکە.', 'ar': 'يرجى ملء الحقول بشكل صحيح.', 'en': 'Please fill in the fields correctly.'},
    'planner_cannot_reach': {'ku': '⚠️ بەم ژمارە وەرزە ناگەیتە ئامانجەکەت! پێویستت بە GPA {required} هەیە لە هەر وەرزێکدا', 'badini': '⚠️ ب ئەڤی ژمارەیا وەرزان ناگەهیە ئارمانجا خۆ! پێویستی ب GPA {required} هەی ل هەر وەرزەکێ', 'ar': '⚠️ لا يمكنك الوصول للهدف بهذا العدد من الفصول! تحتاج GPA {required} في كل فصل', 'en': '⚠️ You cannot reach your target in this many semesters! You need GPA {required} each semester'},
    'planner_already_met': {'ku': '🎉 ئامانجەکەت مسۆگەرە!', 'badini': '🎉 ئارمانجا تەمسۆگەرە!', 'ar': '🎉 هدفك مضمون بالفعل!', 'en': '🎉 Your target is already guaranteed!'},
    'planner_required': {'ku': '🎯 پێویستە تێکڕای نمرەی وەرزی داهاتووت لە {required} کەمتر نەبێت', 'badini': '🎯 پێویستە تێکڕایا نمرەیا وەرزی پێشبینیکری کێمتری {required} نەبیت', 'ar': '🎯 يجب ألا يقل معدلك في الفصول القادمة عن {required}', 'en': '🎯 You need at least GPA {required} in remaining semesters'},

    // QR / Deck import-export
    'deck_imported': {'ku': 'فلاشکاردەکان بە سەرکەوتوویی هاوردە کران! ✅', 'badini': 'فلاشکارت ب سەرکەفتن هاتنە هاوردەکرن! ✅', 'ar': 'تم استيراد البطاقات بنجاح! ✅', 'en': 'Deck imported successfully! ✅'},

    // Profile / University ID card (extra detail rows)
    'cumulative_gpa': {'ku': 'کۆنمرەی گشتی (GPA)', 'badini': 'کۆنمرەیا گشتی (GPA)', 'ar': 'المعدل التراكمي', 'en': 'Cumulative GPA'},
    'credits_completed': {'ku': 'کرێدیتی تەواوکراو', 'badini': 'کاتێن تەواوکری', 'ar': 'الساعات المعتمدة المكتملة', 'en': 'Credits Completed'},
    'academic_advisor': {'ku': 'مامۆستای ئەکادیمی', 'badini': 'مامۆستایێ ئەکادیمی', 'ar': 'المرشد الأكاديمي', 'en': 'Academic Advisor'},

    // Teacher Dashboard & Features
    'teacher_analytics_title': {'ku': 'ئامارەکانی قوتابیان', 'badini': 'ئامارێن قوتابیان', 'ar': 'تحليلات الطلاب', 'en': 'Student Analytics'},
    'teacher_lectures_title': {'ku': 'بارکردنی وانەکان', 'badini': 'بارکرنا وانان', 'ar': 'رفع المحاضرات', 'en': 'Upload Lectures'},
    'teacher_announcements_title': {'ku': 'ئاگادارییەکان', 'badini': 'ئاگاداری', 'ar': 'الإعلانات', 'en': 'Announcements'},
    'teacher_quizzes_exams_title': {'ku': 'کویز و تاقیکردنەوەکان', 'badini': 'کویز و تاقیکرن', 'ar': 'الاختبارات والامتحانات', 'en': 'Quizzes & Exams'},
    'upload_lecture': {'ku': 'بارکردنی وانەی نوێ', 'badini': 'بارکرنا وانەکا نوو', 'ar': 'رفع محاضرة جديدة', 'en': 'Upload New Lecture'},
    'lecture_title': {'ku': 'ناوی وانە', 'badini': 'ناڤێ وانێ', 'ar': 'عنوان المحاضرة', 'en': 'Lecture Title'},
    'lecture_type': {'ku': 'جۆری وانە', 'badini': 'جۆرێ وانێ', 'ar': 'نوع المحاضرة', 'en': 'Lecture Type'},
    'pdf_format': {'ku': 'فایلی PDF', 'badini': 'فایلا PDF', 'ar': 'ملف PDF', 'en': 'PDF Document'},
    'ppt_format': {'ku': 'پڕیزێنتەیشن PPT', 'badini': 'عرض تەقدیمی PPT', 'ar': 'عرض تقديمي PPT', 'en': 'PPT Presentation'},
    'video_format': {'ku': 'ڤیدیۆ', 'badini': 'ڤیدیۆ', 'ar': 'فيديو', 'en': 'Video Lesson'},
    'file_url_or_name': {'ku': 'لینک یان ناوی فایل', 'badini': 'لینک یان ناڤێ فایلێ', 'ar': 'رابط أو اسم الملف', 'en': 'File Link / Path'},
    'send_announcement': {'ku': 'ناردنی ئاگاداری', 'badini': 'شاندنا ئاگاداریێ', 'ar': 'إرسال إعلان', 'en': 'Send Announcement'},
    'announcement_title': {'ku': 'سەردێڕی ئاگاداری', 'badini': 'سەردێڕێ ئاگاداریێ', 'ar': 'عنوان الإعلان', 'en': 'Announcement Title'},
    'announcement_content': {'ku': 'ناوەڕۆکی ئاگاداری', 'badini': 'ناوەڕۆکا ئاگاداریێ', 'ar': 'محتوى الإعلان', 'en': 'Announcement Content'},
    'priority_normal': {'ku': 'ئاسایی', 'badini': 'ئاسایی', 'ar': 'عادي', 'en': 'Normal'},
    'priority_important': {'ku': 'گرنگ', 'badini': 'گرنگ', 'ar': 'مهم', 'en': 'Important'},
    'priority_urgent': {'ku': 'بەپەلە', 'badini': 'بەپەلە', 'ar': 'عاجل', 'en': 'Urgent'},
    'create_exam': {'ku': 'دروستکردنی تاقیکردنەوە (Exam)', 'badini': 'چێکرنا تاقیکرنێ (Exam)', 'ar': 'إنشاء امتحان formal', 'en': 'Create Timed Exam'},
    'passing_score': {'ku': 'نمرەی دەرچوون (%)', 'badini': 'نمرەیا دەربازبوونێ (%)', 'ar': 'درجة النجاح (%)', 'en': 'Passing Score (%)'},
    'duration_minutes': {'ku': 'ماوە (بە خولەک)', 'badini': 'ماوە (ب خولەک)', 'ar': 'المدة (بالدقائق)', 'en': 'Duration (Minutes)'},
    'grade_distribution': {'ku': 'دابەشبوونی نمرەکان', 'badini': 'دابەشبوونا نمرەیان', 'ar': 'توزيع الدرجات', 'en': 'Grade Distribution'},
    'top_performers': {'ku': 'قوتابییە باڵاکان', 'badini': 'قوتابیێن سەرەکە', 'ar': 'الطلاب المتفوقين', 'en': 'Top Performers'},
    'at_risk_students': {'ku': 'قوتابییانی پێویست بە هاوکاری', 'badini': 'قوتابیێن پێویست ب هاریکاریێ', 'ar': 'الطلاب المحتاجين للمساعدة', 'en': 'At-Risk Students'},
    'send_feedback': {'ku': 'ناردنی فێدباک بۆ قوتابی', 'badini': 'شاندنا تێبینیان بۆ قوتابی', 'ar': 'إرسال ملاحظات للطالب', 'en': 'Send Student Feedback'},
    'student_analytics': {'ku': 'ئاماری گشتی قوتابیان', 'badini': 'ئامارا گشتی یا قوتابیان', 'ar': 'تحليلات الطلاب العامة', 'en': 'Overall Student Analytics'},
    'teacher_stats_lectures': {'ku': 'وانە بارکراوەکان', 'badini': 'وانێن بارکری', 'ar': 'المحاضرات المرفوعة', 'en': 'Lectures Uploaded'},
    'teacher_stats_announcements': {'ku': 'ئاگادارییەکان', 'badini': 'ئاگاداری', 'ar': 'الإعلانات', 'en': 'Announcements'},

    // Profile & Settings
    'vip_banner_title_guest': {'ku': 'بەشداربوونی نایابی VIP', 'badini': 'پشکداریا نایاب یا VIP', 'ar': 'اشتراك VIP المميز', 'en': 'VIP Premium Membership'},
    'vip_banner_title_active': {'ku': 'ئەندامی نایابی VIP (چالاککراوە 👑)', 'badini': 'ئەندامێ نایاب یێ VIP (چالاککریە 👑)', 'ar': 'عضو VIP المميز (مفعّل 👑)', 'en': 'VIP Member (Active 👑)'},
    'vip_banner_desc_guest': {'ku': 'سێمینار و ڕاپۆرت بە وۆرد + پێشبینی تاقیکردنەوە', 'badini': 'سێمینار و ڕاپۆرت ب وۆرد + پێشبینیا تاقیکرنێ', 'ar': 'تصدير Word و PPTX + توقعات الامتحانات', 'en': 'Word & PPTX exports + Quiz predictions'},
    'vip_banner_desc_active': {'ku': 'داگرتنی Word و PPTX + تاقیکردنەوە و چاتی بێسنوور', 'badini': 'داگرتنا Word و PPTX + چاتێ بێ سنوور', 'ar': 'تحميل Word و PPTX + محادثات واختبارات غير محدودة', 'en': 'Word & PPTX downloads + Unlimited chat'},
    'vip_upgrade_btn': {'ku': 'بوون بە VIP ⚡', 'badini': 'بوون ب VIP ⚡', 'ar': 'ترقية VIP ⚡', 'en': 'Get VIP ⚡'},
    'vip_renew_btn': {'ku': 'نوێکردنەوە', 'badini': 'نویکرن', 'ar': 'تجديد', 'en': 'Renew'},
    'support_and_info': {'ku': 'پشتگیری و زانیاری', 'badini': 'پشتگیری و پێزانین', 'ar': 'الدعم والمعلومات', 'en': 'Support & Information'},
    'feedback_suggestions': {'ku': 'ڕا و پێشنیارەکان', 'badini': 'ڕا و پێشنیار', 'ar': 'الآراء والمقترحات', 'en': 'Feedback & Suggestions'},
    'feedback_subtitle': {'ku': 'ناردنی داواکاری و پێشنیار بۆ گەشەپێدەران', 'badini': 'هنارتنا داخازی و پێشنیاران بۆ گەشەپێدەران', 'ar': 'إرسال الطلبات والملاحظات للمطورين', 'en': 'Send requests & feedback to developers'},
    'account': {'ku': 'هەژمار', 'badini': 'هەژمار', 'ar': 'الحساب', 'en': 'Account'},
    'delete_account': {'ku': 'سڕینەوەی یەکجاریی هەژمار', 'badini': 'ژێبرنا ئێکجاری یا هەژمارێ', 'ar': 'حذف الحساب نهائياً', 'en': 'Delete Account'},
    'delete_account_desc': {'ku': 'سڕینەوەی هەموو داتاکان و هەژماری بەکارهێنەر', 'badini': 'ژێبرنا هەمی داتایان و هەژمارێ', 'ar': 'حذف جميع البيانات والحساب بشكل دائم', 'en': 'Permanently remove all data and account'},
    'delete_account_confirm_title': {'ku': 'سڕینەوەی هەژمار؟', 'badini': 'ژێبرنا هەژمارێ؟', 'ar': 'حذف الحساب؟', 'en': 'Delete Account?'},
    'delete_account_confirm_desc': {'ku': 'ئایا دڵنیایت لە سڕینەوەی یەکجاریی هەژمارەکەت؟ ئەم کارە هەموو داتاکانت دەسڕێتەوە و ناتوانرێت بگەڕێندرێتەوە.', 'badini': 'ئەرێ تو پشتڕاستی ژ ژێبرنا ئێکجاری یا هەژمارا خۆ؟ ئەڤ چەندە دێ هەمی داتایێن تە ژێبەت و ناهێنە ڤەگەڕاندن.', 'ar': 'هل أنت متأكد من رغبتك في حذف حسابك نهائياً؟ سيتم مسح جميع بياناتك ولا يمكن استرجاعها.', 'en': 'Are you sure you want to delete your account? All your data will be permanently erased.'},
    'yes_delete': {'ku': 'بەڵێ، بیسڕەوە', 'badini': 'بەلێ، بژێبە', 'ar': 'نعم، احذف', 'en': 'Yes, Delete'},
    'developed_by': {'ku': 'گەشەی پێدراوە لەلایەن تیمی birdev', 'badini': 'هاتیە گەشەپێدان ژ لایێ تیمی birdev', 'ar': 'تم التطوير بواسطة فريق birdev', 'en': 'Developed by birdev team'},
    'all_rights_reserved': {'ku': 'سەرجەم مافەکانی پارێزراوە', 'badini': 'هەمی ماف پاراستینە', 'ar': 'جميع الحقوق محفوظة', 'en': 'All rights reserved'},
    'feedback_dialog_desc': {'ku': 'پێشنیار یان ڕای خۆت بنووسە بۆ بەرزکردنەوەی کوالێتی ZankoAI', 'badini': 'پێشنیار یان ڕایا خۆ بنڤیسە بۆ بلندکرنا کوالێتیا ZankoAI', 'ar': 'اكتب اقتراحاتك أو ملاحظاتك لتحسين ZankoAI', 'en': 'Write your suggestions or feedback to improve ZankoAI'},
    'feedback_input_hint': {'ku': 'ڕا و پێشنیارەکەت بنووسە...', 'badini': 'ڕا و پێشنیارا خۆ بنڤیسە...', 'ar': 'اكتب ملاحظاتك واقتراحاتك هنا...', 'en': 'Write your feedback here...'},
    'feedback_input_empty': {'ku': 'تکایە پێشنیارەکەت بنووسە', 'badini': 'تکایە پێشنیارا خۆ بنڤیسە', 'ar': 'يرجى كتابة اقتراحك', 'en': 'Please enter your feedback'},
    'feedback_sent_success': {'ku': 'پێشنیارەکەت بە سەرکەوتووی گەیشتە تیمی birdev! ✅', 'badini': 'پێشنیارا تە ب سەرکەفتیانە گەهشتە تیمی birdev! ✅', 'ar': 'تم إرسال اقتراحك بنجاح إلى فريق birdev! ✅', 'en': 'Your feedback was sent successfully to birdev team! ✅'},
    'feedback_type_feature': {'ku': '✨ داواکاری تایبەتمەندی', 'badini': '✨ داخازیا تایبەتمەندیێ', 'ar': '✨ طلب ميزة', 'en': '✨ Feature Request'},
    'feedback_type_bug': {'ku': '🐞 کێشەی تەکنیکی', 'badini': '🐞 کێشەیا تەکنیکی', 'ar': '🐞 خطأ تقني', 'en': '🐞 Technical Issue'},
    'feedback_type_content': {'ku': '📚 ناوەڕۆکی زانکۆ', 'badini': '📚 ناڤەرۆکا زانکۆیێ', 'ar': '📚 محتوى جامعي', 'en': '📚 University Content'},
    'feedback_type_other': {'ku': '💬 ڕای گشتی', 'badini': '💬 ڕایا گشتی', 'ar': '💬 رأي عام', 'en': '💬 General Feedback'},
    'notification_settings': {'ku': 'ڕێکخستنی ئاگادارییەکان', 'badini': 'ڕێکخستنا ئاگادارییان', 'ar': 'إعدادات الإشعارات', 'en': 'Notification Settings'},
    'exam_alerts': {'ku': 'ئاگادارکردنەوەی تاقیکردنەوەکان', 'badini': 'ئاگادارکرنا تاقیکرنان', 'ar': 'تنبيهات الامتحانات', 'en': 'Exam Alerts'},
    'exam_alerts_desc': {'ku': 'ناردنی بیرخەرەوەی ژێرمێژووی تاقیکردنەوەی میدترم و فایناڵ', 'badini': 'هنارتنا بیرئینانێ بۆ تاقیکرنێن میدتێرم و فاینال', 'ar': 'تذكيرات بمواعيد امتحانات الميدترم والنهائي', 'en': 'Reminders for midterms and final exams'},
    'study_streak_reminder': {'ku': 'بیرخەرەوەی بەردەوامیی خوێندن', 'badini': 'بیرئینانا بەردەوامیا خوێندنێ', 'ar': 'تذكير استمرار المذاكرة', 'en': 'Study Streak Reminder'},
    'study_streak_desc': {'ku': 'ناردنی بیرخەرەوە بۆ پاراستنی زنجیرەی ڕۆژانەی دراسەکردن', 'badini': 'هنارتنا بیرئینانێ بۆ پاراستنا زنجیرا ڕۆژانە یا دراسەکرنێ', 'ar': 'تذكير يومي للحفاظ على سلسلة الدراسة اليومية', 'en': 'Daily reminders to maintain your study streak'},
    'campus_news': {'ku': 'هەواڵ و نوێکارییەکانی زانکۆ', 'badini': 'نووچە و نویکاریێن زانکۆیێ', 'ar': 'أخبار وتحديثات الجامعة', 'en': 'Campus & University News'},
    'campus_news_desc': {'ku': 'ئاگادارکردنەوە لە زانکۆلاین و هەواڵە گرنگەکان', 'badini': 'ئاگاداری ژ زانکۆلاین و نووچەیێن گرنگ', 'ar': 'تنبيهات حول زانكولاين والأخبار الهامة', 'en': 'Important announcements and updates'},
    'vip_alerts': {'ku': 'ئاگادارکردنەوەی بەشداربوونی VIP', 'badini': 'ئاگادارکرنا پشکداریا VIP', 'ar': 'تنبيهات اشتراك VIP', 'en': 'VIP Subscription Alerts'},
    'vip_alerts_desc': {'ku': 'بیرخەرەوەی ماوەی بەسەرچوونی هەژماری VIP', 'badini': 'بیرئینانا دەمێ ب سەرڤەچوونا هەژمارا VIP', 'ar': 'تذكير بقرب انتهاء صلاحية اشتراك VIP', 'en': 'Reminders before VIP subscription expires'},
    'notifications_saved': {'ku': 'ڕێکخستنەکانی ئاگاداری بە سەرکەوتوویی پاشەکەوت کران 🔔', 'badini': 'ڕێکخستنێن ئاگاداریێ ب سەرکەفتیانە هاتنە پاراستن 🔔', 'ar': 'تم حفظ إعدادات الإشعارات بنجاح 🔔', 'en': 'Notification settings saved successfully 🔔'},
    'clear_cache': {'ku': 'سڕینەوەی کاشی ئۆفلاین (Clear Cache)', 'badini': 'ژێبرنا کاشا ئۆفلاین', 'ar': 'مسح الذاكرة المؤقتة (Clear Cache)', 'en': 'Clear Offline Cache'},
    'clear_cache_desc': {'ku': 'سڕینەوەی فایلی کاتی و پاککردنەوەی فەزای مۆبایلەکەت', 'badini': 'ژێبرنا فایلێن دەمکی و بەتاڵکرنا جهێ مۆبایلێ', 'ar': 'حذف الملفات المؤقتة وتفريغ مساحة الجهاز', 'en': 'Remove temporary files and free up storage'},
    'cache_cleared_success': {'ku': 'کاشی ئۆفلاینی ئەپەکە بە سەرکەوتوویی پاککرایەوە 🧹', 'badini': 'کاشا ئۆفلاین یا ئەپێ ب سەرکەفتیانە هاتە پاقژکرن 🧹', 'ar': 'تم مسح الذاكرة المؤقتة للتطبيق بنجاح 🧹', 'en': 'App offline cache cleared successfully 🧹'},
    'understood': {'ku': 'پەسەندە و تێگەیشتم', 'badini': 'یا دروستە و تێگەهشتم', 'ar': 'موافق ومفهوم', 'en': 'Understood'},
    'check_updates': {'ku': 'پشکنین بۆ ئەپدەیت', 'badini': 'پشکنین بۆ نویکرنێ', 'ar': 'التحقق من التحديثات', 'en': 'Check for Updates'},
    'you_have_latest_version': {'ku': '🎉 تۆ نوێترین وەشانی ZankoAI بەکاردەهێنیت', 'badini': '🎉 تو نووترین وەشانا ZankoAI بکار دئینی', 'ar': '🎉 أنت تستخدم أحدث إصدار من ZankoAI', 'en': '🎉 You are using the latest version of ZankoAI'},
    'university_not_set': {'ku': 'زانکۆ دیاری نەکراوە', 'badini': 'زانکۆ نەهاتیە دیاریکرن', 'ar': 'لم يتم تحديد الجامعة', 'en': 'University Not Set'},
    'edit_profile_desc': {'ku': 'ناوی تەواو، زانکۆ، بەش و شاری نیشتەجێبوون نوێ بکەرەوە', 'badini': 'ناڤێ تەمام، زانکۆ، پشک و باژێرێ خۆ نووبکە', 'ar': 'تحديث الاسم الكامل، الجامعة، القسم والمدينة', 'en': 'Update your name, university, department and city'},
    'please_enter_full_name': {'ku': 'تکایە ناوی تەواو بنووسە', 'badini': 'تکایە ناڤێ تەمام بنڤیسە', 'ar': 'يرجى إدخال الاسم الكامل', 'en': 'Please enter your full name'},
    'profile_updated_success': {'ku': '✅ زانیارییەکان بە سەرکەوتوویی نوێکرانەوە!', 'badini': '✅ پێزانین ب سەرکەفتیانە هاتنە نویکرن!', 'ar': '✅ تم تحديث المعلومات بنجاح!', 'en': '✅ Profile updated successfully!'},
    'save_profile_data': {'ku': '💾 پاشەکەوتکردنی زانیاری', 'badini': '💾 پاراستنا پێزانینان', 'ar': '💾 حفظ البيانات', 'en': '💾 Save Profile Information'},
    'change_profile_photo': {'ku': 'گۆڕینی وێنەی پڕۆفایل', 'badini': 'گوهۆڕینا وێنەیێ پرۆفایلی', 'ar': 'تغيير صورة الملف الشخصي', 'en': 'Change Profile Picture'},
    'choose_avatar_or_url': {'ku': 'وێنەیەک لە ئاڤاتارەکان هەڵبژێرە یان لینکی وێنەکەت بنووسە', 'badini': 'وێنەکێ ژ ئاڤاتاران هەلبژێرە یان وێنێ خۆ دانە', 'ar': 'اختر صورة رمزية أو أدخل رابط صورتك', 'en': 'Choose an avatar or enter an image link'},
    'phone_gallery': {'ku': 'گالێری مۆبایل', 'badini': 'گالێریا مۆبایلێ', 'ar': 'معرض الصور', 'en': 'Photo Gallery'},
    'camera_photo': {'ku': 'وێنەی کامێرا', 'badini': 'وێنێ کامیرایێ', 'ar': 'الكاميرا', 'en': 'Take Photo'},
    'suggested_avatars': {'ku': 'ئاڤاتارە پێشنیازکراوەکان:', 'badini': 'ئاڤاتارێن پێشنیازکری:', 'ar': 'الصور الرمزية المقترحة:', 'en': 'Suggested Avatars:'},
    'custom_image_url': {'ku': 'لینکی وێنەی تایبەت (URL)', 'badini': 'لینکێ وێنەیێ تایبەت (URL)', 'ar': 'رابط الصورة المخصصة (URL)', 'en': 'Custom Image URL'},
    'avatar_updated_success': {'ku': '✅ وێنەی پڕۆفایل بە سەرکەوتوویی جێگیرکرا!', 'badini': '✅ وێنەیێ پرۆفایلی ب سەرکەفتیانە هاتە دانان!', 'ar': '✅ تم تحديث صورة الملف الشخصي بنجاح!', 'en': 'Profile picture updated successfully! ✅'},
    'save_avatar': {'ku': '💾 جێگیرکردنی وێنەی پڕۆفایل', 'badini': '💾 دانانا وێنەیێ پرۆفایلی', 'ar': '💾 حفظ صورة الملف الشخصي', 'en': '💾 Save Profile Picture'},
    'course_details': {'ku': 'وردەکاری وانە', 'badini': 'هویرکاریێن وانەیێ', 'ar': 'تفاصيل المادة', 'en': 'Course Details'},
    'set_exam_date': {'ku': 'دیاریکردنی کاتی تاقیکردنەوە', 'badini': 'دەستنیشانکرنا دەمێ تاقیکرنێ', 'ar': 'تحديد موعد الامتحان', 'en': 'Set Exam Date'},
    'ai_study_tools': {'ku': 'ئامرازە زیرەکەکانی دراسەکردن', 'badini': 'ئامرازێن زیرەک بۆ دراسەکرنێ', 'ar': 'أدوات الدراسة بالذكاء الاصطناعي', 'en': 'AI Study Tools'},
    'ai_explain_course': {'ku': 'ڕوونکردنەوەی گشتی وانە', 'badini': 'شلوڤەکرنا گشتی یا وانەیێ', 'ar': 'شرح شامل للمادة', 'en': 'Comprehensive Explanation'},
    'course_quiz_fast': {'ku': 'تاقیکردنەوەی خێرا (Quiz)', 'badini': 'تاقیکرنا بلەز (Quiz)', 'ar': 'اختبار سريع', 'en': 'Quick Quiz'},
    'key_concepts_btn': {'ku': 'خاڵ و یاسا گرنگەکان', 'badini': 'پۆینت و یاسایێن گرنگ', 'ar': 'أهم المفاهيم والقوانين', 'en': 'Key Concepts & Formulas'},
    'lecture_materials': {'ku': 'سڵاید و فایلی وانەکان', 'badini': 'فایل و سلایدێن وانەیان', 'ar': 'ملفات وسلايدات المحاضرات', 'en': 'Lecture Materials & PDFs'},
    'upload_lecture_btn': {'ku': 'بارکردنی PDF', 'badini': 'بارکرنا فایلا PDF', 'ar': 'رفع محاضرة', 'en': 'Upload PDF'},
    'chat_with_lecture': {'ku': 'پرسیار و گفتوگۆ', 'badini': 'پسیار و دانوستاندن', 'ar': 'محادثة وسؤال', 'en': 'Chat & Ask'},
    'summarize_lecture': {'ku': 'کورتەی فەوری', 'badini': 'کورتیا بلەز', 'ar': 'تلخيص فوري', 'en': 'Quick Summary'},
    'lectures_count': {'ku': 'فایلی وانە', 'badini': 'فایلێن وانەیێ', 'ar': 'ملفات المحاضرة', 'en': 'Lectures'},
    'quick_presets': {'ku': 'دیاریکردنی خێرا (ڕۆژ)', 'badini': 'دەستنیشانکرنا بلەز (ڕۆژ)', 'ar': 'تحديد سريع (أيام)', 'en': 'Quick Presets (Days)'},
    'pick_from_calendar': {'ku': 'هەڵبژاردن لە ڕۆژژمێرەوە', 'badini': 'هەلبژارتن ژ ڕۆژژمێرێ', 'ar': 'اختيار من التقويم', 'en': 'Pick from Calendar'},
    'change_document': {'ku': 'گۆڕینی فایل', 'badini': 'گوهۆڕینا فایلێ', 'ar': 'تغيير الملف', 'en': 'Change File'},
    'view_document_text': {'ku': 'بینینی دەقی فایل', 'badini': 'دیتنا دەقێ فایلێ', 'ar': 'عرض نص الملف', 'en': 'View Extracted Text'},
    'document_preview': {'ku': 'پێشبینینی ناوەڕۆکی دۆکیومێنت', 'badini': 'پێشبینیا ناڤەرۆکا دۆکیۆمێنتێ', 'ar': 'معاينة محتوى المستند', 'en': 'Document Content Preview'},
    'ask_pdf_hint': {'ku': 'پرسیارێک دەربارەی ئەم فایلە بنووسە...', 'badini': 'پسیارەکێ ل سەر ڤێ فایلێ بنڤیسە...', 'ar': 'اسأل سؤالاً حول هذا المستند...', 'en': 'Ask a question about this document...'},
    'summarize_doc': {'ku': 'کورتەی سەرەکی 📝', 'badini': 'کورتیا سەرەکی 📝', 'ar': 'الملخص الرئيسي 📝', 'en': 'Key Summary 📝'},
    'key_exam_questions': {'ku': 'پرسیارە گرنگەکان ❓', 'badini': 'پسیارێن گرنگ ❓', 'ar': 'أسئلة هامة ❓', 'en': 'Exam Questions ❓'},
    'key_formulas': {'ku': 'یاسا و چەمکەکان 📐', 'badini': 'یاسا و چەمک 📐', 'ar': 'القوانين والمفاهيم 📐', 'en': 'Key Formulas 📐'},
    'quick_quiz_doc': {'ku': 'تاقیکردنەوەی خێرا ⚡', 'badini': 'تاقیکرنا بلەز ⚡', 'ar': 'اختبار سريع ⚡', 'en': 'Quick Quiz ⚡'},
    'copy_response': {'ku': 'کۆپیکردن', 'badini': 'کۆپیکرن', 'ar': 'نسخ', 'en': 'Copy'},
    'response_copied': {'ku': 'وەڵامەکە کۆپی کرا! 📋', 'badini': 'بەرسڤ هاتە کۆپیکرن! 📋', 'ar': 'تم نسخ الإجابة! 📋', 'en': 'Answer copied! 📋'},
  };
}


