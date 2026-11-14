import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'web_audio_unlock_stub.dart'
    if (dart.library.js_interop) 'web_audio_unlock_web.dart';

/// خدمة الصوت المتكاملة ثنائية اللغة (عربي + إنجليزي) لـ Terra Space:
/// - نطق تلقائي فوري بصوت مصري واضح (ar-EG -> ar-SA -> ar) بسرعة 0.85 ونبرة 1.0
/// - تشغيل صوت مصري طبيعي عبر الخادم (/api/tts) على Chrome عند عدم توفر صوت عربي في Windows
/// - فتح قفل AudioContext وHTMLAudio وSpeechSynthesis في Chrome لحظياً عند ضغطة المستخدم
/// - STT تفاعلي يدعم العربية (ar-EG) والإنجليزية (en-US) مع بث لحظي للكلام
class VoiceService {
  static const double defaultSpeechRate = 0.85;
  static const double defaultPitch = 1.0;
  static const List<String> arabicLanguageFallbacks = ['ar-EG', 'ar-SA', 'ar'];
  static const List<String> englishLanguageFallbacks = ['en-US', 'en-GB', 'en'];

  String backendBaseUrl;

  VoiceService({this.backendBaseUrl = 'http://localhost:8000'});

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);
  final ValueNotifier<bool> autoSpeakEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<String> recognizedWords = ValueNotifier<String>('');
  final ValueNotifier<String> sttLocale = ValueNotifier<String>('ar-EG');
  final ValueNotifier<String> activeTtsLocale = ValueNotifier<String>('ar-EG');

  bool _ttsReady = false;
  bool _sttAvailable = false;
  bool _audioUnlocked = false;
  List<dynamic> _cachedVoices = [];
  int _speakGeneration = 0;
  String? _lastSpokenSignature;
  DateTime? _lastSpokenAt;

  bool get audioUnlocked => _audioUnlocked;

  static bool isArabicText(String text) {
    final arCount = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
    final enCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    return arCount > 0 && arCount >= enCount;
  }

  /// إزالة الإيموجي والرموز الخاصة والتنسيقات قبل القراءة الصوتية لضمان نطق سلس وواضح
  static String cleanForSpeech(String text) {
    return text
        .replaceAll(
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true),
          '',
        )
        .replaceAll(RegExp(r'[*_`#]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// يُستدعى لحظياً داخل حدث ضغطة المستخدم (Mic / Send / Chip) لفك قيود التشغيل التلقائي في Chrome.
  void unlockAudioOnGesture() {
    _audioUnlocked = true;
    unlockBrowserSpeechAndAudio();
    if (!_ttsReady) {
      init();
    }
  }

  Future<void> _refreshCachedVoices() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        _cachedVoices = voices;
      }
    } catch (_) {}
  }

  bool _hasBrowserVoiceForLang(String langPrefix) {
    final target = langPrefix.toLowerCase();
    return _cachedVoices.whereType<Map>().any((v) {
      final loc = (v['locale'] ?? '').toString().toLowerCase();
      return loc.startsWith(target);
    });
  }

  Future<void> init() async {
    if (!_ttsReady) {
      try {
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {}

      try {
        await _tts.setSpeechRate(defaultSpeechRate);
        await _tts.setPitch(defaultPitch);
        await _tts.setVolume(1.0);

        _tts.setStartHandler(() => isSpeaking.value = true);
        _tts.setCompletionHandler(() => isSpeaking.value = false);
        _tts.setCancelHandler(() => isSpeaking.value = false);
        _tts.setErrorHandler((_) => isSpeaking.value = false);

        await _refreshCachedVoices();
        await _configureTtsForLang('ar');
        _ttsReady = true;
      } catch (_) {}
    }

    if (!_sttAvailable) {
      try {
        _sttAvailable = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              isListening.value = false;
            }
          },
          onError: (_) {
            isListening.value = false;
          },
        );
      } catch (_) {
        _sttAvailable = false;
      }
    }
  }

  Future<void> _configureTtsForLang(String langPrefix) async {
    final candidates = langPrefix == 'ar' ? arabicLanguageFallbacks : englishLanguageFallbacks;
    try {
      await _tts.setSpeechRate(defaultSpeechRate);
      await _tts.setPitch(defaultPitch);
      await _tts.setVolume(1.0);

      if (_cachedVoices.isEmpty) {
        await _refreshCachedVoices();
      }

      if (_cachedVoices.isNotEmpty) {
        for (final locCandidate in candidates) {
          final pref = locCandidate.toLowerCase();
          final prefUnderscore = pref.replaceAll('-', '_');
          final match = _cachedVoices.whereType<Map>().where((v) {
            final loc = (v['locale'] ?? '').toString().toLowerCase();
            return loc == pref ||
                loc == prefUnderscore ||
                loc.startsWith('$pref-') ||
                loc.startsWith('${prefUnderscore}_') ||
                (pref.length == 2 && loc.startsWith(pref));
          }).toList();

          if (match.isNotEmpty) {
            final voice = match.first;
            final voiceLocale = (voice['locale'] ?? locCandidate).toString();
            await _tts.setLanguage(voiceLocale);
            await _tts.setVoice({
              'name': (voice['name'] ?? '').toString(),
              'locale': voiceLocale,
            });
            activeTtsLocale.value = voiceLocale;
            return;
          }
        }
      }

      for (final locCandidate in candidates) {
        try {
          if (!kIsWeb) {
            final available = await _tts.isLanguageAvailable(locCandidate);
            if (available == false || available == 0) {
              continue;
            }
          }
          final result = await _tts.setLanguage(locCandidate);
          activeTtsLocale.value = locCandidate;
          if (result == null || result == 1 || result == true) {
            return;
          }
        } catch (_) {}
      }

      await _tts.setLanguage(candidates.first);
      activeTtsLocale.value = candidates.first;
    } catch (_) {}
  }

  Future<bool> _speakViaBackendNeuralTts(String text, String langLocale) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$backendBaseUrl/api/tts'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'lang': langLocale}),
          )
          .timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        activeTtsLocale.value = langLocale;
        return await playAudioBytesOnWeb(
          resp.bodyBytes,
          onStart: () => isSpeaking.value = true,
          onComplete: () => isSpeaking.value = false,
        );
      }
    } catch (_) {}
    return false;
  }

  /// قراءة النص صوتياً فوراً وبثبات تام على الويب والموبايل (مع دعم قراءة كل مقاطع MP3 المتتالية للنهاية).
  Future<void> speak(String text, {String? audioUrl, List<String>? audioUrls}) async {
    final cleaned = cleanForSpeech(text);
    final urlsList = (audioUrls != null && audioUrls.isNotEmpty)
        ? audioUrls
        : (audioUrl != null && audioUrl.trim().isNotEmpty ? [audioUrl.trim()] : <String>[]);
    if (cleaned.isEmpty && urlsList.isEmpty) return;

    final signature = '${urlsList.join(',')}|$cleaned';
    final now = DateTime.now();
    if (_lastSpokenSignature == signature &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!).inMilliseconds < 1500) {
      return;
    }
    _lastSpokenSignature = signature;
    _lastSpokenAt = now;

    final int myGen = ++_speakGeneration;

    await init();
    if (myGen != _speakGeneration) return;

    await _stopInternal();
    if (myGen != _speakGeneration) return;

    final lang = isArabicText(cleaned) ? 'ar' : 'en';
    final langLocale = lang == 'ar' ? 'ar-EG' : 'en-US';

    if (kIsWeb && urlsList.isNotEmpty) {
      activeTtsLocale.value = langLocale;
      bool anyPlayed = false;
      for (int i = 0; i < urlsList.length; i++) {
        if (myGen != _speakGeneration) break;
        final rawUrl = urlsList[i].trim();
        if (rawUrl.isEmpty) continue;
        final fullUrl = rawUrl.startsWith('http')
            ? rawUrl
            : '${backendBaseUrl.replaceAll(RegExp(r'/+$'), '')}${rawUrl.startsWith('/') ? rawUrl : '/$rawUrl'}';
        final playedSeg = await playAudioUrlOnWeb(
          fullUrl,
          onStart: () {
            if (myGen == _speakGeneration) isSpeaking.value = true;
          },
          onComplete: () {
            if (myGen == _speakGeneration && i == urlsList.length - 1) {
              isSpeaking.value = false;
            }
          },
        );
        if (playedSeg) anyPlayed = true;
      }
      if (myGen == _speakGeneration) isSpeaking.value = false;
      if (myGen != _speakGeneration || anyPlayed) return;
    }

    if (cleaned.isEmpty || myGen != _speakGeneration) return;

    // على الويب نستخدم صوت الخادم المصري الطبيعي (edge-tts) أولاً، ولا نشغل المتصفح أبداً إذا تم إلغاء الدور.
    if (kIsWeb && (lang == 'ar' || !_hasBrowserVoiceForLang(lang))) {
      final played = await _speakViaBackendNeuralTts(cleaned, langLocale);
      if (myGen != _speakGeneration || played) return;
    }

    if (myGen != _speakGeneration) return;

    try {
      await _configureTtsForLang(lang);
      if (myGen != _speakGeneration) return;
      isSpeaking.value = true;
      await _tts.speak(cleaned);
    } catch (_) {
      if (myGen == _speakGeneration) isSpeaking.value = false;
    } finally {
      if (!kIsWeb && myGen == _speakGeneration) {
        isSpeaking.value = false;
      }
    }
  }

  Future<void> _stopInternal() async {
    stopWebAudio();
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeaking.value = false;
  }

  Future<void> stop() async {
    _speakGeneration++;
    await _stopInternal();
  }

  void setSttLocale(String locale) {
    sttLocale.value = locale;
  }

  Future<bool> startListening({
    required void Function(String text) onFinalResult,
    void Function(String partial)? onPartialResult,
  }) async {
    unlockAudioOnGesture();
    await init();
    await stop();
    if (!_sttAvailable) {
      try {
        _sttAvailable = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              isListening.value = false;
            }
          },
          onError: (_) => isListening.value = false,
        );
      } catch (_) {}
      if (!_sttAvailable) return false;
    }

    try {
      recognizedWords.value = '';
      isListening.value = true;
      await _speech.listen(
        localeId: sttLocale.value,
        listenOptions: stt.SpeechListenOptions(partialResults: true),
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        onResult: (res) {
          final words = res.recognizedWords.trim();
          recognizedWords.value = words;
          if (onPartialResult != null && words.isNotEmpty) {
            onPartialResult(words);
          }
          if (res.finalResult && words.isNotEmpty) {
            isListening.value = false;
            onFinalResult(words);
          }
        },
      );
      return true;
    } catch (_) {
      isListening.value = false;
      return false;
    }
  }

  Future<void> stopListening({void Function(String text)? onCommitIfAny}) async {
    unlockAudioOnGesture();
    try {
      await _speech.stop();
    } catch (_) {}
    isListening.value = false;
    final current = recognizedWords.value.trim();
    if (onCommitIfAny != null && current.isNotEmpty) {
      recognizedWords.value = '';
      onCommitIfAny(current);
    }
  }
}
