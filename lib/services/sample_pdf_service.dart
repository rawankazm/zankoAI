import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SamplePdfService {
  static final SamplePdfService _instance = SamplePdfService._internal();
  factory SamplePdfService() => _instance;
  SamplePdfService._internal();

  final Map<String, File> _pdfCache = {};

  /// Get rich text content for a lecture PDF
  String getSampleLectureText(String fileName, String courseTitle) {
    final lower = fileName.toLowerCase();
    final courseLower = courseTitle.toLowerCase();

    if (lower.contains('calc') || courseLower.contains('calc') || courseLower.contains('math')) {
      return '''
ZANKO AI ACADEMIC STUDY MATERIAL
Course: Calculus & Mathematical Analysis
Lecture: Limits, Derivatives & Integrals

--- SECTION 1: LIMITS & CONTINUITY ---
A limit is the value that a function approaches as the input approaches some value.
Formal Definition: lim_{x -> a} f(x) = L.
Continuity condition:
1. f(a) is defined.
2. lim_{x -> a} f(x) exists.
3. lim_{x -> a} f(x) = f(a).

--- SECTION 2: DERIVATIVES & CHAIN RULE ---
The derivative represents the instantaneous rate of change of a function.
Formula: f'(x) = lim_{h -> 0} (f(x+h) - f(x)) / h.
Key Rules:
- Power Rule: d/dx [x^n] = n * x^(n-1)
- Product Rule: d/dx [u * v] = u' * v + u * v'
- Quotient Rule: d/dx [u / v] = (u' * v - u * v') / (v^2)
- Chain Rule: d/dx [f(g(x))] = f'(g(x)) * g'(x)

--- SECTION 3: INTEGRATION & FUNDAMENTAL THEOREM ---
Integration is the reverse process of differentiation (anti-derivative).
Fundamental Theorem of Calculus: Integral from a to b of f(x) dx = F(b) - F(a).

--- PRACTICE PROBLEMS & SOLUTIONS ---
Problem 1: Find lim_{x -> 2} (x^2 - 4) / (x - 2).
Solution: Factor (x^2 - 4) = (x - 2)(x + 2). Cancel (x - 2).
lim_{x -> 2} (x + 2) = 4.

Problem 2: Derivative of f(x) = sin(x^2).
Solution: By Chain Rule, f'(x) = cos(x^2) * 2x = 2x * cos(x^2).
''';
    } else if (lower.contains('os_') || courseLower.contains('operating') || courseLower.contains('system')) {
      return '''
ZANKO AI ACADEMIC STUDY MATERIAL
Course: Operating Systems Architecture
Lecture: Processes, Threads & Memory Management

--- SECTION 1: PROCESS MANAGEMENT & PCB ---
A process is a program in execution.
Process States: New, Ready, Running, Waiting, Terminated.
Process Control Block (PCB) contains:
- Process ID (PID)
- Program Counter (PC)
- CPU Registers & Scheduling Info
- Memory Management Info

--- SECTION 2: THREADS & CONCURRENCY ---
A thread is the smallest unit of CPU execution (Lightweight Process).
Types: User Threads vs Kernel Threads.
Multithreading Models: Many-to-One, One-to-One, Many-to-Many.
Deadlock Conditions (Coffman Conditions):
1. Mutual Exclusion
2. Hold and Wait
3. No Preemption
4. Circular Wait

--- SECTION 3: VIRTUAL MEMORY & PAGING ---
Paging divides physical memory into fixed-size frames and logical memory into pages.
Translation Lookaside Buffer (TLB) acts as a high-speed cache for page table lookups.
Page Fault occurs when a requested page is not in physical RAM and must be fetched from Disk.

--- EXAM REVIEW QUESTIONS ---
Q1: Compare Process vs Thread in terms of overhead and context switching.
Q2: Explain Banker's Algorithm for Deadlock Avoidance.
''';
    } else if (lower.contains('ml_') || courseLower.contains('machine') || courseLower.contains('ai')) {
      return '''
ZANKO AI ACADEMIC STUDY MATERIAL
Course: Artificial Intelligence & Machine Learning
Lecture: Supervised Learning, Neural Networks & Transformers

--- SECTION 1: SUPERVISED VS UNSUPERVISED LEARNING ---
Supervised Learning trains models on labeled data (Input X -> Target Y).
- Regression: Predicts continuous values (e.g. Price, Temperature).
- Classification: Predicts discrete labels (e.g. Spam/Not Spam, Pass/Fail).
Unsupervised Learning finds hidden patterns in unlabeled data (Clustering, K-Means, PCA).

--- SECTION 2: NEURAL NETWORKS & BACKPROPAGATION ---
Artificial Neural Networks (ANN) consist of Input Layer, Hidden Layers, and Output Layer.
Activation Functions:
- ReLU: f(x) = max(0, x)
- Sigmoid: f(x) = 1 / (1 + e^(-x))
- Softmax: Used for multi-class probability output.
Loss Function: Mean Squared Error (MSE) or Cross-Entropy.
Backpropagation uses Gradient Descent and Chain Rule to update weights:
W_new = W_old - learning_rate * (dL/dW).

--- SECTION 3: TRANSFORMERS & LARGE LANGUAGE MODELS ---
Self-Attention Mechanism allows models to weight importance of different tokens in a sequence.
Formula: Attention(Q, K, V) = softmax((Q * K^T) / sqrt(d_k)) * V.
Architecture: Encoder-Decoder framework powering LLMs like Gemini and GPT.
''';
    } else {
      return '''
ZANKO AI ACADEMIC STUDY MATERIAL
Course: $courseTitle
Lecture: $fileName

--- SECTION 1: COURSE OVERVIEW & CORE CONCEPTS ---
Welcome to $courseTitle. This academic guide provides a structural overview of key concepts, definitions, and problem-solving techniques essential for university exams.

--- SECTION 2: KEY THEOREMS & METHODOLOGY ---
1. Concept Definition: Understanding fundamental building blocks.
2. System Analysis: Evaluating operational boundaries and efficiency.
3. Practical Application: Solving real-world case studies and tutorial exercises.

--- SECTION 3: SUMMARY & EXAM PREPARATION ---
- Review primary formulas and definitions daily.
- Practice solving previous semester midterm and final exam questions.
- Use ZankoAI Assistant to generate instant practice quizzes and study summaries.
''';
    }
  }

  /// Generate physical PDF File on device storage
  Future<File> getOrCreateSamplePdf(String fileName, String courseTitle) async {
    final cacheKey = '$courseTitle-$fileName';
    if (_pdfCache.containsKey(cacheKey) && await _pdfCache[cacheKey]!.exists()) {
      return _pdfCache[cacheKey]!;
    }

    final tempDir = await getTemporaryDirectory();
    final safeFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final filePath = '${tempDir.path}/$safeFileName';
    final file = File(filePath);

    if (await file.exists() && await file.length() > 500) {
      _pdfCache[cacheKey] = file;
      return file;
    }

    final textContent = getSampleLectureText(fileName, courseTitle);
    final bytes = await _createPdfBytes(fileName, courseTitle, textContent);
    await file.writeAsBytes(bytes);
    _pdfCache[cacheKey] = file;
    return file;
  }

  /// Create PDF Document bytes using Syncfusion PDF
  Future<Uint8List> _createPdfBytes(String fileName, String courseTitle, String content) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();

    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont subTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.italic);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfBrush primaryBrush = PdfSolidBrush(PdfColor(13, 71, 161));
    final PdfBrush textBrush = PdfSolidBrush(PdfColor(33, 33, 33));

    // Draw Title Header
    page.graphics.drawString(
      'ZANKO AI ACADEMIC MATERIAL',
      titleFont,
      brush: primaryBrush,
      bounds: const Rect.fromLTWH(0, 0, 500, 30),
    );

    page.graphics.drawString(
      'Course: $courseTitle  |  Lecture: $fileName',
      subTitleFont,
      brush: textBrush,
      bounds: const Rect.fromLTWH(0, 32, 500, 20),
    );

    // Draw Separator Line
    page.graphics.drawLine(
      PdfPen(PdfColor(200, 200, 200), width: 1),
      const Offset(0, 56),
      const Offset(500, 56),
    );

    // Draw Content Body
    final PdfTextElement textElement = PdfTextElement(
      text: content,
      font: bodyFont,
      brush: textBrush,
    );

    textElement.draw(
      page: page,
      bounds: const Rect.fromLTWH(0, 70, 500, 680),
    );

    final List<int> bytes = await document.save();
    document.dispose();
    return Uint8List.fromList(bytes);
  }
}
