class Reward {
  final String id;
  final String title;
  final String description;
  final int points;
  final String? icon;

  Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'points': points,
      'icon': icon,
    };
  }

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      points: json['points'] ?? 0,
      icon: json['icon'],
    );
  }
}