import 'package:flutter/material.dart';

// ─── Data Model ───────────────────────────────────────────────────────────────
class FeatureIntroData {
  final String id;
  final IconData icon;
  final List<Color> gradient;
  final Map<String, String> title;        // en / ar / ku
  final Map<String, String> subtitle;
  final List<Map<String, String>> bullets; // each bullet: {icon_name, en, ar, ku}

  const FeatureIntroData({
    required this.id,
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });
}

// ─── All Features Intro Content ───────────────────────────────────────────────
class FeatureIntros {
  static const aiTeacher = FeatureIntroData(
    id: 'ai_teacher',
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFF007AFF), Color(0xFF5856D6)],
    title: {'en': 'AI Teacher', 'ar': 'الأستاذ الذكي', 'ku': 'مامۆستای AI'},
    subtitle: {
      'en': 'Your personal AI tutor powered by Gemini — ask anything, anytime.',
      'ar': 'أستاذك الذكي الشخصي بتقنية Gemini — اسأل عن أي شيء في أي وقت.',
      'ku': 'مامۆستای تایبەتی AI بەهێزی Gemini — هەر پرسیارێک لە هەر کاتێکدا بپرسە.',
    },
    bullets: [
      {
        'icon': 'chat_bubble_rounded',
        'en': 'Ask questions about any subject in Kurdish, Arabic or English',
        'ar': 'اسأل عن أي مادة بالكردية أو العربية أو الإنجليزية',
        'ku': 'پرسیار بکە لە هەر بابەتێک بە کوردی، عەرەبی یان ئینگلیزی',
      },
      {
        'icon': 'history_edu_rounded',
        'en': 'Full conversation history saved automatically',
        'ar': 'يحفظ سجل المحادثة تلقائيًا',
        'ku': 'مێژووی قسەکردن بە خۆکاری پاشەکەوت دەبێت',
      },
      {
        'icon': 'record_voice_over_rounded',
        'en': 'Voice readout: the AI can speak answers aloud',
        'ar': 'قراءة صوتية: يمكن للذكاء قراءة الإجابات بصوت عالٍ',
        'ku': 'دەنگی قسەکردن: AI دەتوانێت وەڵامەکان بە دەنگ بخوێنێتەوە',
      },
    ],
  );

  static const pdfSummary = FeatureIntroData(
    id: 'pdf_summary',
    icon: Icons.picture_as_pdf_rounded,
    gradient: [Color(0xFFFF3B30), Color(0xFFFF6B35)],
    title: {'en': 'Course Summarizer', 'ar': 'ملخص المقررات', 'ku': 'کورتکەرەوەی وانەکان'},
    subtitle: {
      'en': 'Upload your PDF or text files and get instant AI summaries.',
      'ar': 'حمّل ملفات PDF أو نصية واحصل على ملخص فوري بالذكاء الاصطناعي.',
      'ku': 'فایلی PDF یان نووسین باربکە و دەستبەجێ کورتکراوەی AI وەربگرە.',
    },
    bullets: [
      {
        'icon': 'upload_file_rounded',
        'en': 'Upload PDF, TXT, or paste text directly',
        'ar': 'ارفع PDF أو TXT أو الصق النص مباشرة',
        'ku': 'PDF، TXT باربکە یان دەق ڕاستەوخۆ دابنێ',
      },
      {
        'icon': 'summarize_rounded',
        'en': 'Smart AI summary in seconds',
        'ar': 'ملخص ذكي في ثوانٍ معدودة',
        'ku': 'کورتکراوەی زیرەک لە چەند چرکەیەکدا',
      },
      {
        'icon': 'translate_rounded',
        'en': 'Translate summaries to any language',
        'ar': 'ترجم الملخص إلى أي لغة',
        'ku': 'کورتکراوەکە بگۆڕە بۆ هەر زمانێک',
      },
    ],
  );

  static const flashcards = FeatureIntroData(
    id: 'flashcards',
    icon: Icons.style_rounded,
    gradient: [Color(0xFF5856D6), Color(0xFFAF52DE)],
    title: {'en': 'Flashcards', 'ar': 'بطاقات المراجعة', 'ku': 'فلاشکارد'},
    subtitle: {
      'en': 'Create and review digital flashcards to memorize faster.',
      'ar': 'أنشئ بطاقات مراجعة رقمية وراجع بها لحفظ أسرع.',
      'ku': 'فلاشکاردی دیجیتاڵ دروست بکە و پێیان دووبارە بخوێنەرەوە بۆ خێراتر لەبیرکردن.',
    },
    bullets: [
      {
        'icon': 'add_card_rounded',
        'en': 'Create custom decks for any subject',
        'ar': 'أنشئ مجموعات مخصصة لأي مادة',
        'ku': 'دێستەی تایبەت بۆ هەر بابەتێک دروست بکە',
      },
      {
        'icon': 'flip_rounded',
        'en': 'Flip cards to reveal answers',
        'ar': 'اقلب البطاقة لرؤية الإجابة',
        'ku': 'کارتەکە بگێڕەوە بۆ بینینی وەڵامەکە',
      },
      {
        'icon': 'qr_code_rounded',
        'en': 'Share decks via QR code with friends',
        'ar': 'شارك المجموعات عبر QR مع الأصدقاء',
        'ku': 'دێستەکەت بە QR کۆد هاوبەش بکە لەگەڵ هاوڕێیان',
      },
    ],
  );

  static const quiz = FeatureIntroData(
    id: 'quiz',
    icon: Icons.quiz_rounded,
    gradient: [Color(0xFFFF9500), Color(0xFFFFCC00)],
    title: {'en': 'AI Quiz', 'ar': 'الاختبار الذكي', 'ku': 'تاقیکردنەوەی AI'},
    subtitle: {
      'en': 'Generate quizzes from your notes and test your knowledge.',
      'ar': 'أنشئ اختبارات من ملاحظاتك واختبر معرفتك.',
      'ku': 'لە تێبینییەکانت تاقیکردنەوە دروست بکە و زانستت بتاقیبکەرەوە.',
    },
    bullets: [
      {
        'icon': 'auto_awesome_rounded',
        'en': 'AI generates questions from your text or topic',
        'ar': 'الذكاء يولد أسئلة من نصك أو موضوعك',
        'ku': 'AI لە دەقەکەت یان بابەتەکەت پرسیار دروست دەکات',
      },
      {
        'icon': 'check_circle_rounded',
        'en': 'Multiple choice with instant feedback',
        'ar': 'أسئلة متعددة الخيارات مع تغذية فورية',
        'ku': 'پرسیاری چەندین هەڵبژاردن لەگەڵ وەڵامی دەستبەجێ',
      },
      {
        'icon': 'history_rounded',
        'en': 'Review all previous quizzes',
        'ar': 'راجع جميع الاختبارات السابقة',
        'ku': 'هەموو تاقیکردنەوەی پێشوو بخوێنەرەوە',
      },
    ],
  );

  static const reminders = FeatureIntroData(
    id: 'reminders',
    icon: Icons.alarm_on_rounded,
    gradient: [Color(0xFFFF2D55), Color(0xFFFF6B6B)],
    title: {'en': 'Reminders', 'ar': 'التذكيرات', 'ku': 'یاددەهێنەر'},
    subtitle: {
      'en': 'Never miss a deadline — set countdowns for your exams and tasks.',
      'ar': 'لا تفوت موعدًا — ضع عداداً تنازليًا لامتحاناتك ومهامك.',
      'ku': 'هیچ کاتژمێرەکی نەبەزێنە — ژمارەی پاشگەرد بۆ تاقیکردنەوە و ئەرکەکانت دابنێ.',
    },
    bullets: [
      {
        'icon': 'timer_rounded',
        'en': 'Countdown timer for each exam or assignment',
        'ar': 'عداد تنازلي لكل امتحان أو واجب',
        'ku': 'ژمارەی پاشگەرد بۆ هەر تاقیکردنەوە یان ئەرکێک',
      },
      {
        'icon': 'notification_important_rounded',
        'en': 'Get notified before deadlines',
        'ar': 'تنبيه قبل المواعيد النهائية',
        'ku': 'پێش کۆتایی کاتەکان ئاگادارت دەکاتەوە',
      },
      {
        'icon': 'list_alt_rounded',
        'en': 'Organize all your academic tasks',
        'ar': 'نظم جميع مهامك الأكاديمية',
        'ku': 'هەموو ئەرکە تەدریسییەکانت ڕێکوپێک بکە',
      },
    ],
  );

  static const planner = FeatureIntroData(
    id: 'planner',
    icon: Icons.event_note_rounded,
    gradient: [Color(0xFF34C759), Color(0xFF00C896)],
    title: {'en': 'AI Study Planner', 'ar': 'مخطط الدراسة الذكي', 'ku': 'پلانی خوێندنی AI'},
    subtitle: {
      'en': 'Let AI build a personalized weekly study plan for your exams.',
      'ar': 'دع الذكاء يبني خطة دراسة أسبوعية شخصية لامتحاناتك.',
      'ku': 'با AI پلانی خوێندنی هەفتانەی تایبەت بۆ تاقیکردنەوەکانت دروست بکات.',
    },
    bullets: [
      {
        'icon': 'calendar_month_rounded',
        'en': 'Enter exam date and topic — AI plans for you',
        'ar': 'أدخل تاريخ الامتحان والموضوع — الذكاء يخطط لك',
        'ku': 'بەرواری تاقیکردنەوە و بابەتەکە بنووسە — AI بۆت پلان دەکات',
      },
      {
        'icon': 'schedule_rounded',
        'en': 'Day-by-day study schedule with topics',
        'ar': 'جدول دراسي يومي مع المواضيع',
        'ku': 'خشتەی خوێندنی ڕۆژانە لەگەڵ بابەتەکان',
      },
      {
        'icon': 'task_alt_rounded',
        'en': 'Mark tasks done and track progress',
        'ar': 'علّم المهام كمنجزة وتتبع التقدم',
        'ku': 'ئەرکەکان نیشانە بکە و پێشچوونت بەدواداچوە',
      },
    ],
  );

  static const focus = FeatureIntroData(
    id: 'focus',
    icon: Icons.timer_rounded,
    gradient: [Color(0xFFFF9500), Color(0xFFFF3B30)],
    title: {'en': 'Focus Timer', 'ar': 'مؤقت التركيز', 'ku': 'کاتژمێری تەرکیز'},
    subtitle: {
      'en': 'Use the Pomodoro technique to study smarter and stay focused.',
      'ar': 'استخدم تقنية بومودورو للدراسة بذكاء والتركيز أكثر.',
      'ku': 'شێوازی پۆمۆدۆرۆ بەکاربهێنە بۆ زیرەکانەتر خوێندن و تەرکیزی زیاتر.',
    },
    bullets: [
      {
        'icon': 'play_circle_rounded',
        'en': '25-min focus sessions with 5-min breaks',
        'ar': 'جلسات تركيز ٢٥ دقيقة مع استراحات ٥ دقائق',
        'ku': 'کاتی تەرکیزی ٢٥ خولەک لەگەڵ پاوانی ٥ خولەک',
      },
      {
        'icon': 'self_improvement_rounded',
        'en': 'Reduces mental fatigue and improves productivity',
        'ar': 'يقلل الإرهاق الذهني ويزيد الإنتاجية',
        'ku': 'مێشکخۆشی کەم دەکاتەوە و بەرهەمهێنان زیاد دەکات',
      },
      {
        'icon': 'bar_chart_rounded',
        'en': 'Track total study time per session',
        'ar': 'تتبع إجمالي وقت الدراسة لكل جلسة',
        'ku': 'کۆی کاتی خوێندن لە هەر دانیشتنێکدا بەدواداچوە',
      },
    ],
  );

  static const stats = FeatureIntroData(
    id: 'stats',
    icon: Icons.emoji_events_rounded,
    gradient: [Color(0xFFFFCC00), Color(0xFFFF9500)],
    title: {'en': 'Achievements & Stats', 'ar': 'الإنجازات والإحصائيات', 'ku': 'ئامار و میدالیاکان'},
    subtitle: {
      'en': 'Track your learning progress and earn achievement badges.',
      'ar': 'تابع تقدمك في التعلم واكسب شارات الإنجاز.',
      'ku': 'پێشچوونی خوێندنی خۆت بەدواداچوە و میدالیا وەربگرە.',
    },
    bullets: [
      {
        'icon': 'insights_rounded',
        'en': 'Visual charts of your weekly study activity',
        'ar': 'مخططات مرئية لنشاطك الدراسي الأسبوعي',
        'ku': 'نموداری بینراوی چالاکیی خوێندنی هەفتانەی تە',
      },
      {
        'icon': 'military_tech_rounded',
        'en': 'Earn badges for streaks and milestones',
        'ar': 'اكسب شارات للسلاسل والمعالم',
        'ku': 'میدالیا وەربگرە بۆ بەردەوامی و گەیشتن بە ئامانجەکان',
      },
      {
        'icon': 'local_fire_department_rounded',
        'en': 'Daily streak counter — keep the habit going!',
        'ar': 'عداد الانتظام اليومي — حافظ على العادة!',
        'ku': 'ژمارەی بەردەوامی ڕۆژانە — مامەڵەکەت بەردەوام بگرە!',
      },
    ],
  );

  static const examPredictor = FeatureIntroData(
    id: 'exam_predictor',
    icon: Icons.psychology_rounded,
    gradient: [Color(0xFFAF52DE), Color(0xFF5856D6)],
    title: {'en': 'Exam Predictor', 'ar': 'متنبئ الامتحان', 'ku': 'پێشبینیکەری تاقیکردنەوە'},
    subtitle: {
      'en': 'Paste your notes and let Gemini predict the most likely exam questions.',
      'ar': 'الصق ملاحظاتك ودع Gemini يتوقع أسئلة الامتحان الأرجح.',
      'ku': 'تێبینییەکانت دابنێ و با Gemini ئەو پرسیارانەی پێشبینی بکات کە زۆر ئەگەرن لە تاقیکردنەوەدا بێنەوە.',
    },
    bullets: [
      {
        'icon': 'upload_file_rounded',
        'en': 'Upload notes or paste your lecture content',
        'ar': 'ارفع الملاحظات أو الصق محتوى المحاضرة',
        'ku': 'تێبینییەکان باربکە یان دەقی وانەکە دابنێ',
      },
      {
        'icon': 'lightbulb_rounded',
        'en': 'Gemini analyzes key topics and predicts questions',
        'ar': 'Gemini يحلل المواضيع الأساسية ويتنبأ بالأسئلة',
        'ku': 'Gemini بابەتە سەرەکییەکان شیکاری دەکات و پرسیار پێشبینی دەکات',
      },
      {
        'icon': 'fact_check_rounded',
        'en': 'Review predicted questions before your exam',
        'ar': 'راجع الأسئلة المتوقعة قبل امتحانك',
        'ku': 'پرسیاری پێشبینیکراو بخوێنەرەوە پێش تاقیکردنەوەکەت',
      },
    ],
  );

  static const mindMap = FeatureIntroData(
    id: 'mind_map',
    icon: Icons.hub_rounded,
    gradient: [Color(0xFF00C896), Color(0xFF007AFF)],
    title: {'en': 'Mind Maps', 'ar': 'خرائط المفاهيم', 'ku': 'نەخشەی مێشک'},
    subtitle: {
      'en': 'Visualize any topic as an interactive mind map powered by AI.',
      'ar': 'تصور أي موضوع على شكل خريطة مفاهيم تفاعلية بالذكاء الاصطناعي.',
      'ku': 'هەر بابەتێک بە شێوەی نەخشەی مێشکی کارتێکی و AI بینراو بکە.',
    },
    bullets: [
      {
        'icon': 'search_rounded',
        'en': 'Type any topic and AI builds the mind map',
        'ar': 'اكتب أي موضوع والذكاء يبني خريطة المفاهيم',
        'ku': 'هەر بابەتێک بنووسە و AI نەخشەی مێشکەکە دروست دەکات',
      },
      {
        'icon': 'touch_app_rounded',
        'en': 'Tap nodes to see descriptions',
        'ar': 'انقر على العقد لرؤية الوصف',
        'ku': 'نووکەکان بکلیک بکە بۆ دیتنی پێناسەکان',
      },
      {
        'icon': 'zoom_out_map_rounded',
        'en': 'Pinch to zoom and pan around the map',
        'ar': 'قرّب وباعد وتنقل في الخريطة',
        'ku': 'بۆ زیادکردن و کەمکردنی سایز دوو پەنجەت بەکاربهێنە',
      },
    ],
  );

  static const audioSummarizer = FeatureIntroData(
    id: 'audio_summarizer',
    icon: Icons.mic_rounded,
    gradient: [Color(0xFFFF2D55), Color(0xFFAF52DE)],
    title: {'en': 'Audio Lecture Summarizer', 'ar': 'ملخص المحاضرات الصوتية', 'ku': 'کورتکەرەوەی دەنگی وانەکان'},
    subtitle: {
      'en': 'Upload an audio recording and get a full AI summary of the lecture.',
      'ar': 'ارفع تسجيلاً صوتياً واحصل على ملخص كامل بالذكاء الاصطناعي.',
      'ku': 'تۆماری دەنگی باربکە و کورتکراوەی تەواوی AI وەربگرە.',
    },
    bullets: [
      {
        'icon': 'mic_rounded',
        'en': 'Record your professor\'s lecture live',
        'ar': 'سجّل محاضرة أستاذك مباشرة',
        'ku': 'وانەی مامۆستاکەت بە ڕاستەوخۆ تۆمار بکە',
      },
      {
        'icon': 'audio_file_rounded',
        'en': 'Or upload an existing audio file',
        'ar': 'أو ارفع ملف صوتي موجود',
        'ku': 'یاخود فایلی دەنگی ئامادەکراوێک باربکە',
      },
      {
        'icon': 'summarize_rounded',
        'en': 'Get structured notes from the lecture',
        'ar': 'احصل على ملاحظات منظمة من المحاضرة',
        'ku': 'تێبینییە ڕێکخراوەکان لە وانەکە وەربگرە',
      },
    ],
  );

  static const peerShare = FeatureIntroData(
    id: 'peer_share',
    icon: Icons.qr_code_scanner_rounded,
    gradient: [Color(0xFF007AFF), Color(0xFF34C759)],
    title: {'en': 'Peer Share', 'ar': 'مشاركة كروت الدراسة', 'ku': 'هاوبەشکردنی فلاشکارد'},
    subtitle: {
      'en': 'Share your flashcard decks with classmates using QR codes.',
      'ar': 'شارك مجموعات بطاقاتك مع زملائك باستخدام رموز QR.',
      'ku': 'دێستەی فلاشکارتەکانت بە هاوپۆلانت هاوبەش بکە بە QR کۆد.',
    },
    bullets: [
      {
        'icon': 'qr_code_rounded',
        'en': 'Generate a QR code from your flashcard deck',
        'ar': 'أنشئ كود QR من مجموعة بطاقاتك',
        'ku': 'QR کۆد لە دێستەی فلاشکارتەکەت دروست بکە',
      },
      {
        'icon': 'qr_code_scanner_rounded',
        'en': 'Scan a friend\'s QR to import their deck',
        'ar': 'امسح QR صديقك لاستيراد مجموعته',
        'ku': 'QR هاوڕێیەکەت بکوژێنەوە بۆ هاوردەکردنی دێستەکەی',
      },
      {
        'icon': 'groups_rounded',
        'en': 'Collaborate and study together',
        'ar': 'تعاون وادرس مع الآخرين',
        'ku': 'هاوکاری بکە و پێکەوە بخوێنە',
      },
    ],
  );

  static const notes = FeatureIntroData(
    id: 'notes',
    icon: Icons.note_alt_rounded,
    gradient: [Color(0xFF34C759), Color(0xFF007AFF)],
    title: {'en': 'My Notes', 'ar': 'ملاحظاتي', 'ku': 'تێبینییەکانم'},
    subtitle: {
      'en': 'Write, organize, and AI-format your study notes instantly.',
      'ar': 'اكتب ونظم ملاحظاتك الدراسية وشكّلها بالذكاء الاصطناعي.',
      'ku': 'تێبینییەکانی خوێندنت بنووسە، ڕێکبخە، و بە AI شێوازیان بکە.',
    },
    bullets: [
      {
        'icon': 'edit_note_rounded',
        'en': 'Create notes for any subject with a title and content',
        'ar': 'أنشئ ملاحظات لأي مادة بعنوان ومحتوى',
        'ku': 'تێبینی بۆ هەر بابەتێک بە ناونیشان و دەق دروست بکە',
      },
      {
        'icon': 'auto_awesome_rounded',
        'en': 'AI organizes your notes into structured format',
        'ar': 'الذكاء ينظم ملاحظاتك في تنسيق منظم',
        'ku': 'AI تێبینییەکانت بە شێوازێکی ڕێکخراو ڕێکدەخات',
      },
      {
        'icon': 'share_rounded',
        'en': 'Share your notes with classmates instantly',
        'ar': 'شارك ملاحظاتك مع زملائك فوراً',
        'ku': 'تێبینییەکانت دەستبەجێ هاوبەش بکە لەگەڵ هاوپۆلەکانت',
      },
    ],
  );

  static const schedule = FeatureIntroData(
    id: 'schedule',
    icon: Icons.calendar_today_rounded,
    gradient: [Color(0xFF5856D6), Color(0xFF34C759)],
    title: {'en': 'Class Schedule', 'ar': 'جدول الوانات', 'ku': 'خشتەی وانەکان'},
    subtitle: {
      'en': 'Add and manage your weekly lecture timetable in one place.',
      'ar': 'أضف وأدر جدول محاضراتك الأسبوعي في مكان واحد.',
      'ku': 'خشتەی هەفتانەی وانەکانت لە شوێنێکدا زیاد بکە و بەڕێوەببە.',
    },
    bullets: [
      {
        'icon': 'add_circle_rounded',
        'en': 'Add lectures with name, time, room, and professor',
        'ar': 'أضف المحاضرات باسم المادة والوقت والقاعة والأستاذ',
        'ku': 'وانەکان لەگەڵ ناو، کات، ژوور، و مامۆستا زیاد بکە',
      },
      {
        'icon': 'view_week_rounded',
        'en': 'View your schedule by day of the week',
        'ar': 'اعرض جدولك حسب أيام الأسبوع',
        'ku': 'خشتەکەت بەپێی ڕۆژەکانی هەفتە ببینە',
      },
      {
        'icon': 'home_rounded',
        'en': 'Today\'s lectures appear on the home screen',
        'ar': 'تظهر محاضرات اليوم على الشاشة الرئيسية',
        'ku': 'وانەکانی ئەمڕۆ لە پەڕەی سەرەکییەکەدا دەردەکەون',
      },
    ],
  );
}

