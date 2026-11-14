import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/embedded_crop_data.dart';
import '../l10n/app_strings.dart';
import '../models/crop_models.dart';
import '../providers/terra_provider.dart';

class VisionDoctorTab extends StatefulWidget {
  const VisionDoctorTab({super.key});

  @override
  State<VisionDoctorTab> createState() => _VisionDoctorTabState();
}

class _VisionDoctorTabState extends State<VisionDoctorTab> {
  final ImagePicker _picker = ImagePicker();
  String _selectedCropId = 'tomato';
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;

  Future<void> _pickAndDiagnose(ImageSource source) async {
    final tp = context.read<TerraProvider>();
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedFileName = picked.name;
      });
      await tp.runPlantDocDiagnosis(
        cropId: _selectedCropId,
        imageBytes: bytes,
        filename: picked.name,
      );
    } catch (_) {
      await tp.runPlantDocDiagnosis(
        cropId: _selectedCropId,
        filename: _selectedFileName ?? '${_selectedCropId}_leaf.jpg',
      );
    }
  }

  Future<void> _runSampleScan({double? simulatedConfidence, String? hintClass}) async {
    final tp = context.read<TerraProvider>();
    await tp.runPlantDocDiagnosis(
      cropId: _selectedCropId,
      imageBytes: _selectedImageBytes,
      filename: _selectedFileName ?? '${_selectedCropId}_field.jpg',
      hintClass: hintClass,
      simulatedConfidence: simulatedConfidence,
    );
  }

  Future<void> _callEngineer(String phone) async {
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);
    final diag = tp.latestDiagnosis;

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
                  s.t('📸 تشخيص أمراض النباتات (PlantDoc AI)', '📸 Plant Disease Diagnosis (PlantDoc AI)'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  s.t(
                    'مدعوم بمجموعة بيانات PlantDoc الحقلية الحقيقية (27 فئة أمراض وأوراق سليمة)، مع إحالة تلقائية للمهندس عند انخفاض الثقة عن 75% أو في المحاصيل غير المدعومة.',
                    'Powered by the real-field PlantDoc dataset (27 disease & healthy classes), with automatic agronomist escalation when confidence < 75% or for out-of-scope crops.',
                  ),
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCropId,
                  decoration: InputDecoration(
                    labelText: s.t('اختر المحصول المراد فحصه يا أخي المزارع', 'Select the crop to inspect'),
                    prefixIcon: const Icon(Icons.eco_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: EmbeddedCropData.visionCrops.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(s.visionCropTitle(c)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCropId = v);
                  },
                ),
                const SizedBox(height: 14),
                if (_selectedImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _selectedImageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded, size: 38, color: Color(0xFF2E7D32)),
                        const SizedBox(height: 6),
                        Text(
                          s.t(
                            'التقط صورة واضحة لورقة المحصول المصابة',
                            'Capture or upload a clear photo of the affected leaf',
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                        onPressed: tp.loadingDiagnosis ? null : () => _pickAndDiagnose(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: Text(s.t('تصوير بالكاميرا', 'Take Photo')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: tp.loadingDiagnosis ? null : () => _pickAndDiagnose(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: Text(s.t('اختيار من المعرض', 'Gallery')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.biotech_rounded, size: 18),
                      label: Text(s.t('فحص فوري عالي الثقة (88%)', 'Quick High-Confidence Scan (88%)')),
                      onPressed: tp.loadingDiagnosis ? null : () => _runSampleScan(simulatedConfidence: 0.88),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                      label: Text(s.t('اختبار ثقة < 75% (تصعيد مهندس)', 'Test Confidence < 75% (Escalate)')),
                      onPressed: tp.loadingDiagnosis ? null : () => _runSampleScan(simulatedConfidence: 0.64),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (tp.loadingDiagnosis)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (diag != null) ...[
          const SizedBox(height: 16),
          _buildDiagnosisResultCard(tp, s, diag),
        ],
      ],
    );
  }

  Widget _buildDiagnosisResultCard(TerraProvider tp, AppStrings s, VisionDiagnosisResult diag) {
    final badgeColor = diag.isHealthy
        ? const Color(0xFF2E7D32)
        : diag.escalateToEngineer
            ? const Color(0xFFC62828)
            : const Color(0xFFEF6C00);

    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diag.diseaseNameAr,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.t(
                          'التصنيف: ${diag.predictedClass} • الثقة: ${diag.confidencePct}%',
                          'Class: ${diag.predictedClass} • Confidence: ${diag.confidencePct}%',
                        ),
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {
                    tp.voiceService.unlockAudioOnGesture();
                    tp.voiceService.speak(diag.voiceMessageAr, audioUrl: diag.audioUrl);
                  },
                  icon: const Icon(Icons.volume_up_rounded),
                  tooltip: s.t('سماع التشخيص بالصوت', 'Listen to diagnosis'),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              s.t('💬 رسالة المساعد الصوتي للمزارع:', '💬 Voice Assistant Summary:'),
              style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
            ),
            const SizedBox(height: 4),
            Text(diag.voiceMessageAr, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 12),
            Text(
              s.t('🔍 الأعراض الملاحظة:', '🔍 Observed Symptoms:'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(diag.symptomsAr, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 10),
            Text(
              s.t('🌿 العلاج العضوي الآمن:', '🌿 Safe Organic Treatment:'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
            Text(diag.organicTreatmentAr, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 10),
            Text(
              s.t('🧪 العلاج الكيميائي الموصى به:', '🧪 Recommended Chemical Treatment:'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
            ),
            Text(diag.chemicalTreatmentAr, style: const TextStyle(height: 1.4)),
            if (diag.escalateToEngineer) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t(
                        '🚨 تم التصعيد التلقائي لأقرب مهندس زراعي',
                        '🚨 Escalated to Nearest Agricultural Engineer',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C)),
                    ),
                    if (diag.escalationReason != null) ...[
                      const SizedBox(height: 4),
                      Text(diag.escalationReason!, style: const TextStyle(fontSize: 13)),
                    ],
                    if (diag.recommendedEngineer != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.t(
                                'المهندس المختص: ${s.engineerName(diag.recommendedEngineer!.name)}\n'
                                'التخصص: ${s.specialty(diag.recommendedEngineer!.specialty)} • المسافة: ${diag.recommendedEngineer!.distanceKm} كم',
                                'Assigned Engineer: ${s.engineerName(diag.recommendedEngineer!.name)}\n'
                                'Specialty: ${s.specialty(diag.recommendedEngineer!.specialty)} • Distance: ${diag.recommendedEngineer!.distanceKm} km',
                              ),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
                            onPressed: () => _callEngineer(diag.recommendedEngineer!.phone),
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: Text(s.t('اتصل الآن', 'Call Now')),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

