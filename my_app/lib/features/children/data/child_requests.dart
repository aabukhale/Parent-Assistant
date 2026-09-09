import 'package:flutter/foundation.dart';

import 'models/child.dart';

/// Create / update payload for `POST|PATCH /families/{family}/children`.
///
/// Field names match `StoreChildRequest` / `UpdateChildRequest` exactly.
/// `birth_date` is sent as `YYYY-MM-DD`; `interest_ids` is the full desired set
/// of interest UUIDs (the backend replaces the pivot with `sync`).
@immutable
class ChildInput {
  const ChildInput({
    required this.name,
    required this.birthDate,
    this.gender,
    this.avatarColor,
    this.interestIds = const [],
  });

  final String name;
  final DateTime birthDate;
  final ChildGender? gender;
  final String? avatarColor;
  final List<String> interestIds;

  static String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'birth_date': formatDate(birthDate),
    if (gender != null) 'gender': gender!.wire,
    if (avatarColor != null && avatarColor!.isNotEmpty)
      'avatar_color': avatarColor,
    'interest_ids': interestIds,
  };

  factory ChildInput.fromChild(Child child) => ChildInput(
    name: child.name,
    birthDate: child.birthDate,
    gender: child.gender,
    avatarColor: child.avatarColor,
    interestIds: child.interestIds,
  );
}
