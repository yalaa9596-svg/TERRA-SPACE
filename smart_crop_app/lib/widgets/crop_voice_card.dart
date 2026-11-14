import 'package:flutter/material.dart';
import '../models/crop_models.dart';
import '../services/voice_service.dart';

class CropVoiceCard extends StatelessWidget {
  final CropRotationItem crop;
  final String dialogue;
  final bool isSuitable;
  final VoiceService voiceService;

  const CropVoiceCard({
    super.key,
    required this.crop,
    required this.dialogue,
    required this.isSuitable,
    required this.voiceService,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSuitable
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final borderColor = isSuitable
        ? const Color(0xFF2E7D32)
        : const Color(0xFFE65100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Text(
                  crop.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رسالة صوتية من ${crop.nameAr}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                    Text(
                      isSuitable
                          ? 'تحليل أقمار ناسا والدورة الزراعية: مناسب للزراعة ✅'
                          : 'تنبيه الدورة الزراعية أو المناخ ⚠️',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: voiceService.isSpeaking,
                builder: (context, speaking, _) {
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: borderColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      if (speaking) {
                        voiceService.stop();
                      } else {
                        voiceService.speak(dialogue);
                      }
                    },
                    icon: Icon(speaking ? Icons.stop_circle : Icons.volume_up_rounded),
                    label: Text(speaking ? 'إيقاف' : 'اسمعني'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '"$dialogue"',
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B3B2B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

