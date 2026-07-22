import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';

class GpaTrackerScreen extends StatefulWidget {
  const GpaTrackerScreen({super.key});

  @override
  State<GpaTrackerScreen> createState() => _GpaTrackerScreenState();
}

class _GpaTrackerScreenState extends State<GpaTrackerScreen> {
  final TextEditingController _gpaInputController = TextEditingController();
  final TextEditingController _targetGpaController = TextEditingController();
  final TextEditingController _semestersRemainingController = TextEditingController();
  String _gpaPlannerResult = '';

  @override
  void dispose() {
    _gpaInputController.dispose();
    _targetGpaController.dispose();
    _semestersRemainingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    final user = authService.currentUser;
    final gpaHistory = user?.gpaHistory ?? [3.2, 3.4, 3.65, 3.8];
    final currentGpa = user?.gpa ?? 3.65;

    final lang = Provider.of<LanguageProvider>(context);
    String t(String key) => lang.translate(key);

    // Translations
    final title = t('gpa_title');
    final totalGpaText = t('gpa_total');
    final chartHeader = t('gpa_chart_header');
    final addGpaLabel = t('gpa_add_label');
    final addBtn = t('gpa_add_btn');
    final listHeader = t('gpa_list_header');
    final semesterLabel = t('gpa_semester_label');

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // GPA Total Display
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        totalGpaText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentGpa.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Chart Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chartHeader,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, ),
                      ),
                      const SizedBox(height: 24),
                      // Line chart container
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: GpaChartPainter(gpaHistory, theme.brightness == Brightness.dark, theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Add GPA Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _gpaInputController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: addGpaLabel,
                            hintText: 'e.g. 3.75',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Simple state update for mock tracking
                          final val = double.tryParse(_gpaInputController.text.trim());
                          if (val != null && val >= 0.0 && val <= 4.0) {
                            setState(() {
                              gpaHistory.add(val);
                              _gpaInputController.clear();
                            });
                          }
                        },
                        child: Text(addBtn),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Target GPA Planner Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t('target_planner_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _targetGpaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: Provider.of<LanguageProvider>(context, listen: false).translate('target_gpa'),
                                hintText: 'e.g. 3.8',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _semestersRemainingController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: Provider.of<LanguageProvider>(context, listen: false).translate('remaining_semesters'),
                                hintText: 'e.g. 3',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          final target = double.tryParse(_targetGpaController.text.trim());
                          final remaining = int.tryParse(_semestersRemainingController.text.trim());
                          if (target == null || target < 0.0 || target > 4.0 || remaining == null || remaining <= 0) {
                            setState(() {
                              _gpaPlannerResult = t('planner_input_error');
                            });
                            return;
                          }

                          final totalCompletedSemesters = gpaHistory.length;
                          final currentCumGpa = currentGpa;

                          // Calculation formula
                          final totalSemesters = totalCompletedSemesters + remaining;
                          final requiredSum = (target * totalSemesters) - (currentCumGpa * totalCompletedSemesters);
                          final requiredGpa = requiredSum / remaining;

                          setState(() {
                            final gpaStr = requiredGpa.toStringAsFixed(2);
                            if (requiredGpa > 4.0) {
                              _gpaPlannerResult = t('planner_cannot_reach').replaceAll('{required}', gpaStr);
                            } else if (requiredGpa < 0.0) {
                              _gpaPlannerResult = t('planner_already_met');
                            } else {
                              _gpaPlannerResult = t('planner_required').replaceAll('{required}', gpaStr);
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                        child: Text(t('calculate'), style: const TextStyle()),
                      ),
                      if (_gpaPlannerResult.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _gpaPlannerResult,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // List of Semesters
              Text(
                listHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (gpaHistory.isEmpty)
                Center(child: Padding(padding: EdgeInsets.all(16), child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('empty_record'))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gpaHistory.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text((index + 1).toString()),
                        ),
                        title: Text(
                          '$semesterLabel ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              gpaHistory[index].toStringAsFixed(2),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  gpaHistory.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter to draw a premium line graph of GPA history
class GpaChartPainter extends CustomPainter {
  final List<double> gpaHistory;
  final bool isDarkMode;
  final Color primaryColor;

  GpaChartPainter(this.gpaHistory, this.isDarkMode, this.primaryColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (gpaHistory.isEmpty) return;

    final paintLine = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintGlow = Paint()
      ..color = primaryColor.withOpacity(0.15)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final paintDotBorder = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = isDarkMode ? Colors.white12 : Colors.black12
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw horizontal grid lines (for GPA scales 1.0, 2.0, 3.0, 4.0)
    for (int i = 1; i <= 4; i++) {
      final y = size.height - (i * size.height / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      
      // Draw labels
      textPainter.text = TextSpan(
        text: '$i.0',
        style: TextStyle(
          color: isDarkMode ? Colors.white38 : Colors.black38,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - 24, y - 12));
    }

    if (gpaHistory.length < 2) {
      // Draw single point
      final y = size.height - (gpaHistory[0] * size.height / 4);
      final offset = Offset(size.width / 2, y);
      canvas.drawCircle(offset, 6, paintDot);
      canvas.drawCircle(offset, 6, paintDotBorder);
      return;
    }

    final double stepX = size.width / (gpaHistory.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < gpaHistory.length; i++) {
      final double x = i * stepX;
      // GPA max scale is 4.0
      final double y = size.height - (gpaHistory[i] * size.height / 4);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      // Draw quadratic bezier curves for smooth premium curvature
      final prevPoint = points[i - 1];
      final currentPoint = points[i];
      final controlPointX = prevPoint.dx + (currentPoint.dx - prevPoint.dx) / 2;
      path.cubicTo(
        controlPointX,
        prevPoint.dy,
        controlPointX,
        currentPoint.dy,
        currentPoint.dx,
        currentPoint.dy,
      );
    }

    // Draw glow shadow behind the line
    canvas.drawPath(path, paintGlow);
    // Draw the main line
    canvas.drawPath(path, paintLine);

    // Draw the glowing circular nodes
    for (var point in points) {
      canvas.drawCircle(point, 6, paintDot);
      canvas.drawCircle(point, 6, paintDotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant GpaChartPainter oldDelegate) {
    return oldDelegate.gpaHistory != gpaHistory || oldDelegate.isDarkMode != isDarkMode;
  }
}
