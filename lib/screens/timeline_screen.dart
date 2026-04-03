import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/timeline_event.dart';
import '../theme/app_theme.dart';
import '../widgets/event_detail_dialog.dart';
import 'add_edit_event_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  List<TimelineEvent> _events = [];
  final Set<int> _visibleEventIds = {};
  late AnimationController _fabController;
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fabController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _events = TimelineEvent.getDemoEvents();
    _scrollController.addListener(_onScroll);

    // إظهار الحدث الأول فوراً
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _visibleEventIds.add(_events.first.id);
        });
        _fabController.forward();
      }
    });
  }

  void _onScroll() {
    // إخفاء/إظهار الزر العائم عند السكرول
    final currentScrollOffset = _scrollController.offset;
    if (currentScrollOffset > 100 && _showFab) {
      setState(() {
        _showFab = false;
      });
      _fabController.reverse();
    } else if (currentScrollOffset <= 100 && !_showFab) {
      setState(() {
        _showFab = true;
      });
      _fabController.forward();
    }

    // إظهار الأحداث التدريجي
    for (int i = 0; i < _events.length; i++) {
      final event = _events[i];

      // تحقق من موضع العنصر في الشاشة
      if (_scrollController.offset > i * 180 - 100) {
        if (!_visibleEventIds.contains(event.id)) {
          setState(() {
            _visibleEventIds.add(event.id);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('رحلة حبنا'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _addNewEvent,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'إضافة حدث جديد',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sort_date',
                child: Row(
                  children: [
                    Icon(Icons.sort, color: AppColors.dustyRose, size: 20),
                    const SizedBox(width: 12),
                    Text('ترتيب بالتاريخ', style: GoogleFonts.manrope()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_view',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: AppColors.dustyRose, size: 20),
                    const SizedBox(width: 12),
                    Text('إعادة تحميل', style: GoogleFonts.manrope()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cinematic Pearl Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.5, -0.6),
                  radius: 1.5,
                  colors: [
                    AppColors.surfaceRose,
                    AppColors.pearlWhite,
                    AppColors.pearlWhite,
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Floating Petals (Soft Overlay)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/images/pattern_petals.png', // Assuming this exists or falls back
                repeat: ImageRepeat.repeat,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),

          _events.isEmpty ? _buildEmptyState() : _buildTimelineContent(),
        ],
      ),
      floatingActionButton: _showFab ? _buildFloatingActionButton() : null,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _addNewEvent,
      backgroundColor: AppColors.dustyRose,
      elevation: 4,
      icon: const Icon(Icons.favorite, color: Colors.white, size: 18),
      label: Text(
        'إضافة ذكرى',
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✨', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          Text(
            'ابدأ في كتابة قصة حبكم',
            style: GoogleFonts.notoSerif(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'قصتكم تستحق أن تُخَلّد بدقة الألماس',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: AppColors.lightText,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _addNewEvent,
            child: const Text('إضافة أول ذكرى'),
          ),
        ],
      ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildTimelineContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'أجمل محطاتنا',
                  style: GoogleFonts.notoSerif(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate().scaleX(delay: 300.ms, duration: 600.ms),
                const SizedBox(height: 12),
                Text(
                  '${_events.length} لحظة محفورة في القلب',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightText,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final event = _events[index];
              final isVisible = _visibleEventIds.contains(event.id);
              return _buildTimelineItem(
                event: event,
                isFirst: index == 0,
                isLast: index == _events.length - 1,
                isVisible: isVisible,
                index: index,
              );
            }, childCount: _events.length),
          ),
        ),

        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Column(
              children: [
                const Icon(Icons.favorite, color: AppColors.dustyRose, size: 30)
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      duration: 1000.ms,
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.2, 1.2),
                    ),
                const SizedBox(height: 16),
                Text(
                  'والحكاية لم تنتهِ بعد...',
                  style: GoogleFonts.notoSerif(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: AppColors.dustyRose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required TimelineEvent event,
    required bool isFirst,
    required bool isLast,
    required bool isVisible,
    required int index,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TimelineTile(
        alignment: TimelineAlign.manual,
        lineXY: 0.25,
        isFirst: isFirst,
        isLast: isLast,
        beforeLineStyle: LineStyle(
          color: AppColors.champagneGold.withValues(alpha: 0.4),
          thickness: 2,
        ),
        afterLineStyle: LineStyle(
          color: AppColors.champagneGold.withValues(alpha: 0.4),
          thickness: 2,
        ),
        indicatorStyle: IndicatorStyle(
          width: 46,
          height: 46,
          indicator: _buildIndicator(event, isVisible, index),
          drawGap: true,
        ),
        endChild: _buildEventCard(event, isVisible, index),
      ),
    );
  }

  Widget _buildIndicator(TimelineEvent event, bool isVisible, int index) {
    return Container(
          decoration: BoxDecoration(
            color: AppColors.pearlWhite,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.champagneGold.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.champagneGold.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(event.icon, style: const TextStyle(fontSize: 22)),
          ),
        )
        .animate(target: isVisible ? 1 : 0)
        .scale(duration: 600.ms, curve: Curves.easeOutBack)
        .fadeIn();
  }

  Widget _buildEventCard(TimelineEvent event, bool isVisible, int index) {
    return Container(
          margin: const EdgeInsets.only(
            left: 12,
            right: 8,
            bottom: 32,
            top: 12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Glassmorphic Frost Effect
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                InkWell(
                  onTap: () => _showEventDetail(event),
                  onLongPress: () => _showEventOptions(event),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRose,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(event.date),
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dustyRose,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _buildCardMenu(event),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Title
                        Text(
                          event.title,
                          style: GoogleFonts.notoSerif(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Description
                        Text(
                          event.description,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppColors.lightText,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        if (event.imageUrl != null) ...[
                          const SizedBox(height: 16),
                          Hero(
                            tag: 'event_${event.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: event.imageUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 160,
                                  color: AppColors.surfaceRose,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(target: isVisible ? 1 : 0)
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 600.ms);
  }

  Widget _buildCardMenu(TimelineEvent event) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz_rounded,
        color: AppColors.softTaupe.withValues(alpha: 0.5),
        size: 20,
      ),
      onSelected: (value) => _handleEventAction(value, event),
      itemBuilder: (context) => [
        _buildPopupItem(
          'edit',
          Icons.edit_outlined,
          'تعديل',
          AppColors.dustyRose,
        ),
        _buildPopupItem(
          'duplicate',
          Icons.copy_rounded,
          'نسخ',
          AppColors.champagneGold,
        ),
        _buildPopupItem(
          'delete',
          Icons.delete_outline_rounded,
          'حذف',
          Colors.redAccent,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String title,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.manrope(fontSize: 14)),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'sort_date':
        setState(() {
          _events.sort((a, b) => a.date.compareTo(b.date));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم ترتيب الأحداث بالتاريخ')),
        );
        break;
      case 'reset_view':
        setState(() {
          _visibleEventIds.clear();
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _events.isNotEmpty) {
            setState(() {
              _visibleEventIds.add(_events.first.id);
            });
          }
        });
        break;
    }
  }

  void _handleEventAction(String action, TimelineEvent event) {
    switch (action) {
      case 'edit':
        _editEvent(event);
        break;
      case 'duplicate':
        _duplicateEvent(event);
        break;
      case 'delete':
        _deleteEvent(event);
        break;
    }
  }

  void _showEventOptions(TimelineEvent event) {
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
              event.title,
              style: GoogleFonts.notoSerif(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionTile(
              Icons.edit_outlined,
              'تعديل الحدث',
              AppColors.dustyRose,
              () {
                Navigator.pop(context);
                _editEvent(event);
              },
            ),
            _buildActionTile(
              Icons.copy_rounded,
              'نسخ الحدث',
              AppColors.champagneGold,
              () {
                Navigator.pop(context);
                _duplicateEvent(event);
              },
            ),
            _buildActionTile(
              Icons.delete_outline_rounded,
              'حذف الحدث',
              Colors.redAccent,
              () {
                Navigator.pop(context);
                _deleteEvent(event);
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
    return '${date.day} ${months[date.month - 1]}';
  }

  void _showEventDetail(TimelineEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailDialog(
        event: event,
        isFromDemo: _isDemoEvent(event),
        onEventUpdated: (updatedEvent) {
          setState(() {
            final index = _events.indexWhere((e) => e.id == event.id);
            if (index != -1) {
              _events[index] = updatedEvent;
              _events.sort((a, b) => a.date.compareTo(b.date));
            }
          });
        },
        onEventDeleted: (deletedEvent) {
          setState(() {
            _events.removeWhere((e) => e.id == deletedEvent.id);
            _visibleEventIds.remove(deletedEvent.id);
          });
        },
      ),
    );
  }

  bool _isDemoEvent(TimelineEvent event) {
    final demoEvents = TimelineEvent.getDemoEvents();
    return demoEvents.any((demo) => demo.id == event.id);
  }

  void _addNewEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(
          onSave: (newEvent) {
            setState(() {
              final newId = DateTime.now().millisecondsSinceEpoch;
              final eventWithId = newEvent.copyWith(
                id: newId,
                orderIndex: _events.length,
              );
              _events.add(eventWithId);
              _events.sort((a, b) => a.date.compareTo(b.date));
            });
          },
        ),
      ),
    );
  }

  void _editEvent(TimelineEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(
          event: event,
          onSave: (updatedEvent) {
            setState(() {
              final index = _events.indexWhere((e) => e.id == event.id);
              if (index != -1) {
                _events[index] = updatedEvent;
                _events.sort((a, b) => a.date.compareTo(b.date));
              }
            });
          },
        ),
      ),
    );
  }

  void _duplicateEvent(TimelineEvent event) {
    final duplicatedEvent = event.copyWith(
      id: DateTime.now().millisecondsSinceEpoch,
      title: '${event.title} - نسخة',
      orderIndex: _events.length,
    );

    setState(() {
      _events.add(duplicatedEvent);
      _events.sort((a, b) => a.date.compareTo(b.date));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الحدث بنجاح'),
        backgroundColor: AppColors.dustyRose,
      ),
    );
  }

  void _deleteEvent(TimelineEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.pearlWhite,
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${event.title}"؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.manrope(color: AppColors.softTaupe),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _events.removeWhere((e) => e.id == event.id);
                _visibleEventIds.remove(event.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف "${event.title}" بنجاح'),
                  backgroundColor: AppColors.dustyRose,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabController.dispose();
    super.dispose();
  }
}
