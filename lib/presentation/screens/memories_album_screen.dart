// lib/presentation/screens/memories_album_screen.dart
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../../generated/l10n.dart';
import '../providers/media_provider.dart';

class MemoriesAlbumScreen extends ConsumerStatefulWidget {
  const MemoriesAlbumScreen({super.key});

  @override
  ConsumerState<MemoriesAlbumScreen> createState() =>
      _MemoriesAlbumScreenState();
}

class _MemoriesAlbumScreenState extends ConsumerState<MemoriesAlbumScreen> {
  int _filterIndex = 0; // 0: All, 1: Featured, 2: Photos, 3: Videos
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addMemory(s),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
      ).animate().scale(delay: 1.seconds),
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
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
    final filterLabels = [s.all, s.featured, s.photos, s.videos, 'حمل'];

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
            child: AnimatedContainer(
              duration: AppConstants.shortAnimation,
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
          return RepaintBoundary(
            child: _MediaCard(
              media: media[i],
              index: i,
              onTap: () => _openGallery(media, i, s),
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
                child: CachedNetworkImage(
                  imageUrl: item.thumbnailUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
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
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              onTap: () => _openGallery(media, i, s),
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
      _ => media,
    };
  }

  void _openGallery(List<MediaFileEntity> media, int index, S s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullScreenGallery(mediaFiles: media, initialIndex: index, s: s),
      ),
    );
  }

  void _addMemory(S s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.addMemorySoon),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ─── Media Card ───────────────────────────────────────────────────────────────

class _MediaCard extends StatelessWidget {
  final MediaFileEntity media;
  final int index;
  final VoidCallback onTap;
  final S s;

  const _MediaCard({
    required this.media,
    required this.index,
    required this.onTap,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: media.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 140,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        height: 140,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    if (media.mediaType == MediaType.video)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    if (media.isFeatured)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 14,
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

class FullScreenGallery extends StatefulWidget {
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
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.mediaFiles[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.mediaFiles.length}',
          style: GoogleFonts.manrope(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showInfo ? Icons.info_rounded : Icons.info_outline_rounded,
              color: Colors.white,
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
              final m = widget.mediaFiles[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(m.cloudinaryUrl),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            itemCount: widget.mediaFiles.length,
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
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
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
                            color: Colors.white,
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
                                color: Colors.white70,
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
                                    color: Colors.white70,
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
