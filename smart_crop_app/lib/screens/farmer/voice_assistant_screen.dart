import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/embedded_crop_data.dart';
import '../../l10n/app_strings.dart';
import '../../models/crop_models.dart';
import '../../providers/terra_provider.dart';
import '../../services/voice_service.dart';

/// شاشة المساعد الصوتي التفاعلي للمزارع
class VoiceAssistantScreen extends StatelessWidget {
  const VoiceAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const TerraLogoBadge(size: 32, borderRadius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('المساعد الصوتي التفاعلي 🌱', 'Smart Voice Agronomist 🌱'),
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    s.t(
                      'محادثة صوتية فورية مدعومة ببيانات ناسا وPlantDoc',
                      'Live Voice AI powered by NASA POWER & PlantDoc',
                    ),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: AppLanguageToggle(
              isEn: tp.isEnglish,
              compact: true,
              darkBackground: true,
              onChanged: (lang) => tp.setAppLanguage(lang),
            ),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(14),
        child: VoiceAssistantPanel(fullScreen: true),
      ),
    );
  }
}

class VoiceAssistantPanel extends StatefulWidget {
  final bool fullScreen;
  final VoidCallback? onOpenFullScreen;

  const VoiceAssistantPanel({
    super.key,
    this.fullScreen = false,
    this.onOpenFullScreen,
  });

  @override
  State<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends State<VoiceAssistantPanel> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  int _lastMsgCount = 0;

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitVoiceOrTextQuery(TerraProvider tp, String rawText) async {
    final clean = rawText.trim();
    if (clean.isEmpty) return;

    tp.voiceService.unlockAudioOnGesture();
    _queryController.clear();
    _scrollToBottom();

    await tp.sendVoiceQuery(clean, speakReply: true);
    if (!mounted) return;
    _scrollToBottom();
  }

