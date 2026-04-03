import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/timeline_event.dart';
import '../theme/app_theme.dart';
import 'package:our_love_story/screens/add_edit_event_screen.dart';

class EventDetailDialog extends StatelessWidget {
  final TimelineEvent event;
  final Function(TimelineEvent)? onEventUpdated;
  final Function(TimelineEvent)? onEventDeleted;
  final bool isFromDemo;

  const EventDetailDialog({
    super.key,
    required this.event,
    this.onEventUpdated,
    this.onEventDeleted,
    this.isFromDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightPink.withValues(alpha: 0.1),
              AppColors.white,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header مع أزرار الإجراءات
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryPink,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(event.icon, style: TextStyle(fontSize: 24)),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatDate(event.date),
                          style: TextStyle(
                            color: AppColors.lightPink,
                            fontSize: 14,
                          ),
                        ),
                        if (isFromDemo)
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'نموذج تجريبي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // أزرار الإجراءات
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editEvent(context),
                        icon: Icon(Icons.edit, color: AppColors.white),
                        tooltip: 'تعديل الحدث',
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: AppColors.white),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().slideY(begin: -0.3, end: 0, duration: 400.ms).fadeIn(),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صورة الحدث
                    if (event.imageUrl != null) ...[
                      ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 200,
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: event.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.lightPink.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryPink,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.lightPink.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          event.icon,
                                          style: TextStyle(fontSize: 50),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'ذكرى جميلة',
                                          style: TextStyle(
                                            color: AppColors.primaryPink,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0))
                          .fadeIn(delay: 200.ms),
                      SizedBox(height: 20),
                    ],

                    // تفاصيل الحدث
                    Text(
                      'تفاصيل الحدث',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.primaryPink,
                            fontSize: 18,
                          ),
                    ).animate().slideX(begin: -0.3, end: 0, delay: 300.ms),

                    SizedBox(height: 10),

                    Text(
                          event.description,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                height: 1.6,
                                color: AppColors.darkText,
                              ),
                        )
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideY(begin: 0.2, end: 0),

                    SizedBox(height: 20),

                    // معلومات إضافية
                    if (event.location != null) ...[
                      _buildInfoCard(
                        icon: Icons.location_on,
                        title: 'المكان',
                        content: event.location!,
                        color: AppColors.secondaryPurple,
                      ),
                      SizedBox(height: 10),
                    ],

                    // الوسوم إذا كانت متوفرة
                    if (event.tags != null && event.tags!.isNotEmpty) ...[
                      _buildTagsSection(),
                      SizedBox(height: 20),
                    ],

                    // إحصائيات الحدث
                    _buildEventStats(),

                    SizedBox(height: 20),

                    // رسالة رومانسية
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryPink.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text('💕', style: TextStyle(fontSize: 24)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'لحظة مميزة في رحلة حبنا الجميلة',
                              style: TextStyle(
                                color: AppColors.primaryPink,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().scale(delay: 500.ms).fadeIn(),

                    SizedBox(height: 20),

                    // أزرار الإجراءات السفلية
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _editEvent(context),
                            icon: Icon(Icons.edit),
                            label: Text('تعديل الحدث'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPink,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        if (!isFromDemo) // إخفاء زر الحذف للبيانات التجريبية
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteEvent(context),
                              icon: Icon(Icons.delete, color: Colors.red),
                              label: Text(
                                'حذف',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ).animate().slideY(begin: 0.3, end: 0, delay: 600.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 10),
          Text(
            '$title: ',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Expanded(
            child: Text(content, style: TextStyle(color: AppColors.darkText)),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوسوم',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryPink,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: event.tags!.map((tag) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: AppColors.secondaryPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEventStats() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات إضافية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryPurple,
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.secondaryPurple, size: 16),
              SizedBox(width: 8),
              Text(
                'منذ ${event.daysSinceEvent} يوم',
                style: TextStyle(color: AppColors.darkText),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.wb_sunny, color: AppColors.goldAccent, size: 16),
              SizedBox(width: 8),
              Text(
                'فصل ${event.season}',
                style: TextStyle(color: AppColors.darkText),
              ),
            ],
          ),
          if (event.isToday)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.goldAccent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  'اليوم! 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _editEvent(BuildContext context) {
    Navigator.pop(context); // إغلاق dialog الحالي
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(
          event: event,
          onSave: (updatedEvent) {
            if (onEventUpdated != null) {
              onEventUpdated!(updatedEvent);
            }

            // إظهار رسالة نجاح مع معلومات الحفظ
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'تم تحديث "${updatedEvent.title}" بنجاح',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (isFromDemo)
                            Text(
                              'تم حفظه كحدث شخصي',
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.primaryPink,
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'عرض',
                  textColor: Colors.white,
                  onPressed: () {
                    // يمكن إضافة منطق لعرض الحدث المحدث
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _deleteEvent(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text('تأكيد الحذف'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حذف "${event.title}"؟'),
            SizedBox(height: 10),
            Text(
              'لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق dialog التأكيد
              Navigator.pop(context); // إغلاق dialog التفاصيل

              if (onEventDeleted != null) {
                onEventDeleted!(event);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف "${event.title}" بنجاح'),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: 'تراجع',
                    textColor: Colors.white,
                    onPressed: () {
                      // منطق التراجع عن الحذف
                      if (onEventUpdated != null) {
                        onEventUpdated!(event);
                      }
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف', style: TextStyle(color: Colors.white)),
          ),
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
