class TimelineEvent {
  final int id;
  final DateTime date;
  final String title;
  final String description;
  final String icon;
  final String? imageUrl;
  final bool isActive;
  final int orderIndex;
  final String? location;
  final List<String>? tags;

  TimelineEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.icon,
    this.imageUrl,
    this.isActive = true,
    required this.orderIndex,
    this.location,
    this.tags,
  });

  // إنشاء نسخة محدثة من الحدث
  TimelineEvent copyWith({
    int? id,
    DateTime? date,
    String? title,
    String? description,
    String? icon,
    String? imageUrl,
    bool? isActive,
    int? orderIndex,
    String? location,
    List<String>? tags,
  }) {
    return TimelineEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      orderIndex: orderIndex ?? this.orderIndex,
      location: location ?? this.location,
      tags: tags ?? this.tags,
    );
  }

  // تحويل إلى Map للحفظ في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'description': description,
      'icon': icon,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'order_index': orderIndex,
      'location': location,
      'tags': tags?.join(','),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // إنشاء TimelineEvent من Map
  factory TimelineEvent.fromMap(Map<String, dynamic> map) {
    return TimelineEvent(
      id: map['id'] ?? 0,
      date: DateTime.parse(map['date']),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '💕',
      imageUrl: map['image_url'],
      isActive: (map['is_active'] ?? 1) == 1,
      orderIndex: map['order_index'] ?? 0,
      location: map['location'],
      tags: map['tags']?.toString().split(','),
    );
  }

  // تحويل إلى JSON
  Map<String, dynamic> toJson() => toMap();

  // إنشاء من JSON
  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent.fromMap(json);

  // للطباعة والتصحيح
  @override
  String toString() {
    return 'TimelineEvent{id: $id, title: $title, date: $date, icon: $icon}';
  }

  // للمقارنة
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // تحديد الفصل الموسمي للحدث
  String get season {
    switch (date.month) {
      case 12:
      case 1:
      case 2:
        return 'الشتاء';
      case 3:
      case 4:
      case 5:
        return 'الربيع';
      case 6:
      case 7:
      case 8:
        return 'الصيف';
      case 9:
      case 10:
      case 11:
        return 'الخريف';
      default:
        return 'غير محدد';
    }
  }

  // حساب عدد الأيام منذ الحدث
  int get daysSinceEvent {
    return DateTime.now().difference(date).inDays;
  }

  // تحديد ما إذا كان الحدث قريباً (خلال 30 يوم)
  bool get isUpcoming {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    return difference >= 0 && difference <= 30;
  }

  // تحديد ما إذا كان الحدث اليوم
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // الحصول على البيانات التجريبية
  static List<TimelineEvent> getDemoEvents() {
    return [
      TimelineEvent(
        id: 1,
        date: DateTime(2025, 1, 31),
        title: 'أول لقاء',
        description: 'بداية قصة حب جميلة، حين التقت عيوننا لأول مرة وعرفت أن هذه هي بدايتنا. كان يوماً مليئاً بالمشاعر الجميلة والإحراج اللطيف، والابتسامات الخجولة التي رسمت ملامح المستقبل.',
        icon: '💫',
        orderIndex: 1,
        location: 'بمنزل العروسه بالخي 12',
        tags: ['لقاء_أول', 'حب', 'ذكريات'],
        imageUrl: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=500',
      ),
      TimelineEvent(
        id: 2,
        date: DateTime(2025, 2, 6),
        title: 'ثاني لقاء (قراءة الفاتحة)',
        description: 'يوم مبارك حين قرأنا الفاتحة وبدأنا رحلة رسمية نحو المستقبل المشترك. حضر الأهل والأقارب، وكانت البسمات تملأ الوجوه، والدعوات الطيبة تملأ القلوب.',
        icon: '🤲',
        orderIndex: 2,
        location: 'منزل العائلة',
        tags: ['فاتحة', 'خطوبة', 'أهل'],
        imageUrl: 'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=500',
      ),
      TimelineEvent(
        id: 3,
        date: DateTime(2025, 2, 14),
        title: 'الشبكة',
        description: 'يوم عيد الحب، حين ارتديت الخاتم الذي يرمز لارتباطنا الأبدي. كان اختيار التوقيت مثالياً - عيد الحب العالمي ليكون بداية قصة حبنا الرسمية. الدبله + المحبس + الخاتم الذهبي اللامع كانو وما زالو رمزاً لمستقبل مشرق.',
        icon: '💍',
        orderIndex: 3,
        location: 'محل الذهب بالاردنيه',
        tags: ['شبكة', 'عيد_الحب', 'خاتم'],
        imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=500',
      ),
      TimelineEvent(
        id: 4,
        date: DateTime(2025, 8, 29),
        title: 'كتب الكتاب',
        description: 'خطوة مهمة نحو الزواج، يوم توقيع عقد القران والاحتفال مع الأهل والأصدقاء. كانت مناسبة مليئة بالفرحة والبركات، حيث اجتمع الجميع للاحتفال بهذه الخطوة المباركة في حياتنا.',
        icon: '📝',
        orderIndex: 4,
        location: 'مسجد التوحيد بالعاشر من رمضان',
        tags: ['كتب_كتاب', 'زواج', 'احتفال'],
        imageUrl: 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=500',
      ),
      TimelineEvent(
        id: 5,
        date: DateTime(2025, 9, 5),
        title: 'نقل العفش',
        description: 'تجهيز بيت الزوجية الجديد وترتيب كل شيء لاستقبال حياتنا المشتركة. يوم مليء بالحماس والتخطيط، حيث اخترنا كل قطعة أثاث بعناية لتعكس ذوقنا المشترك وتكون شاهداً على ذكرياتنا القادمة.',
        icon: '🏠',
        orderIndex: 5,
        location: 'البيت الجديد -  الحي 29',
        tags: ['نقل', 'بيت', 'أثاث'],
        imageUrl: 'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=500',
      ),
      TimelineEvent(
        id: 6,
        date: DateTime(2025, 9, 17),
        title: 'الفرح',
        description: 'اليوم المنتظر! يوم زفافنا وبداية حياة جديدة مليئة بالحب والسعادة. كان حلماً تحقق، حيث احتفلنا مع أحبائنا في جو من الفرحة والبهجة، ورقصنا على أنغام الحب تحت نجوم الليل.',
        icon: '🎉',
        orderIndex: 6,
        location: 'سيشن تصوير بنادي المقاولين العرب  ',
        tags: ['زفاف', 'فرح', 'احتفال'],
        imageUrl: 'https://images.unsplash.com/photo-1519741497674-611481863552?w=500',
      ),
    ];
  }

  // إضافة أحداث إضافية للتنوع
  static List<TimelineEvent> getAdditionalEvents() {
    return [
      TimelineEvent(
        id: 7,
        date: DateTime(2025, 3, 8),
        title: '  اعترف بالحب ',
        description: ' اول مره اعترف فيها محمد بي حبي',
        icon: '🌹',
        orderIndex: 7,
        location: 'بنها ',
        tags: ['اعتراف', 'حب'],
        imageUrl: 'https://images.unsplash.com/photo-1544982503-9f984c14501a?w=500',
      ),
      TimelineEvent(
        id: 8,
        date: DateTime(2025, 7, 3),
        title: 'اول اعتراف بالحب',
        description: ' اول مره اعترفت فيها بي حب محمد  ',
        icon: '🌊',
        orderIndex: 8,
        location: 'راس البر',
        tags: ['سفر', 'رحلة', 'بحر'],
        imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
      ),
    ];
  }

  // البحث في الأحداث
  static List<TimelineEvent> searchEvents(List<TimelineEvent> events, String query) {
    if (query.isEmpty) return events;
    
    return events.where((event) {
      return event.title.toLowerCase().contains(query.toLowerCase()) ||
             event.description.toLowerCase().contains(query.toLowerCase()) ||
             event.location?.toLowerCase().contains(query.toLowerCase()) == true ||
             event.tags?.any((tag) => tag.toLowerCase().contains(query.toLowerCase())) == true;
    }).toList();
  }

  // ترتيب الأحداث
  static List<TimelineEvent> sortEvents(List<TimelineEvent> events, {bool ascending = true}) {
    final sortedEvents = List<TimelineEvent>.from(events);
    sortedEvents.sort((a, b) {
      return ascending ? a.date.compareTo(b.date) : b.date.compareTo(a.date);
    });
    return sortedEvents;
  }

  // تصفية الأحداث حسب السنة
  static List<TimelineEvent> filterByYear(List<TimelineEvent> events, int year) {
    return events.where((event) => event.date.year == year).toList();
  }

  // تصفية الأحداث حسب الشهر
  static List<TimelineEvent> filterByMonth(List<TimelineEvent> events, int month) {
    return events.where((event) => event.date.month == month).toList();
  }

  // احصائيات الأحداث
  static Map<String, int> getEventsStatistics(List<TimelineEvent> events) {
    final stats = <String, int>{};
    stats['total'] = events.length;
    stats['thisYear'] = events.where((e) => e.date.year == DateTime.now().year).length;
    stats['thisMonth'] = events.where((e) => 
      e.date.year == DateTime.now().year && 
      e.date.month == DateTime.now().month
    ).length;
    stats['upcoming'] = events.where((e) => e.isUpcoming).length;
    
    return stats;
  }
}
