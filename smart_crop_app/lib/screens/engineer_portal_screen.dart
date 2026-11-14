import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/embedded_crop_data.dart';
import '../l10n/app_strings.dart';
import '../providers/terra_provider.dart';

class EngineerPortalScreen extends StatefulWidget {
  const EngineerPortalScreen({super.key});

  @override
  State<EngineerPortalScreen> createState() => _EngineerPortalScreenState();
}

class _EngineerPortalScreenState extends State<EngineerPortalScreen> {
  final _nameCtrl = TextEditingController(text: 'م. عمر يوسف');
  final _phoneCtrl = TextEditingController(text: '01000000007');
  final _expCtrl = TextEditingController(text: '10');
  String _specialty = 'أمراض نباتية';
  Map<String, dynamic> _selectedLoc = EmbeddedCropData.egyptLocations[1];
  bool _registered = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerEngineer(TerraProvider tp) async {
    final s = AppStrings(tp.isEnglish);
    await tp.registerAndEnterEngineer(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      lat: (_selectedLoc['lat'] as num).toDouble(),
      lon: (_selectedLoc['lon'] as num).toDouble(),
      specialty: _specialty,
      governorate: _selectedLoc['name'].toString(),
      yearsOfExp: int.tryParse(_expCtrl.text.trim()) ?? 8,
    );
    if (!mounted) return;
    setState(() => _registered = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'تم تسجيل بيانات المهندس الزراعي وتحديث الحالات ✅',
            'Engineer profile saved & cases refreshed ✅',
          ),
        ),
      ),
    );
  }

  void _openAdviceDialog(TerraProvider tp, AppStrings s, int requestId) {
    final adviceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('إرسال توصية وعلاج للمزارع', 'Send Advice & Treatment to Farmer')),
        content: TextField(
          controller: adviceCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: s.t(
              'اكتب الجرعة المناسبة أو خطة المعالجة الزراعية...',
              'Enter dosage, irrigation adjustment, or treatment plan...',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              final text = adviceCtrl.text.trim();
              if (text.isNotEmpty) {
                await tp.replyAsEngineer(
                  requestId: requestId,
                  status: 'done',
                  advice: text,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('إرسال للمزارع', 'Send to Farmer')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);
    final cases = tp.engineerCases.isNotEmpty ? tp.engineerCases : tp.sentFarmerConsultations;

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
                Row(
                  children: [
                    const Icon(Icons.engineering_rounded, color: Color(0xFF1B5E20), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.t(
                              '👨‍🔬 حساب المهندس: ${s.engineerName(_nameCtrl.text)}',
                              '👨‍🔬 Engineer Profile: ${s.engineerName(_nameCtrl.text)}',
                            ),
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            s.t(
                              'التخصص: ${s.specialty(_specialty)} • تليفون: ${_phoneCtrl.text}',
                              'Specialty: ${s.specialty(_specialty)} • Phone: ${_phoneCtrl.text}',
                            ),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _registered = !_registered),
                      icon: Icon(_registered ? Icons.edit_rounded : Icons.expand_less_rounded, size: 18),
                      label: Text(_registered ? s.t('تبديل / تعديل الحساب', 'Edit / Switch') : s.t('إخفاء', 'Hide')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: EmbeddedCropData.rawEngineers.take(6).map((e) {
                      final active = _phoneCtrl.text == e['phone'].toString();
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ActionChip(
                          backgroundColor: active ? const Color(0xFF1B5E20) : const Color(0xFFE8F5E9),
                          label: Text(
                            '${s.engineerName(e['name'].toString())} (${s.specialty(e['specialty'].toString())})',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: active ? Colors.white : const Color(0xFF1B5E20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _nameCtrl.text = e['name'].toString();
                              _phoneCtrl.text = e['phone'].toString();
                              _specialty = e['specialty'].toString();
                            });
                            _registerEngineer(tp);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (!_registered) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: s.t('اسم المهندس الزراعي', 'Engineer Name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(
                      labelText: s.t('رقم الهاتف', 'Phone Number'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _specialty,
                    decoration: InputDecoration(
                      labelText: s.t('التخصص', 'Specialty'),
                      border: const OutlineInputBorder(),
                    ),
                    items: const ['أمراض نباتية', 'محاصيل حقلية', 'خضروات', 'فاكهة', 'ري وتربة']
                        .map((sp) => DropdownMenuItem(value: sp, child: Text(s.specialty(sp))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _specialty = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedLoc,
                    decoration: InputDecoration(
                      labelText: s.t('المحافظة / الموقع', 'Region / Location'),
                      border: const OutlineInputBorder(),
                    ),
                    items: EmbeddedCropData.egyptLocations
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(
                              tp.isEnglish
                                  ? (l['name_en'] ?? s.locationName(l['name'].toString())).toString()
                                  : l['name'].toString(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLoc = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _expCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: s.t('سنوات الخبرة', 'Years of Experience'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                      onPressed: () => _registerEngineer(tp),
                      child: Text(s.t('تسجيل وحفظ بيانات المهندس', 'Save Engineer Profile')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: const Color(0xFF0D3B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.satellite_alt_rounded, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.t(
                          'بيانات ناسا العلمية التفصيلية للمهندس (NASA POWER & Open-Meteo Telemetry)',
                          'NASA POWER & Open-Meteo Agronomist Telemetry',
                        ),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.t(
                    'إحداثيات المزارع الحالي (${tp.farmer.name}): (${tp.farmer.lat.toStringAsFixed(4)}, ${tp.farmer.lon.toStringAsFixed(4)}) • الارتفاع: ${(tp.climate.elevation ?? 18.0).toStringAsFixed(0)}م',
                    'Farmer Coordinates (${tp.farmer.name}): (${tp.farmer.lat.toStringAsFixed(4)}, ${tp.farmer.lon.toStringAsFixed(4)}) • Elev: ${(tp.climate.elevation ?? 18.0).toStringAsFixed(0)}m',
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _engTelemetryChip(s.t('T2M (متوسط)', 'T2M (Avg)'), '${tp.climate.tAvg.toStringAsFixed(1)}°C'),
                    _engTelemetryChip(s.t('T2M_MAX (عظمى)', 'T2M_MAX'), '${tp.climate.tMax.toStringAsFixed(1)}°C'),
                    _engTelemetryChip(s.t('T2M_MIN (صغرى)', 'T2M_MIN'), '${tp.climate.tMin.toStringAsFixed(1)}°C'),
                    _engTelemetryChip(s.t('GWETROOT (رطوبة الجذور)', 'GWETROOT (Root)'), '${(tp.climate.soilAvg * 100).toStringAsFixed(1)}%'),
                    _engTelemetryChip(s.t('RH2M (رطوبة جوية)', 'RH2M (Humidity)'), '${tp.climate.rhAvg.toStringAsFixed(0)}%'),
                    _engTelemetryChip(s.t('PRECTOTCORR (أمطار 30 يوم)', 'PRECTOTCORR (30d)'), '${tp.climate.rainTotal.toStringAsFixed(1)} mm'),
                    _engTelemetryChip(s.t('Open-Meteo (أمطار 48س)', 'Open-Meteo (48h)'), '${(tp.climate.rainNext2d ?? 0.0).toStringAsFixed(1)} mm'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.t('📥 حالات المزارعين الواردة:', '📥 Incoming Farmer Cases:'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => tp.loadEngineerCases(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: s.t('تحديث الحالات', 'Refresh cases'),
            ),
          ],
        ),
        if (cases.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                s.t(
                  'لا توجد حالات تصعيد أو استشارات معلقة حالياً. عند قيام أي مزارع بتصوير حالة حرجة سيتم تحويلها هنا فوراً.',
                  'No pending escalations or consultations yet. Critical field scans will appear here automatically.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...cases.map(
            (c) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.t('المزارع: ${c.otherName}', 'Farmer: ${c.otherName}'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Chip(label: Text(s.consultationStatus(c))),
                      ],
                    ),
                    if (c.distanceKm != null)
                      Text(
                        s.t(
                          'المسافة: ${c.distanceKm} كم • الهاتف: ${c.otherPhone}',
                          'Distance: ${c.distanceKm} km • Phone: ${c.otherPhone}',
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    if (c.diseaseClass != null)
                      Text(
                        s.t('التشخيص المبدئي: ${c.diseaseClass}', 'Initial Diagnosis: ${c.diseaseClass}'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (c.symptoms != null) Text(s.t('الأعراض: ${c.symptoms}', 'Symptoms: ${c.symptoms}')),
                    if (c.note != null) Text(s.t('ملاحظة: ${c.note}', 'Note: ${c.note}')),
                    if (c.engineerAdvice != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                        child: Text(s.t('توصيتك المرسلة: ${c.engineerAdvice}', 'Your Sent Advice: ${c.engineerAdvice}')),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                        onPressed: () => _openAdviceDialog(tp, s, c.id),
                        icon: const Icon(Icons.medical_services_rounded, size: 18),
                        label: Text(s.t('إرسال توصية للمزارع', 'Send Advice to Farmer')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _engTelemetryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          Text(value, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

