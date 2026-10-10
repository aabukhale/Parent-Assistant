class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.childId,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String category;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? childId;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;
  String? get route => data['route'] as String?;

  AppNotification markedRead() => AppNotification(
    id: id,
    category: category,
    type: type,
    title: title,
    body: body,
    data: data,
    childId: childId,
    readAt: readAt ?? DateTime.now(),
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    category: j['category'] as String? ?? '',
    type: j['type'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    data: (j['data'] is Map)
        ? (j['data'] as Map).cast<String, dynamic>()
        : const {},
    childId: j['child_id'] as String?,
    readAt: j['read_at'] is String
        ? DateTime.tryParse(j['read_at'] as String)?.toLocal()
        : null,
    createdAt: j['created_at'] is String
        ? DateTime.tryParse(j['created_at'] as String)?.toLocal()
        : null,
  );
}
