// lib/presentation/screens/memories_album_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/video_project_entity.dart';
import '../../generated/l10n.dart';
import '../providers/media_provider.dart';
import 'video_studio_screen.dart';

class MemoriesAlbumScreen extends ConsumerStatefulWidget {
  const MemoriesAlbumScreen({super.key});

  @override
  ConsumerState<MemoriesAlbumScreen> createState() =>
      _MemoriesAlbumScreenState();
}

class _MemoriesAlbumScreenState extends ConsumerState<MemoriesAlbumScreen> {
  int _filterIndex = 0; // 0: All, 1: Featured, 2: Photos, 3: Videos, 4: Pregnancy
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaProvider);
    final s = S.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(s),
      body: Stack(
        children: [
          _buildBackground(),
          mediaAsync.when(
            data: (media) {
              final filtered = _applyFilter(media);
              return _buildContent(filtered, s);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(s.errorLoadingMemories)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemorySheet(s),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        icon: Icon(
          Icons.add_a_photo_rounded,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        label: Text(
          s.addMemory,
          style: GoogleFonts.manrope(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ).animate().scale(delay: 400.ms),
    );
  }

  AppBar _buildAppBar(S s) {
    return AppBar(
      title: Text(
        s.albumTitle,
        style: GoogleFonts.notoSerif(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          tooltip: 'استوديو الفيديو 🎬',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VideoStudioScreen()),
          ),
          icon: Icon(
            Icons.movie_filter_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _isGridView = !_isGridView),
          icon: Icon(
            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: Theme.of(context).brightness == Brightness.light
                  ? [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface,
                    ]
                  : [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.2),
                      Theme.of(context).colorScheme.surface,
                    ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<MediaFileEntity> media, S s) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 8),
            child: Text(
              s.treasureMoment,
              style: GoogleFonts.notoSerif(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
          ),
        ),

        // Filter tabs — pinned
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterDelegate(child: _buildFilterTabs(s)),
        ),

        if (media.isEmpty)
          SliverFillRemaining(child: _buildEmpty(s))
        else if (_isGridView)
          _buildGrid(media, s)
        else
          _buildList(media, s),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildFilterTabs(S s) {
    final filterLabels = [s.all, s.featured, s.photos, s.videos, s.pregnancy];

    return Container(
      height: 70,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        itemCount: filterLabels.length,
        itemBuilder: (_, i) {
          final label = filterLabels[i];
          final selected = _filterIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
              child: AnimatedContainer(
                duration: AppConstants.shortAnimation,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.outline,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<MediaFileEntity> media, S s) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: media.length,
        itemBuilder: (_, i) {
          final item = media[i];
          return RepaintBoundary(
            child: _MediaCard(
              media: item,
              index: i,
              onTap: () => _handleMediaTap(media, i, s),
              onToggleFeatured: () =>
                  ref.read(mediaProvider.notifier).toggleFeatured(item.id),
              onDelete: () => _confirmDeleteMedia(item, s),
              s: s,
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<MediaFileEntity> media, S s) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((_, i) {
          final item = media[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _MediaThumbnail(media: item),
                ),
              ),
              title: Text(
                item.description ?? s.beautifulMemory,
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${item.uploadDate.day}/${item.uploadDate.month}/${item.uploadDate.year}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      item.isFeatured
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: item.isFeatured
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    onPressed: () => ref
                        .read(mediaProvider.notifier)
                        .toggleFeatured(item.id),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _confirmDeleteMedia(item, s),
                  ),
                ],
              ),
              onTap: () => _handleMediaTap(media, i, s),
            ),
          ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
        }, childCount: media.length),
      ),
    );
  }

  Widget _buildEmpty(S s) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📸', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text(
            s.noMemoriesYet,
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.startDocumenting,
            style: GoogleFonts.manrope(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ).animate().fadeIn().scale(),
    );
  }

  List<MediaFileEntity> _applyFilter(List<MediaFileEntity> media) {
    return switch (_filterIndex) {
      1 => media.where((m) => m.isFeatured).toList(),
      2 => media.where((m) => m.mediaType == MediaType.photo).toList(),
      3 => media.where((m) => m.mediaType == MediaType.video).toList(),
      4 =>
        media
            .where(
              (m) =>
                  m.tags.contains('حمل') ||
                  m.tags.contains('pregnancy') ||
                  (m.description?.contains('حمل') ?? false) ||
                  (m.description?.contains('معاذ') ?? false),
            )
            .toList(),
      _ => media,
    };
  }

  void _handleMediaTap(List<MediaFileEntity> media, int index, S s) {
    final item = media[index];
    if (item.mediaType == MediaType.video &&
        item.fileName != null &&
        item.fileName!.endsWith('.json') &&
        File(item.fileName!).existsSync()) {
      try {
        final raw = File(item.fileName!).readAsStringSync();
        final project = VideoProjectEntity.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoStudioScreen(initialProject: project),
          ),
        );
        return;
      } catch (_) {}
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullScreenGallery(mediaFiles: media, initialIndex: index, s: s),
      ),
    );
  }

  void _confirmDeleteMedia(MediaFileEntity item, S s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          s.confirmDeletion,
          style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
        ),
        content: Text(
          s.areYouSureDeleteEvent(item.description ?? s.beautifulMemory),
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(mediaProvider.notifier).deleteMedia(item.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }

  void _showAddMemorySheet(S s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      builder: (_) => _AddMemorySheet(
        onSave: (media) async {
          await ref.read(mediaProvider.notifier).addMedia(media);
        },
      ),
    );
  }
}

