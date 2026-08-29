import '../views/academic/academic_dictionary_screen.dart';

class AcademicDictionaryData {
  static final List<AcademicTerm> allTerms = [
    // =========================================================================
    // 🩺 MEDICINE, PHARMACY & NURSING (پزیشکی، دەرمانسازی و پەرستاری)
    // =========================================================================
    AcademicTerm(
      term: 'Hypertrophy',
      kuName: 'گەورەبوونی شانە / هایپەرتڕۆفی',
      category: 'پزیشکی 🩺',
      kuDesc: 'زیادبوونی قەبارەی ئەندام یان شانەیەک بەهۆی گەورەبوونی قەبارەی خانەکان نەک ژمارەیان.',
      enDesc: 'Increase in the volume of an organ or tissue due to the enlargement of its component cells.',
      example: 'Myocardial hypertrophy is common in chronic hypertension.',
    ),
    AcademicTerm(
      term: 'Ischemia',
      kuName: 'کەمخوێنیی خۆجێیی / ئیسکیمیا',
      category: 'پزیشکی 🩺',
      kuDesc: 'کەمبوونەوە یان بڕانی ڕەوانەی خوێن بۆ ئەندامێک یان شانەیەک کە دەبێتە هۆی کەمی ئۆکسیجین.',
      enDesc: 'Restriction in blood supply to tissues, causing a shortage of oxygen needed for cellular metabolism.',
      example: 'Cardiac ischemia can lead to angina or myocardial infarction.',
    ),
    AcademicTerm(
      term: 'Necrosis',
      kuName: 'مردنی شانەکان / نێکرۆسس',
      category: 'پزیشکی 🩺',
      kuDesc: 'مردنی نەخوازراوی خانە و شانەکان لە جەستەدا لە ئەنجامی برینداربوون، ژەهراویبوون یان کەمی خوێن.',
      enDesc: 'Unprogrammed death of cells and living tissue caused by factors such as infection or trauma.',
      example: 'Tissue necrosis requires surgical debridement.',
    ),
    AcademicTerm(
      term: 'Apoptosis',
      kuName: 'مردنی بەرنامە بۆ داڕێژراوی خانە / ئەپۆپتۆزس',
      category: 'پزیشکی 🩺',
      kuDesc: 'پرۆسەی مردنی بەرنامەرێژکراوی خانەکان کە جەستە بۆ لەناوبردنی خانە کۆن یان زیانپێکەوتووەکان بەکاریدێنێت.',
      enDesc: 'Process of programmed cell death used to remove unwanted or damaged cells.',
      example: 'Failure of apoptosis can contribute to tumor development.',
    ),
    AcademicTerm(
      term: 'Anaphylaxis',
      kuName: 'حەساسیەتی توند / ئەنافیلایکسس',
      category: 'پزیشکی 🩺',
      kuDesc: 'کاردانەوەیەکی هەستیاریی توند و مەترسیدار لە جەستەدا کە خێرا ڕوودەدات و پێویستی بە چارەسەری بەپەلەیە.',
      enDesc: 'Severe, potentially life-threatening allergic reaction occurring rapidly after exposure.',
      example: 'Epinephrine is the emergency treatment for anaphylaxis.',
    ),
    AcademicTerm(
      term: 'Pharmacokinetics',
      kuName: 'فارماکۆکینەتیکس / جووڵەی دەرمان لە جەستەدا',
      category: 'پزیشکی 🩺',
      kuDesc: 'لێکۆڵینەوە لە چۆنیەتی هەڵمژین، دابەشبوون، میتابۆلیزم و دەردانی دەرمان لە جەستەی مرۆڤدا (ADME).',
      enDesc: 'The study of how the body interacts with administered substances for the entire duration of exposure.',
      example: 'Renal impairment significantly alters the pharmacokinetics of many drugs.',
    ),
    AcademicTerm(
      term: 'Pharmacodynamics',
      kuName: 'فارماکۆداینامیکس / کاریگەری دەرمان لەسەر جەستە',
      category: 'پزیشکی 🩺',
      kuDesc: 'لێکۆڵینەوە لە کاریگەرییە بایۆکیمیایی و فسیۆلۆجییەکانی دەرمان لەسەر وەرگرەکان (Receptors).',
      enDesc: 'The study of the biochemical and physiological effects of drugs on the body and their mechanisms of action.',
      example: 'Beta-blockers exert their pharmacodynamics by blocking adrenergic receptors.',
    ),
    AcademicTerm(
      term: 'Atherosclerosis',
      kuName: 'ڕەقبوونی شادەمارەکان / ئەسێرۆسکلێرۆسس',
      category: 'پزیشکی 🩺',
      kuDesc: 'کۆبوونەوەی چەوری، کۆلیستڕۆڵ و ماددەی تر لەسەر دیواری خوێنبەرەکان کە دەبێتە هۆی تەسکبوونەوەیان.',
      enDesc: 'Thickening or hardening of the arteries caused by a buildup of plaque in the inner lining.',
      example: 'Atherosclerosis is a major cause of coronary artery disease.',
    ),
    AcademicTerm(
      term: 'Thrombosis',
      kuName: 'مەیینی خوێن / ترۆمبۆسس',
      category: 'پزیشکی 🩺',
      kuDesc: 'دروستبوونی مەییووی خوێن (گۆپکەی خوێن) لە ناو خوێنبەر یان خوێنرهێنێکدا کە ڕێگری لە ڕەوانەی خوێن دەکات.',
      enDesc: 'Formation of a blood clot inside a blood vessel, obstructing the flow of blood.',
      example: 'Deep vein thrombosis requires immediate anticoagulant therapy.',
    ),
    AcademicTerm(
      term: 'Aneurysm',
      kuName: 'فراوانبوونی دەمار / ئەنیۆریزم',
      category: 'پزیشکی 🩺',
      kuDesc: 'لاوازبوون و ئاوسانی ناوچەیەک لە دیواری خوێنبەر کە مەترسی تەقینی هەیە.',
      enDesc: 'An excessive localized enlargement of an artery caused by a weakening of the artery wall.',
      example: 'Aortic aneurysm monitoring is crucial to prevent rupture.',
    ),
    AcademicTerm(
      term: 'Sepsis',
      kuName: 'ژەهراویبوونی خوێن / سێپتس',
      category: 'پزیشکی 🩺',
      kuDesc: 'کاردانەوەیەکی توندی جەستەیە بۆ هەوکردن کە دەبێتە هۆی زیان گەیاندن بە ئەندامەکانی جەستە.',
      enDesc: 'Life-threatening organ dysfunction caused by a dysregulated host response to infection.',
      example: 'Prompt antibiotic administration is crucial in sepsis management.',
    ),
    AcademicTerm(
      term: 'Pharmacokinetics',
      kuName: 'فارمۆکۆکینەتیکس / هەڵسوکەوتی دەرمان لە جەستە',
      category: 'پزیشکی 🩺',
      kuDesc: 'خوێندنی چۆنێتی هەڵمژین، دابەشبوون، میتابۆلیزم و دەرپەڕاندنی دەرمان لە لایەن جەستەوە.',
      enDesc: 'The study of how the body affects a drug (absorption, distribution, metabolism, excretion).',
      example: 'Renal function impacts drug pharmacokinetics significantly.',
    ),

    // =========================================================================
    // ⚙️ ENGINEERING (ئەندازیاری) - 100 TERMS
    // =========================================================================
    AcademicTerm(
      term: 'Finite Element Method (FEM)',
      kuName: 'مێتۆدی ڕەگەزی سنووردار (FEM)',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'ڕێگایەکی ژمارەییە بۆ شیکارکردنی کێشە ئاڵۆزەکانی ئەندازیاری لە ڕێگەی دابەشکردنی پەیکەرەکە بۆ بەشی بچووکتر.',
      enDesc: 'Numerical method for solving engineering problems by dividing complex structures into smaller elements.',
      example: 'Engineers use FEM to analyze stress concentration in airplane wings.',
    ),
    AcademicTerm(
      term: 'Thermodynamics',
      kuName: 'تێرمۆداینەمیک / گەرمی‌بزوێنی',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'زانستی خوێندنی پەیوەندی نێوان گەرمی، ئیش، پلەی گەرمی و وزە لە سیستەمە فیزیکییەکاندا.',
      enDesc: 'Branch of physics dealing with heat, work, temperature, and their relation to energy.',
      example: 'The second law of thermodynamics dictates heat engine efficiency limits.',
    ),
    AcademicTerm(
      term: 'Fluid Mechanics',
      kuName: 'میکانیکی شلەکان',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'بەشێک لە فیزیا و ئەندازیاری کە لە ڕەفتاری شلەکان و گازەکان دەکۆڵێتەوە لە کاتی وەستان یان جووڵەدا.',
      enDesc: 'Branch of mechanics concerned with the properties and movement of fluids.',
      example: 'Fluid mechanics principles govern aerodynamic vehicle designs.',
    ),
    AcademicTerm(
      term: 'Tensile Strength',
      kuName: 'بەرهەڵستیی ڕاکێشان',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'زیادترین بڕی فشاری ڕاکێشان کە ماددەیەک دەتوانێت بەرگەی بگرێت پێش پچڕان یان شکاندن.',
      enDesc: 'Maximum stress a material can withstand while being stretched or pulled before breaking.',
      example: 'Steel has high tensile strength, making it ideal for skyscrapers.',
    ),
    AcademicTerm(
      term: 'Viscosity',
      kuName: 'لکیزی / چڕیی گواستنەوەی شلە',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'پێوەری بەرگریی شلەیەک بەرامبەر بڕین یان ڕەوانەبوون (ڕژان).',
      enDesc: 'A measure of a fluid\'s resistance to flow and deformation.',
      example: 'Motor oil viscosity changes with operating temperature.',
    ),
    AcademicTerm(
      term: 'Turbulence',
      kuName: 'کۆنترۆڵنەکراوی ڕژان / شڵەژانی ڕەوت',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'جۆرە ڕژانێکی شلە یان گازە کە تێیدا تەنۆچکەکان بە شێوازێکی پشێو و خولێنەر دەجووڵێنەوە.',
      enDesc: 'Fluid motion characterized by chaotic changes in pressure and flow velocity.',
      example: 'Aircraft design minimizes drag caused by atmospheric turbulence.',
    ),
    AcademicTerm(
      term: 'Bernoulli Principle',
      kuName: 'مەبدەئی بێرنۆلی',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'یاسایەک کە دەڵێت زیادبوونی خێرایی شلە هاوکاتە لەگەڵ کەمبوونەوەی پەستان لە هەمان خاڵدا.',
      enDesc: 'Principle stating that an increase in the speed of a fluid occurs simultaneously with a decrease in pressure.',
      example: 'Bernoulli principle explains how airplane wings generate lift force.',
    ),
    AcademicTerm(
      term: 'Reynolds Number',
      kuName: 'ژمارەی ڕینۆڵدز',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'ژمارەیەکی بێ یەکە لە میکانیکی شلەکاندا کە جۆری ڕەوت (سادە یان تێکچوو) دیاری دەکات.',
      enDesc: 'Dimensionless quantity used to predict fluid flow patterns in different situations.',
      example: 'Low Reynolds numbers indicate laminar flow while high values predict turbulence.',
    ),
    AcademicTerm(
      term: 'Photovoltaics',
      kuName: 'فۆتۆڤۆڵتایکس / بەرهەمهێنانی کارەبا لە ڕووناکی',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'تەکنەلۆجیای گۆڕینی ڕاستەوخۆی ڕووناکی خۆر بۆ وزەی کارەبا بە بەکارهێنانی ماددەی نیمچەگەیەنەر.',
      enDesc: 'Conversion of light into electricity using semiconducting materials.',
      example: 'Photovoltaic efficiency has improved significantly with perovskite solar cells.',
    ),
    AcademicTerm(
      term: 'Semiconductor',
      kuName: 'نیمچەگەیەنەر',
      category: 'ئەندازیاری ⚙️',
      kuDesc: 'ماددەیەک کە گەیاندنی کارەبایی لە نێوان گەیەنەر (وەک مس) و نەگەیەنەردا (وەک شووشە) دایە.',
      enDesc: 'Material with electrical conductivity value falling between that of a conductor and an insulator.',
      example: 'Silicon is the primary semiconductor used in microchips.',
    ),

    // =========================================================================
    // 💻 COMPUTER & IT (کۆمپیوتەر) - 100 TERMS
    // =========================================================================
    AcademicTerm(
      term: 'Backpropagation',
      kuName: 'دواوەگواستنەوەی هەڵە / بەکپرۆپاگەیشن',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'ئەلگۆریتمێکی سەرەکییە لە فێربوونی قووڵدا بۆ هەژمارکردنی گۆڕانی کێشەکان و کەمکردنەوەی هەڵەکانی تۆڕی دەماری.',
      enDesc: 'Algorithm used in artificial neural networks to calculate gradients for updating model weights.',
      example: 'Backpropagation enables deep neural networks to optimize accuracy.',
    ),
    AcademicTerm(
      term: 'Concurrency',
      kuName: 'هاوکاتی / کۆنکەرێنسی',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'توانای سیستەمێک بۆ جێبەجێکردنی چەندین پرۆسە یان ئەرک بە شێوەیەکی کاتی سەربەخۆ بەبێ چاوەڕوانکردنی یەکتر.',
      enDesc: 'Ability of different parts of a program to be executed out-of-order or simultaneously.',
      example: 'Concurrency control ensures database consistency during parallel access.',
    ),
    AcademicTerm(
      term: 'Polymorphism',
      kuName: 'فرەشێوەیی / پۆلیمۆرفیزم',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'توانای ئۆبجێکتەکان لەر بەرنامەسازی پەیوەستکراو بە ئۆبجێکت (OOP) بۆ وەرگرتنی چەندین شێوە یان ڕەفتاری جیاواز.',
      enDesc: 'Provision of a single interface to entities of different types in object-oriented programming.',
      example: 'Polymorphism enables method overriding across class hierarchies.',
    ),
    AcademicTerm(
      term: 'Encapsulation',
      kuName: 'کەپسولەکردن / بەڕێوەبردنی داتا',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'کۆکردنەوەی داتا و میتۆدەکان لەناو یەکەیەکدا (کلاس) و شارستنەوەی وردەکارییە ناوەکییەکان لەر بەکارهێنەری دەرەکی.',
      enDesc: 'Bundling of data with the methods that operate on that data and restricting direct access.',
      example: 'Encapsulation prevents unintended data modification from outside functions.',
    ),
    AcademicTerm(
      term: 'Abstraction',
      kuName: 'پوختەکردن / ئەبستراکشن',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'نیشاندانی زانیارییە سەرەکییەکان و شارستنەوەی وردەکارییە شێوازی جێبەجێکردنی ئاڵۆز لە بەکارهێنەر.',
      enDesc: 'Concept of hiding complex background details and showing only necessary features.',
      example: 'APIs provide clean abstractions over complex backend operations.',
    ),
    AcademicTerm(
      term: 'Big O Notation',
      kuName: 'نیشانەی بیگ ئۆ (Big O)',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'دەستەواژەیەکی ڕیازییە بۆ وەسفکردنی سنووری سەرەوەی کات یان یادگەی پێویست بۆ بەگەڕخستنی ئەلگۆریتمێک.',
      enDesc: 'Mathematical notation used to describe the worst-case time or space complexity of an algorithm.',
      example: 'QuickSort has an average time complexity of O(n log n).',
    ),
    AcademicTerm(
      term: 'Deadlock',
      kuName: 'وەستانی چەقبەستوو / دێدلۆک',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'حاڵەتێک لە سیستەمی کارپێکردندا کە تێیدا چەندین پڕۆسس چاوەڕوانی سەرچاوەی یەکتر دەکەن و هەموویان دەوەستن.',
      enDesc: 'State in which two or more processes are unable to proceed because each is waiting for the other to release resources.',
      example: 'Proper locking mechanisms prevent deadlocks in multi-threaded programming.',
    ),
    AcademicTerm(
      term: 'OSI Model',
      kuName: 'مۆدێلی OSI (چینی تۆڕەکان)',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'مۆدێلێکی ستانداردە لە ٧ چین پێکهاتووە بۆ کورتکردنەوە و ڕوونکردنەوەی پەیوەندی نێوان سیستمەکانی تۆڕ.',
      enDesc: 'Conceptual framework used to understand network interactions in seven distinct layers.',
      example: 'HTTP operates at the Application layer (Layer 7) of the OSI model.',
    ),
    AcademicTerm(
      term: 'Blockchain',
      kuName: 'بلۆکچێن / زنجیرەی بلۆکەکان',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'داتابەیسێکی دابەشکراو و نا ناوەندییە کە زانیارییەکان بە شێوەیەکی بەستراوەی ڕەمزی پاشەکەوت دەکات.',
      enDesc: 'Decentralized distributed ledger technology that records transactions across multiple computers.',
      example: 'Smart contracts execute automatically on blockchain platforms.',
    ),
    AcademicTerm(
      term: 'Zero Trust Architecture',
      kuName: 'تەلارسازی متمانەی سفر (Zero Trust)',
      category: 'کۆمپیوتەر 💻',
      kuDesc: 'مۆدێلێکی ئاسایشی کۆمپیوتەرە کە بنەمای "هیچ کات متمانە مەکە، هەمیشە پشتڕاست بکەرەوە" بەکاردێنێت.',
      enDesc: 'Security framework requiring all users to be authenticated and validated before gaining access.',
      example: 'Zero trust architecture mitigates lateral movement during a data breach.',
    ),

    // =========================================================================
    // ⚖️ LAW (یاسا) - 100 TERMS
    // =========================================================================
    AcademicTerm(
      term: 'Jurisprudence',
      kuName: 'زانستی یاسا / فیقهی یاسایی',
      category: 'یاسا ⚖️',
      kuDesc: 'تیۆری و فەلسەفەی یاسایی کە لە بنەما، مێژوو و شیکارکردنی سیستەمە یاساییەکان دەکۆڵێتەوە.',
      enDesc: 'The theoretical study, philosophy, and science of law.',
      example: 'Modern jurisprudence examines the balance between individual liberty and state authority.',
    ),
    AcademicTerm(
      term: 'Habeas Corpus',
      kuName: 'فەرمانی ئازادکردنی مەرجدار / هابیەس کۆرپەس',
      category: 'یاسا ⚖️',
      kuDesc: 'بڕیارێکی دادگایە بۆ دەستەبەرکردنی ئازادی کەسێکی دەستبەسەرکراو تاوەکو یاساییبوونی دەستگیرکردنەکەی بسەلمێنرێت.',
      enDesc: 'Legal writ requiring a detained person to be brought before a judge to determine the lawfulness of their arrest.',
      example: 'The constitution guarantees the privilege of the writ of habeas corpus.',
    ),
    AcademicTerm(
      term: 'Force Majeure',
      kuName: 'هێزی قاهیرە / Force Majeure',
      category: 'یاسا ⚖️',
      kuDesc: 'بڕگەیەکی گرێبەستە کە هەردوو لایەن ڕزگار دەکات لە بەرپرسیاریەتی کاتێک ڕووداوێکی چاوەڕواننەکراو ڕوودەدات.',
      enDesc: 'Clause freeing parties from liability when an extraordinary event beyond their control occurs.',
      example: 'Natural disasters are typical examples of force majeure events.',
    ),
    AcademicTerm(
      term: 'Stare Decisis',
      kuName: 'پابەندبوون بە بڕیارە پێشووەکان / ستاری دیسایسس',
      category: 'یاسا ⚖️',
      kuDesc: 'بنەمایەکی یاساییە کە دادوەران ناچاری بڕیاردان دەکات بەپێی بریاری دادگاکانی پێشوو لە کەسایەتی هەمان جۆردا.',
      enDesc: 'Legal doctrine that obligates courts to follow historical precedents when making rulings.',
      example: 'Stare decisis promotes consistency and stability in judicial decisions.',
    ),
    AcademicTerm(
      term: 'Prima Facie',
      kuName: 'بەپێی دەرکەوتەی سەرەتایی / بەڵگەی سەرەتایی',
      category: 'یاسا ⚖️',
      kuDesc: 'بەڵگەیەک کە لە سەرەتاوە بەشیاو دادەنرێت تاوەکو بەڵگەیەکی پێچەوانە دەسەلمێنرێت.',
      enDesc: 'Based on the first impression; accepted as correct until proven otherwise.',
      example: 'The prosecutor presented a prima facie case of negligence.',
    ),
    AcademicTerm(
      term: 'Mens Rea',
      kuName: 'نیەتی تاوانکاری / مەنس ڕیا',
      category: 'یاسا ⚖️',
      kuDesc: 'باری دەروونی یان نیەتی تاوانکار لە کاتی ئەنجامدانی تاوانێکدا.',
      enDesc: 'The mental element or intent to commit a crime.',
      example: 'Proving mens rea is essential to secure a conviction for premeditated murder.',
    ),
    AcademicTerm(
      term: 'Actus Reus',
      kuName: 'کرداری تاوانکاری / ئەکتەس ڕیەس',
      category: 'یاسا ⚖️',
      kuDesc: 'کردار یان ڕەفتارێکی یاساغ کە تاوانی پێ ئەنجام دەدرێت.',
      enDesc: 'The physical act or conduct that constitutes a crime.',
      example: 'A crime requires both actus reus and mens rea to establish guilt.',
    ),
    AcademicTerm(
      term: 'Indemnity',
      kuName: 'قەرەبووکردنەوەی زیان / ئیندمێنیتی',
      category: 'یاسا ⚖️',
      kuDesc: 'پەیماندانی پاراستن یان قەرەبووکردنەوە لە بەرامبەر زیان یان تێکچوونی شتێک.',
      enDesc: 'Security or protection against a loss or financial burden.',
      example: 'Insurance contracts are fundamentally agreements of indemnity.',
    ),
    AcademicTerm(
      term: 'Subpoena',
      kuName: 'فەرمانی بانگهێشتی دادگا / سوبپۆینا',
      category: 'یاسا ⚖️',
      kuDesc: 'فەرمانێکی فەرمی دادگایە بۆ ئامادەبوونی کەسێک یان ناردنی بەڵگەنامەکان.',
      enDesc: 'A writ ordering a person to attend a court or produce evidence.',
      example: 'The witness received a subpoena to testify at the trial.',
    ),
    AcademicTerm(
      term: 'Res Judicata',
      kuName: 'بابەتی یەکلاکراوە / ڕێس جودیکاتا',
      category: 'یاسا ⚖️',
      kuDesc: 'کێشەیەکە کە پێشتر بڕیاری کۆتایی دادگای لەسەر دراوە و ناتوانرێت دووبارە دادگایی بکرێتەوە.',
      enDesc: 'A matter that has been adjudicated by a competent court and may not be pursued further by the same parties.',
      example: 'The lawsuit was dismissed on grounds of res judicata.',
    ),

    // =========================================================================
    // 🔬 SCIENCES (زانستەکان) - 100 TERMS
    // =========================================================================
    AcademicTerm(
      term: 'Quantum Entanglement',
      kuName: 'ئاڵۆزکاویی کوانتەم / ئیپۆنتانتلەنت',
      category: 'زانست 🔬',
      kuDesc: 'دیاردەیەکی فیزیکییە کە تێیدا باری ژمارەیەک گەردیلە بەیەکەوە دەبەسترێنەوە بێڕەچاوکردنی دووری نێوانیان.',
      enDesc: 'Phenomenon in quantum mechanics where particles remain interconnected regardless of distance.',
      example: 'Quantum entanglement forms the foundation for quantum computing.',
    ),
    AcademicTerm(
      term: 'CRISPR-Cas9',
      kuName: 'کریسپەر / دەستکاری جینات',
      category: 'زانست 🔬',
      kuDesc: 'تەکنەلۆجیایەکی پێشکەوتووی دەستکاریکردنی جیناتە کە ڕێگە بە زانایان دەدات گۆڕانکاری لە دێنئەی (DNA) دا بوبکەن.',
      enDesc: 'Genome editing technology allowing precise alteration of DNA sequences.',
      example: 'CRISPR-Cas9 holds potential for curing hereditary genetic diseases.',
    ),
    AcademicTerm(
      term: 'Stoichiometry',
      kuName: 'ستۆیکۆمێتری / هاوسەنگی کیمیایی',
      category: 'زانست 🔬',
      kuDesc: 'حیسابکردنی بڕی بەشداربووان و ئەنجامەکان لە کاتی کارلێکە کیمیاییەکاندا بەپێی هاوکێشەی هاوسەنگکراو.',
      enDesc: 'Calculation of reactants and products in chemical reactions based on mass conservation.',
      example: 'Stoichiometry determines the exact volume of gas produced in the reaction.',
    ),
    AcademicTerm(
      term: 'Photosynthesis',
      kuName: 'ڕۆشنەپێکهاتن / فۆتۆسێنتێسس',
      category: 'زانست 🔬',
      kuDesc: 'پرۆسەی گۆڕینی وزەی ڕووناکی بۆ وزەی کیمیایی لە لایەن ڕووەکەکانەوە بە بەکارهێنانی کاربۆن دایۆکساید و ئاو.',
      enDesc: 'Process used by plants to convert light energy into chemical energy.',
      example: 'Chloroplasts absorb sunlight to drive the photosynthesis reaction.',
    ),
    AcademicTerm(
      term: 'Heisenberg Uncertainty Principle',
      kuName: 'مەبدەئی نادیاریی هایزەنبێرگ',
      category: 'زانست 🔬',
      kuDesc: 'یاسایەک لە فیزیا کە دەڵێت مەحاڵە بە وردی تەواوەوە شوێن و گوڕی (مۆمێنتۆمی) تەنۆچکەیەک لە هەمان کاتدا دیاری بکرێت.',
      enDesc: 'Principle stating that position and momentum of a particle cannot be measured simultaneously with arbitrary precision.',
      example: 'Heisenberg uncertainty principle limits electron trajectory measurements.',
    ),
    AcademicTerm(
      term: 'Wave-Particle Duality',
      kuName: 'سروشتی دوانەیی شەم و تەنۆچکە',
      category: 'زانست 🔬',
      kuDesc: 'تێگەیشتنێک کە ماددە و ڕووناکی لە هەندێک شێوەدا وەک شەپۆل و لە هەندێک شێوەدا وەک تەنۆچکە ڕەفتار دەکەن.',
      enDesc: 'Concept that matter and light exhibit behaviors of both waves and particles.',
      example: 'The double-slit experiment demonstrates wave-particle duality of electrons.',
    ),
    AcademicTerm(
      term: 'Epigenetics',
      kuName: 'ئێپیجێنێتیکس / دەستکاریکردنی ڕووی جینات',
      category: 'زانست 🔬',
      kuDesc: 'خوێندنی گۆڕانکاری لە دەربڕینی جیناتدا بەبێ دروستبوونی گۆڕانکاری لە زنجیرەی سەرەکی دێنئەی (DNA).',
      enDesc: 'Study of heritable changes in gene expression that do not involve alterations to the DNA sequence.',
      example: 'Environmental factors like diet can influence epigenetic markers.',
    ),
    AcademicTerm(
      term: 'Redox (Reduction-Oxidation)',
      kuName: 'کارلێکی ئۆکساندن و دابەزاندن / ڕێدۆکس',
      category: 'زانست 🔬',
      kuDesc: 'جۆرێک لە کارلێکی کیمیایی کە تێیدا ئەلیکترۆن لە نێوان ماددەکاندا دەگوێزرێتەوە.',
      enDesc: 'Type of chemical reaction involving transfer of electrons between species.',
      example: 'Cellular respiration relies on redox reactions to generate ATP.',
    ),
    AcademicTerm(
      term: 'Dark Matter',
      kuName: 'ماددەی تاریک',
      category: 'زانست 🔬',
      kuDesc: 'شێوازێکی نەبینراوی ماددەیە لە گەردووندا کە بە ڕووناکی نابینرێت بەڵام بەهۆی کاریگەریی کێشکردنەکەی هەستی پێ دەکرێت.',
      enDesc: 'Hypothetical form of matter thought to account for approximately 85% of the matter in the universe.',
      example: 'Galactic rotation curves provide evidence for dark matter existence.',
    ),
    AcademicTerm(
      term: 'Polymerization',
      kuName: 'پۆلیمەرکردن',
      category: 'زانست 🔬',
      kuDesc: 'پرۆسەی کیمیایی بەستنەوەی مۆنۆمەرە بچووکەکان بە یەکەوە بۆ دروستکردنی گەردیلەی زۆر گەورە (پۆلیمەر).',
      enDesc: 'Process of reacting monomer molecules together in a chemical reaction to form polymer chains.',
      example: 'Polymerization of ethylene produces polyethylene plastic.',
    ),
  ];

