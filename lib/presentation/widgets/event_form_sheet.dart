// lib/presentation/widgets/event_form_sheet.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/timeline_event_entity.dart';
import '../../generated/l10n.dart';

class EventFormSheet extends StatefulWidget {
  final TimelineEventEntity? event;
  final Future<void> Function(TimelineEventEntity) onSave;

  const EventFormSheet({super.key, this.event, required this.onSave});

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _tagsCtrl;
  late DateTime _date;
  late String _icon;
  String? _localImagePath;
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
    '👶',
    '🤰',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _imageUrlCtrl = TextEditingController(text: e?.imageUrl ?? '');
    _tagsCtrl = TextEditingController(text: e?.tags.join(', ') ?? '');
    _date = e?.date ?? DateTime.now();
    _icon = e?.icon ?? '💕';
    _localImagePath = e?.localImagePath;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _imageUrlCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1440,
        imageQuality: 85,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final fileName = 'event_${const Uuid().v4()}.$ext';
      final savedFile = await File(
        picked.path,
      ).copy('${appDir.path}/$fileName');

      if (mounted) {
        setState(() {
          _localImagePath = savedFile.path;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.event != null;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEditing ? s.editEvent : s.addNewMemory,
                style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              _buildField(
                controller: _titleCtrl,
                label: s.eventTitle,
                hint: s.exampleFirstMeet,
                icon: Icons.title,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? s.enterTitleError : null,
              ),
              const SizedBox(height: 16),

              // Description
              _buildField(
                controller: _descCtrl,
                label: s.description,
                hint: s.writeDetails,
                icon: Icons.description,
                maxLines: 3,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? s.enterDescError : null,
              ),
              const SizedBox(height: 16),

              // Location (optional)
              _buildField(
                controller: _locationCtrl,
                label: s.locationOptional,
                hint: s.exampleFamilyHome,
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),

              // Tags (optional)
              _buildField(
                controller: _tagsCtrl,
                label: s.tagsOptional,
                hint: 'حب, سفر, ذكرى',
                icon: Icons.tag_rounded,
              ),
              const SizedBox(height: 16),

              // Image Picker + Optional URL
              _buildImageSection(context, s),
              const SizedBox(height: 16),

              // Date picker
              _buildDatePicker(context, s),
              const SizedBox(height: 16),

              // Icon picker
              _buildIconPicker(context, s),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Text(isEditing ? s.saveChanges : s.addEvent),
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

  Widget _buildImageSection(BuildContext context, S s) {
    final theme = Theme.of(context);
    final hasLocal =
        _localImagePath != null && File(_localImagePath!).existsSync();
    final hasUrl = _imageUrlCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(s.gallery),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(s.camera),
              ),
            ),
          ],
        ),
        if (hasLocal || hasUrl) ...[
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: hasLocal
                    ? Image.file(
                        File(_localImagePath!),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: _imageUrlCtrl.text.trim(),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          height: 150,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.scrim.withValues(alpha: 0.54),
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _localImagePath = null;
                      _imageUrlCtrl.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          _buildField(
            controller: _imageUrlCtrl,
            label: s.imageUrlOptional,
            hint: 'https://...',
            icon: Icons.link_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context, S s) {
    final theme = Theme.of(context);
    final months = [
      '',
      s.january,
      s.february,
      s.march,
      s.april,
      s.may,
      s.june,
      s.july,
      s.august,
      s.september,
      s.october,
      s.november,
      s.december,
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
      title: Text(
        s.eventDate,
        style: GoogleFonts.manrope(color: theme.colorScheme.onSurface),
      ),
      subtitle: Text(
        '${_date.day} ${months[_date.month]} ${_date.year}',
        style: GoogleFonts.manrope(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) setState(() => _date = picked);
      },
    );
  }

  Widget _buildIconPicker(BuildContext context, S s) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.eventIcon,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
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
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface.withValues(alpha: 0),
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
      final tags = _tagsCtrl.text
          .split(RegExp(r'[,،]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final event = TimelineEventEntity(
        id: widget.event?.id ?? const Uuid().v4(),
        date: _date,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        icon: _icon,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        localImagePath: _localImagePath,
        imageUrl: _imageUrlCtrl.text.trim().isEmpty
            ? null
            : _imageUrlCtrl.text.trim(),
        orderIndex: widget.event?.orderIndex ?? 0,
        tags: tags,
        isDemo: widget.event?.isDemo ?? false,
        createdAt: widget.event?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.onSave(event);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final s = S.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.saveError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