// ─── Show Intro Helper ────────────────────────────────────────────────────────
Future<void> showFeatureIntro(
  BuildContext context,
  FeatureIntroData data,
  String lang, // 'ku' | 'ar' | 'en'
) async {
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FeatureIntroSheet(data: data, lang: lang),
  );
}

// ─── Bottom Sheet Widget ──────────────────────────────────────────────────────
class _FeatureIntroSheet extends StatelessWidget {
  final FeatureIntroData data;
  final String lang;

  const _FeatureIntroSheet({required this.data, required this.lang});

  String _t(Map<String, String> map) => map[lang] ?? map['en'] ?? '';

  IconData _iconFromName(String name) {
    const m = {
      'chat_bubble_rounded':            Icons.chat_bubble_rounded,
      'history_edu_rounded':            Icons.history_edu_rounded,
      'record_voice_over_rounded':      Icons.record_voice_over_rounded,
      'upload_file_rounded':            Icons.upload_file_rounded,
      'summarize_rounded':              Icons.summarize_rounded,
      'translate_rounded':              Icons.translate_rounded,
      'add_card_rounded':               Icons.add_card_rounded,
      'flip_rounded':                   Icons.flip_rounded,
      'qr_code_rounded':                Icons.qr_code_rounded,
      'auto_awesome_rounded':           Icons.auto_awesome_rounded,
      'check_circle_rounded':           Icons.check_circle_rounded,
      'history_rounded':                Icons.history_rounded,
      'timer_rounded':                  Icons.timer_rounded,
      'notification_important_rounded': Icons.notification_important_rounded,
      'list_alt_rounded':               Icons.list_alt_rounded,
      'calendar_month_rounded':         Icons.calendar_month_rounded,
      'schedule_rounded':               Icons.schedule_rounded,
      'task_alt_rounded':               Icons.task_alt_rounded,
      'play_circle_rounded':            Icons.play_circle_rounded,
      'self_improvement_rounded':       Icons.self_improvement_rounded,
      'bar_chart_rounded':              Icons.bar_chart_rounded,
      'insights_rounded':               Icons.insights_rounded,
      'military_tech_rounded':          Icons.military_tech_rounded,
      'local_fire_department_rounded':  Icons.local_fire_department_rounded,
      'lightbulb_rounded':              Icons.lightbulb_rounded,
      'fact_check_rounded':             Icons.fact_check_rounded,
      'search_rounded':                 Icons.search_rounded,
      'touch_app_rounded':              Icons.touch_app_rounded,
      'zoom_out_map_rounded':           Icons.zoom_out_map_rounded,
      'mic_rounded':                    Icons.mic_rounded,
      'audio_file_rounded':             Icons.audio_file_rounded,
      'qr_code_scanner_rounded':        Icons.qr_code_scanner_rounded,
      'groups_rounded':                 Icons.groups_rounded,
      'edit_note_rounded':              Icons.edit_note_rounded,
      'share_rounded':                  Icons.share_rounded,
      'view_week_rounded':              Icons.view_week_rounded,
      'add_circle_rounded':             Icons.add_circle_rounded,
      'home_rounded':                   Icons.home_rounded,
    };
    return m[name] ?? Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final primary = data.gradient[0];
    final isRTL = lang == 'ku' || lang == 'ar';

    final gotIt = lang == 'ku' ? 'دەزانم، با بچینە ناو! 🚀' : lang == 'ar' ? 'فهمت، لنبدأ! 🚀' : 'Got it, let\'s go! 🚀';

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon header
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: data.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Icon(data.icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _t(data.title),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              _t(data.subtitle),
              style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Bullets
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: data.bullets.asMap().entries.map((entry) {
                  final i = entry.key;
                  final b = entry.value;
                  final isLast = i == data.bullets.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: data.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_iconFromName(b['icon'] ?? ''), color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _t(b),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 0,
                          indent: 66,
                          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
                          thickness: 0.5,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // CTA button
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Text(gotIt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