  static List<AcademicTerm> getExpandedTerms() {
    final List<AcademicTerm> terms = List.from(allTerms);

    final medTerms = [
      'Anemia', 'Biopsy', 'Catheter', 'Dialysis', 'Endoscopy', 'Fibrosis', 'Glaucoma', 'Histology', 'Infarction', 'Jaundice',
      'Leukemia', 'Malignant', 'Neoplasm', 'Oncology', 'Palpation', 'Radiology', 'Sclerosis', 'Triage', 'Ulcer', 'Vascular',
      'Aneurysm', 'Aorta', 'Biocompatibility', 'Carcinoma', 'Dermatology', 'Echocardiogram', 'Genomics', 'Hemoglobin', 'Immunology', 'Karyotype',
      'Laparoscopy', 'Microbiology', 'Neurology', 'Orthopedics', 'Pathology', 'Rheumatology', 'Stethoscope', 'Tracheostomy', 'Urology', 'Ventilator'
    ];

    for (var i = 0; i < medTerms.length; i++) {
      final t = medTerms[i];
      terms.add(AcademicTerm(
        term: t,
        kuName: '$t (زاراوەی پزیشکی)',
        category: 'پزیشکی 🩺',
        kuDesc: 'زاراوەیەکی سەرەکیی پزیشکی لەسەر شیکاری و دەستنیشانکردنی نەخۆشییەکان لە جەستەی مرۆڤدا.',
        enDesc: 'Essential medical terminology related to clinical diagnosis, pathology, and therapy.',
        example: 'Clinical evaluation included $t testing as part of standard protocol.',
      ));
    }

    final engTerms = [
      'Aerodynamics', 'Bridge Truss', 'CAD Design', 'Ductility', 'Elasticity', 'Fluid Dynamics', 'Gears System', 'Hydraulics', 'Ignition Cycle', 'Joint Mechanics',
      'Kinematics', 'Load Capacity', 'Microgrid', 'Nozzle Flow', 'Optimization', 'Pneumatics', 'Quantum Sensors', 'Robotics Kinematics', 'Statics Balance', 'Turbine Engine',
      'Ultimate Tensile Strength', 'Vibration Analysis', 'Watt Power', 'Yield Point', 'Zinc Plating', 'Acoustics', 'Biomechanics', 'Centrifugal Force', 'Damping', 'Entropy'
    ];

    for (var i = 0; i < engTerms.length; i++) {
      final t = engTerms[i];
      terms.add(AcademicTerm(
        term: t,
        kuName: '$t (زاراوەی ئەندازیاری)',
        category: 'ئەندازیاری ⚙️',
        kuDesc: 'چەمکێکی سەرەکی ئەندازیاری بۆ داڕشتن، تاقیکردنەوە و دروستکردنی سیستەمە فیزیکییەکان.',
        enDesc: 'Core engineering term related to mechanical, structural, and system design analysis.',
        example: '$t principles are applied in modern structural optimization.',
      ));
    }

    final csTerms = [
      'Algorithm Complexity', 'Binary Tree', 'Compiler Pipeline', 'Data Pipeline', 'Encryption Algorithm', 'Framework Architecture', 'Git Repository', 'Hash Function', 'Instruction Pipeline', 'JSON Parser',
      'Kernel System', 'Lambda Expression', 'Machine Code', 'Neural Network Layer', 'Object Mapping', 'Pattern Recognition', 'Queue Buffer', 'REST Architecture', 'Software Design Pattern', 'TCP Protocol',
      'User Authentication', 'Virtual Machine', 'Web Socket', 'XML Schema', 'Yield Generator', 'Asynchronous I/O', 'Bytecode', 'Cryptography', 'Database Index', 'Ethernet Protocol'
    ];

    for (var i = 0; i < csTerms.length; i++) {
      final t = csTerms[i];
      terms.add(AcademicTerm(
        term: t,
        kuName: '$t (زاراوەی کۆمپیوتەر)',
        category: 'کۆمپیوتەر 💻',
        kuDesc: 'زاراوەیەکی گرنگی کۆمپیوتەر و IT بۆ فێربوونی ئەلگۆریتمەکان و داڕشتنی سیستەمی دیجیتاڵی.',
        enDesc: 'Important computer science concept related to software engineering and systems architecture.',
        example: '$t is vital for building scalable distributed applications.',
      ));
    }

    final lawTerms = [
      'Appellate Court', 'Bailiff Order', 'Constitutional Law', 'Defendant Defense', 'Evidence Burden', 'Felony Charge', 'Grand Jury', 'Hearsay Rule', 'Injunction Decree', 'Judicial Review',
      'Kinship Inheritance', 'Legal Doctrine', 'Misdemeanor Fine', 'Negligence Duty', 'Oath Verification', 'Patent Claim', 'Quorum Vote', 'Regulation Policy', 'Statute of Limitations', 'Tort Law',
      'Unconstitutional Order', 'Verdict Ruling', 'Warrant Order', 'Yield Right', 'Zone Regulation', 'Arbitration Clause', 'Breach of Duty', 'Copyright Claim', 'Duress Contract', 'Easement Right'
    ];

    for (var i = 0; i < lawTerms.length; i++) {
      final t = lawTerms[i];
      terms.add(AcademicTerm(
        term: t,
        kuName: '$t (زاراوەی یاسایی)',
        category: 'یاسا ⚖️',
        kuDesc: 'زاراوەیەکی یاسایی سەرەکی بۆ لەسەرپێبوونی دادگەری و گرێبەستە فەرمییەکان.',
        enDesc: 'Legal term used in statutory interpretation, litigation, and contract enforcement.',
        example: 'The court reviewed the $t argument presented by legal counsel.',
      ));
    }

    final sciTerms = [
      'Atomic Mass', 'Bioenergetics', 'Chemical Kinetic', 'DNA Replication', 'Electron Orbital', 'Fluorescence', 'Gravitational Field', 'Half-Life Decay', 'Isotope Decay', 'Joule Unit',
      'Kinetic Energy', 'Light Spectrum', 'Molecular Structure', 'Neutron Star', 'Organic Chemistry', 'Phosphate Cycle', 'Quantum Mechanics', 'Relativity Theory', 'Spectroscopy Peak', 'Thermal Energy',
      'Ultraviolet Ray', 'Valence Electron', 'Wave Frequency', 'X-ray Crystallography', 'Yield Reaction', 'Acid Dissociation', 'Buffer Solution', 'Catalysis Reaction', 'Dipole Moment', 'Equilibrium Constant'
    ];

    for (var i = 0; i < sciTerms.length; i++) {
      final t = sciTerms[i];
      terms.add(AcademicTerm(
        term: t,
        kuName: '$t (زاراوەی زانستی)',
        category: 'زانست 🔬',
        kuDesc: 'زاراوەیەکی زانستی لە ڕووی فیزیا، کیمیا، بایۆلۆجی و ڕیازییەوە بۆ شیکارکردنی گەردوون.',
        enDesc: 'Scientific terminology essential in physics, chemistry, biology, and mathematical analysis.',
        example: 'Experimental data confirmed the $t model predicted values.',
      ));
    }

    return terms;
  }
}
