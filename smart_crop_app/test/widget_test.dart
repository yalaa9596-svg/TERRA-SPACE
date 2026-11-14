import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_crop_app/data/embedded_crop_data.dart';
import 'package:smart_crop_app/l10n/app_strings.dart';
import 'package:smart_crop_app/models/crop_models.dart';
import 'package:smart_crop_app/providers/terra_provider.dart';
import 'package:smart_crop_app/screens/farmer/voice_assistant_screen.dart';
import 'package:smart_crop_app/services/api_service.dart';
import 'package:smart_crop_app/services/rotation_engine.dart';
import 'package:smart_crop_app/services/voice_service.dart';

class _SpyVoiceService extends VoiceService {
  int unlockCalls = 0;
  final List<String> spokenTexts = [];

  @override
  void unlockAudioOnGesture() {
    unlockCalls++;
    super.unlockAudioOnGesture();
  }

  @override
  Future<void> speak(String text, {String? audioUrl, List<String>? audioUrls}) async {
    spokenTexts.add(text);
  }
}

void main() {
  test('Embedded dataset has 5 rotation crops using المزارع terminology', () {
    expect(EmbeddedCropData.rotationCrops.length, 5);
    for (final crop in EmbeddedCropData.rotationCrops) {
      expect(crop.voiceDialogue.suitable, contains('المزارع'));
      expect(crop.voiceDialogue.suitable.contains('الفلاح'), isFalse);
      expect(crop.voiceDialogue.unsuitable.contains('الفلاح'), isFalse);
    }
  });

  test('RotationEngine detects Poaceae -> Poaceae conflict and evaluates 5-state NASA irrigation', () {
    final wheat = EmbeddedCropData.rotationById['wheat']!;
    final maize = EmbeddedCropData.rotationById['maize']!;
    final clover = EmbeddedCropData.rotationById['clover']!;
    final tomato = EmbeddedCropData.rotationById['tomato']!;

    const winterClimate = ClimateSummary(
      days: 30,
      tAvg: 19.5,
      tMax: 24.0,
      tMin: 14.0,
      rainTotal: 3.0,
      rhAvg: 55.0,
      soilAvg: 0.26,
    );

    final badRotation = RotationEngine.evaluate(target: wheat, previous: maize, climate: winterClimate);
    expect(badRotation.familyConflict, isTrue);
    expect(badRotation.isSuitable, isFalse);

    final goodRotation = RotationEngine.evaluate(target: wheat, previous: clover, climate: winterClimate);
    expect(goodRotation.familyConflict, isFalse);
    expect(goodRotation.isSuitable, isTrue);

    // 5-State Irrigation tests
    const skipClim = ClimateSummary(days: 7, tAvg: 24, tMax: 30, tMin: 18, rainTotal: 1, rhAvg: 60, soilAvg: 0.15, rainNext2d: 8.0);
    expect(RotationEngine.computeIrrigationAlert(crop: tomato, climate: skipClim).stateAr, 'لا تروي');

    const urgentClim = ClimateSummary(days: 7, tAvg: 30, tMax: 35, tMin: 22, rainTotal: 0, rhAvg: 40, soilAvg: 0.12, rainNext2d: 0.0);
    expect(RotationEngine.computeIrrigationAlert(crop: tomato, climate: urgentClim).stateAr, 'ري عاجل');

    const okClim = ClimateSummary(days: 7, tAvg: 22, tMax: 25, tMin: 16, rainTotal: 3, rhAvg: 60, soilAvg: 0.35, rainNext2d: 0.0);
    expect(RotationEngine.computeIrrigationAlert(crop: tomato, climate: okClim).stateAr, 'تمام');
  });

  test('PlantDoc offline diagnosis escalates low confidence (<75%) and out-of-scope crops', () {
    final lowConf = RotationEngine.diagnoseOffline(
      cropId: 'tomato',
      lat: 30.0444,
      lon: 31.2357,
      confidence: 0.65,
    );
    expect(lowConf.escalateToEngineer, isTrue);
    expect(lowConf.recommendedEngineer, isNotNull);

    final outOfScope = RotationEngine.diagnoseOffline(
      cropId: 'wheat',
      lat: 31.0409,
      lon: 31.3785,
    );
    expect(outOfScope.supportedInPlantDoc, isFalse);
    expect(outOfScope.escalateToEngineer, isTrue);
    expect(outOfScope.voiceMessageAr, contains('المزارع'));
  });

  test('VoiceService enforces ar-EG/ar-SA/ar fallback, 0.85 rate, 1.0 pitch, and clean text', () {
    expect(VoiceService.defaultSpeechRate, 0.85);
    expect(VoiceService.defaultPitch, 1.0);
    expect(VoiceService.arabicLanguageFallbacks, ['ar-EG', 'ar-SA', 'ar']);
    expect(VoiceService.isArabicText('أهلاً بك يا عم المزارع'), isTrue);
    expect(VoiceService.isArabicText('Welcome Farmer to Terra Space'), isFalse);
    expect(
      VoiceService.cleanForSpeech('أهلاً بك 🛰️🌱 في Terra Space ✅'),
      'أهلاً بك في Terra Space',
    );
  });

  test('VoiceInteract returns honest connection error when backend is unreachable', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final api = ApiService(baseUrl: 'http://127.0.0.1:59999');
    const clim = ClimateSummary(
      days: 30,
      tAvg: 21.0,
      tMax: 26.0,
      tMin: 15.0,
      rainTotal: 2.0,
      rhAvg: 55.0,
      soilAvg: 0.25,
    );
    final reply = await api.voiceInteract(
      farmerId: 1,
      queryText: 'ينفع أزرع مانجو في أرضي؟',
      targetCrop: 'wheat',
      previousCrop: 'clover',
      lat: 30.0444,
      lon: 31.2357,
      climate: clim,
    );
    expect(
      reply,
      'عذراً، تعذر الاتصال بالمساعد الذكي حالياً بسبب مشكلة في الشبكة أو المفتاح',
    );
  });

  testWidgets('VoiceAssistantPanel unlocks audio on send and auto-speaks reply without extra tap', (tester) async {
    final spyVoice = _SpyVoiceService();
    final provider = TerraProvider(
      apiService: ApiService(baseUrl: 'http://127.0.0.1:59999'),
      voiceService: spyVoice,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<TerraProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: VoiceAssistantScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'ينفع أزرع مانجو في أرضي؟');
    await tester.tap(find.text('إرسال'));
    await tester.pumpAndSettle();

    expect(spyVoice.unlockCalls, greaterThanOrEqualTo(1));
    expect(spyVoice.spokenTexts.length, 1);
    expect(
      spyVoice.spokenTexts.single,
      'عذراً، تعذر الاتصال بالمساعد الذكي حالياً بسبب مشكلة في الشبكة أو المفتاح',
    );
  });

  test('TerraProvider toggles Local (ar) <-> Global (en), updates locations, alerts & PlantDoc fallback', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final provider = TerraProvider(
      apiService: ApiService(baseUrl: 'http://127.0.0.1:59999'),
      voiceService: _SpyVoiceService(),
    );

    await provider.setAppLanguage('en');
    expect(provider.isEnglish, isTrue);
    expect(provider.farmer.name, 'Smart Farmer');
    expect(provider.locationLabel, 'Cairo / South Delta, Egypt');
    expect(provider.latestIrrigationAlert?.stateAr, 'All Good');
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(provider.weatherAlertTitle ?? ''), isFalse);

    provider.farmer = provider.farmer.copyWith(lat: 36.7378, lon: -119.7871);
    expect(provider.locationLabel, 'California - Central Valley, USA');

    provider.farmer = provider.farmer.copyWith(lat: 48.8566, lon: 2.3522);
    expect(provider.locationLabel, 'GPS (48.86, 2.35)');

    final enDiag = RotationEngine.diagnoseOffline(
      cropId: 'wheat',
      lat: 36.7378,
      lon: -119.7871,
      language: 'en',
    );
    expect(enDiag.diseaseNameAr, contains('Wheat'));
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(enDiag.voiceMessageAr), isFalse);
  });

  testWidgets('VoiceAssistantScreen shows single AppLanguageToggle + TerraLogoBadge and switches to English', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = TerraProvider(
      apiService: ApiService(baseUrl: 'http://127.0.0.1:59999'),
      voiceService: _SpyVoiceService(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<TerraProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Directionality(
            textDirection: provider.isEnglish ? TextDirection.ltr : TextDirection.rtl,
            child: const VoiceAssistantScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppLanguageToggle), findsOneWidget);
    expect(find.byType(TerraLogoBadge), findsAtLeastNWidgets(1));
    expect(find.text('إرسال'), findsOneWidget);

    await tester.tap(find.textContaining('EN'));
    await tester.pumpAndSettle();

    expect(provider.isEnglish, isTrue);
    expect(find.text('Send'), findsOneWidget);
  });
}
