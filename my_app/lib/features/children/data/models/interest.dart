import 'package:flutter/foundation.dart';

/// One row of the localized interests catalog (`GET /interests`,
/// `InterestResource`). `name` is already localized to the request locale by
/// the backend; writes use [id] (a UUID), never the name.
@immutable
class Interest {
  const Interest({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.color,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? icon;
  final String? color;
  final int sortOrder;

  factory Interest.fromJson(Map<String, dynamic> json) => Interest(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) => other is Interest && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
