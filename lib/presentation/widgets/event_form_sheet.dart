// lib/presentation/widgets/event_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../domain/entities/timeline_event_entity.dart';
import '../../../../theme/app_theme.dart';

class EventFormSheet extends StatefulWidget {
  final TimelineEventEntity? event;
  final Future<void> Function(TimelineEventEntity) onSave;

  const EventFormSheet({super.key, this.event, required this.onSave});

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late DateTime _date;
  late String _icon;
  bool _isSaving = false;

  static const _icons = [
    '💫',
    '🤲',
    '💍',
    '📝',
    '🏠',
    '🎉',
    '❤️',
    '💕',
    '💖',
    '💗',
    '🌹',
    '🎊',
    '🥰',
    '😍',
    '🌟',
    '✨',
    '🎈',
    '🎁',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _date = e?.date ?? DateTime.now();
    _icon = e?.icon ?? '💕';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.pearlWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.softTaupe.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEditing ? 'تعديل الحدث' : 'إضافة ذكرى جديدة',
                style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              _buildField(
                controller: _titleCtrl,
                label: 'عنوان الحدث',
                hint: 'مثال: أول لقاء',
                icon: Icons.title,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'يرجى إدخال العنوان' : null,
              ),
              const SizedBox(height: 16),

              // Description
              _buildField(
                controller: _descCtrl,
                label: 'الوصف',
                hint: 'اكتب تفاصيل هذه الذكرى...',
                icon: Icons.description,
                maxLines: 3,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'يرجى إدخال الوصف' : null,
              ),
              const SizedBox(height: 16),

              // Location (optional)
              _buildField(
                controller: _locationCtrl,
                label: 'المكان (اختياري)',
                hint: 'مثال: منزل العائلة',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),

              // Date picker
              _buildDatePicker(),
              const SizedBox(height: 16),

              // Icon picker
              _buildIconPicker(),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة الحدث'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildDatePicker() {
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'إبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today, color: AppColors.dustyRose),
      title: Text('تاريخ الحدث', style: GoogleFonts.manrope()),
      subtitle: Text(
        '${_date.day} ${months[_date.month]} ${_date.year}',
        style: GoogleFonts.manrope(
          color: AppColors.dustyRose,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.dustyRose,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _date = picked);
      },
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أيقونة الحدث',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: AppColors.dustyRose,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _icons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final icon = _icons[i];
              final selected = _icon == icon;
              return GestureDetector(
                onTap: () => setState(() => _icon = icon),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.dustyRose
                        : AppColors.surfaceRose,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.dustyRose
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final event = TimelineEventEntity(
        id: widget.event?.id ?? const Uuid().v4(),
        date: _date,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        icon: _icon,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        imageUrl: widget.event?.imageUrl,
        orderIndex: widget.event?.orderIndex ?? 0,
        tags: widget.event?.tags ?? [],
        isDemo: widget.event?.isDemo ?? false,
        createdAt: widget.event?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.onSave(event);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
