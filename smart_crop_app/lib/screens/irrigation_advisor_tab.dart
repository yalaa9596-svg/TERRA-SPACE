import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/embedded_crop_data.dart';
import '../l10n/app_strings.dart';
import '../providers/terra_provider.dart';
import '../services/rotation_engine.dart';

class IrrigationAdvisorTab extends StatelessWidget {
  const IrrigationAdvisorTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);
    final currentCropId = tp.farmer.cropId ?? 'wheat';
    final crop = EmbeddedCropData.rotationById[currentCropId] ??
        EmbeddedCropData.rotationCrops.first;
    final alert = tp.latestIrrigationAlert ??
        RotationEngine.computeIrrigationAlert(
          crop: crop,
          climate: tp.climate,
          language: tp.appLang,
        );
    final displayMessage =
        (tp.isEnglish && RegExp(r'[\u0600-\u06FF]').hasMatch(alert.message))
            ? RotationEngine.computeIrrigationAlert(
                crop: crop,
                climate: tp.climate,
                language: 'en',
              ).message
            : alert.message;
    final displayState = s.irrigationState(alert);
    final displayAction = s.irrigationAction(alert);
    final displayCropName = s.cropName(crop);

    final statusColor = alert.level == 'urgent'
        ? const Color(0xFFC62828)
        : alert.level == 'water'
            ? const Color(0xFFEF6C00)
            : alert.level == 'skip'
                ? const Color(0xFF1565C0)
                : alert.level == 'wave'
                    ? const Color(0xFF6A1B9A)
                    : const Color(0xFF2E7D32);

    final stateIcon = alert.level == 'urgent'
        ? '🚨'
        : alert.level == 'water'
            ? '💧'
            : alert.level == 'skip'
                ? '🌧️'
                : alert.level == 'wave'
                    ? '🌡️'
                    : '✅';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: statusColor, width: 1.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(crop.icon, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t(
                            'محصول المزارع الحالي: $displayCropName',
                            'Current Crop: $displayCropName',
                          ),
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.t('الحالة: $displayState $stateIcon', 'Status: $displayState $stateIcon'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      tp.voiceService.unlockAudioOnGesture();
                      tp.voiceService.speak(displayMessage);
                    },
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: s.t('استمع لتوصية الري', 'Listen to irrigation advice'),
                  ),
                ],
              ),
              if (displayAction.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.t('الإجراء المطلوب: $displayAction', 'Required Action: $displayAction'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  displayMessage,
                  style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    '🛰️ مؤشرات الري الـ 5 من ناسا (NASA POWER + Open-Meteo)',
                    '🛰️ 5-State NASA Irrigation Telemetry (NASA POWER + Open-Meteo)',
                  ),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _gaugeTile(
                  title: s.t(
                    'رطوبة منطقة الجذور الحالية (GWETROOT)',
                    'Current Root-Zone Soil Moisture (GWETROOT)',
                  ),
                  subtitle: s.t(
                    'الحد الأدنى الآمن لمحصول $displayCropName: ${(crop.soilMoistureMin * 100).toInt()}%',
                    'Safe minimum for $displayCropName: ${(crop.soilMoistureMin * 100).toInt()}%',
                  ),
                  progress: tp.climate.soilAvg.clamp(0.0, 1.0),
                  trailing: '${(tp.climate.soilAvg * 100).toStringAsFixed(0)}%',
                  color: tp.climate.soilAvg >= crop.soilMoistureMin ? Colors.teal : Colors.redAccent,
                ),
                const Divider(height: 24),
                _metricRow(
                  Icons.opacity_rounded,
                  s.t('كمية مياه الري المقترحة اليوم:', 'Recommended Water Today:'),
                  alert.waterMm > 0
                      ? s.t(
                          '${alert.waterMm} لتر / م² (${(alert.waterMm * 4.2).toStringAsFixed(0)} م³ للفدان)',
                          '${alert.waterMm} L/m² (${(alert.waterMm * 4.2).toStringAsFixed(0)} m³/feddan)',
                        )
                      : s.t('0 لتر (لا يحتاج ري)', '0 L (No irrigation needed)'),
                ),
                _metricRow(
                  Icons.wb_sunny_rounded,
                  s.t('أقصى درجة حرارة مسجلة:', 'Max Recorded Temperature:'),
                  s.t('${tp.climate.tMax.toStringAsFixed(1)}°م', '${tp.climate.tMax.toStringAsFixed(1)}°C'),
                ),
                _metricRow(
                  Icons.umbrella_rounded,
                  s.t('إجمالي الأمطار خلال 7 أيام:', '7-Day Total Rainfall:'),
                  s.t('${tp.climate.rainTotal.toStringAsFixed(1)} ملم', '${tp.climate.rainTotal.toStringAsFixed(1)} mm'),
                ),
                _metricRow(
                  Icons.cloud_queue_rounded,
                  s.t('توقعات الأمطار خلال 48 ساعة:', '48h Rain Forecast:'),
                  s.t(
                    '${(tp.climate.rainNext2d ?? 0.0).toStringAsFixed(1)} ملم',
                    '${(tp.climate.rainNext2d ?? 0.0).toStringAsFixed(1)} mm',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFF1F8E9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('📋 حالات محرك الري الخمسة المعتمدة:', '📋 5-State NASA Irrigation Engine Rules:'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(s.t(
                  '1. ري عاجل: رطوبة منخفضة + حرارة مرتفعة فوق المثالي بـ 3°م.',
                  '1. Urgent Irrigation: Dry root zone + heat > optimal +3°C.',
                )),
                Text(s.t(
                  '2. ري مطلوب: تربة جافة أو حرارة عالية بدون مطر كافٍ.',
                  '2. Irrigation Needed: Dry soil or prolonged heat without rain.',
                )),
                Text(s.t(
                  '3. لا تروي: توقع أمطار >= 5 ملم خلال يومين.',
                  '3. Do Not Irrigate: >= 5 mm rain forecasted in 48 hours.',
                )),
                Text(s.t(
                  '4. موجة حر أو برد: درجات حرارة تتجاوز حد تحمل المحصول.',
                  '4. Heat / Cold Wave: Temperatures exceed crop tolerance bounds.',
                )),
                Text(s.t(
                  '5. تمام: جميع المؤشرات متوازنة والأرض في أمان.',
                  '5. All Good: Moisture and climate indicators are balanced.',
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gaugeTile({
    required String title,
    required String subtitle,
    required double progress,
    required String trailing,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            Text(trailing, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _metricRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
        ],
      ),
    );
  }
}
