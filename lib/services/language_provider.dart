import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { kurdish, arabic, english }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  LanguageProvider() {
    _loadLanguageFromPrefs();
  }

  AppLanguage get currentLanguage => _currentLanguage;
  
  String get languageCode {
    switch (_currentLanguage) {
      case AppLanguage.kurdish:
        return 'ku';
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

  /// Returns the appropriate font family for the current language.
  /// Kurdish uses DroidKufi, Arabic uses Noto Sans Arabic, English uses default (Inter via GoogleFonts).
  String? get fontFamily {
    switch (_currentLanguage) {
      case AppLanguage.kurdish:
        return 'DroidKufi';
      case AppLanguage.arabic:
        return 'Noto Sans Arabic';
      case AppLanguage.english:
        return null;
    }
  }

  Future<void> _loadLanguageFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = prefs.getString('app_language');
    if (langStr != null) {
      if (langStr == 'ku') _currentLanguage = AppLanguage.kurdish;
      if (langStr == 'ar') _currentLanguage = AppLanguage.arabic;
      if (langStr == 'en') _currentLanguage = AppLanguage.english;
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
      case AppLanguage.arabic:
        return translations['ar'] ?? key;
      case AppLanguage.english:
        return translations['en'] ?? key;
    }
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    // Bottom Navigation
    'nav_home': {'ku': 'سەرەکی', 'ar': 'الرئيسية', 'en': 'Home'},
    'nav_courses': {'ku': 'وانەکان', 'ar': 'المواد', 'en': 'Courses'},
    'nav_ai_teacher': {'ku': 'مامۆستا AI', 'ar': 'معلم AI', 'en': 'AI Tutor'},
    'nav_quiz': {'ku': 'کویز', 'ar': 'اختبار', 'en': 'Quiz'},
    'nav_profile': {'ku': 'پڕۆفایل', 'ar': 'الملف', 'en': 'Profile'},

    // Home / Dashboard Header & Search
    'greeting': {'ku': 'بەیانیت باش،', 'ar': 'صباح الخير،', 'en': 'Good morning,'},
    'ask_ai_anything': {'ku': 'پرسیار لە AI بکه...', 'ar': 'اسأل الذكاء الاصطناعي...', 'en': 'Ask AI anything...'},
    'ai_tutor': {'ku': 'مامۆستای زیرەک', 'ar': 'المعلم الذكي', 'en': 'AI Tutor'},
    'ai_tutor_subtitle': {
      'ku': 'هاوکاری تایبەتی فێربوونت.\nپرسیار بکە، فێربە و گەشە بکە.',
      'ar': 'مساعدك الشخصي للتعلم.\nاسأل، تعلم وتطور.',
      'en': 'Your personal learning assistant.\nAsk, learn and grow together.'
    },
    'start_learning': {'ku': 'دەستپێکردنی فێربوون', 'ar': 'ابدأ التعلم', 'en': 'Start Learning'},
    'explain': {'ku': 'ڕوونکردنەوە', 'ar': 'شرح', 'en': 'Explain'},
    'summarize': {'ku': 'کورتکردنەوە', 'ar': 'تلخيص', 'en': 'Summarize'},
    'voice_tutor': {'ku': 'مامۆستای دەنگی', 'ar': 'المعلم الصوتي', 'en': 'Voice Tutor'},
    'pdf_chat': {'ku': 'چاتی PDF', 'ar': 'محادثة PDF', 'en': 'PDF Chat'},

    // Cards
    'current_gpa': {'ku': 'کۆنمرەی گشتی (GPA)', 'ar': 'المعدل التراكمي', 'en': 'Current GPA'},
    'excellent': {'ku': 'زۆر باشە', 'ar': 'ممتاز', 'en': 'Excellent'},
    'continue_learning': {'ku': 'بەردەوامبوون لە خوێندن', 'ar': 'متابعة التعلم', 'en': 'Continue Learning'},
    'continue': {'ku': 'بەردەوامبە', 'ar': 'متابعة', 'en': 'Continue'},
    'see_all': {'ku': 'بینینی هەمووی', 'ar': 'عرض الكل', 'en': 'See all'},
    'quick_ai_tools': {'ku': 'ئامرازە خێراکانی AI', 'ar': 'أدوات الذكاء الاصطناعي', 'en': 'Quick AI Tools'},
    'recommended_courses': {'ku': 'وانە پێشنیارکراوەکان', 'ar': 'المواد المقترحة', 'en': 'Recommended Courses'},

    // Settings & Profile
    'settings_profile': {'ku': 'ڕێکخستنەکان و پرۆفایل', 'ar': 'الإعدادات والملف الشخصي', 'en': 'Settings & Profile'},
    'official_student_verification': {'ku': 'پشکنینی فەرمی قوتابی', 'ar': 'التحقق الرسمي من الطالب', 'en': 'Official Student Verification'},
    'learning_stats': {'ku': 'ئامارەکانی فێربوون', 'ar': 'إحصائيات التعلم', 'en': 'Learning Stats'},
    'study_time': {'ku': 'کاتی خوێندن', 'ar': 'وقت الدراسة', 'en': 'Study Time'},
    'quizzes': {'ku': 'کویزەکان', 'ar': 'الاختبارات', 'en': 'Quizzes'},
    'gpa': {'ku': 'کۆنمرە (GPA)', 'ar': 'المعدل', 'en': 'GPA'},
    'preferences': {'ku': 'هەڵبژاردنەکان', 'ar': 'التفضيلات', 'en': 'Preferences'},
    'dark_mode': {'ku': 'باری تاریک', 'ar': 'الوضع الداكن', 'en': 'Dark Mode'},
    'app_language': {'ku': 'زمانی ئەپڵیکەیشن', 'ar': 'لغة التطبيق', 'en': 'App Language'},
    'notifications': {'ku': 'ئاگادارییەکان', 'ar': 'الإشعارات', 'en': 'Notifications'},
    'privacy_security': {'ku': 'تایبەتمەندی و ئاسایش', 'ar': 'الخصوصية والأمان', 'en': 'Privacy & Security'},
    'about_zanko': {'ku': 'دەربارەی ZankoAI', 'ar': 'عن ZankoAI', 'en': 'About ZankoAI'},

    // Courses & Lessons
    'all_courses': {'ku': 'سەرجەم وانەکان', 'ar': 'جميع المواد', 'en': 'All Courses'},
    'search_courses': {'ku': 'گەڕان لە وانەکاندا...', 'ar': 'البحث في المواد...', 'en': 'Search courses...'},
    'lessons': {'ku': 'وانە', 'ar': 'دروس', 'en': 'Lessons'},

    // Quiz Maker
    'quiz_maker': {'ku': 'دروستکەری کویز بە AI', 'ar': 'منشئ الاختبارات', 'en': 'AI Quiz Maker'},
    'select_course': {'ku': 'وانەکە هەڵبژێرە', 'ar': 'اختر المادة', 'en': 'Select Course'},
    'select_topic': {'ku': 'بابەتەکە هەڵبژێرە', 'ar': 'اختر الموضوع', 'en': 'Select Topic'},
    'generate_quiz': {'ku': 'دروستکردنی کویز', 'ar': 'إنشاء الاختبار', 'en': 'Generate Quiz'},

    'notes_title': {'ku': 'تێبینییەکانم', 'ar': 'ملاحظاتي', 'en': 'My Notes'},
    'search_notes': {'ku': 'گەڕان لە تێبینییەکاندا...', 'ar': 'البحث في الملاحظات...', 'en': 'Search notes...'},
    'new_note': {'ku': 'تێبینی نوێ', 'ar': 'ملاحظة جديدة', 'en': 'New Note'},

    // Common Actions
    'edit': {'ku': 'دەستکاری', 'ar': 'تعديل', 'en': 'Edit'},
    'delete': {'ku': 'سڕینەوە', 'ar': 'حذف', 'en': 'Delete'},
    'cancel': {'ku': 'هەڵوەشاندنەوە', 'ar': 'إلغاء', 'en': 'Cancel'},
    'ok': {'ku': 'باشە', 'ar': 'حسناً', 'en': 'OK'},
    'save': {'ku': 'خەزنکردن', 'ar': 'حفظ', 'en': 'Save'},
    'clear': {'ku': 'سڕینەوە', 'ar': 'مسح', 'en': 'Clear'},
    
    // Common Errors/Messages
    'error': {'ku': 'هەڵەیەک ڕوویدا', 'ar': 'حدث خطأ', 'en': 'Error'},
    'failed_to_load': {'ku': 'نەتوانرا باربکرێت', 'ar': 'فشل التحميل', 'en': 'Failed to load'},
    'empty_record': {'ku': 'سجلەکە چۆڵە', 'ar': 'السجل فارغ', 'en': 'Empty record'},
    'scan_error': {'ku': 'هەڵە لە سکانکەر', 'ar': 'خطأ في المسح', 'en': 'Scan Error'},
    
    // File / Chat
    'add_pdf': {'ku': 'زیادکردنی PDF', 'ar': 'إضافة PDF', 'en': 'Add PDF'},
    'gemini_api_key': {'ku': 'کلیلێ APIی Gemini', 'ar': 'مفتاح Gemini API', 'en': 'Gemini API Key'},
    'save_key': {'ku': 'خەزنکردنی کلیل', 'ar': 'حفظ المفتاح', 'en': 'Save Key'},
    'clear_chat_history': {'ku': 'سڕینەوەی مێژووی چات؟', 'ar': 'مسح سجل الدردشة؟', 'en': 'Clear Chat History?'},
    'clear_chat_desc': {'ku': 'ئەمە چاتە خەزنکراوەکان دەسڕێتەوە.', 'ar': 'سيؤدي هذا إلى حذف المحادثات المحفوظة.', 'en': 'This will delete saved conversations.'},
    'please_enter_topic': {'ku': 'تکایە سەرەتا بابەتێک بنووسە.', 'ar': 'يرجى إدخال موضوع أولاً.', 'en': 'Please enter a topic first.'},
    'please_enter_notes': {'ku': 'تکایە سەرەتا تێبینییەکان بنووسە یان فایلێک بەرزبکەرەوە.', 'ar': 'يرجى إدخال ملاحظات أو رفع ملف أولاً.', 'en': 'Please enter notes or upload a file first.'},
    'note_saved': {'ku': 'تێبینییەکە بە سەرکەوتوویی خەزنکرا!', 'ar': 'تم حفظ الملاحظة بنجاح!', 'en': 'Note saved successfully!'},
    'note_deleted': {'ku': 'تێبینییەکە سڕایەوە', 'ar': 'تم حذف الملاحظة', 'en': 'Note deleted'},
    'provide_title_content': {'ku': 'تکایە هەم ناونیشان و هەم ناوەڕۆک دابین بکە', 'ar': 'يرجى تقديم كل من العنوان والمحتوى', 'en': 'Please provide both title and content'},
    
    // Stats / Profile Extras
    'english_us': {'ku': 'English (US)', 'ar': 'English (US)', 'en': 'English (US)'},
    'english_desc': {'ku': 'زمانی نێودەوڵەتی', 'ar': 'اللغة الدولية', 'en': 'Default International Language'},
    'kurdish_name': {'ku': 'کوردی (Kurdish)', 'ar': 'کوردی (Kurdish)', 'en': 'کوردی (Kurdish)'},
    'kurdish_desc': {'ku': 'زمانی کوردیی سۆرانی', 'ar': 'زمانی کوردیی سۆرانی', 'en': 'زمانی کوردیی سۆرانی'},
    'arabic_name': {'ku': 'العربية (Arabic)', 'ar': 'العربية (Arabic)', 'en': 'العربية (Arabic)'},
    'arabic_desc': {'ku': 'اللغة العربية الفصحى', 'ar': 'اللغة العربية الفصحى', 'en': 'اللغة العربية الفصحى'},
    'daily_reminders': {'ku': 'بیرخستنەوەی ڕۆژانە', 'ar': 'تذكير يومي', 'en': 'Daily Study Reminders'},
    'version': {'ku': 'v1.0.0', 'ar': 'v1.0.0', 'en': 'v1.0.0'},
    
    // Labels
    'questions_label': {'ku': 'پرسیارەکان', 'ar': 'الأسئلة', 'en': 'Questions'},
    'accuracy_label': {'ku': 'ووردی', 'ar': 'الدقة', 'en': 'Accuracy'},
    'courses_label': {'ku': 'کۆرسەکان', 'ar': 'المواد', 'en': 'Courses'},
    'target_gpa': {'ku': 'کۆنمرەی ئامانج', 'ar': 'المعدل المستهدف', 'en': 'Target GPA'},
    'remaining_semesters': {'ku': 'وەرزی ماوە', 'ar': 'الفصول المتبقية', 'en': 'Remaining Semesters'},
    'task_subject_label': {'ku': 'ناوی ئەرکەکە / بابەت', 'ar': 'اسم المهمة / الموضوع', 'en': 'Task / Subject Name'},
    'course_name_label': {'ku': 'ناوی وانە / کۆرس', 'ar': 'اسم المادة / الدورة', 'en': 'Course Name'},
    
    // Badges
    'ai_scholar': {'ku': 'زانای AI', 'ar': 'عالم AI', 'en': 'AI Scholar'},
    'quiz_master': {'ku': 'پاڵەوانی کویز', 'ar': 'بطل الاختبارات', 'en': 'Quiz Master'},
    'focus_guru': {'ku': 'پسپۆڕی تەرکیز', 'ar': 'خبير التركيز', 'en': 'Focus Guru'},
    'deep_reader': {'ku': 'خوێنەری زیرەک', 'ar': 'القارئ المتعمق', 'en': 'Deep Reader'},

    // Notifications
    'notif_ai_summary': {'ku': 'کورتەی AI ئامادەیە', 'ar': 'ملخص AI جاهز', 'en': 'AI Summary Ready'},
    'notif_quiz_high': {'ku': 'ئاستێکی بەرزی کویز!', 'ar': 'أداء عالي في الاختبار!', 'en': 'Quiz Performance High!'},
    'notif_assignment': {'ku': 'بیرخستنەوەی کاتی کۆتایی ئەرک', 'ar': 'تذكير بموعد التسليم', 'en': 'Assignment Deadline Reminder'},
    'notif_new_material': {'ku': 'ماددەی نوێی وانە بەردەستە', 'ar': 'مواد دراسية جديدة متاحة', 'en': 'New Course Material Available'},
    'notif_gpa_update': {'ku': 'نوێکردنەوەی کۆنمرە', 'ar': 'تحديث المعدل', 'en': 'GPA Update Calculated'},

    // Hints & Tooltips
    'type_answer': {'ku': 'وەڵامەکە بنووسە...', 'ar': 'اكتب الإجابة...', 'en': 'Type answer...'},
    'note_title_hint': {'ku': 'ناونیشانی تێبینی...', 'ar': 'عنوان الملاحظة...', 'en': 'Note Title...'},
    'note_content_hint': {'ku': 'ناوەڕۆکی تێبینییەکە بنووسە یان بڵێ...', 'ar': 'اكتب أو أملِ محتوى الملاحظة...', 'en': 'Write or dictate note content...'},
    'planner_hint_exam': {'ku': 'نموونە: تاقیکردنەوەی کۆتایی سیستمەکانی کارپێکردن', 'ar': 'مثال: الامتحان النهائي لأنظمة التشغيل', 'en': 'e.g. Operating Systems Final Exam'},
    'flashcards_hint': {'ku': 'نموونە: چینی مۆدێلی OSI', 'ar': 'مثال: طبقات نموذج OSI', 'en': 'e.g. OSI model layers, CPU execution cycle'},
    'toggle_view': {'ku': 'گۆڕینی بینین', 'ar': 'تغيير العرض', 'en': 'Toggle View'},
    'dictate_voice_note': {'ku': 'نووسین بە دەنگی کوردی', 'ar': 'الإملاء الصوتي', 'en': 'Dictate Kurdish Voice Note'},
    'scan_qr_deck': {'ku': 'سکانکردنی کارتی QR', 'ar': 'مسح بطاقة QR', 'en': 'Scan QR Deck'},
    'share_qr_deck': {'ku': 'هاوبەشکردنی کارتی QR', 'ar': 'مشاركة بطاقة QR', 'en': 'Share QR Deck'},
    'tts_tooltip': {'ku': 'خوێندنەوە بە دەنگ', 'ar': 'قراءة صوتية', 'en': 'Text to Speech'},
    'clear_chat_tooltip': {'ku': 'سڕینەوەی چات', 'ar': 'مسح الدردشة', 'en': 'Clear Chat'},
    'config_api_key_tooltip': {'ku': 'ڕێکخستنی کلیلێ API', 'ar': 'إعداد مفتاح API', 'en': 'Configure API Key'},
    'email_hint': {'ku': 'نموونە@zanko.edu', 'ar': 'مثال@zanko.edu', 'en': 'example@zanko.edu'},

    // Notifications Screen
    'no_notifications': {'ku': 'هیچ ئاگادارییەک نییە', 'ar': 'لا توجد إشعارات', 'en': 'No Notifications'},
    'all_caught_up': {'ku': 'هەموو شتێکت خوێندووەتەوە!', 'ar': 'أنت على اطلاع تام!', 'en': "You're all caught up!"},
    'mark_read': {'ku': 'نیشانەکردن بە خوێنراو', 'ar': 'تحديد كمقروء', 'en': 'Mark Read'},
    'filter_all': {'ku': 'هەموو', 'ar': 'الكل', 'en': 'All'},
    'filter_unread': {'ku': 'نەخوێنراو', 'ar': 'غير مقروء', 'en': 'Unread'},
    'filter_ai_tutor': {'ku': 'مامۆستای AI', 'ar': 'معلم AI', 'en': 'AI Tutor'},
    'filter_course': {'ku': 'وانە', 'ar': 'المادة', 'en': 'Course'},
    'filter_quiz': {'ku': 'کویز', 'ar': 'اختبار', 'en': 'Quiz'},
    'filter_reminder': {'ku': 'بیرخستنەوە', 'ar': 'تذكير', 'en': 'Reminder'},

    // Focus Screen
    'focus_timer_title': {'ku': 'کاتژمێری تەرکیزکردن', 'ar': 'مؤقت التركيز', 'en': 'Pomodoro Focus Timer'},
    'focus_session': {'ku': 'خولی تەرکیزکردن', 'ar': 'جلسة التركيز', 'en': 'Study Focus Session'},
    'break_session': {'ku': 'خولی پشوودان', 'ar': 'وقت الاستراحة', 'en': 'Relax Break Session'},
    'switch_to_focus': {'ku': 'بگۆڕە بۆ تەرکیز', 'ar': 'التبديل للدراسة', 'en': 'Switch to Focus'},
    'switch_to_break': {'ku': 'بگۆڕە بۆ پشوو', 'ar': 'التبديل للاستراحة', 'en': 'Switch to Break'},
    'focus_complete': {'ku': 'تەرکیز تەواو بوو!', 'ar': 'انتهت جلسة التركيز!', 'en': 'Focus Complete!'},
    'break_complete': {'ku': 'پشوو تەواو بوو!', 'ar': 'انتهت الاستراحة!', 'en': 'Break Complete!'},
    'focus_label': {'ku': 'تەرکیز', 'ar': 'تركيز', 'en': 'FOCUS'},
    'break_label': {'ku': 'پشوو', 'ar': 'استراحة', 'en': 'BREAK'},

    // Notes Screen
    'no_notes_found': {'ku': 'هیچ تێبینییەک نەدۆزرایەوە', 'ar': 'لم يتم العثور على ملاحظات', 'en': 'No Notes Found'},
    'recording_voice_note': {'ku': 'تۆمارکردنی تێبینی دەنگی', 'ar': 'تسجيل ملاحظة صوتية', 'en': 'Recording Voice Note'},
    'ai_organizing_note': {'ku': 'AI ئەو تێبینییە ڕیکدەخات...', 'ar': 'الذكاء الاصطناعي ينظم الملاحظة...', 'en': 'AI is polishing & organizing note...'},
    'general': {'ku': 'گشتی', 'ar': 'عام', 'en': 'General'},
    'save_note': {'ku': 'خەزنکردنی تێبینی', 'ar': 'حفظ الملاحظة', 'en': 'Save Note'},

    // Stats / Achievement labels
    'stat_organized_notes': {'ku': 'کەمێک تێبینی AI ڕیکخست', 'ar': 'نظّم ملاحظات AI', 'en': 'Organized 2+ AI Notes'},
    'stat_completed_quiz': {'ku': 'تاقیکردنەوەی کویز تەواو کرد', 'ar': 'أكمل اختبارات', 'en': 'Completed 1+ Quiz tests'},
    'stat_completed_pomodoro': {'ku': 'پۆمۆدۆرۆ تەواو کرد', 'ar': 'أكمل جلسات بومودورو', 'en': 'Completed 1+ Pomodoros'},
    'stat_extracted_pdf': {'ku': 'تێبینی PDF دەرکرد', 'ar': 'استخرج ملاحظات PDF', 'en': 'Extracted 1+ PDF notes'},

    // Profile Screen
    'full_name': {'ku': 'ناوی تەواو', 'ar': 'الاسم الكامل', 'en': 'Full Name'},
    'university_email': {'ku': 'ئیمەیلی زانکۆ', 'ar': 'البريد الإلكتروني الجامعي', 'en': 'University Email'},
    'university': {'ku': 'زانکۆ', 'ar': 'الجامعة', 'en': 'University'},
    'faculty_major': {'ku': 'فاکەڵتی و پسپۆڕی', 'ar': 'الكلية والتخصص', 'en': 'Faculty & Major'},
    'academic_stage': {'ku': 'قۆناغی ئەکادیمی', 'ar': 'المرحلة الأكاديمية', 'en': 'Academic Stage'},
    'campus_status': {'ku': 'بارودۆخی کامپس', 'ar': 'الحالة في الحرم الجامعي', 'en': 'Campus Status'},
    'select_app_language': {'ku': 'زمانی ئەپڵیکەیشن دیاری بکە', 'ar': 'اختر لغة التطبيق', 'en': 'Select App Language'},
    'digital_id': {'ku': 'ناسنامەی دیجیتاڵ', 'ar': 'الهوية الرقمية', 'en': 'DIGITAL ID'},
    'tap_for_campus_qr': {'ku': 'دەست بدە بۆ کۆدی QR', 'ar': 'اضغط لرمز QR الجامعي', 'en': 'Tap for Campus QR & Details'},
    'valid_until': {'ku': 'VALID 2024 - 2026', 'ar': 'VALID 2024 - 2026', 'en': 'VALID 2024 - 2026'},
    'done': {'ku': 'تەواو', 'ar': 'تم', 'en': 'Done'},

    // Onboarding Screen
    'onboarding_welcome': {'ku': 'بەخێربێن بۆ ZankoAI', 'ar': 'مرحباً بك في ZankoAI', 'en': 'Welcome to ZankoAI'},
    'onboarding_subtitle': {'ku': 'هاوکارت بۆ خوێندن بە هێزی AI', 'ar': 'مساعدك الذكي للدراسة الجامعية', 'en': 'Your all-in-one AI-powered study companion designed for university students.'},
    'onboarding_summarize': {'ku': 'کورتکردنەوەی وانەکانت', 'ar': 'لخّص موادك الدراسية', 'en': 'Summarize Your Courses'},
    'onboarding_plan': {'ku': 'ئامادەکردنی پلانی خوێندن', 'ar': 'خطط لأسبوعك الدراسي', 'en': 'Plan Your Study Week'},
    'onboarding_plan_sub': {'ku': 'AI پلانی ڕۆژانەی تایبەتی بۆ تاقیکردنەوەکانت ئامادە دەکات.', 'ar': 'الذكاء الاصطناعي يبني خطة دراسية مخصصة يوماً بيوم.', 'en': 'AI builds a personalized day-by-day study plan for your exams.'},
    'onboarding_test': {'ku': 'خۆت تاقی بکەرەوە', 'ar': 'اختبر نفسك', 'en': 'Test Yourself'},
    'onboarding_test_sub': {'ku': 'کویز، کارتی فلاش، و پرسیاری تاقیکردنەوە بە AI دروستبکە.', 'ar': 'أنشئ اختبارات وبطاقات تعليمية وأسئلة متوقعة بالذكاء الاصطناعي.', 'en': 'Generate quizzes, flashcards, and predicted exam questions with AI.'},
    'onboarding_ready': {'ku': 'ئامادەی دەستپێکردن؟', 'ar': 'مستعد للبدء؟', 'en': 'Ready to Start?'},
    'onboarding_ready_sub': {'ku': 'کلیلێ Gemini API لە ئەکاونتی Google AI Studio دابگرە.', 'ar': 'أدخل مفتاح Gemini API من الصفحة الرئيسية لفتح ميزات الذكاء الاصطناعي.', 'en': 'Set your Gemini API key from the home screen to unlock all AI features.'},

    // Course Detail Screen
    'no_pdf_uploaded': {'ku': 'هیچ PDF ئەپلۆد نەکراوە', 'ar': 'لم يتم رفع ملفات PDF', 'en': 'No PDF Lectures Uploaded'},
    'upload_pdf_desc': {'ku': 'سلایدەکانی وانەت یان تێبینییەکانت ئەپلۆد بکە بۆ چات بەکارهێنانی AI و دروستکردنی کورتە.', 'ar': 'ارفع شرائح المحاضرة أو ملاحظاتك للدردشة مع AI وإنشاء الملخصات.', 'en': 'Upload your lecture slides or notes to chat with AI and generate summaries.'},
    'chat_with_ai': {'ku': 'چاتی AI', 'ar': 'محادثة AI', 'en': 'Chat with AI'},
    'ai_summary': {'ku': 'کورتەی AI', 'ar': 'ملخص AI', 'en': 'AI Summary'},
    'lecture_title_hint': {'ku': 'نموونە: تێبینییەکانی بابی 3', 'ar': 'مثال: ملاحظات الفصل 3', 'en': 'Enter Lecture Title (e.g. Chapter 3 Notes)'},
    'yesterday': {'ku': 'دوێنێ', 'ar': 'أمس', 'en': 'Yesterday'},
    'just_now': {'ku': 'ئێستا', 'ar': 'الآن', 'en': 'Just now'},

    // Home Screen
    'todays_progress': {'ku': 'پێشکەوتنی ئەمڕۆ', 'ar': 'تقدم اليوم', 'en': "Today's Progress"},
    'todays_breakdown': {'ku': 'وردەکاری فێربوونی ئەمڕۆ', 'ar': 'تفاصيل تعلم اليوم', 'en': "Today's Learning Breakdown"},
    'recommended_for_you': {'ku': 'پێشنیارکراو بۆ تۆ', 'ar': 'موصى به لك', 'en': 'Recommended for You'},
    'student_role': {'ku': 'قوتابی', 'ar': 'طالب', 'en': 'Student'},
    'goal_2_hours': {'ku': 'ئامانج: ٢ کاتژمێر', 'ar': 'الهدف: ساعتان', 'en': 'Goal: 2 hours'},
    'goal_30': {'ku': 'ئامانج: ٣٠', 'ar': 'الهدف: 30', 'en': 'Goal: 30'},
    'top_5_percent': {'ku': 'تاپ ٥٪ی پۆل', 'ar': 'أعلى 5% من الصف', 'en': 'Top 5% of class'},

    // PDF / Summary Screen
    'no_text_extracted': {'ku': 'هیچ دەقێک دەرنەکرا.', 'ar': 'لم يتم استخراج نص.', 'en': 'No text could be extracted.'},
    'document': {'ku': 'بەڵگەنامە', 'ar': 'مستند', 'en': 'Document'},

    // QR Share Sheet
    'invalid_qr_format': {'ku': 'فۆرماتی کۆدی QR نادروستە.', 'ar': 'تنسيق رمز QR غير صالح.', 'en': 'Invalid QR code format for ZankoAI.'},
    'qr_data_too_large': {'ku': 'داتای کارتەکان زۆر گەورەیە بۆ QR.', 'ar': 'بيانات البطاقات كبيرة جدًا لرمز QR.', 'en': 'Flashcard data too large for QR.'},

    // Teacher screens
    'general_topics': {'ku': 'بابەتە گشتییەکان', 'ar': 'مواضيع عامة', 'en': 'General Topics'},

    // failed_to_generate
    'failed_to_generate': {'ku': 'شکستی هێنا لە دروستکردن', 'ar': 'فشل في الإنشاء', 'en': 'Failed to generate'},

    // Study planner
    'study_planner_title': {'ku': 'پلانی خوێندنم', 'ar': 'خطة دراستي', 'en': 'My Study Plan'},

    // GPA tracker hints
    'gpa_hint_375': {'ku': 'نموونە: ٣.٧٥', 'ar': 'مثال: 3.75', 'en': 'e.g. 3.75'},
    'gpa_hint_38': {'ku': 'نموونە: ٣.٨', 'ar': 'مثال: 3.8', 'en': 'e.g. 3.8'},
    'gpa_hint_3': {'ku': 'نموونە: ٣', 'ar': 'مثال: 3', 'en': 'e.g. 3'},
    'schedule_time_hint': {'ku': 'نموونە: ١٠:١٥ - ١١:٤٥', 'ar': 'مثال: 10:15 - 11:45', 'en': 'e.g. 10:15 - 11:45'},

    // Flashcards screen
    'flashcards_title': {'ku': 'فلاشکاردی خوێندنەوە', 'ar': 'بطاقات المراجعة الذكية', 'en': 'AI Study Flashcards'},
    'flashcards_input_label': {'ku': 'بابەتێک بنووسە یان دەقێک لێرە دابنێ', 'ar': 'اكتب الموضوع أو انسخ النص', 'en': 'Enter topic or copy text'},
    'flashcards_generate_btn': {'ku': 'دروستکردنی فلاشکارد', 'ar': 'إنشاء البطاقات', 'en': 'Generate Flashcards'},
    'flashcards_empty_state': {'ku': 'تا ئێستا هیچ فلاشکاردێک دروست نەکراوە.', 'ar': 'لا توجد بطاقات مراجعة منشأة حالياً.', 'en': 'No flashcards generated yet.'},
    'flashcards_tap_to_flip': {'ku': 'کلیک بکە بۆ گۆڕینی لای کارتەکە', 'ar': 'اضغط لقلب البطاقة', 'en': 'Tap to Flip card'},

    // Exam Predictor
    'exam_predictor_title': {'ku': 'پێشبینیکەری تاقیکردنەوە', 'ar': 'مستشار الامتحان الذكي', 'en': 'Exam Predictor'},
    'exam_predictor_input_label': {'ku': 'تێبینییەکانی خوێندن یان دەقی بابەتەکە لێرە دابنێ', 'ar': 'الصق ملاحظات الدراسة أو محتوى الدرس', 'en': 'Paste your study notes or lesson contents'},
    'exam_predictor_or_label': {'ku': 'یاخود', 'ar': 'أو', 'en': 'OR'},
    'exam_predictor_upload_btn': {'ku': 'بارکردنی فایلی دەقی (Text/Markdown)', 'ar': 'تحميل ملف نصي (Text/Markdown)', 'en': 'Upload Text/Markdown File'},
    'exam_predictor_predict_btn': {'ku': 'پێشبینیکردنی پرسیارەکان', 'ar': 'توقع أسئلة الامتحان', 'en': 'Predict Exam Questions'},
    'exam_predictor_result_label': {'ku': 'پرسیارە پێشبینیکراوەکان و ڕێنماییەکان', 'ar': 'الأسئلة المتوقعة والنصائح', 'en': 'Predicted Questions & Tips'},
    'exam_predictor_loading': {'ku': 'ژیری دەستکرد خەریکی شیکردنەوەی تێبینییەکان و پێشبینیکردنی پرسیارەکانە...', 'ar': 'يقوم الذكاء الاصطناعي بتحليل الملاحظات وتوقع الأسئلة...', 'en': 'AI is analyzing your notes & predicting questions...'},
    'exam_predictor_info': {'ku': 'تێبینییەکانی وانەکەت یان دەستپێکی بەشەکە بنووسە بۆ ئەوەی ژیری دەستکرد پێشبینی ئەو پرسیارانە بکات کە ئەگەری زۆرە لە تاقیکردنەوەدا بێنەوە.', 'ar': 'أدخل ملاحظات المحاضرة أو المنهج ليقوم الذكاء الاصطناعي بتوقع الأسئلة المتوقعة في الامتحان.', 'en': 'Enter your lectures notes, syllabus, or content to let Gemini AI predict what is likely to show up in your exam.'},
    'exam_predictor_hint': {'ku': 'لێرە بنووسە یان کۆپی بکە...', 'ar': 'اكتب أو الصق هنا...', 'en': 'Type or paste here...'},

    // Mind Map
    'mind_map_title': {'ku': 'نەخشەی مێشکی زیرەک', 'ar': 'خريطة المفاهيم الذكية', 'en': 'AI Mind Map'},
    'mind_map_placeholder': {'ku': 'بابەتێک بنووسە (بۆ نموونە: بیرۆکەی کۆمپیوتەر)', 'ar': 'أدخل موضوع الخريطة (مثال: إدارة الذاكرة)', 'en': 'Enter topic (e.g. Memory Management)'},
    'mind_map_empty': {'ku': 'نەخشەیەکی بینراو دروست بکە بۆ تێگەیشتن لە چەمکەکان.', 'ar': 'أنشئ خريطة بصرية لربط موضوعات دراستك.', 'en': 'Generate a visual map to connect study topics.'},
    'mind_map_no_desc': {'ku': 'هیچ ڕوونکردنەوەیەک نییە.', 'ar': 'لا يوجد وصف.', 'en': 'No description available.'},

    // Audio Summarizer
    'audio_summarizer_title': {'ku': 'کورتکەرەوەی دەنگی وانەکان', 'ar': 'مستخلص المحاضرات الصوتية', 'en': 'Audio Summarizer'},
    'audio_summarizer_info': {'ku': 'دەنگی مامۆستا لە کاتی وتنەوەی وانەکەدا تۆمار بکە یان فایلێکی دەنگی باربکە بۆ ئەوەی دەستبەجێ بیکاتە نووسین و کورتکراوەی نایاب.', 'ar': 'سجل صوت المحاضر أثناء الدرس أو حمل تسجيلاً صوتياً ليتم تفريغه وتلخيصه فوراً.', 'en': 'Record your professor during the lecture or upload an audio recording to transcribe and summarize instantly.'},
    'audio_summarizer_upload_btn': {'ku': 'بارکردنی فایلی دەنگی', 'ar': 'تحميل ملف صوتي', 'en': 'Upload Audio File'},
    'audio_summarizer_result_label': {'ku': 'کورتکراوەی دەنگی وانەکە', 'ar': 'ملخص المحاضرة الصوتية', 'en': 'Audio Lecture Summary'},
    'audio_summarizer_loading': {'ku': 'خەریکی وەرگێڕانی دەنگ بۆ نووسین و کورتکردنەوەی دەنگەکەیە...', 'ar': 'جاري التفريغ الصوتي وتلخيص المحاضرة...', 'en': 'Transcribing and generating AI summary...'},
    'audio_summarizer_tap_record': {'ku': 'کلیک بکە بۆ دەستپێکردنی تۆمارکردن', 'ar': 'اضغط لبدء التسجيل', 'en': 'Tap to start recording'},

    // Stats Screen
    'stats_title': {'ku': 'ئاماری خوێندن و دەستکەوتەکانم', 'ar': 'إحصائيات الدراسة والإنجازات', 'en': 'Study Statistics & Achievements'},
    'stats_weekly_activity': {'ku': 'چالاکییەکانی خوێندنم', 'ar': 'النشاط الأسبوعي', 'en': 'Weekly Activity'},
    'stats_badges': {'ku': 'میدالیا و دەستکەوتەکانم', 'ar': 'الشارات والميداليات المستحقة', 'en': 'Earned Badges'},
    'stats_pomodoros': {'ku': 'خولەکانی تەرکیز', 'ar': 'جلسات بومودورو', 'en': 'Pomodoros'},
    'stats_quizzes_done': {'ku': 'کویزە تەواوکراوەکان', 'ar': 'الاختبارات المنجزة', 'en': 'Quizzes Done'},
    'stats_cards_flipped': {'ku': 'فلاشکاردەکان', 'ar': 'البطاقات المراجعة', 'en': 'Cards Flipped'},
    'stats_notes_kept': {'ku': 'تێبینییە ڕێکخراوەکان', 'ar': 'الملاحظات المحفوظة', 'en': 'Notes Kept'},

    // GPA Tracker
    'gpa_title': {'ku': 'خەمڵاندنی نمرە و نەخشەی GPA', 'ar': 'حساب المعدل ومخطط التقدم', 'en': 'GPA Calculator & Progress Chart'},
    'gpa_total': {'ku': 'کۆنمرەی گشتی (GPA)', 'ar': 'المعدل التراكمي العام', 'en': 'Total Cumulative GPA'},
    'gpa_chart_header': {'ku': 'نەخشەی پێشکەوتنی وەرزەکان', 'ar': 'مخطط تقدم الفصول الدراسية', 'en': 'Semester Progress Chart'},
    'gpa_add_label': {'ku': 'نمرەی وەرزێکی نوێ زیاد بکە (0.0 - 4.0)', 'ar': 'أضف معدل فصل دراسي (0.0 - 4.0)', 'en': 'Add Semester GPA (0.0 - 4.0)'},
    'gpa_add_btn': {'ku': 'زیادکردن', 'ar': 'إضافة', 'en': 'Add'},
    'gpa_list_header': {'ku': 'سجلی نمرەکانی پێشوو', 'ar': 'سجل الفصول الدراسية', 'en': 'Semester History'},
    'gpa_semester_label': {'ku': 'وەرز', 'ar': 'فصل دراسي', 'en': 'Semester'},

    // Study Planner
    'study_planner_card_title': {'ku': 'پلانێکی نوێ داڕێژە', 'ar': 'إنشاء جدول دراسة جديد', 'en': 'Create Study Schedule'},
    'study_planner_topic_label': {'ku': 'ناوی بابەت یان تاقیکردنەوە', 'ar': 'المادة أو موضوع الامتحان', 'en': 'Course / Exam Topic'},
    'study_planner_days_label': {'ku': 'ڕۆژەکانی ماوە بۆ تاقیکردنەوە', 'ar': 'الأيام المتبقية', 'en': 'Days Remaining'},
    'study_planner_generate_btn': {'ku': 'پلانی خوێندن داڕێژە', 'ar': 'توليد خطة الدراسة', 'en': 'Generate Study Plan'},
    'study_planner_empty': {'ku': 'پلانەکەت لێرەدا نیشان دەدرێت.', 'ar': 'ستظهر خطتك الدراسية المقترحة هنا.', 'en': 'Your generated study schedule will appear here.'},

    // Reminders
    'reminders_title': {'ku': 'ئەرک و یاددەهێنەرەکانم', 'ar': 'المهام والتذكيرات الدراسية', 'en': 'Task & Homework Reminders'},
    'reminders_active': {'ku': 'ئەرکە چالاکەکان', 'ar': 'المهام النشطة', 'en': 'Active Tasks'},
    'reminders_completed': {'ku': 'تەواوکراوەکان', 'ar': 'المهام المكتملة', 'en': 'Completed'},
    'reminders_no_tasks': {'ku': 'هیچ یاددەهێنەرێکی چالاک نییە.', 'ar': 'لا توجد تذكيرات نشطة حالياً.', 'en': 'No active reminders.'},
    'reminders_add_title': {'ku': 'یاددەهێنەر یان ئەرکی نوێ زیاد بکە', 'ar': 'إضافة مهمة أو تذكير جديد', 'en': 'Add New Task or Reminder'},
    'reminders_passed': {'ku': 'وادەکەی بەسەرچوو', 'ar': 'انتهى الوقت', 'en': 'Passed / Completed'},
    'reminders_time_left': {'ku': 'ماوە بۆ جێبەجێکردن: {days} ڕۆژ، {hours} سەعات', 'ar': 'المتبقي: {days} يوم، {hours} ساعة', 'en': 'Time left: {days} days, {hours} hrs'},
    'reminders_no_deadline': {'ku': 'هیچ وادەیەک دیاری نەکراوە', 'ar': 'لم يتم تحديد موعد', 'en': 'No deadline set'},
    'close': {'ku': 'داخستن', 'ar': 'إغلاق', 'en': 'Close'},

    // Schedule
    'schedule_lectures_count': {'ku': 'وانە', 'ar': 'محاضرات', 'en': 'lectures'},

    // General snackbar / dialog translations
    'snackbar_enter_topic': {'ku': 'تکایە بابەتێک بنووسە.', 'ar': 'يرجى كتابة موضوع.', 'en': 'Please enter a topic.'},
    'snackbar_fill_all_fields': {'ku': 'تکایە هەموو خانەکان پڕبکەرەوە.', 'ar': 'يرجى ملء جميع الحقول.', 'en': 'Please fill in all fields.'},
    'snackbar_enter_subject': {'ku': 'تکایە ناوی بابەتەکە بنووسە.', 'ar': 'يرجى كتابة اسم الموضوع.', 'en': 'Please enter the subject name.'},

    // AI Teacher
    'ai_teacher_voice_active': {'ku': 'خوێندنەوەی دەنگی چالاکە 🔊', 'ar': 'القراءة الصوتية نشطة 🔊', 'en': 'Voice Reading Active 🔊'},
    'ai_teacher_voice_stop': {'ku': 'وەستان / Stop', 'ar': 'إيقاف / Stop', 'en': 'Stop / إيقاف'},
    'ai_teacher_read_aloud': {'ku': 'Read Aloud', 'ar': 'القراءة بصوت عال', 'en': 'Read Aloud'},

    // Onboarding - additional keys
    'onboarding_summarize_sub': {'ku': 'PDF باربکە یان دەق بنووسە — دەستبەجێ کورتکراوە و وەرگێڕان وەربگرە.', 'ar': 'ارفع ملفات PDF أو الصق النص للحصول على ملخصات فورية.', 'en': 'Upload PDFs or paste text — get instant AI summaries and translations.'},
    'onboarding_skip': {'ku': 'تێپەڕکردن', 'ar': 'تخطي', 'en': 'Skip'},
    'onboarding_next': {'ku': 'دواتر →', 'ar': 'التالي →', 'en': 'Next →'},
    'onboarding_lets_go': {'ku': 'با بچینە ناو! 🚀', 'ar': 'هيا نبدأ! 🚀', 'en': "Let's Go! 🚀"},

    // Shared buttons
    'add': {'ku': 'زیادکردن', 'ar': 'إضافة', 'en': 'Add'},

    // QR Share
    'qr_share_title': {'ku': 'هاوبەشکردنی فلاشکاردەکان', 'ar': 'مشاركة مجموعة الكروت', 'en': 'Share Deck'},
    'qr_share_desc': {'ku': 'با هاوڕێکەت ئەم کۆدی QRە سکان بکات بۆ ئەوەی فلاشکاردەکانت وەربگرێت!', 'ar': 'دع صديقك يمسح هذا الكود لاستيراد الكروت فوراً!', 'en': 'Let your friend scan this QR code to import this deck instantly!'},
    'qr_scan_instructions': {'ku': 'کۆدی QR لە ناو چوارگۆشەکە دابنێ', 'ar': 'ضع رمز QR داخل المربع للمسح', 'en': 'Align QR code inside the box to scan'},
    'calculate': {'ku': 'هەژمارکردن', 'ar': 'حساب', 'en': 'Calculate'},
    'target_planner_title': {'ku': 'دیاریکردنی ئامانجی کۆنمرە', 'ar': 'مخطط المعدل المستهدف', 'en': 'Target GPA Planner'},
    'planner_input_error': {'ku': 'تکایە خانەکان بە دروستی پڕبکەرەوە.', 'ar': 'يرجى ملء الحقول بشكل صحيح.', 'en': 'Please fill in the fields correctly.'},
    'planner_cannot_reach': {'ku': '⚠️ بەم ژمارە وەرزە ناگەیتە ئامانجەکەت! پێویستت بە GPA {required} هەیە لە هەر وەرزێکدا', 'ar': '⚠️ لا يمكنك الوصول للهدف بهذا العدد من الفصول! تحتاج GPA {required} في كل فصل', 'en': '⚠️ You cannot reach your target in this many semesters! You need GPA {required} each semester'},
    'planner_already_met': {'ku': '🎉 ئامانجەکەت مسۆگەرە!', 'ar': '🎉 هدفك مضمون بالفعل!', 'en': '🎉 Your target is already guaranteed!'},
    'planner_required': {'ku': '🎯 پێویستە تێکڕای نمرەی وەرزی داهاتووت لە {required} کەمتر نەبێت', 'ar': '🎯 يجب ألا يقل معدلك في الفصول القادمة عن {required}', 'en': '🎯 You need at least GPA {required} in remaining semesters'},

    // QR / Deck import-export
    'deck_imported': {'ku': 'فلاشکاردەکان بە سەرکەوتوویی هاوردە کران! ✅', 'ar': 'تم استيراد البطاقات بنجاح! ✅', 'en': 'Deck imported successfully! ✅'},

    // Profile / University ID card (extra detail rows)
    'cumulative_gpa': {'ku': 'کۆنمرەی گشتی (GPA)', 'ar': 'المعدل التراكمي', 'en': 'Cumulative GPA'},
    'credits_completed': {'ku': 'کرێدیتی تەواوکراو', 'ar': 'الساعات المعتمدة المكتملة', 'en': 'Credits Completed'},
    'academic_advisor': {'ku': 'مامۆستای ئەکادیمی', 'ar': 'المرشد الأكاديمي', 'en': 'Academic Advisor'},
  };
}

