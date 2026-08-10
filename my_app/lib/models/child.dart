class Child {
  final String id;
  final String name;
  final int age;
  final String schoolGrade;
  final String? imageUrl;
  final List<String> interests;
  final List<String> learningGoals;
  final List<String> allergies;

  Child({
    required this.id,
    required this.name,
    required this.age,
    required this.schoolGrade,
    this.imageUrl,
    this.interests = const [],
    this.learningGoals = const [],
    this.allergies = const [],
  });

  Child copyWith({
    String? id,
    String? name,
    int? age,
    String? schoolGrade,
    String? imageUrl,
    List<String>? interests,
    List<String>? learningGoals,
    List<String>? allergies,
  }) {
    return Child(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      schoolGrade: schoolGrade ?? this.schoolGrade,
      imageUrl: imageUrl ?? this.imageUrl,
      interests: interests ?? this.interests,
      learningGoals: learningGoals ?? this.learningGoals,
      allergies: allergies ?? this.allergies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'schoolGrade': schoolGrade,
      'imageUrl': imageUrl,
      'interests': interests,
      'learningGoals': learningGoals,
      'allergies': allergies,
    };
  }

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      schoolGrade: json['schoolGrade'] ?? '',
      imageUrl: json['imageUrl'],
      interests: List<String>.from(json['interests'] ?? []),
      learningGoals: List<String>.from(json['learningGoals'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
    );
  }
}