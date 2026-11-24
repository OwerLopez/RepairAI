/// Represents a repair guide or procedure retrieved from the knowledge base.
class Procedure {
  /// Creates a [Procedure] wrapping raw JSON knowledge base [data].
  const Procedure(this.data);

  /// Raw dictionary representation of the procedure.
  final Map<String, dynamic> data;

  /// Unique procedure identifier (e.g., 'straight-seam', 'sashiko-darn').
  String get id => data['id'] as String;

  /// The type of damage addressed by this procedure (e.g., 'hole', 'tear', 'seam').
  String get damage => data['damage'] as String;

  /// Compatible fabric materials for this repair guide.
  List<String> get materials => (data['materials'] as List).cast<String>();

  /// Source attribution name or publisher.
  String get source => data['source'] as String;

  /// External URL pointing to the complete published guide.
  Uri get url => Uri.parse(data['url'] as String);

  /// Returns the localized procedure title for [language] (0 for Spanish, 1 for English).
  String title(int language) => (data['title'] as List)[language] as String;

  /// Returns the localized tools and materials summary for [language].
  String tools(int language) => (data['tools'] as List)[language] as String;

  /// Returns the ordered list of localized step instructions for [language].
  List<String> steps(int language) => (data['steps'] as List)
      .map((step) => (step as List)[language] as String)
      .toList();

  /// Whether this procedure requires a sewing machine.
  bool get usesMachine => id == 'straight-seam';
}

/// In-memory knowledge base containing repair procedures and compatibility matcher.
class Knowledge {
  /// Creates a [Knowledge] base by deserializing [json] assets.
  Knowledge(Map<String, dynamic> json)
    : version = json['version'] as String,
      procedures = (json['procedures'] as List)
          .map((row) => Procedure(row as Map<String, dynamic>))
          .toList();

  /// Version string of the bundled knowledge catalog.
  final String version;

  /// All repair procedures loaded from the catalog.
  final List<Procedure> procedures;

  /// Retrieves compatible repair procedures for the given [damage], [material],
  /// and [machineAvailable] status, sorted by specificity.
  List<Procedure> retrieve({
    required String damage,
    required String material,
    required bool machineAvailable,
  }) {
    final compatible = procedures
        .where(
          (procedure) =>
              procedure.damage == damage &&
              procedure.materials.contains(material) &&
              (machineAvailable || !procedure.usesMachine),
        )
        .toList();
    // A procedure with narrower material coverage is the more specific match.
    compatible.sort((a, b) {
      final specificity = a.materials.length.compareTo(b.materials.length);
      return specificity == 0 ? a.id.compareTo(b.id) : specificity;
    });
    return compatible;
  }
}
