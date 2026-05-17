// lib/data/seeds/demo_events_seed.dart

class SeedEvent {
  final DateTime date;
  final String title;
  final String description;
  final String icon;
  final String? imageUrl;
  final int orderIndex;
  final String? location;
  final List<String> tags;

  SeedEvent({
    required this.date,
    required this.title,
    required this.description,
    required this.icon,
    this.imageUrl,
    required this.orderIndex,
    this.location,
    this.tags = const [],
  });
}

class DemoEventsSeed {
  DemoEventsSeed._();

  static final List<SeedEvent> events = [
    SeedEvent(
      date: DateTime(2025, 1, 31),
      title: 'أول لقاء',
      description:
          'بداية قصة حب جميلة، حين التقت عيوننا لأول مرة وعرفت أن هذه هي بدايتنا. كان يوماً مليئاً بالمشاعر الجميلة والإحراج اللطيف، والابتسامات الخجولة التي رسمت ملامح المستقبل.',
      icon: '💫',
      orderIndex: 1,
      location: 'بمنزل اهل زوجتي بالخي 12',
      tags: ['لقاء_أول', 'حب', 'ذكريات'],
      imageUrl:
          'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 2, 6),
      title: 'ثاني لقاء (قراءة الفاتحة)',
      description:
          'يوم مبارك حين قرأنا الفاتحة وبدأنا رحلة رسمية نحو المستقبل المشترك. حضر الأهل والأقارب، وكانت البسمات تملأ الوجوه، والدعوات الطيبة تملأ القلوب.',
      icon: '🤲',
      orderIndex: 2,
      location: 'منزل العائلة بالخي 12',
      tags: ['فاتحة', 'خطوبة', 'أهل'],
      imageUrl:
          'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 2, 14),
      title: 'الشبكة',
      description:
          'يوم عيد الحب، حين ارتديت الخاتم الذي يرمز لارتباطنا الأبدي. الدبله + المحبس + الخاتم الذهبي اللامع كانو وما زالو رمزاً لمستقبل مشرق.',
      icon: '💍',
      orderIndex: 3,
      location: 'محل الذهب بالاردنيه',
      tags: ['شبكة', 'عيد_الحب', 'خاتم'],
      imageUrl:
          'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 3, 8),
      title: 'اعتراف بالحب',
      description: 'أول مرة اعترف فيها محمد بحبه.',
      icon: '🌹',
      orderIndex: 4,
      location: 'بنها',
      tags: ['اعتراف', 'حب'],
      imageUrl:
          'https://images.unsplash.com/photo-1544982503-9f984c14501a?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 7, 3),
      title: 'أول اعتراف بالحب',
      description: 'أول مرة اعترفت فيها سارة بحب محمد.',
      icon: '🌊',
      orderIndex: 5,
      location: 'رأس البر',
      tags: ['سفر', 'رحلة', 'بحر'],
      imageUrl:
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 8, 29),
      title: 'كتب الكتاب',
      description:
          'خطوة مهمة نحو الزواج، يوم توقيع عقد القران والاحتفال مع الأهل والأصدقاء.',
      icon: '📝',
      orderIndex: 6,
      location: 'مسجد التوحيد بالعاشر من رمضان',
      tags: ['كتب_كتاب', 'زواج', 'احتفال'],
      imageUrl:
          'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 9, 5),
      title: 'نقل العفش',
      description:
          'تجهيز بيت الزوجية الجديد وترتيب كل شيء لاستقبال حياتنا المشتركة.',
      icon: '🏠',
      orderIndex: 7,
      location: 'البيت الجديد - الحي 29',
      tags: ['نقل', 'بيت', 'أثاث'],
      imageUrl:
          'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 9, 17),
      title: 'الفرح',
      description:
          'اليوم المنتظر! يوم زفافنا وبداية حياة جديدة مليئة بالحب والسعادة.',
      icon: '🎉',
      orderIndex: 8,
      location: 'سيشن تصوير بنادي المقاولين العرب',
      tags: ['زفاف', 'فرح', 'احتفال'],
      imageUrl:
          'https://images.unsplash.com/photo-1519741497674-611481863552?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 11, 4),
      title: 'أول حمل',
      description:
          'الفرحة الأولى بخبر الحمل، لحظة لا تنسى امتزجت فيها دموع الفرح بالدعوات.',
      icon: '👶',
      orderIndex: 9,
      location: 'البيت - الحي 29',
      tags: ['حمل', 'فرحة', 'عائلة'],
      imageUrl:
          'https://images.unsplash.com/photo-1516627145497-ae6968895b74?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 11, 9),
      title: 'اجهاض',
      description:
          'لحظة صعبة ودعنا فيها حلمنا الأول، لكن إيماننا وصبرنا كانا أقوى.',
      icon: '👼',
      orderIndex: 10,
      location: 'المستشفى',
      tags: ['صبر', 'اختبار', 'إيمان'],
      imageUrl:
          'https://images.unsplash.com/photo-1516589174184-e6646f65eb7a?w=500',
    ),
    SeedEvent(
      date: DateTime(2025, 11, 15),
      title: 'ثاني حمل',
      description:
          'تجدد الأمل مرة أخرى بخبر الحمل الثاني، دعواتنا أن يتمه الله على خير.',
      icon: '🤰',
      orderIndex: 11,
      location: 'البيت - الحي 29',
      tags: ['أمل', 'حمل', 'دعاء'],
      imageUrl:
          'https://images.unsplash.com/photo-1559839734-2b71f1e3540a?w=500',
    ),
  ];
}