  Future<void> _pickAndDiagnoseCropPhoto(TerraProvider tp, AppStrings s) async {
    tp.voiceService.unlockAudioOnGesture();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _scrollToBottom();
      await tp.sendCropImageInVoiceChat(
        imageBytes: bytes,
        filename: picked.name,
        speakReply: true,
      );
      if (!mounted) return;
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'تعذر فتح الصورة، جرب اختيار صورة واضحة لورقة المحصول 📸',
              'Could not open image. Please choose a clear leaf photo 📸',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _callEngineerPhone(String phone) async {
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {}
  }

  Future<void> _handleVoiceMic(TerraProvider tp, AppStrings s) async {
    tp.voiceService.unlockAudioOnGesture();

    if (tp.voiceService.isListening.value) {
      await tp.voiceService.stopListening(
        onCommitIfAny: (text) => _submitVoiceOrTextQuery(tp, text),
      );
      return;
    }

    final started = await tp.voiceService.startListening(
      onPartialResult: (partial) {
        _queryController.text = partial;
      },
      onFinalResult: (text) => _submitVoiceOrTextQuery(tp, text),
    );
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'الميكروفون يحتاج إذن الجهاز — يمكنك التحدث بعد السماح أو استخدام الكتابة/الأزرار السريعة بالأسفل 🎤',
              'Microphone permission is required — allow mic access or use text/quick prompts below 🎤',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);
    if (tp.chatMessages.length != _lastMsgCount) {
      _lastMsgCount = tp.chatMessages.length;
      _scrollToBottom();
    }

    final chatContainer = Container(
      constraints: widget.fullScreen ? null : const BoxConstraints(minHeight: 280, maxHeight: 370),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.builder(
        controller: _scrollController,
        shrinkWrap: !widget.fullScreen,
        itemCount: tp.chatMessages.length,
        itemBuilder: (context, idx) {
          final m = tp.chatMessages[idx];
          return Align(
            alignment: m.isFarmer
                ? (tp.isEnglish ? Alignment.centerRight : Alignment.centerLeft)
                : (tp.isEnglish ? Alignment.centerLeft : Alignment.centerRight),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: m.isFarmer ? const Color(0xFF1B5E20) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: m.isFarmer
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        m.imageBytes!,
                        height: 130,
                        width: 210,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          m.text,
                          textDirection: VoiceService.isArabicText(m.text)
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: m.isFarmer ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (!m.isFarmer) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            tp.voiceService.unlockAudioOnGesture();
                            tp.voiceService.speak(
                              m.text,
                              audioUrl: m.audioUrl,
                              audioUrls: m.audioUrls,
                            );
                          },
                          child: const Icon(
                            Icons.volume_up_rounded,
                            size: 18,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!m.isFarmer && m.recommendedEngineer != null) ...[
                    const SizedBox(height: 8),
                    _buildEngineerContactCard(m.recommendedEngineer!, s),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    final quickPrompts = tp.isEnglish
        ? [
            'Should I irrigate today? How is the weather?',
            'When should I plant and is my soil & climate suitable?',
            'Is my current crop suitable or recommend a better rotation?',
            'Leaves have yellow spots, what should I do?',
            'أروي النهارده ولا فيه مطر؟',
            'Find the nearest agricultural engineer and phone number',
          ]
        : [
            'أزرع إمتى وهل التربة والجو في موقعي صالحين؟',
            'Should I irrigate today? How is the weather?',
            'فيه أمطار ولا جفاف النهارده؟ أروي ولا لأ؟',
            'هل محصولي مناسب لأرضي ولا ترشحلي محصول تاني؟',
            'ورق الزرع فيه اصفرار وبقع، أعمل إيه؟',
            'اديني اسم ورقم مهندس زراعي قريب مني',
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tp, s),
          _buildLiveStatusStrip(tp, s),
          const SizedBox(height: 10),
          if (widget.fullScreen) Expanded(child: chatContainer) else chatContainer,
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.add_a_photo_rounded, size: 16, color: Color(0xFF1B5E20)),
                    backgroundColor: const Color(0xFFFFF8E1),
                    label: Text(
                      s.t('صوّر المحصول لو فيه ضرر 📸', 'Snap Leaf for Disease Check 📸'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    ),
                    onPressed: () => _pickAndDiagnoseCropPhoto(tp, s),
                  ),
                ),
                ...quickPrompts.map((p) => _quickPromptChip(tp, p)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: s.t('ارفع صورة للمحصول لفحص الضرر', 'Upload leaf photo for diagnosis'),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F5E9),
                  foregroundColor: const Color(0xFF1B5E20),
                ),
                onPressed: tp.loadingVoiceReply ? null : () => _pickAndDiagnoseCropPhoto(tp, s),
                icon: const Icon(Icons.add_a_photo_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: s.t(
                      'كلمني أو ارفع صورة المحصول يا عم المزارع...',
                      'Ask by voice/text or upload a crop photo...',
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onSubmitted: (txt) => _submitVoiceOrTextQuery(tp, txt),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                onPressed: tp.loadingVoiceReply
                    ? null
                    : () => _submitVoiceOrTextQuery(tp, _queryController.text),
                icon: tp.loadingVoiceReply
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(s.t('إرسال', 'Send')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TerraProvider tp, AppStrings s) {
    final cId = tp.farmer.cropId ?? 'wheat';
    final cropItem = EmbeddedCropData.rotationById[cId];
    final cropLabel = cropItem != null
        ? s.cropName(cropItem)
        : (EmbeddedCropData.ensureCropRegistered(cropId: cId).nameAr);

    return Row(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: tp.voiceService.isSpeaking,
          builder: (context, speaking, _) {
            if (speaking) {
              return const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF00796B),
                child: Icon(Icons.graphic_eq_rounded, color: Colors.white),
              );
            }
            return const TerraLogoBadge(size: 40, borderRadius: 20);
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.t("المساعد الصوتي لـ", "Voice Agent for")} ${tp.farmer.name} 🎙️',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
              Text(
                '${s.t("زرعتك", "Crop")}: $cropLabel • ${s.t("البديل المناسب", "Next Best")}: ${tp.recommendedAlternatives.take(2).join(tp.isEnglish ? ", " : "، ")}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        if (!widget.fullScreen && widget.onOpenFullScreen != null)
          IconButton(
            tooltip: s.t('تكبير شاشة المحادثة', 'Expand voice chat'),
            icon: const Icon(Icons.open_in_full_rounded, color: Color(0xFF1B5E20), size: 20),
            onPressed: () {
              tp.voiceService.unlockAudioOnGesture();
              widget.onOpenFullScreen!();
            },
          ),
        ValueListenableBuilder<bool>(
          valueListenable: tp.voiceService.autoSpeakEnabled,
          builder: (context, autoOn, _) {
            return IconButton(
              tooltip: autoOn
                  ? s.t('الصوت التلقائي شغال', 'Auto voice reply ON')
                  : s.t('الصوت التلقائي متوقف', 'Auto voice reply OFF'),
              icon: Icon(
                autoOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: autoOn ? const Color(0xFF1B5E20) : Colors.grey,
              ),
              onPressed: () {
                tp.voiceService.unlockAudioOnGesture();
                final next = !autoOn;
                tp.voiceService.autoSpeakEnabled.value = next;
                if (!next) tp.voiceService.stop();
              },
            );
          },
        ),
        const SizedBox(width: 4),
        ValueListenableBuilder<bool>(
          valueListenable: tp.voiceService.isListening,
          builder: (context, listening, _) {
            return FloatingActionButton.small(
              heroTag: widget.fullScreen ? 'voice_mic_btn_full' : 'voice_mic_btn',
              backgroundColor: listening ? Colors.redAccent : const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              tooltip: s.t('اضغط واتكلم بصوتك', 'Tap & Speak'),
              onPressed: () => _handleVoiceMic(tp, s),
              child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLiveStatusStrip(TerraProvider tp, AppStrings s) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: tp.voiceService.isListening,
          builder: (context, listening, _) {
            if (!listening) return const SizedBox.shrink();
            return ValueListenableBuilder<String>(
              valueListenable: tp.voiceService.recognizedWords,
              builder: (context, words, _) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    words.isEmpty
                        ? (tp.voiceService.sttLocale.value.startsWith('en')
                            ? '🎙️ Listening in English (en-US)... Speak now'
                            : '🎙️ بسمعك بالمصري (ar-EG)... اتكلم دلوقتي')
                        : '🎙️ "$words"',
                    style: const TextStyle(
                      color: Color(0xFFB71C1C),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                );
              },
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: tp.voiceService.isSpeaking,
          builder: (context, speaking, _) {
            if (!speaking) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00796B).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, color: Color(0xFF00695C), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.t('🔊 الطبيب الزراعي يتحدث الآن...', '🔊 Smart Agronomist is speaking...'),
                      style: const TextStyle(
                        color: Color(0xFF004D40),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB71C1C),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => tp.voiceService.stop(),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text(s.t('إيقاف', 'Stop'), style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEngineerContactCard(EngineerProfile eng, AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1B5E20),
            child: Icon(Icons.engineering_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.t("👨‍🌾 المهندس الزراعي", "👨‍🌾 Agronomist")}: ${s.engineerName(eng.name)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                Text(
                  '${s.specialty(eng.specialty)} • ${s.t("تليفون", "Phone")}: ${eng.phone}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
            ),
            onPressed: () => _callEngineerPhone(eng.phone),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
            label: Text(s.t('اتصال', 'Call'), style: const TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _quickPromptChip(TerraProvider tp, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6),
      child: ActionChip(
        backgroundColor: const Color(0xFFE8F5E9),
        label: Text(prompt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: () => _submitVoiceOrTextQuery(tp, prompt),
      ),
    );
  }
}
