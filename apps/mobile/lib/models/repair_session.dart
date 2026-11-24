import 'dart:convert';
import 'dart:typed_data';

/// Represents a textile repair session tracked in the journal.
class RepairSession {
  /// Creates a new [RepairSession] instance.
  const RepairSession({
    this.id,
    required this.started,
    this.diagnosis,
    this.damage,
    this.material,
    this.plan,
    this.beforePhoto,
    this.afterPhoto,
    this.completedSteps = 0,
    this.outcome,
    this.finished,
    this.notes = '',
  });

  /// The unique identifier of the repair session in the database.
  final int? id;

  /// The timestamp when the repair session was initiated.
  final DateTime started;

  /// The JSON-serialized diagnosis data from the initial scan.
  final String? diagnosis;

  /// The type of damage identified (e.g., 'hole', 'tear', 'seam').
  final String? damage;

  /// The textile material confirmed by the user (e.g., 'denim', 'woven').
  final String? material;

  /// The JSON-serialized procedure repair plan.
  final String? plan;

  /// The initial evidence photo before repair.
  final Uint8List? beforePhoto;

  /// The outcome photo taken after repair.
  final Uint8List? afterPhoto;

  /// The number of procedure steps completed so far.
  final int completedSteps;

  /// The reported outcome ('repaired', 'partial', 'stopped', or null if in progress).
  final String? outcome;

  /// The timestamp when the repair session finished, if completed.
  final DateTime? finished;

  /// Optional user notes about the repair session.
  final String notes;

  /// Decodes and returns the [plan] as a JSON map, or null if [plan] is unset.
  Map<String, dynamic>? get planMap {
    if (plan == null) return null;
    try {
      return jsonDecode(plan!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Decodes and returns the [diagnosis] as a JSON map, or null if [diagnosis] is unset.
  Map<String, dynamic>? get diagnosisMap {
    if (diagnosis == null) return null;
    try {
      return jsonDecode(diagnosis!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Creates a [RepairSession] from a database row or JSON map.
  factory RepairSession.fromMap(Map<String, Object?> map) {
    DateTime parseDate(Object? value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    DateTime? parseNullableDate(Object? value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    String? serializeJson(Object? value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is Map) return jsonEncode(value);
      return value.toString();
    }

    return RepairSession(
      id: map['id'] as int?,
      started: parseDate(map['started']),
      diagnosis: serializeJson(map['diagnosis']),
      damage: map['damage'] as String?,
      material: map['material'] as String?,
      plan: serializeJson(map['plan']),
      beforePhoto: (map['before_photo'] ?? map['beforePhoto']) as Uint8List?,
      afterPhoto: (map['after_photo'] ?? map['afterPhoto']) as Uint8List?,
      completedSteps:
          (map['completed_steps'] ?? map['completedSteps']) as int? ?? 0,
      outcome: map['outcome'] as String?,
      finished: parseNullableDate(map['finished']),
      notes: (map['notes'] as String?)?.trim() ?? '',
    );
  }

  /// Converts this [RepairSession] into a map suitable for database persistence.
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'started': started.toIso8601String(),
    if (diagnosis != null) 'diagnosis': diagnosis,
    if (damage != null) 'damage': damage,
    if (material != null) 'material': material,
    if (plan != null) 'plan': plan,
    if (beforePhoto != null) 'before_photo': beforePhoto,
    if (afterPhoto != null) 'after_photo': afterPhoto,
    'completed_steps': completedSteps,
    if (outcome != null) 'outcome': outcome,
    if (finished != null) 'finished': finished!.toIso8601String(),
    'notes': notes,
  };
}
