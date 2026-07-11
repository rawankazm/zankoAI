import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../services/language_provider.dart';

class MindMapView extends StatefulWidget {
  const MindMapView({super.key});

  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView> {
  final TextEditingController _topicController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _mindMapData;
  Offset _panOffset = Offset.zero;
  double _zoomScale = 1.0;

  // Custom layout variables
  List<MindMapNode> _nodes = [];
  List<MindMapEdge> _edges = [];

  Future<void> _generateMindMap() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _mindMapData = null;
      _nodes = [];
      _edges = [];
      _panOffset = Offset.zero;
      _zoomScale = 1.0;
    });

    try {
      final aiService = Provider.of<AiService>(context, listen: false);
      
      // Request Gemini to output a strict JSON representation of a mind map
      final prompt = "تکایە نەخشەیەکی مێشک (Mind Map) بۆ ئەم بابەتەی خوارەوە دروست بکە لە شێوەی دەقی JSON ڕێکخراو بە تەواوی. "
          "پێویستە وەڵامەکەت بە زمانی کوردی بێت و تەنها دەقی JSON بێت بەبێ هیچ دەقێکی تر یان تاگی markdown. "
          "نموونەی فۆرماتەکە:\n"
          "{\n"
          "  \"name\": \"بابەتەکە\",\n"
          "  \"description\": \"پێناسەیەکی زۆر کورت\",\n"
          "  \"children\": [\n"
          "    {\n"
          "      \"name\": \"تەوەرەی یەکەم\",\n"
          "      \"description\": \"پێناسەی کورت\",\n"
          "      \"children\": [\n"
          "        {\"name\": \"بابەتی لاوەکی ١\", \"description\": \"پێناسەی کورت\"},\n"
          "        {\"name\": \"بابەتی لاوەکی ٢\", \"description\": \"پێناسەی کورت\"}\n"
          "      ]\n"
          "    }\n"
          "  ]\n"
          "}\n\n"
          "بابەتەکە: $topic";

      String responseText = await aiService.askTeacher(prompt, []);
      
      // Clean up markdown block if present
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final Map<String, dynamic> data = json.decode(responseText);
      setState(() {
        _mindMapData = data;
        _layoutMindMap(data);
      });
    } catch (e) {
      // Fallback mock data in case JSON parsing or call fails
      _loadFallbackMock(topic);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadFallbackMock(String topic) {
    final Map<String, dynamic> mockData = {
      "name": topic,
      "description": "ڕێبەری سەرەکی بابەتەکە",
      "children": [
        {
          "name": "گرنگترین چەمکەکان",
          "description": "بناغە و بیرۆکە سەرەکییەکان",
          "children": [
            {"name": "پێناسە", "description": "تێگەیشتنی سەرەتایی"},
            {"name": "مێژوو", "description": "پاشخانی سەرهەڵدان"}
          ]
        },
        {
          "name": "کارپێکردن و کردارەکان",
          "description": "چۆنیەتی جێبەجێکردن لە پراکتیکدا",
          "children": [
            {"name": "ڕێکارەکان", "description": "هەنگاوەکانی کار"},
            {"name": "بەکارهێنان", "description": "ئەو شوێنانەی سوودی لێ دەبینرێت"}
          ]
        }
      ]
    };
    setState(() {
      _mindMapData = mockData;
      _layoutMindMap(mockData);
    });
  }

  // Calculate layout of nodes using radial arrangement
  void _layoutMindMap(Map<String, dynamic> root) {
    _nodes.clear();
    _edges.clear();

    const double centerX = 500.0;
    const double centerY = 500.0;

    // Root node
    final rootNode = MindMapNode(
      id: 'root',
      label: root['name'] ?? 'Root',
      description: root['description'] ?? '',
      position: const Offset(centerX, centerY),
      depth: 0,
    );
    _nodes.add(rootNode);

    final List<dynamic> children = root['children'] ?? [];
    if (children.isEmpty) return;

    final double angleStep = (2 * pi) / children.length;
    const double radiusLevel1 = 180.0;

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      final double angle = i * angleStep;
      final double x = centerX + radiusLevel1 * cos(angle);
      final double y = centerY + radiusLevel1 * sin(angle);
      
      final String childId = 'child_$i';
      final childNode = MindMapNode(
        id: childId,
        label: child['name'] ?? '',
        description: child['description'] ?? '',
        position: Offset(x, y),
        depth: 1,
      );
      _nodes.add(childNode);
      _edges.add(MindMapEdge(from: rootNode, to: childNode));

      final List<dynamic> subChildren = child['children'] ?? [];
      if (subChildren.isNotEmpty) {
        final double subAngleStep = angleStep / (subChildren.length + 1);
        const double radiusLevel2 = 140.0;
        
        for (int j = 0; j < subChildren.length; j++) {
          final subChild = subChildren[j];
          final double subAngle = (angle - angleStep / 2) + (j + 1) * subAngleStep;
          final double sx = x + radiusLevel2 * cos(subAngle);
          final double sy = y + radiusLevel2 * sin(subAngle);

          final String subChildId = 'sub_${i}_$j';
          final subChildNode = MindMapNode(
            id: subChildId,
            label: subChild['name'] ?? '',
            description: subChild['description'] ?? '',
            position: Offset(sx, sy),
            depth: 2,
          );
          _nodes.add(subChildNode);
          _edges.add(MindMapEdge(from: childNode, to: subChildNode));
        }
      }
    }
  }

  void _showNodeDetails(MindMapNode node) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            node.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
            textAlign: TextAlign.center,
          ),
          content: Text(
            node.description.isNotEmpty ? node.description : 'هیچ ڕوونکردنەوەیەک نییە.',
            style: const TextStyle(height: 1.5, fontFamily: 'Noto Sans Arabic', fontSize: 13.5),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('باشە', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    final String title = langProvider.currentLanguage == AppLanguage.english
        ? 'AI Mind Map'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'خريطة المفاهيم الذكية'
            : 'نەخشەی مێشکی زیرەک';

    final String placeholder = langProvider.currentLanguage == AppLanguage.english
        ? 'Enter topic (e.g. Memory Management)'
        : langProvider.currentLanguage == AppLanguage.arabic
            ? 'أدخل موضوع الخريطة (مثال: إدارة الذاكرة)'
            : 'بابەتێک بنووسە (بۆ نموونە: بیرۆکەی کۆمپیوتەر)';

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: Column(
          children: [
            // Search Input Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: const TextStyle(fontSize: 12, fontFamily: 'Noto Sans Arabic'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generateMindMap,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(60, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded),
                  ),
                ],
              ),
            ),

            // Mind Map Canvas
            Expanded(
              child: _mindMapData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hub_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            langProvider.currentLanguage == AppLanguage.english
                                ? 'Generate a visual map to connect study topics.'
                                : langProvider.currentLanguage == AppLanguage.arabic
                                    ? 'أنشئ خريطة بصرية لربط موضوعات دراستك.'
                                    : 'نەخشەیەکی بینراو دروست بکە بۆ تێگەیشتن لە چەمکەکان.',
                            style: const TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _panOffset += details.delta;
                            });
                          },
                          child: Container(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            child: InteractiveViewer(
                              boundaryMargin: const EdgeInsets.all(1000),
                              minScale: 0.1,
                              maxScale: 3.0,
                              child: Stack(
                                children: [
                                  // Draw connections
                                  CustomPaint(
                                    size: const Size(1000, 1000),
                                    painter: MindMapPainter(
                                      nodes: _nodes,
                                      edges: _edges,
                                      theme: theme,
                                      panOffset: _panOffset,
                                    ),
                                  ),
                                  // Position Interactive Nodes
                                  ..._nodes.map((node) {
                                    final position = node.position + _panOffset;
                                    double size = node.depth == 0 ? 90.0 : (node.depth == 1 ? 75.0 : 60.0);
                                    
                                    return Positioned(
                                      left: position.dx - size / 2,
                                      top: position.dy - size / 2,
                                      child: GestureDetector(
                                        onTap: () => _showNodeDetails(node),
                                        child: Container(
                                          width: size,
                                          height: size,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: node.depth == 0
                                                  ? [theme.colorScheme.primary, theme.colorScheme.secondary]
                                                  : (node.depth == 1
                                                      ? [theme.colorScheme.tertiary, theme.colorScheme.tertiary.withOpacity(0.7)]
                                                      : [Colors.blueGrey.shade700, Colors.blueGrey.shade500]),
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              )
                                            ],
                                            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child: Text(
                                                node.label,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                  fontFamily: 'Noto Sans Arabic',
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MindMapNode {
  final String id;
  final String label;
  final String description;
  final Offset position;
  final int depth;

  MindMapNode({
    required this.id,
    required this.label,
    required this.description,
    required this.position,
    required this.depth,
  });
}

class MindMapEdge {
  final MindMapNode from;
  final MindMapNode to;

  MindMapEdge({required this.from, required this.to});
}

class MindMapPainter extends CustomPainter {
  final List<MindMapNode> nodes;
  final List<MindMapEdge> edges;
  final ThemeData theme;
  final Offset panOffset;

  MindMapPainter({
    required this.nodes,
    required this.edges,
    required this.theme,
    required this.panOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      final start = edge.from.position + panOffset;
      final end = edge.to.position + panOffset;
      
      // Draw bezier curves instead of straight lines for a premium aesthetic
      final controlPoint1 = Offset(start.dx + (end.dx - start.dx) / 2, start.dy);
      final controlPoint2 = Offset(start.dx + (end.dx - start.dx) / 2, end.dy);

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, end.dx, end.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
