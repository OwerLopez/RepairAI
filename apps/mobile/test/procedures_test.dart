import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reparaai/procedures.dart';

void main() {
  final catalog = Knowledge(
    jsonDecode(File('assets/procedures.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('ranks the fabric-specific procedure first and keeps its sources', () {
    final matches = catalog.retrieve(
      damage: 'hole',
      material: 'denim',
      machineAvailable: false,
    );
    expect(matches.map((match) => match.id), ['denim-darn', 'woven-patch']);
    for (final plan in matches) {
      expect(plan.url.scheme, 'https');
      expect(plan.steps(0), hasLength(plan.steps(1).length));
    }
  });

  test('withholds procedures when material or needed equipment is absent', () {
    expect(
      catalog.retrieve(
        damage: 'hole',
        material: 'unknown',
        machineAvailable: true,
      ),
      isEmpty,
    );
    expect(
      catalog.retrieve(
        damage: 'seam',
        material: 'denim',
        machineAvailable: false,
      ),
      isEmpty,
    );
    expect(
      catalog
          .retrieve(damage: 'seam', material: 'denim', machineAvailable: true)
          .single
          .id,
      'straight-seam',
    );
    expect(
      catalog.retrieve(
        damage: 'stain',
        material: 'woven',
        machineAvailable: true,
      ),
      isEmpty,
    );
  });
}
