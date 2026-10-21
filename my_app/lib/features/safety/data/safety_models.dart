// Models for family safety: location, safe places, journeys, quick
// check-ins, help alerts and the safety centre. Parsing is lenient (missing
// fields → null) because several payloads are shared by parent and child
// endpoints that hide different fields.

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
    : const [];

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

double? _double(Object? v) => (v as num?)?.toDouble();
int? _int(Object? v) => (v as num?)?.toInt();

class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
  });

  final double latitude;
  final double longitude;
  final int? accuracyM;

  static GeoPoint? fromJson(Object? v) {
    if (v is! Map) return null;
    final lat = _double(v['latitude']);
    final lng = _double(v['longitude']);
    if (lat == null || lng == null) return null;
    return GeoPoint(
      latitude: lat,
      longitude: lng,
      accuracyM: _int(v['accuracy_m']),
    );
  }
}

/// One child on the family map.
class ChildLocationSnapshot {
  const ChildLocationSnapshot({
    required this.childId,
    required this.childName,
    required this.status,
    required this.sharingEnabled,
    required this.childInformed,
    this.avatarColor,
    this.avatarKey,
    this.location,
    this.recordedAt,
    this.ageMinutes,
    this.deviceName,
    this.platform,
    this.lastContactAt,
    this.locationPermission,
    this.batteryPct,
    this.batteryCharging,
  });

  final String childId;
  final String childName;
  final String? avatarColor;
  final String? avatarKey;

  /// sharing_off | no_device | permission_missing | location_off | offline |
  /// no_location_yet | stale | fresh
  final String status;
  final bool sharingEnabled;
  final bool childInformed;
  final GeoPoint? location;
  final DateTime? recordedAt;
  final int? ageMinutes;
  final String? deviceName;
  final String? platform;
  final DateTime? lastContactAt;
  final String? locationPermission;
  final int? batteryPct;
  final bool? batteryCharging;

  bool get hasLocation => location != null;

  factory ChildLocationSnapshot.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] as Map?;
    final dev = j['device'] as Map?;
    return ChildLocationSnapshot(
      childId: j['child_id'] as String,
      childName: j['child_name'] as String? ?? '',
      avatarColor: j['avatar_color'] as String?,
      avatarKey: j['avatar_key'] as String?,
      status: j['status'] as String? ?? 'sharing_off',
      sharingEnabled: j['sharing_enabled'] as bool? ?? false,
      childInformed: j['child_informed'] as bool? ?? false,
      location: GeoPoint.fromJson(loc),
      recordedAt: _date(loc?['recorded_at']),
      ageMinutes: _int(loc?['age_minutes']),
      deviceName: dev?['name'] as String?,
      platform: dev?['platform'] as String?,
      lastContactAt: _date(dev?['last_contact_at']),
      locationPermission: dev?['location_permission'] as String?,
      batteryPct: _int(dev?['battery_pct']),
      batteryCharging: dev?['battery_charging'] as bool?,
    );
  }
}

class SafePlace {
  const SafePlace({
    required this.id,
    required this.name,
    required this.kind,
    required this.radiusM,
    required this.notifyArrive,
    required this.notifyLeave,
    this.point,
    this.address,
    this.childIds,
  });

  final String id;
  final String name;

  /// home | school | other
  final String kind;
  final GeoPoint? point;
  final int radiusM;
  final String? address;
  final bool notifyArrive;
  final bool notifyLeave;
  final List<String>? childIds;

  factory SafePlace.fromJson(Map<String, dynamic> j) => SafePlace(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    kind: j['kind'] as String? ?? 'other',
    point: GeoPoint.fromJson(j),
    radiusM: _int(j['radius_m']) ?? 150,
    address: j['address'] as String?,
    notifyArrive: j['notify_arrive'] as bool? ?? true,
    notifyLeave: j['notify_leave'] as bool? ?? false,
    childIds: (j['child_ids'] as List?)?.cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'latitude': point?.latitude,
    'longitude': point?.longitude,
    'radius_m': radiusM,
    'address': address,
    'notify_arrive': notifyArrive,
    'notify_leave': notifyLeave,
    'child_ids': childIds,
  };
}

class Journey {
  const Journey({
    required this.id,
    required this.childId,
    required this.destinationName,
    required this.status,
    required this.startedAt,
    required this.expectedAt,
    this.childName,
    this.safePlaceId,
    this.endedAt,
  });

