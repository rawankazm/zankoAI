import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../services/ai_service.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../models/note_model.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  
  NoteModel? _editingNote;
  bool _isAiOrganizing = false;
  bool _currentNoteIsAiFormatted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  void _showNoteModal(BuildContext context, [NoteModel? note]) {
    _editingNote = note;
    _currentNoteIsAiFormatted = note?.isAiFormatted ?? false;
    
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _courseController.text = note.courseName ?? '';
    } else {
      _titleController.clear();
      _contentController.clear();
      _courseController.clear();
    }

    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String t(String key) => langProvider.translate(key);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: langProvider.textDirection,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        note == null ? t('add_note_title') : t('edit_note_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Noto Sans Arabic'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: t('note_title_label'),
                          hintText: t('note_title_hint'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _courseController,
                        decoration: InputDecoration(
                          labelText: t('note_course_label'),
                          hintText: 'e.g. Operating Systems',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: t('note_content_label'),
                          hintText: t('note_content_hint'),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.mic, color: Colors.blueAccent),
                            tooltip: 'Simulate Kurdish Voice Note',
                            onPressed: () => _startVoiceRecordingModal(context, setModalState),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_isAiOrganizing)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('AI خەریکی پۆلێنکردن و ڕێکخستنی دەقەکەیە...', style: TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 12)),
                              ],
                            ),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () async {
                            final rawContent = _contentController.text.trim();
                            if (rawContent.isEmpty) return;

                            setModalState(() => _isAiOrganizing = true);
                            
                            final aiService = Provider.of<AiService>(context, listen: false);
                            try {
                              final polished = await aiService.organizeNote(rawContent);
                              setModalState(() {
                                _contentController.text = polished;
                                _isAiOrganizing = false;
                                _currentNoteIsAiFormatted = true;
                              });
                            } catch (e) {
                              setModalState(() => _isAiOrganizing = false);
                            }
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(t('ai_organize_btn')),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
                        ),
                        
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveNote(context, t),
                              child: Text(t('save')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(t('close')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Voice recording mock modal with animated wave bars and timer
  void _startVoiceRecordingModal(BuildContext context, StateSetter setModalState) {
    int recordSeconds = 0;
    Timer? recordTimer;
    bool isRecording = true;
    List<double> barHeights = List.generate(10, (_) => 10.0 + Random().nextDouble() * 30.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            recordTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (isRecording) {
                setDialogState(() {
                  recordSeconds++;
                  // Randomize bar heights for visual waves
                  barHeights = List.generate(10, (_) => 10.0 + Random().nextDouble() * 30.0);
                });
              }
            });

            String timeStr = '${(recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(recordSeconds % 60).toString().padLeft(2, '0')}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'تۆمارکردنی دەنگی بە زمانی کوردی',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, size: 50, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Animated waveform bars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: barHeights.map((h) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 6,
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  
                  ElevatedButton(
                    onPressed: () {
                      recordTimer?.cancel();
                      Navigator.pop(context);
                      
                      // Append translated mock text matching notes
                      final mockTexts = [
                        'پێداچوونەوە بە بەشەکانی یەکەم و دووەمی سیستەمی کارپێکردن بۆ تاقیکردنەوە.',
                        'پڕۆسێسەر مێشکی مۆبایل و کۆمپیوتەرە و بەرپرسی یەکەمە لە جێبەجێکردنی کارەکان.',
                        'خشتەی داتابەیس پێکدێت لە دێڕ و ستوونەکان بۆ پاراستنی زانیاری بەکارھێنەران.'
                      ];
                      
                      final randomText = mockTexts[Random().nextInt(mockTexts.length)];
                      
                      setModalState(() {
                        final currentText = _contentController.text.trim();
                        _contentController.text = currentText.isEmpty 
                            ? randomText 
                            : '$currentText\n$randomText';
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('تەواوکردن و بەکارهێنان / Done', style: TextStyle(fontFamily: 'Noto Sans Arabic')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveNote(BuildContext context, String Function(String) t) {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final course = _courseController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە سەردێڕ و ناوەڕۆک پڕبکەرەوە', style: TextStyle(fontFamily: 'Noto Sans Arabic'))),
      );
      return;
    }

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    if (_editingNote == null) {
      final newNote = NoteModel(
        id: const Uuid().v4(),
        title: title,
        content: content,
        createdAt: DateTime.now(),
        courseName: course.isNotEmpty ? course : null,
        isAiFormatted: _currentNoteIsAiFormatted || content.contains('ZankoAI') || content.contains('ڕێکخستن'),
      );
      dbService.addNote(newNote);
    } else {
      final updated = _editingNote!.copyWith(
        title: title,
        content: content,
        courseName: course.isNotEmpty ? course : null,
        isAiFormatted: _currentNoteIsAiFormatted || content.contains('ZankoAI') || content.contains('ڕێکخست'),
      );
      dbService.updateNote(updated);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('save_note_success'), style: const TextStyle(fontFamily: 'Noto Sans Arabic'))),
    );
  }

  void _deleteNote(BuildContext context, String noteId, String Function(String) t) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    dbService.deleteNote(noteId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('delete_note_success'), style: const TextStyle(fontFamily: 'Noto Sans Arabic'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('notes_title')),
        ),
        body: dbService.notes.isEmpty
            ? Center(
                child: Text(
                  t('no_notes'),
                  style: const TextStyle(fontFamily: 'Noto Sans Arabic', fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: dbService.notes.length,
                itemBuilder: (context, index) {
                  final note = dbService.notes[index];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: Icon(
                        note.isAiFormatted ? Icons.auto_awesome : Icons.edit_note,
                        color: note.isAiFormatted ? Colors.purple : theme.colorScheme.primary,
                      ),
                      title: Text(
                        note.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic'),
                      ),
                      subtitle: Text(
                        note.courseName ?? t('uncategorized'),
                        style: const TextStyle(fontSize: 12, fontFamily: 'Noto Sans Arabic'),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                note.content,
                                style: const TextStyle(fontFamily: 'Noto Sans Arabic', height: 1.4),
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded, color: Colors.green),
                                    tooltip: 'هاوبەشکردن',
                                    onPressed: () {
                                      Share.share(
                                        '📌 ${note.title}\n${note.courseName != null ? '📚 ${note.courseName}\n' : ''}\n${note.content}',
                                        subject: note.title,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showNoteModal(context, note),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteNote(context, note.id, t),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab_notes_unique',
          onPressed: () => _showNoteModal(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
