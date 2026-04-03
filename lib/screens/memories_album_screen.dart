import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/media_file.dart';
import '../models/timeline_event.dart';
import '../theme/app_theme.dart';

class MemoriesAlbumScreen extends StatefulWidget {
  const MemoriesAlbumScreen({super.key});

  @override
  State<MemoriesAlbumScreen> createState() => _MemoriesAlbumScreenState();
}

class _MemoriesAlbumScreenState extends State<MemoriesAlbumScreen>
    with TickerProviderStateMixin {
  List<MediaFile> _allMediaFiles = [];
  List<MediaFile> _filteredMediaFiles = [];
  List<TimelineEvent> _events = [];
  String _selectedFilter = 'الكل';
  bool _isLoading = false;
  bool _isGridView = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
    });

    // المحاكاة
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _allMediaFiles = MediaFile.getDemoMediaFiles();
          _filteredMediaFiles = _allMediaFiles;
          _events = TimelineEvent.getDemoEvents();
          _isLoading = false;
        });
      }
    });
  }

  void _filterMedia(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'الكل') {
        _filteredMediaFiles = _allMediaFiles;
      } else if (filter == 'المميزة') {
        _filteredMediaFiles = _allMediaFiles
            .where((media) => media.isFeatured)
            .toList();
      } else if (filter == 'الفيديوهات') {
        _filteredMediaFiles = _allMediaFiles
            .where((media) => media.mediaType == MediaType.video)
            .toList();
      } else if (filter == 'الصور') {
        _filteredMediaFiles = _allMediaFiles
            .where((media) => media.mediaType == MediaType.photo)
            .toList();
      } else {
        final event = _events.firstWhere(
          (e) => e.title == filter,
          orElse: () => _events.first,
        );
        _filteredMediaFiles = _allMediaFiles
            .where((media) => media.eventId == event.id)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'ألبوم الذكريات',
          style: GoogleFonts.notoSerif(
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
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
            ),
            color: AppColors.dustyRose,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceRose,
                    AppColors.pearlWhite,
                    AppColors.pearlWhite,
                  ],
                ),
              ),
            ),
          ),

          _isLoading ? _buildLoadingWidget() : _buildContent(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewMemory,
        backgroundColor: AppColors.dustyRose,
        elevation: 4,
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
      ).animate().scale(delay: 1.seconds),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 16),
            child: Text(
              'كل لحظة هي كنز...',
              style: GoogleFonts.notoSerif(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
          ),
        ),

        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterHeaderDelegate(child: _buildFilterTabs()),
        ),

        if (_filteredMediaFiles.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else if (_isGridView)
          _buildMediaGrid()
        else
          _buildMediaList(),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final filters =
        ['الكل', 'المميزة', 'الصور', 'الفيديوهات'] +
        _events.take(3).map((e) => e.title).toList();

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.pearlWhite.withValues(alpha: 0.8),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = _selectedFilter == filter;

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => _filterMedia(filter),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.dustyRose
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.dustyRose
                            : AppColors.softTaupe.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.dustyRose.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filter,
                      style: GoogleFonts.manrope(
                        color: isSelected ? Colors.white : AppColors.lightText,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.dustyRose),
          const SizedBox(height: 24),
          Text(
            'نسترجع أجمل ذكرياتكم...',
            style: GoogleFonts.manrope(
              color: AppColors.softTaupe,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📸', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text(
            'لا توجد ذكريات هنا بعد',
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ابدأ بتوثيق لحظاتكم التي لا تُنسى',
            style: GoogleFonts.manrope(color: AppColors.lightText),
          ),
        ],
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildMediaGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: _filteredMediaFiles.length,
        itemBuilder: (context, index) {
          final media = _filteredMediaFiles[index];
          return _buildMediaCard(media, index);
        },
      ),
    );
  }

  Widget _buildMediaCard(MediaFile media, int index) {
    return GestureDetector(
      onTap: () => _openFullScreenView(index),
      onLongPress: () => _showMediaOptions(media),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: media.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: AppColors.surfaceRose,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.champagneGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (media.description != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                media.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkText,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${media.uploadDate.day}/${media.uploadDate.month}/${media.uploadDate.year}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.softTaupe,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(delay: (index * 50).ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildMediaList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final media = _filteredMediaFiles[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.surfaceRose),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: media.thumbnailUrl,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                media.description ?? 'ذكرى جميلة',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                '${media.uploadDate.day}/${media.uploadDate.month}/${media.uploadDate.year}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.softTaupe,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.dustyRose,
              ),
              onTap: () => _openFullScreenView(index),
            ),
          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
        }, childCount: _filteredMediaFiles.length),
      ),
    );
  }

  void _openFullScreenView(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGallery(
          mediaFiles: _filteredMediaFiles,
          initialIndex: index,
        ),
      ),
    );
  }

  void _showMediaOptions(MediaFile mediaFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.pearlWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.softTaupe.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'خيارات الذكرى',
              style: GoogleFonts.notoSerif(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionTile(
              Icons.star_rounded,
              mediaFile.isFeatured ? 'إلغاء التمييز' : 'تمييز كمفضلة',
              AppColors.champagneGold,
              () {
                Navigator.pop(context);
              },
            ),
            _buildActionTile(
              Icons.share_rounded,
              'مشاركة الذكرى',
              AppColors.dustyRose,
              () {
                Navigator.pop(context);
              },
            ),
            _buildActionTile(
              Icons.download_rounded,
              'تحميل إلى الجهاز',
              AppColors.deepMauve,
              () {
                Navigator.pop(context);
              },
            ),
            _buildActionTile(
              Icons.delete_outline_rounded,
              'حذف من الألبوم',
              Colors.redAccent,
              () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }

  void _addNewMemory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('إضافة ذكرى جديدة - قريباً!'),
        backgroundColor: AppColors.dustyRose,
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 70;
  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(_FilterHeaderDelegate oldDelegate) => true;
}

class FullScreenGallery extends StatefulWidget {
  final List<MediaFile> mediaFiles;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.mediaFiles,
    required this.initialIndex,
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
            builder: (context, index) {
              final mediaFile = widget.mediaFiles[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  mediaFile.cloudinaryUrl,
                ),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'media_${mediaFile.id}',
                ),
              );
            },
            itemCount: widget.mediaFiles.length,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: AppColors.dustyRose),
            ),
            pageController: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
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
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.mediaFiles[_currentIndex].description ??
                              'ذكرى جميلة',
                          style: GoogleFonts.notoSerif(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.champagneGold,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(
                                widget.mediaFiles[_currentIndex].uploadDate,
                              ),
                              style: GoogleFonts.manrope(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.mediaFiles[_currentIndex].location !=
                                null) ...[
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.dustyRose,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.mediaFiles[_currentIndex].location!,
                                style: GoogleFonts.manrope(
                                  color: Colors.white70,
                                  fontSize: 13,
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

  String _formatDate(DateTime date) {
    final months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