// ─── Add Memory Bottom Sheet ─────────────────────────────────────────────────

class _AddMemorySheet extends StatefulWidget {
  final Future<void> Function(MediaFileEntity) onSave;

  const _AddMemorySheet({required this.onSave});

  @override
  State<_AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<_AddMemorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _localPath;
  bool _isFeatured = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _urlCtrl.dispose();
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
      final fileName = 'memory_${const Uuid().v4()}.$ext';
      final savedFile = await File(
        picked.path,
      ).copy('${appDir.path}/$fileName');

      if (mounted) {
        setState(() {
          _localPath = savedFile.path;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (_localPath == null && _urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.chooseImageSource)));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final tags = _tagsCtrl.text
          .split(RegExp(r'[,،]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final url = _urlCtrl.text.trim();
      final media = MediaFileEntity(
        id: const Uuid().v4(),
        cloudinaryUrl: url,
        thumbnailUrl: url,
        localPath: _localPath,
        mediaType: MediaType.photo,
        uploadDate: _date,
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        isFeatured: _isFeatured,
        tags: tags,
      );

      await widget.onSave(media);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final hasLocal = _localPath != null && File(_localPath!).existsSync();

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
                s.addNewMemory,
                style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
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
              if (hasLocal) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_localPath!),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.scrim.withValues(alpha: 0.54),
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _localPath = null),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: s.imageUrlOptional,
                    hintText: 'https://...',
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? s.enterDescError : null,
                decoration: InputDecoration(
                  labelText: s.description,
                  hintText: s.writeDetails,
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  labelText: s.locationOptional,
                  hintText: s.exampleFamilyHome,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsCtrl,
                decoration: InputDecoration(
                  labelText: s.tagsOptional,
                  hintText: 'حب, حمل, سفر',
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.markAsFeatured, style: GoogleFonts.manrope()),
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.primary,
                ),
                title: Text(s.eventDate, style: GoogleFonts.manrope()),
                subtitle: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: GoogleFonts.manrope(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null && mounted) {
                    setState(() => _date = picked);
                  }
                },
              ),
              const SizedBox(height: 20),
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
                      : Text(s.addMemory),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Media Thumbnail Helper ────────────────────────────────────────────

class _MediaThumbnail extends StatelessWidget {
  final MediaFileEntity media;

  const _MediaThumbnail({required this.media});

