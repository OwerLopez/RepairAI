import 'package:flutter/material.dart';
import 'glass.dart';
import 'services/impact_service.dart';
import 'ui.dart';

/// Widget displaying environmental impact metrics calculated from completed repairs.
class ImpactWidget extends StatelessWidget {
  /// Creates an [ImpactWidget] displaying impact statistics for [completedRepairs].
  const ImpactWidget({super.key, required this.completedRepairs});

  /// The number of successfully completed repairs.
  final int completedRepairs;

  @override
  Widget build(BuildContext context) {
    final impact = ImpactService.calculateImpact(completedRepairs);

    return GlassCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Glyph(Icons.eco_outlined, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('Impacto ambiental', 'Environmental impact'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: ice,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.t(
                        'Ahorro estimado por tus prendas reparadas',
                        'Estimated savings from your repaired garments',
                      ),
                      style: const TextStyle(color: softText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.check_circle_outline,
                  value: '${impact.wasteAvoided}',
                  label: context.t('Prendas', 'Garments'),
                  unit: context.t('rescatadas', 'rescued'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.cloud_outlined,
                  value: impact.co2Saved.toStringAsFixed(1),
                  label: 'kg CO₂',
                  unit: context.t('evitados', 'saved'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.water_drop_outlined,
                  value: '${impact.waterSaved}',
                  label: 'L',
                  unit: context.t('ahorrados', 'saved'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.unit,
  });

  final IconData icon;
  final String value;
  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x3506111f),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x3384cce1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: ice),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: frost,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ice,
            ),
          ),
          Text(unit, style: const TextStyle(fontSize: 10, color: softText)),
        ],
      ),
    );
  }
}