  final String id;
  final String childId;
  final String? childName;
  final String destinationName;
  final String? safePlaceId;

  /// active | overdue | arrived | cancelled
  final String status;
  final DateTime startedAt;
  final DateTime expectedAt;
  final DateTime? endedAt;

  bool get isLive => status == 'active' || status == 'overdue';
  bool get isOverdue => status == 'overdue';

  factory Journey.fromJson(Map<String, dynamic> j) => Journey(
    id: j['id'] as String,
    childId: j['child_id'] as String? ?? '',
    childName: j['child_name'] as String?,
    destinationName: j['destination_name'] as String? ?? '',
    safePlaceId: j['safe_place_id'] as String?,
    status: j['status'] as String? ?? 'active',
    startedAt: _date(j['started_at']) ?? DateTime.now(),
    expectedAt: _date(j['expected_at']) ?? DateTime.now(),
    endedAt: _date(j['ended_at']),
  );
}

class SafetyCheckin {
  const SafetyCheckin({
    required this.id,
    required this.childId,
    required this.kind,
    this.childName,
    this.note,
    this.location,
    this.createdAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  final String id;
  final String childId;
  final String? childName;

  /// arrived | okay | pick_me_up | call_me
  final String kind;
  final String? note;
  final GeoPoint? location;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  bool get isUrgent => kind == 'pick_me_up' || kind == 'call_me';

  factory SafetyCheckin.fromJson(Map<String, dynamic> j) => SafetyCheckin(
    id: j['id'] as String,
    childId: j['child_id'] as String? ?? '',
    childName: j['child_name'] as String?,
    kind: j['kind'] as String? ?? 'okay',
    note: j['note'] as String?,
    location: GeoPoint.fromJson(j['location']),
    createdAt: _date(j['created_at']),
    acknowledgedAt: _date(j['acknowledged_at']),
    acknowledgedBy: j['acknowledged_by'] as String?,
  );
}

class HelpAlert {
  const HelpAlert({
    required this.id,
    required this.childId,
    required this.status,
    required this.recipients,
    required this.pushQueued,
    this.childName,
    this.message,
    this.location,
    this.batteryPct,
    this.createdAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  final String id;
  final String childId;
  final String? childName;

  /// open | acknowledged | resolved | cancelled
  final String status;
  final String? message;
  final GeoPoint? location;
  final int? batteryPct;
  final List<({String id, String name})> recipients;

  /// Devices a push was queued for. 0 = nobody reachable by push right now.
  final int pushQueued;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  bool get isOpen => status == 'open';
  bool get isAcknowledged => status == 'acknowledged' || status == 'resolved';

  factory HelpAlert.fromJson(Map<String, dynamic> j) => HelpAlert(
    id: j['id'] as String,
    childId: j['child_id'] as String? ?? '',
    childName: j['child_name'] as String?,
    status: j['status'] as String? ?? 'open',
    message: j['message'] as String?,
    location: GeoPoint.fromJson(j['location']),
    batteryPct: _int(j['battery_pct']),
    recipients: _list(j['recipients'])
        .map((r) => (id: r['id'] as String, name: r['name'] as String? ?? ''))
        .toList(growable: false),
    pushQueued: _int(j['push_queued']) ?? 0,
    createdAt: _date(j['created_at']),
    acknowledgedAt: _date(j['acknowledged_at']),
    acknowledgedBy: j['acknowledged_by'] as String?,
  );
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.canPickUp,
    this.relation,
    this.notes,
  });

  final String id;
  final String name;
  final String? relation;
  final String phone;
  final bool canPickUp;
  final String? notes;

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    relation: j['relation'] as String?,
    phone: j['phone'] as String? ?? '',
    canPickUp: j['can_pick_up'] as bool? ?? false,
    notes: j['notes'] as String?,
  );
}

/// A grown-up the child can reach (urgent recipient).
class TrustedPerson {
  const TrustedPerson({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;
}

class Caregiver {
  const Caregiver({
    required this.memberId,
    required this.userId,
    required this.name,
    required this.role,
    required this.receivesUrgentAlerts,
    required this.childScope,
    required this.childIds,
    required this.permissions,
  });

  final String memberId;
  final String userId;
  final String name;

  /// owner | parent | caregiver
  final String role;
  final bool receivesUrgentAlerts;

  /// all | selected
  final String childScope;
  final List<String> childIds;
  final List<String> permissions;

  factory Caregiver.fromJson(Map<String, dynamic> j) => Caregiver(
    memberId: j['member_id'] as String,
    userId: j['user_id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    role: j['role'] as String? ?? 'caregiver',
    receivesUrgentAlerts: j['receives_urgent_alerts'] as bool? ?? true,
    childScope: j['child_scope'] as String? ?? 'all',
    childIds: (j['child_ids'] as List?)?.cast<String>() ?? const [],
    permissions: (j['permissions'] as List?)?.cast<String>() ?? const [],
  );
}

class SafetyCentre {
  const SafetyCentre({
    required this.contacts,
    this.pickupInstructions,
    this.emergencyNumber,
    this.people = const [],
    this.caregivers = const [],
    this.openHelpId,
  });

  final List<EmergencyContact> contacts;
  final String? pickupInstructions;
  final String? emergencyNumber;

  /// Child view: grown-ups who get urgent alerts.
  final List<TrustedPerson> people;

  /// Parent view: every adult with their access.
  final List<Caregiver> caregivers;
  final String? openHelpId;

  factory SafetyCentre.fromJson(Map<String, dynamic> j) => SafetyCentre(
    contacts: _list(j['contacts']).map(EmergencyContact.fromJson).toList(),
    pickupInstructions: j['pickup_instructions'] as String?,
    emergencyNumber: j['emergency_number'] as String?,
    people: _list(j['people'])
        .map(
          (p) => TrustedPerson(
            id: p['id'] as String,
            name: p['name'] as String? ?? '',
            phone: p['phone'] as String?,
          ),
        )
        .toList(),
    caregivers: _list(j['caregivers']).map(Caregiver.fromJson).toList(),
    openHelpId: j['open_help'] as String?,
  );
}

class FamilyMap {
  const FamilyMap({
    required this.children,
    required this.places,
    required this.journeys,
  });

  final List<ChildLocationSnapshot> children;
  final List<SafePlace> places;
  final List<Journey> journeys;

  factory FamilyMap.fromJson(Map<String, dynamic> j) => FamilyMap(
    children: _list(j['children']).map(ChildLocationSnapshot.fromJson).toList(),
    places: _list(j['places']).map(SafePlace.fromJson).toList(),
    journeys: _list(j['journeys']).map(Journey.fromJson).toList(),
  );
}

class Agreement {
  const Agreement({
    required this.id,
    required this.title,
    required this.items,
    required this.version,
    required this.childAgreedCurrent,
    this.childAgreedAt,
  });

  final String id;
  final String title;
  final List<({String section, String text})> items;
  final int version;
  final bool childAgreedCurrent;
  final DateTime? childAgreedAt;

  factory Agreement.fromJson(Map<String, dynamic> j) => Agreement(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    items: _list(j['items'])
        .map(
          (i) => (
            section: i['section'] as String? ?? 'responsibilities',
            text: i['text'] as String? ?? '',
          ),
        )
        .toList(),
    version: _int(j['version']) ?? 1,
    childAgreedCurrent: j['child_agreed_current'] as bool? ?? false,
    childAgreedAt: _date(j['child_agreed_at']),
  );
}

class LessonProgress {
  const LessonProgress({required this.key, this.completedAt});

  final String key;
  final DateTime? completedAt;

  bool get done => completedAt != null;

  factory LessonProgress.fromJson(Map<String, dynamic> j) => LessonProgress(
    key: j['key'] as String,
    completedAt: _date(j['completed_at']),
  );
}

class AccessLogEntry {
  const AccessLogEntry({
    required this.id,
    required this.action,
    required this.actorType,
    this.actorName,
    this.childName,
    this.meta,
    this.createdAt,
  });

  final String id;
  final String action;
  final String actorType;
  final String? actorName;
  final String? childName;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;

  factory AccessLogEntry.fromJson(Map<String, dynamic> j) => AccessLogEntry(
    id: j['id'] as String,
    action: j['action'] as String? ?? '',
    actorType: j['actor_type'] as String? ?? 'system',
    actorName: j['actor_name'] as String?,
    childName: j['child_name'] as String?,
    meta: (j['meta'] as Map?)?.cast<String, dynamic>(),
    createdAt: _date(j['created_at']),
  );
}