  @override
  Widget build(BuildContext context) {
    final hasLocal =
        media.localPath != null && File(media.localPath!).existsSync();
    if (hasLocal) {
      return Image.file(File(media.localPath!), fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: media.thumbnailUrl.isNotEmpty
          ? media.thumbnailUrl
          : media.cloudinaryUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        height: 140,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      errorWidget: (_, _, _) => Container(
        height: 140,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_not_supported,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

// ─── Media Card ───────────────────────────────────────────────────────────────

class _MediaCard extends StatelessWidget {
  final MediaFileEntity media;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onToggleFeatured;
  final VoidCallback onDelete;
  final S s;

  const _MediaCard({
    required this.media,
    required this.index,
    required this.onTap,
    required this.onToggleFeatured,
    required this.onDelete,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: onTap,
          onLongPress: onDelete,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    _MediaThumbnail(media: media),
                    if (media.mediaType == MediaType.video)
                      Positioned.fill(
                        child: Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.scrim.withValues(alpha: 0.26),
                          child: Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onToggleFeatured,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: media.isFeatured
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(
                                    context,
                                  ).colorScheme.scrim.withValues(alpha: 0.38),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            media.isFeatured
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (media.description != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    media.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  '${media.uploadDate.day}/${media.uploadDate.month}/${media.uploadDate.year}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (index * 50).ms)
        .scale(begin: const Offset(0.95, 0.95));
  }
}

// ─── Full Screen Gallery ──────────────────────────────────────────────────────

class FullScreenGallery extends ConsumerStatefulWidget {
  final List<MediaFileEntity> mediaFiles;
  final int initialIndex;
  final S s;

  const FullScreenGallery({
    super.key,
    required this.mediaFiles,
    required this.initialIndex,
    required this.s,
  });

  @override
  ConsumerState<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends ConsumerState<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  late List<MediaFileEntity> _items;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.mediaFiles);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageProvider _resolveImageProvider(MediaFileEntity m) {
    if (m.localPath != null && File(m.localPath!).existsSync()) {
      return FileImage(File(m.localPath!));
    }
    return CachedNetworkImageProvider(m.cloudinaryUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(backgroundColor: Theme.of(context).colorScheme.scrim);
    }
    final current = _items[_currentIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.scrim,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${_items.length}',
          style: GoogleFonts.manrope(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              current.isFeatured
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: current.isFeatured
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () async {
              await ref.read(mediaProvider.notifier).toggleFeatured(current.id);
              if (!mounted) return;
              setState(() {
                _items[_currentIndex] = current.copyWith(
                  isFeatured: !current.isFeatured,
                );
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              await ref.read(mediaProvider.notifier).deleteMedia(current.id);
              if (!mounted) return;
              setState(() {
                _items.removeAt(_currentIndex);
                if (_items.isEmpty) {
                  Navigator.pop(context);
                } else if (_currentIndex >= _items.length) {
                  _currentIndex = _items.length - 1;
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              _showInfo ? Icons.info_rounded : Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => setState(() => _showInfo = !_showInfo),
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (_, index) {
              final m = _items[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: _resolveImageProvider(m),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            itemCount: _items.length,
            loadingBuilder: (_, _) => Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            pageController: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
          ),
          if (_showInfo)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.scrim.withValues(alpha: 0.8),
                          Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          current.description ?? widget.s.beautifulMemory,
                          style: GoogleFonts.notoSerif(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${current.uploadDate.day}/${current.uploadDate.month}/${current.uploadDate.year}',
                              style: GoogleFonts.manrope(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            if (current.location != null) ...[
                              const SizedBox(width: 16),
                              Icon(
                                Icons.location_on_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  current.location!,
                                  style: GoogleFonts.manrope(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: 1, end: 0),
        ],
      ),
    );
  }
}

// ─── Filter Delegate ──────────────────────────────────────────────────────────

class _FilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _FilterDelegate({required this.child});

  @override
  Widget build(_, _, _) => child;
  @override
  double get maxExtent => 70;
  @override
  double get minExtent => 70;
  @override
  bool shouldRebuild(_FilterDelegate old) => true;
}
