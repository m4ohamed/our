// lib/presentation/widgets/event_detail_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../generated/l10n.dart';
import '../../domain/entities/timeline_event_entity.dart';

class EventDetailSheet extends StatelessWidget {
  final TimelineEventEntity event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EventDetailSheet({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final hasLocalImage =
        event.localImagePath != null &&
        File(event.localImagePath!).existsSync();
    final hasNetworkImage =
        event.imageUrl != null && event.imageUrl!.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(theme),
          _buildHeader(context, s, theme),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasLocalImage || hasNetworkImage)
                    _buildImage(theme, hasLocalImage),
                  const SizedBox(height: 20),
                  _buildDescription(theme),
                  const SizedBox(height: 16),
                  if (event.location != null)
                    _buildInfoRow(
                      theme: theme,
                      icon: Icons.location_on_rounded,
                      text: event.location!,
                      color: theme.colorScheme.tertiary,
                    ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    theme: theme,
                    icon: Icons.wb_sunny_rounded,
                    text: s.season(switch (event.seasonKey) {
                      'winter' => s.winter,
                      'spring' => s.spring,
                      'summer' => s.summer,
                      _ => s.autumn,
                    }),
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    theme: theme,
                    icon: Icons.schedule_rounded,
                    text: s.daysAgo(event.daysSinceEvent),
                    color: theme.colorScheme.primary,
                  ),
                  if (event.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTags(theme),
                  ],
                  const SizedBox(height: 24),
                  _buildActions(context, s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, S s, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(event.icon, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.notoSerif(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  _formatDate(event.date, s),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildImage(ThemeData theme, bool hasLocalImage) {
    return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: hasLocalImage
              ? Image.file(
                  File(event.localImagePath!),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 220,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    height: 220,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Text(
                        event.icon,
                        style: const TextStyle(fontSize: 60),
                      ),
                    ),
                  ),
                ),
        )
        .animate()
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          delay: 100.ms,
        )
        .fadeIn(delay: 100.ms);
  }

  Widget _buildDescription(ThemeData theme) {
    return Text(
      event.description,
      style: GoogleFonts.manrope(
        fontSize: 15,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        height: 1.7,
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTags(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: event.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '#$tag',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(BuildContext context, S s) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(s.edit),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              s.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d, S s) {
    final m = [
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
    return '${d.day} ${m[d.month]} ${d.year}';
  }
}
