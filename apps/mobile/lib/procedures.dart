class Procedure {
  const Procedure(this.data);

  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get damage => data['damage'] as String;
  List<String> get materials => (data['materials'] as List).cast<String>();
  String get source => data['source'] as String;
  Uri get url => Uri.parse(data['url'] as String);
  String title(int language) => (data['title'] as List)[language] as String;
  String tools(int language) => (data['tools'] as List)[language] as String;
  List<String> steps(int language) => (data['steps'] as List)
      .map((step) => (step as List)[language] as String)
      .toList();
  bool get usesMachine => id == 'straight-seam';
}

class Knowledge {
  Knowledge(Map<String, dynamic> json)
    : version = json['version'] as String,
      procedures = (json['procedures'] as List)
          .map((row) => Procedure(row as Map<String, dynamic>))
          .toList();

  final String version;
  final List<Procedure> procedures;

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
