// lib/presentation/widgets/event_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../generated/l10n.dart';
import '../../domain/entities/timeline_event_entity.dart';
import '../../theme/app_theme.dart';

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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.pearlWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context, s),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.imageUrl != null) _buildImage(),
                  const SizedBox(height: 20),
                  _buildDescription(context),
                  const SizedBox(height: 16),
                  if (event.location != null)
                    _buildInfoRow(
                      icon: Icons.location_on_rounded,
                      text: event.location!,
                      color: AppColors.deepMauve,
                    ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.wb_sunny_rounded,
                    text: s.season(switch (event.seasonKey) {
                      'winter' => s.winter,
                      'spring' => s.spring,
                      'summer' => s.summer,
                      _ => s.autumn,
                    }),
                    color: AppColors.champagneGold,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.schedule_rounded,
                    text: s.daysAgo(event.daysSinceEvent),
                    color: AppColors.dustyRose,
                  ),
                  if (event.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTags(),
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

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.softTaupe.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceRose,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.dustyRose.withValues(alpha: 0.3),
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
                    color: AppColors.darkText,
                  ),
                ),
                Text(
                  _formatDate(event.date, s),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.dustyRose,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (event.isDemo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.demo,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: AppColors.champagneGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildImage() {
    return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: event.imageUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              height: 200,
              color: AppColors.surfaceRose,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.dustyRose,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              height: 200,
              color: AppColors.surfaceRose,
              child: Center(
                child: Text(event.icon, style: const TextStyle(fontSize: 60)),
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

  Widget _buildDescription(BuildContext context) {
    return Text(
      event.description,
      style: GoogleFonts.manrope(
        fontSize: 15,
        color: AppColors.lightText,
        height: 1.7,
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildInfoRow({
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
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: event.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.deepMauve.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '#$tag',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.deepMauve,
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
        if (!event.isDemo) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.redAccent,
              ),
              label: Text(
                s.delete,
                style: const TextStyle(color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
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
