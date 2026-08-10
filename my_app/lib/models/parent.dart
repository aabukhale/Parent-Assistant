class Parent {
  final String id;
  final String name;
  final String email;
  final List<String> childrenIds;

  Parent({
    required this.id,
    required this.name,
    required this.email,
    this.childrenIds = const [],
  });

  Parent copyWith({
    String? id,
    String? name,
    String? email,
    List<String>? childrenIds,
  }) {
    return Parent(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      childrenIds: childrenIds ?? this.childrenIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'childrenIds': childrenIds,
    };
  }

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      childrenIds: List<String>.from(json['childrenIds'] ?? []),
    );
  }
}