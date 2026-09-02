import 'package:flutter/material.dart';
import '../data/kurdistan_universities_data.dart';
import '../theme.dart';

/// Interactive Bottom Sheet Picker for Kurdistan Universities and Departments
class UniversityDepartmentPicker {
  /// Show University Selector Modal Bottom Sheet
  static Future<UniversityInfo?> showUniversityPicker(
    BuildContext context, {
    String? selectedUniversityName,
    String? preferredCityKey,
  }) async {
    return showModalBottomSheet<UniversityInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UniversityPickerSheet(
        selectedName: selectedUniversityName,
        initialCityKey: preferredCityKey,
      ),
    );
  }

  /// Show Department Selector Modal Bottom Sheet for a given University
  static Future<String?> showDepartmentPicker(
    BuildContext context, {
    required String universityName,
    String? selectedDepartmentName,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DepartmentPickerSheet(
        universityName: universityName,
        selectedDepartment: selectedDepartmentName,
      ),
    );
  }
}

// =========================================================================
// 1. University Picker Sheet
// =========================================================================
class _UniversityPickerSheet extends StatefulWidget {
  final String? selectedName;
  final String? initialCityKey;

  const _UniversityPickerSheet({
    this.selectedName,
    this.initialCityKey,
  });

  @override
  State<_UniversityPickerSheet> createState() => _UniversityPickerSheetState();
}

