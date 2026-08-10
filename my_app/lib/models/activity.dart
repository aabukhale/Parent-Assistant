class Activity {
  final String id;
  final String title;
  final String description;
  final String category;
  final int durationMinutes;
  final String ageRange;
  final List<String> materials;
  final String goal;
  final String? imageUrl;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.durationMinutes,
    required this.ageRange,
    this.materials = const [],
    required this.goal,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'durationMinutes': durationMinutes,
      'ageRange': ageRange,
      'materials': materials,
      'goal': goal,
      'imageUrl': imageUrl,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      durationMinutes: json['durationMinutes'] ?? 0,
      ageRange: json['ageRange'] ?? '',
      materials: List<String>.from(json['materials'] ?? []),
      goal: json['goal'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }
}