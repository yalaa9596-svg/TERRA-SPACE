import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/embedded_crop_data.dart';
import '../l10n/app_strings.dart';
import '../providers/terra_provider.dart';
import 'auth_screen.dart';
import 'engineer_portal_screen.dart';
import 'engineers_tab.dart';
import 'irrigation_advisor_tab.dart';
import 'rotation_explorer_tab.dart';
import 'vision_doctor_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  void _openFarmerAccountDialog(BuildContext context, TerraProvider tp) {
    final s = AppStrings(tp.isEnglish);
    final nameCtrl = TextEditingController(text: tp.farmer.name);
    final serverCtrl = TextEditingController(text: tp.apiService.baseUrl);
    String selectedCrop = tp.farmer.cropId ?? 'wheat';
    EmbeddedCropData.ensureCropRegistered(cropId: selectedCrop);
    String? selectedPrev = tp.farmer.previousCropId ?? 'clover';
    Map<String, dynamic> selectedLoc = EmbeddedCropData.egyptLocations.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(s.t('👨‍🌾 بيانات أرضك ومحصولك', '👨‍🌾 Farm & Crop Profile')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.t('اسمك', 'Farmer Name'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedLoc,
                  decoration: InputDecoration(
                    labelText: s.t('المحافظة / موقع الأرض', 'Region / Field Location'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: EmbeddedCropData.egyptLocations
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(
                            tp.isEnglish
                                ? (l['name_en'] ?? l['name']).toString()
                                : l['name'].toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedLoc = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedCrop,
                  decoration: InputDecoration(
                    labelText: s.t('المحصول اللي زارعه دلوقتي', 'Current Active Crop'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: EmbeddedCropData.allFarmerCrops
                      .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${s.cropName(c)}')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedCrop = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: serverCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: s.t('🌐 رابط السيرفر (اختياري)', '🌐 Backend Server URL (Optional)'),
                    hintText: 'http://10.135.89.240:8000',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('إلغاء', 'Cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
              onPressed: () async {
                if (serverCtrl.text.trim().isNotEmpty &&
                    serverCtrl.text.trim() != tp.apiService.baseUrl) {
                  await tp.setServerUrl(serverCtrl.text);
                }
                await tp.updateFarmerProfile(
                  name: nameCtrl.text.trim().isEmpty ? tp.farmer.name : nameCtrl.text.trim(),
                  phone: tp.farmer.phone,
                  targetCrop: selectedCrop,
                  previousCrop: selectedPrev,
                  lat: (selectedLoc['lat'] as num).toDouble(),
                  lon: (selectedLoc['lon'] as num).toDouble(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.t('حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);

    if (!tp.isAuthenticated) {
      return const AuthScreen();
    }

    const farmerPages = [
      RotationExplorerTab(),
      VisionDoctorTab(),
      IrrigationAdvisorTab(),
      EngineersTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: tp.isEngineerPortal ? const Color(0xFF0D47A1) : const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        titleSpacing: 10,
        title: Row(
          children: [
            const TerraLogoBadge(size: 36, borderRadius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Terra Space — تحدي ناسا', 'Terra Space — NASA Agritech'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    tp.isEngineerPortal
                        ? '${s.t("👨‍🔬 المهندس", "👨‍🔬 Eng.")}: ${s.engineerName(tp.activeEngineer?.name ?? s.t("مهندس زراعي", "Agronomist"))} • ${s.specialty(tp.activeEngineer?.specialty ?? "")}'
                        : '${s.t("👨‍🌾 المزارع", "👨‍🌾 Farmer")}: ${tp.farmer.name} • (${tp.farmer.phone})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: AppLanguageToggle(
              isEn: tp.isEnglish,
              compact: true,
              darkBackground: true,
              onChanged: (lang) => tp.setAppLanguage(lang),
            ),
          ),
          if (!tp.isEngineerPortal) ...[
            IconButton(
              onPressed: () => _openFarmerAccountDialog(context, tp),
              icon: const Icon(Icons.manage_accounts_rounded),
              tooltip: s.t('بيانات المزارع والأرض', 'Farm & Account Settings'),
            ),
            IconButton(
              onPressed: () => tp.refreshLocationAndClimate(autoGps: true),
              icon: const Icon(Icons.my_location_rounded),
              tooltip: s.t('تحديد موقع المزارع عبر GPS', 'Detect Location via GPS'),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              ),
              onPressed: () async {
                await tp.logout();
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: Text(
                s.t('خروج', 'Exit'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ),
        ],
      ),
      body: tp.isEngineerPortal ? const EngineerPortalScreen() : farmerPages[_tabIndex],
      bottomNavigationBar: tp.isEngineerPortal
          ? null
          : NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) {
                tp.voiceService.stop();
                setState(() => _tabIndex = i);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.record_voice_over_outlined),
                  selectedIcon: const Icon(Icons.record_voice_over_rounded),
                  label: s.t('المساعد الصوتي', 'Voice Agent'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.camera_alt_outlined),
                  selectedIcon: const Icon(Icons.camera_alt_rounded),
                  label: s.t('صوّر زرعتك', 'Plant Doctor'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.water_drop_outlined),
                  selectedIcon: const Icon(Icons.water_drop_rounded),
                  label: s.t('الري والمطر', 'Irrigation'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.engineering_outlined),
                  selectedIcon: const Icon(Icons.engineering_rounded),
                  label: s.t('مهندس جنبك', 'Agronomists'),
                ),
              ],
            ),
    );
  }
}
