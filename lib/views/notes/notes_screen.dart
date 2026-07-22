import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../services/ai_service.dart';
import '../../services/database_service.dart';
import '../../services/language_provider.dart';
import '../../models/note_model.dart';
import '../../theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedCourse = 'Operating Systems';
  String _selectedCategoryFilter = 'all'; // stable internal key

  bool _isGridView = true;

  NoteModel? _editingNote;
  bool _isAiOrganizing = false;
  bool _currentNoteIsAiFormatted = false;

  final List<String> _courses = [
    'Operating Systems',
    'Calculus & Linear Algebra',
    'Machine Learning Fundamentals',
    'Data Structures & Algorithms',
    'Python & Data Science',
    'Computer Networks & Security',
    'Database Systems & SQL',
    'General Study Notes',
  ];

  final Map<String, Color> _courseColors = {
    'Operating Systems': const Color(0xFF007AFF),
    'Calculus & Linear Algebra': const Color(0xFFFF9F0A),
    'Machine Learning Fundamentals': const Color(0xFFAF52DE),
    'Data Structures & Algorithms': const Color(0xFF5856D6),
    'Python & Data Science': const Color(0xFFFF3B30),
    'Computer Networks & Security': const Color(0xFF34C759),
    'Database Systems & SQL': const Color(0xFF00C7BE),
    'General Study Notes': const Color(0xFF64D2FF),
  };

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getCourseColor(String? course) {
    return _courseColors[course] ?? ZankoColors.primary;
  }

  void _showNoteModal(BuildContext context, [NoteModel? note]) {
    _editingNote = note;
    _currentNoteIsAiFormatted = note?.isAiFormatted ?? false;
    
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _selectedCourse = note.courseName ?? 'General Study Notes';
    } else {
      _titleController.clear();
      _contentController.clear();
      _selectedCourse = 'Operating Systems';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final lang = Provider.of<LanguageProvider>(context, listen: false);
            String t(String key) => lang.translate(key);
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: ZankoShadows.card,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          note == null ? '✍️ Create New Note' : '✏️ Edit Study Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Title Input
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: Provider.of<LanguageProvider>(context, listen: false).translate('note_title_hint'),
                        hintStyle: TextStyle(color: ZankoColors.textSecondary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF6F6FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Course Dropdown
                    DropdownButtonFormField<String>(
                      value: _courses.contains(_selectedCourse) ? _selectedCourse : _courses.first,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF6F6FB),
                        prefixIcon: Icon(Icons.class_rounded, color: _getCourseColor(_selectedCourse)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _courses.map((c) {
                        return DropdownMenuItem<String>(
                          value: c,
                          child: Text(
                            c,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            _selectedCourse = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Note Body Input
                    TextField(
                      controller: _contentController,
                      maxLines: 6,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: Provider.of<LanguageProvider>(context, listen: false).translate('note_content_hint'),
                        hintStyle: TextStyle(color: ZankoColors.textSecondary),
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : const Color(0xFFF6F6FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(CupertinoIcons.mic_fill, color: ZankoColors.primary),
                          tooltip: Provider.of<LanguageProvider>(context, listen: false).translate('dictate_voice_note'),
                          onPressed: () => _startVoiceRecordingModal(context, setModalState),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI Polish Button
                    if (_isAiOrganizing)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                t('ai_organizing_note'),
                                style: TextStyle(fontSize: 13, color: ZankoColors.primary),
                              ),
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
                        icon: const Icon(CupertinoIcons.sparkles, size: 18),
                        label: Text('AI Format & Summarize', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _saveNote(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Save Note', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startVoiceRecordingModal(BuildContext context, StateSetter setModalState) {
    int recordSeconds = 0;
    Timer? recordTimer;
    bool isRecording = true;
    List<double> barHeights = List.generate(12, (_) => 12.0 + Random().nextDouble() * 30.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final lang = Provider.of<LanguageProvider>(context, listen: false);
            String t(String key) => lang.translate(key);
            recordTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (isRecording) {
                setDialogState(() {
                  recordSeconds++;
                  barHeights = List.generate(12, (_) => 12.0 + Random().nextDouble() * 30.0);
                });
              }
            });

            String timeStr = '${(recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(recordSeconds % 60).toString().padLeft(2, '0')}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.mic_circle_fill, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    t('recording_voice_note'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: barHeights.map((h) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 5,
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      recordTimer?.cancel();
                      Navigator.pop(context);

                      final mockTexts = [
                        'پێداچوونەوە بە بەشەکانی یەکەم و دووەمی سیستەمی کارپێکردن بۆ تاقیکردنەوە.',
                        'پڕۆسێسەر مێشکی مۆبایل و کۆمپیوتەرە و بەرپرسی یەکەمە لە جێبەجێکردنی کارەکان.',
                        'خشتەی داتابەیس پێکدێت لە دێڕ و ستوونەکان بۆ پاراستنی زانیاری بەکارھێنەران.'
                      ];

                      final randomText = mockTexts[Random().nextInt(mockTexts.length)];
                      setModalState(() {
                        final currentText = _contentController.text.trim();
                        _contentController.text = currentText.isEmpty ? randomText : '$currentText\n$randomText';
                      });
                    },
                    icon: const Icon(CupertinoIcons.checkmark_circle_fill),
                    label: Text('Done & Insert Text', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveNote(BuildContext context) {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('provide_title_content'))),
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
        courseName: _selectedCourse,
        isAiFormatted: _currentNoteIsAiFormatted || content.contains('ZankoAI'),
      );
      dbService.addNote(newNote);
    } else {
      final updated = _editingNote!.copyWith(
        title: title,
        content: content,
        courseName: _selectedCourse,
        isAiFormatted: _currentNoteIsAiFormatted || content.contains('ZankoAI'),
      );
      dbService.updateNote(updated);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('note_saved'))),
    );
  }

  void _deleteNote(BuildContext context, String noteId) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    dbService.deleteNote(noteId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('note_deleted'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbService = Provider.of<DatabaseService>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    // Filter notes based on search query & category pills
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredNotes = dbService.notes.where((n) {
      final matchesSearch = searchQuery.isEmpty ||
          n.title.toLowerCase().contains(searchQuery) ||
          n.content.toLowerCase().contains(searchQuery) ||
          (n.courseName?.toLowerCase().contains(searchQuery) ?? false);

      if (!matchesSearch) return false;

      if (_selectedCategoryFilter == 'AI Notes ✦') {
        return n.isAiFormatted;
      } else if (_selectedCategoryFilter != 'all') {
        return n.courseName == _selectedCategoryFilter;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withOpacity(0.9),
        elevation: 0,
        title: Text(
          langProvider.translate('notes_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
              color: ZankoColors.primary,
            ),
            tooltip: Provider.of<LanguageProvider>(context, listen: false).translate('toggle_view'),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? [] : ZankoShadows.card,
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEFEFF6),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
                decoration: InputDecoration(
                  icon: const Icon(CupertinoIcons.search, color: ZankoColors.textSecondary, size: 20),
                  hintText: langProvider.translate('search_notes'),
                  hintStyle: TextStyle(fontSize: 14, color: ZankoColors.textSecondary),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // (key, displayLabel) pairs
                ('all', t('filter_all')),
                ('AI Notes ✦', 'AI Notes ✦'),
                ..._courses.map((c) => (c, c)),
              ].map((entry) {
                final catKey = entry.$1;
                final catLabel = entry.$2;
                final isSelected = _selectedCategoryFilter == catKey;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    backgroundColor: isDark ? ZankoColors.darkCard : Colors.white,
                    selectedColor: ZankoColors.primary,
                    side: BorderSide(
                      color: isSelected
                          ? ZankoColors.primary
                          : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E5EA)),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    label: Text(
                      catLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : ZankoColors.textPrimary),
                      ),
                    ),
                    onSelected: (_) => setState(() => _selectedCategoryFilter = catKey),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Notes List / Grid
          Expanded(
            child: filteredNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.doc_text_search,
                          size: 64,
                          color: ZankoColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          t('no_notes_found'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ZankoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return _buildNoteGridCard(context, note, isDark);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return _buildNoteListCard(context, note, isDark);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_notes_unique',
        backgroundColor: ZankoColors.primary,
        elevation: 6,
        icon: const Icon(CupertinoIcons.add, color: Colors.white),
        label: Text(
          t('new_note'),
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: () => _showNoteModal(context),
      ),
    );
  }

  // Grid Note Card Widget
  Widget _buildNoteGridCard(BuildContext context, NoteModel note, bool isDark) {
    final color = _getCourseColor(note.courseName);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String key) => lang.translate(key);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : ZankoShadows.card,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF0F0F6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showNoteModal(context, note),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note.courseName ?? t('general'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isAiFormatted)
                        const Icon(CupertinoIcons.sparkles, color: ZankoColors.accent, size: 14),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    note.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark ? Colors.white70 : ZankoColors.textSecondary,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${note.createdAt.day}/${note.createdAt.month}',
                    style: TextStyle(fontSize: 10, color: ZankoColors.textSecondary),
                  ),
                  Row(
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(CupertinoIcons.share, size: 16, color: Colors.grey),
                        onPressed: () {
                          Share.share(
                            '📌 ${note.title}\n${note.courseName != null ? '📚 ${note.courseName}\n' : ''}\n${note.content}',
                            subject: note.title,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(CupertinoIcons.trash, size: 16, color: Colors.redAccent),
                        onPressed: () => _deleteNote(context, note.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // List Note Card Widget
  Widget _buildNoteListCard(BuildContext context, NoteModel note, bool isDark) {
    final color = _getCourseColor(note.courseName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : ZankoShadows.card,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF0F0F6),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () => _showNoteModal(context, note),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            note.isAiFormatted ? CupertinoIcons.sparkles : CupertinoIcons.doc_text_fill,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          note.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: ZankoColors.textSecondary),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.share, size: 18, color: Colors.grey),
              onPressed: () {
                Share.share(
                  '📌 ${note.title}\n${note.courseName != null ? '📚 ${note.courseName}\n' : ''}\n${note.content}',
                  subject: note.title,
                );
              },
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.trash, size: 18, color: Colors.redAccent),
              onPressed: () => _deleteNote(context, note.id),
            ),
          ],
        ),
      ),
    );
  }
}
