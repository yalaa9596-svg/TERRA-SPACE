import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/embedded_crop_data.dart';
import '../l10n/app_strings.dart';
import '../providers/terra_provider.dart';
import 'farmer/voice_assistant_screen.dart';

class RotationExplorerTab extends StatefulWidget {
  const RotationExplorerTab({super.key});

  @override
  State<RotationExplorerTab> createState() => _RotationExplorerTabState();
}

class _RotationExplorerTabState extends State<RotationExplorerTab> {
  Future<void> _showAddCustomCropDialog(
      BuildContext context, TerraProvider tp, AppStrings s) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.t('إضافة محصول جديد لليستة زرعتك', 'Add Custom Crop to Your Farm'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t(
                'اكتب اسم أي محصول بتزرعه (أو قول للمساعد الصوتي في الشات وهيضيفه تلقائياً):',
                'Enter any crop you grow (or tell the Voice Agent in chat to add it automatically):',
              ),
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: s.t(
                  'مثال: عنب، مانجو، بطاطس، فراولة، بصل...',
                  'e.g. Avocado, Soybean, Mango, Onion...',
                ),
                filled: true,
                fillColor: const Color(0xFFF1F8E9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (val) async {
                if (val.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  await tp.addAndSelectCustomCrop(val.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                await tp.addAndSelectCustomCrop(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(s.t('إضافة واختيار', 'Add & Select')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);
    final allCrops = EmbeddedCropData.allFarmerCrops;
    final currentCropId = tp.farmer.cropId ?? 'wheat';
    final currentCrop = EmbeddedCropData.rotationById[currentCropId] ??
        EmbeddedCropData.ensureCropRegistered(cropId: currentCropId);

    if (tp.weatherAlertTitle == null) {
      tp.evaluateWeatherNotification();
    }

    return Container(
      color: const Color(0xFFF4F8F3),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location,
                        color: Colors.amberAccent, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${tp.farmer.name} • ${tp.locationLabel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => tp.refreshLocationAndClimate(autoGps: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          s.t('تحديث GPS', 'Sync GPS'),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _miniStatPill(
                      '🌡️ ${tp.climate.tMax.toStringAsFixed(0)}°${s.t("م", "C")}',
                    ),
                    const SizedBox(width: 4),
                    _miniStatPill(
                      '💧 ${(tp.climate.soilAvg * 100).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => tp.triggerSimulatedWeatherAlert('heat'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.t('🔥 تنبيه حر', '🔥 Heat Alert'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => tp.triggerSimulatedWeatherAlert('rain'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.t('🌧️ تنبيه مطر', '🌧️ Rain Alert'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (tp.showWeatherBanner && tp.weatherAlertTitle != null)
            _buildWeatherNotificationBanner(context, tp, s),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.green.shade100),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${s.t("زرعتك", "Your Crop")}: ${currentCrop.icon} ${s.cropName(currentCrop)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: allCrops.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 5),
                      itemBuilder: (context, index) {
                        if (index == allCrops.length) {
                          return ActionChip(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            backgroundColor: const Color(0xFFFFF8E1),
                            side: BorderSide(color: Colors.amber.shade700),
                            label: Text(
                              s.t('+ محصول آخر', '+ Add Crop'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100),
                              ),
                            ),
                            onPressed: () =>
                                _showAddCustomCropDialog(context, tp, s),
                          );
                        }
                        final c = allCrops[index];
                        final selected = c.id == currentCrop.id;
                        return ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          label: Text(
                            '${c.icon} ${s.cropName(c)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF1B5E20),
                            ),
                          ),
                          selected: selected,
                          selectedColor: const Color(0xFF2E7D32),
                          backgroundColor: const Color(0xFFF1F8E9),
                          onSelected: (_) {
                            tp.updateFarmerProfile(
                              name: tp.farmer.name,
                              targetCrop: c.id,
                            );
                            tp.evaluateWeatherNotification();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: VoiceAssistantPanel(fullScreen: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherNotificationBanner(
      BuildContext context, TerraProvider tp, AppStrings s) {
    final isUrgent = tp.weatherAlertType == 'urgent';
    final isRain = tp.weatherAlertType == 'rain';

    final Color bgColor = isUrgent
        ? const Color(0xFFFFF3E0)
        : isRain
            ? const Color(0xFFE3F2FD)
            : const Color(0xFFE8F5E9);
    final Color borderColor = isUrgent
        ? const Color(0xFFE65100)
        : isRain
            ? const Color(0xFF1565C0)
            : const Color(0xFF2E7D32);
    final IconData alertIcon = isUrgent
        ? Icons.wb_sunny_rounded
        : isRain
            ? Icons.thunderstorm_rounded
            : Icons.notifications_active_rounded;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alertIcon, color: borderColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tp.weatherAlertTitle ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: borderColor,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  if (tp.weatherAlertBody != null) {
                    tp.voiceService.unlockAudioOnGesture();
                    tp.voiceService.speak(tp.weatherAlertBody!);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.volume_up, color: Colors.white, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        s.t('اسمع التنبيه', 'Listen'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  final q = tp.isEnglish
                      ? (isRain
                          ? 'Rain is forecasted, should I stop irrigating and what should I do for my crop?'
                          : 'Heat and dry soil warning! What should I do right now to protect my crop?')
                      : (isRain
                          ? 'فيه أمطار جاية، أعمل إيه في محصولي وأروي ولا أوقف الري؟'
                          : 'الحرارة عالية وفيه جفاف، أعمل إيه في محصولي دلوقتي عشان أحميه؟');
                  tp.sendVoiceQuery(q, speakReply: true);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    s.t('اسأل الإيجنت', 'Ask Agent'),
                    style: TextStyle(
                      color: borderColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: tp.dismissWeatherBanner,
                child: Icon(Icons.close, size: 15, color: borderColor),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            tp.weatherAlertBody ?? '',
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