class _UniversityPickerSheetState extends State<_UniversityPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customUniCtrl = TextEditingController();
  String _selectedCityFilter = 'all'; // 'all', 'city_erbil', 'city_slemani', 'city_duhok', 'city_karkuk', 'city_halabja'
  String _searchQuery = '';

  final List<Map<String, String>> _cityFilters = [
    {'key': 'all', 'label': 'گشت زانکۆکان 🏛️'},
    {'key': 'city_erbil', 'label': 'هەولێر (Erbil)'},
    {'key': 'city_slemani', 'label': 'سلێمانی (Slemani)'},
    {'key': 'city_duhok', 'label': 'دهۆک (Duhok)'},
    {'key': 'city_karkuk', 'label': 'کەرکووک (Kirkuk)'},
    {'key': 'city_halabja', 'label': 'هەڵەبجە (Halabja)'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCityKey != null &&
        widget.initialCityKey != 'all' &&
        _cityFilters.any((f) => f['key'] == widget.initialCityKey)) {
      _selectedCityFilter = widget.initialCityKey!;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customUniCtrl.dispose();
    super.dispose();
  }

  List<UniversityInfo> get _filteredUniversities {
    return KurdistanUniversitiesData.universities.where((u) {
      // City filter
      if (_selectedCityFilter != 'all') {
        if (u.id != 'other_univ' && u.cityKey != _selectedCityFilter) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return u.nameKu.toLowerCase().contains(q) ||
          u.nameEn.toLowerCase().contains(q) ||
          u.nameAr.toLowerCase().contains(q) ||
          u.cityNameKu.toLowerCase().contains(q) ||
          u.departments.any((d) => d.toLowerCase().contains(q));
    }).toList();
  }

  void _handleCustomUniversity() {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFFF97316)),
            SizedBox(width: 8),
            Text('نووسینی ناوی زانکۆ / پەیمانگە', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: _customUniCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'ناوی زانکۆ یان پەیمانگەکەت بنووسە...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('پەشیمانبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _customUniCtrl.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dlgCtx);
                final customInfo = UniversityInfo(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  nameKu: text,
                  nameEn: text,
                  nameAr: text,
                  cityKey: 'city_erbil',
                  cityNameKu: 'کوردستان',
                  type: 'custom',
                  typeNameKu: 'تایبەت',
                  departments: KurdistanUniversitiesData.commonDepartments,
                );
                Navigator.pop(context, customInfo);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZankoColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('دیاریکردن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCard = isDark ? const Color(0xFF1E1415) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1F2937);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ZankoColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.school_rounded, color: ZankoColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دیاریکردنی زانکۆ / پەیمانگە',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      Text(
                        'زانکۆکانی هەرێمی کوردستان',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'گەڕان بۆ زانکۆ، کۆلێژ یان شار...',
                hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF2A1C1E) : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // City Filter Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _cityFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final f = _cityFilters[idx];
                final isSelected = _selectedCityFilter == f['key'];
                return ChoiceChip(
                  label: Text(
                    f['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: ZankoColors.primary,
                  backgroundColor: isDark ? const Color(0xFF2A1C1E) : const Color(0xFFF3F4F6),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCityFilter = f['key']!);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Universities List
          Expanded(
            child: _filteredUniversities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        const Text('هیچ زانکۆیەک نەدۆزرایەوە'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _handleCustomUniversity,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('ناوی زانکۆکەت بە دەست بنووسە'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZankoColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _filteredUniversities.length,
                    itemBuilder: (ctx, index) {
                      final uni = _filteredUniversities[index];
                      final isSelected = widget.selectedName != null &&
                          (widget.selectedName == uni.nameKu || widget.selectedName == uni.nameEn);

                      if (uni.id == 'other_univ') {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.4), style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(16),
                            color: ZankoColors.primary.withValues(alpha: 0.06),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ZankoColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.edit_note_rounded, color: ZankoColors.primary),
                            ),
                            title: Text(
                              uni.nameKu,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ZankoColors.primary,
                              ),
                            ),
                            subtitle: const Text('پەیمانگە یان کۆلێژێک کە لە لیستەکەدا نییە', style: TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                            onTap: _handleCustomUniversity,
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ZankoColors.primary.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF26181A) : const Color(0xFFF9FAFB)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? ZankoColors.primary
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: _getUniversityBadgeColor(uni.type).withValues(alpha: 0.15),
                            child: Icon(
                              _getUniversityIcon(uni.type),
                              color: _getUniversityBadgeColor(uni.type),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            uni.nameKu,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: textCol,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getUniversityBadgeColor(uni.type).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  uni.typeNameKu,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getUniversityBadgeColor(uni.type),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '📍 ${uni.cityNameKu}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${uni.departments.length - 1} بەش)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: ZankoColors.primary)
                              : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          onTap: () => Navigator.pop(context, uni),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getUniversityBadgeColor(String type) {
    switch (type) {
      case 'public':
        return const Color(0xFF2563EB); // Blue
      case 'polytechnic':
        return const Color(0xFF0D9488); // Teal
      case 'international':
        return const Color(0xFF7C3AED); // Purple
      case 'private':
        return const Color(0xFFEA580C); // Orange
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getUniversityIcon(String type) {
    switch (type) {
      case 'public':
        return Icons.account_balance_rounded;
      case 'polytechnic':
        return Icons.precision_manufacturing_rounded;
      case 'international':
        return Icons.public_rounded;
      case 'private':
        return Icons.business_rounded;
      default:
        return Icons.school_rounded;
    }
  }
}

// =========================================================================
// 2. Department Picker Sheet
// =========================================================================
class _DepartmentPickerSheet extends StatefulWidget {
  final String universityName;
  final String? selectedDepartment;

  const _DepartmentPickerSheet({
    required this.universityName,
    this.selectedDepartment,
  });

  @override
  State<_DepartmentPickerSheet> createState() => _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends State<_DepartmentPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customDeptCtrl = TextEditingController();
  String _searchQuery = '';
  late List<String> _departments;

  @override
  void initState() {
    super.initState();
    _departments = KurdistanUniversitiesData.getDepartmentsFor(widget.universityName);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customDeptCtrl.dispose();
    super.dispose();
  }

  List<String> get _filteredDepartments {
    if (_searchQuery.trim().isEmpty) return _departments;
    final q = _searchQuery.trim().toLowerCase();
    return _departments.where((d) => d.toLowerCase().contains(q)).toList();
  }

  void _handleCustomDepartment() {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFFF97316)),
            SizedBox(width: 8),
            Text('نووسینی ناوی بەش', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: _customDeptCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'ناوی بەش یان لقە زانستییەکەت بنووسە...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('پەشیمانبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _customDeptCtrl.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dlgCtx);
                Navigator.pop(context, text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZankoColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('دیاریکردن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCard = isDark ? const Color(0xFF1E1415) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1F2937);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.account_tree_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دیاریکردنی بەشی زانستی',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      Text(
                        widget.universityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: ZankoColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'گەڕان بۆ ناوی بەش (نموونە: کۆمپیوتەر، پزیشکی، یاسا)...',
                hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF2A1C1E) : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Departments List
          Expanded(
            child: _filteredDepartments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        const Text('هیچ بەشێک نەدۆزرایەوە'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _handleCustomDepartment,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('ناوی بەشەکەت بە دەست بنووسە'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZankoColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _filteredDepartments.length,
                    itemBuilder: (ctx, index) {
                      final dept = _filteredDepartments[index];
                      final isSelected = widget.selectedDepartment != null && widget.selectedDepartment == dept;
                      final isCustomOption = dept.contains('بەشێکی تر') || dept.contains('پشکا دیتر');

                      if (isCustomOption) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF10B981).withValues(alpha: 0.06),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
                            ),
                            title: const Text(
                              'بەشێکی تر (نووسینی بە دەستی خۆت)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            subtitle: const Text('ئەگەر بەشەکەت لەم لیستەدا نەبوو لێرە بینوسە', style: TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                            onTap: _handleCustomDepartment,
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ZankoColors.primary.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF26181A) : const Color(0xFFF9FAFB)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? ZankoColors.primary
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Icon(
                            _getDepartmentIcon(dept),
                            color: isSelected ? ZankoColors.primary : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            size: 20,
                          ),
                          title: Text(
                            dept,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: textCol,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: ZankoColors.primary, size: 20)
                              : null,
                          onTap: () => Navigator.pop(context, dept),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getDepartmentIcon(String dept) {
    final lower = dept.toLowerCase();
    if (lower.contains('پزیشکی') || lower.contains('medicine') || lower.contains('نوژداری')) {
      return Icons.medical_services_rounded;
    } else if (lower.contains('کۆمپیوتەر') || lower.contains('computer') || lower.contains('software') || lower.contains('it')) {
      return Icons.computer_rounded;
    } else if (lower.contains('ئەندازیاری') || lower.contains('engineering')) {
      return Icons.architecture_rounded;
    } else if (lower.contains('یاسا') || lower.contains('law')) {
      return Icons.gavel_rounded;
    } else if (lower.contains('کارگێڕی') || lower.contains('business') || lower.contains('ژمێریاری')) {
      return Icons.analytics_rounded;
    } else if (lower.contains('زمان') || lower.contains('language') || lower.contains('english')) {
      return Icons.translate_rounded;
    } else if (lower.contains('زانست') || lower.contains('science') || lower.contains('کیمیا') || lower.contains('فیزیا')) {
      return Icons.science_rounded;
    } else if (lower.contains('پەروەردە') || lower.contains('education')) {
      return Icons.school_rounded;
    }
    return Icons.folder_open_rounded;
  }
}
