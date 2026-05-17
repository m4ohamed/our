// lib/presentation/screens/timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:uuid/uuid.dart';
import '../../generated/l10n.dart';

import '../../core/widgets/glass_container.dart';
import '../../domain/entities/timeline_event_entity.dart';
import '../providers/app_providers.dart';
import '../widgets/event_form_sheet.dart';
import '../widgets/event_detail_sheet.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(timelineProvider);
    final s = S.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, s),
      body: Stack(
        children: [
          _buildBackground(),
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(timelineProvider),
            color: Theme.of(context).colorScheme.primary,
            child: eventsAsync.when(
              data: (events) => events.isEmpty
                  ? _buildEmptyState(s)
                  : _buildTimeline(events, s),
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(context, s),
    );
  }

  AppBar _buildAppBar(BuildContext context, S s) {
    return AppBar(
      title: Text(s.ourJourney),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (val) => _handleMenuAction(val, s),
          itemBuilder: (_) => [
            _menuItem('sort', Icons.sort, s.sortDate),
            _menuItem('add', Icons.add_circle_outline, s.addMemory),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.manrope()),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.5, -0.6),
            radius: 1.5,
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
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<TimelineEventEntity> events, S s) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(events.length, s)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final event = events[index];
              return RepaintBoundary(
                child: _TimelineTile(
                  event: event,
                  isFirst: index == 0,
                  isLast: index == events.length - 1,
                  animationDelay: (index * 80).ms,
                  onTap: () => _showDetail(event, s),
                  onEdit: () => _showEditForm(event, s),
                  onDelete: () => _deleteEvent(event, s),
                  s: s,
                ),
              );
            }, childCount: events.length),
          ),
        ),
        SliverToBoxAdapter(child: _buildFooter(s)),
      ],
    );
  }

  Widget _buildHeader(int count, S s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
      child: Column(
        children: [
          Text(
            s.beautifulMilestones,
            style: GoogleFonts.notoSerif(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ).animate().scaleX(delay: 300.ms, duration: 600.ms),
          const SizedBox(height: 12),
          Text(
            s.momentsInHeart(count),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.outline,
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildFooter(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
                Icons.favorite,
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                duration: 1000.ms,
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
              ),
          const SizedBox(height: 16),
          Text(
            s.storyNotEnded,
            style: GoogleFonts.notoSerif(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(S s) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✨', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          Text(
            s.startWritingStory,
            style: GoogleFonts.notoSerif(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showAddForm(s),
            child: Text(s.addFirstMemory),
          ),
        ],
      ).animate().fadeIn(duration: 800.ms),
    );
  }

  Widget _buildFab(BuildContext context, S s) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddForm(s),
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 4,
      icon: const Icon(Icons.favorite, color: Colors.white, size: 18),
      label: Text(
        s.addMemory,
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }

  void _handleMenuAction(String action, S s) {
    if (action == 'add') _showAddForm(s);
  }

  void _showAddForm(S s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventFormSheet(
        onSave: (event) async {
          final newEvent = event.copyWith(id: const Uuid().v4());
          await ref.read(timelineProvider.notifier).addEvent(newEvent);
        },
      ),
    );
  }

  void _showEditForm(TimelineEventEntity event, S s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventFormSheet(
        event: event,
        onSave: (updated) async {
          await ref.read(timelineProvider.notifier).updateEvent(updated);
        },
      ),
    );
  }

  void _showDetail(TimelineEventEntity event, S s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(
        event: event,
        onEdit: () {
          Navigator.pop(context);
          _showEditForm(event, s);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteEvent(event, s);
        },
      ),
    );
  }

  void _deleteEvent(TimelineEventEntity event, S s) {
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
          s.areYouSureDeleteEvent(event.title),
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
              await ref.read(timelineProvider.notifier).deleteEvent(event.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(s.eventDeleted(event.title)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Tile Widget (مُعاد تفكيكه كـ Widget منفصل للأداء) ──────────────

class _TimelineTile extends StatelessWidget {
  final TimelineEventEntity event;
  final bool isFirst;
  final bool isLast;
  final Duration animationDelay;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final S s;

  const _TimelineTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.animationDelay,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return TimelineTile(
      alignment: TimelineAlign.manual,
      lineXY: 0.25,
      isFirst: isFirst,
      isLast: isLast,
      beforeLineStyle: LineStyle(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
        thickness: 2,
      ),
      afterLineStyle: LineStyle(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
        thickness: 2,
      ),
      indicatorStyle: IndicatorStyle(
        width: 46,
        height: 46,
        indicator: _buildIndicator(context),
        drawGap: true,
      ),
      endChild: _buildCard(context),
    );
  }

  Widget _buildIndicator(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(event.icon, style: const TextStyle(fontSize: 22)),
          ),
        )
        .animate()
        .scale(
          duration: 600.ms,
          delay: animationDelay,
          curve: Curves.easeOutBack,
        )
        .fadeIn();
  }

  Widget _buildCard(BuildContext context) {
    return Container(
          margin: const EdgeInsets.only(
            left: 12,
            right: 8,
            bottom: 32,
            top: 12,
          ),
          child: FrostedCard(
            onTap: onTap,
            onLongPress: onEdit,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date badge + menu
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDate(event.date, s),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildMenu(context),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  event.title,
                  style: GoogleFonts.notoSerif(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.imageUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: event.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 160,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, _, _) => Container(
                        height: 160,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 600.ms,
          delay: animationDelay,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 600.ms, delay: animationDelay);
  }

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz_rounded,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        size: 20,
      ),
      onSelected: (val) {
        if (val == 'edit') onEdit();
        if (val == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        _popupItem(
          'edit',
          Icons.edit_outlined,
          s.edit,
          Theme.of(context).colorScheme.primary,
        ),
        _popupItem(
          'delete',
          Icons.delete_outline_rounded,
          s.delete,
          Colors.redAccent,
        ),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.manrope(fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date, S s) {
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
    return '${date.day} ${months[date.month]}';
  }
}
