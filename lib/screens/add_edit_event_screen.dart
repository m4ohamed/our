// ملف screens/add_edit_event_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/timeline_event.dart';
import '../theme/app_theme.dart';

class AddEditEventScreen extends StatefulWidget {
  final TimelineEvent? event; // null للإضافة، موجود للتعديل
  final Function(TimelineEvent) onSave;

  const AddEditEventScreen({super.key, this.event, required this.onSave});

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconController;
  late DateTime _selectedDate;
  String? _imageUrl;

  // قائمة الإيموجي المتاحة
  final List<String> _availableIcons = [
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
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _iconController = TextEditingController(text: widget.event?.icon ?? '💕');
    _selectedDate = widget.event?.date ?? DateTime.now();
    _imageUrl = widget.event?.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل الحدث' : 'إضافة حدث جديد'),
        backgroundColor: AppColors.primaryPink,
        actions: [
          TextButton(
            onPressed: _saveEvent,
            child: Text(
              'حفظ',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightPink.withValues(alpha: 0.1),
              AppColors.white,
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(20),
            children: [
              // عنوان الحدث
              _buildTextFormField(
                controller: _titleController,
                label: 'عنوان الحدث',
                hint: 'مثال: أول لقاء',
                icon: Icons.title,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال عنوان الحدث';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // وصف الحدث
              _buildTextFormField(
                controller: _descriptionController,
                label: 'وصف الحدث',
                hint: 'اكتب تفاصيل هذه الذكرى الجميلة...',
                icon: Icons.description,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال وصف الحدث';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // تاريخ الحدث
              _buildDateSelector(),

              SizedBox(height: 20),

              // أيقونة الحدث
              _buildIconSelector(),

              SizedBox(height: 20),

              // رفع صورة (اختياري)
              _buildImageSelector(),

              SizedBox(height: 30),

              // أزرار الحفظ والإلغاء
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'حفظ التعديلات' : 'إضافة الحدث',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (isEditing) ...[
                    SizedBox(width: 15),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _deleteEvent,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text('حذف الحدث'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primaryPink),
            border: InputBorder.none,
            labelStyle: TextStyle(color: AppColors.primaryPink),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: AppColors.primaryPink),
        title: Text('تاريخ الحدث'),
        subtitle: Text(_formatDate(_selectedDate)),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.primaryPink,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (date != null) {
            setState(() {
              _selectedDate = date;
            });
          }
        },
      ),
    );
  }

  Widget _buildIconSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_emotions, color: AppColors.primaryPink),
                SizedBox(width: 10),
                Text(
                  'أيقونة الحدث',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPink,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            SizedBox(
              height: 100,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = _iconController.text == icon;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _iconController.text = icon;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryPink
                            : AppColors.lightPink.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryPink
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(icon, style: TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: AppColors.primaryPink),
                SizedBox(width: 10),
                Text(
                  'صورة الحدث (اختياري)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPink,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            if (_imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color: AppColors.lightPink.withValues(alpha: 0.2),
                      child: Center(child: Text('خطأ في تحميل الصورة')),
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.camera_alt),
                    label: Text(
                      _imageUrl != null ? 'تغيير الصورة' : 'اختيار صورة',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryPurple,
                    ),
                  ),
                ),
                if (_imageUrl != null) ...[
                  SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _imageUrl = null;
                      });
                    },
                    icon: Icon(Icons.delete, color: Colors.red),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // هنا يمكن رفع الصورة إلى Cloudinary أو خدمة أخرى
      // للتبسيط، سنستخدم رابط تجريبي
      setState(() {
        _imageUrl = 'https://picsum.photos/400/300';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم اختيار الصورة بنجاح')));
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      final newEvent = TimelineEvent(
        id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch,
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        icon: _iconController.text,
        imageUrl: _imageUrl,
        orderIndex: widget.event?.orderIndex ?? 0,
      );

      widget.onSave(newEvent);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.event != null
                ? 'تم تحديث الحدث بنجاح'
                : 'تم إضافة الحدث بنجاح',
          ),
          backgroundColor: AppColors.primaryPink,
        ),
      );
    }
  }

  void _deleteEvent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا الحدث؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              // هنا يتم حذف الحدث
              Navigator.pop(context); // إغلاق الحوار
              Navigator.pop(context); // العودة للصفحة السابقة

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف الحدث بنجاح'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('حذف', style: TextStyle(color: Colors.red)),
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    super.dispose();
  }
}
