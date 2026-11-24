/// Environmental impact calculation service for repaired garments.
class ImpactService {
  ImpactService._();

  /// Estimated CO₂ emissions avoided per garment kept in service (33.4 kg).
  static const double co2PerGarmentKg = 33.4;

  /// Estimated water footprint saved per garment kept in service (3,781 liters).
  static const int waterPerGarmentLiters = 3781;

  /// Calculates cumulative environmental savings for [completedRepairs].
  ///
  /// Returns a record with:
  /// - `co2Saved`: Kilograms of CO₂ avoided (33.4 kg per garment).
  /// - `waterSaved`: Liters of water conserved (3,781 L per garment).
  /// - `wasteAvoided`: Total garments diverted from landfill.
  static ({double co2Saved, int waterSaved, int wasteAvoided}) calculateImpact(
    int completedRepairs,
  ) {
    final count = completedRepairs < 0 ? 0 : completedRepairs;
    return (
      co2Saved: count * co2PerGarmentKg,
      waterSaved: count * waterPerGarmentLiters,
      wasteAvoided: count,
    );
  }
}
