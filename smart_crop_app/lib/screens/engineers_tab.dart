import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../models/crop_models.dart';
import '../providers/terra_provider.dart';
import '../services/rotation_engine.dart';

class EngineersTab extends StatefulWidget {
  const EngineersTab({super.key});

  @override
  State<EngineersTab> createState() => _EngineersTabState();
}

class _EngineersTabState extends State<EngineersTab> {
  String? _selectedSpecialty;
  final TextEditingController _noteController = TextEditingController();

  static const List<String> _specialties = [
    'الكل',
    'أمراض نباتية',
    'محاصيل حقلية',
    'خضروات',
    'فاكهة',
    'ري وتربة',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _callPhone(String phone) async {
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {}
  }

  void _sendRequest(TerraProvider tp, EngineerProfile eng) {
    final s = AppStrings(tp.isEnglish);
    tp.addFarmerConsultation(eng, _noteController.text.trim());
    _noteController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'تم إرسال طلب استشارة المزارع إلى ${eng.name} (${eng.distanceKm} كم من أرضك) ✅',
            'Consultation sent to ${s.engineerName(eng.name)} (${eng.distanceKm} km away) ✅',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);
    final ranked = RotationEngine.rankEngineers(
      lat: tp.farmer.lat,
      lon: tp.farmer.lon,
      specialty: (_selectedSpecialty == null || _selectedSpecialty == 'الكل')
          ? null
          : _selectedSpecialty,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('👨‍🌾 أقرب المهندسين الزراعيين لموقع المزارع', '👨‍🌾 Nearest Agricultural Engineers'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  s.t(
                    'يتم ترتيب المهندسين تلقائياً بالمسافة الجغرافية (Haversine) والتخصص الزراعي الدقيق:',
                    'Engineers are ranked automatically by Haversine GPS distance and crop specialty:',
                  ),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _specialties.map((spec) {
                      final isSelected = (_selectedSpecialty ?? 'الكل') == spec;
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(s.specialty(spec)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedSpecialty = spec),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: s.t('ملاحظة المزارع للمهندس (اختياري)', 'Note to the engineer (optional)'),
                    hintText: s.t(
                      'مثال: توجد بقع صفراء على أوراق الطماطم...',
                      'Example: Yellow spots appearing on lower tomato leaves...',
                    ),
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tp.sentFarmerConsultations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            s.t('📌 طلبات الاستشارة والحالات المصعّدة:', '📌 Sent Consultations & Escalations:'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...tp.sentFarmerConsultations.map(
            (r) => Card(
              color: const Color(0xFFE8F5E9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF2E7D32),
                  child: Icon(Icons.assignment_turned_in, color: Colors.white),
                ),
                title: Text(
                  '${s.engineerName(r.otherName)} • ${s.consultationStatus(r)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  s.t(
                    '${r.note ?? ''}\nهاتف: ${r.otherPhone}',
                    '${r.note ?? ''}\nPhone: ${r.otherPhone}',
                  ),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF1B5E20)),
                  onPressed: () => _callPhone(r.otherPhone),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...ranked.take(8).map((eng) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                child: const Icon(Icons.engineering_rounded, color: Color(0xFF1B5E20)),
              ),
              title: Text(
                '${s.engineerName(eng.name)} (${s.locationName(eng.governorate)})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.t(
                    'التخصص: ${s.specialty(eng.specialty)} • خبرة ${eng.yearsOfExp} سنوات • المسافة: ${eng.distanceKm} كم\nهاتف: ${eng.phone}',
                    'Specialty: ${s.specialty(eng.specialty)} • ${eng.yearsOfExp} yrs exp • ${eng.distanceKm} km\nPhone: ${eng.phone}',
                  ),
                  style: const TextStyle(height: 1.4),
                ),
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 6,
                children: [
                  IconButton.filledTonal(
                    tooltip: s.t('اتصال مباشر', 'Direct Call'),
                    onPressed: () => _callPhone(eng.phone),
                    icon: const Icon(Icons.call_rounded),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                    onPressed: () => _sendRequest(tp, eng),
                    child: Text(s.t('استشارة', 'Consult')),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
