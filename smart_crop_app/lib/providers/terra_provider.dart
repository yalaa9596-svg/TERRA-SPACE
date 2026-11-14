import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/embedded_crop_data.dart';
import '../models/crop_models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/rotation_engine.dart';
import '../services/voice_service.dart';

class VoiceChatMessage {
  final bool isFarmer;
  final String text;
  final DateTime timestamp;
  final Uint8List? imageBytes;
  final EngineerProfile? recommendedEngineer;
  final String? audioUrl;
  final List<String> audioUrls;

  VoiceChatMessage({
    required this.isFarmer,
    required this.text,
    DateTime? timestamp,
    this.imageBytes,
    this.recommendedEngineer,
    this.audioUrl,
    this.audioUrls = const [],
  }) : timestamp = timestamp ?? DateTime.now();
}

class TerraProvider extends ChangeNotifier {
  final ApiService apiService;
  final VoiceService voiceService;

  TerraProvider({ApiService? apiService, VoiceService? voiceService})
      : apiService = apiService ?? ApiService(),
        voiceService = voiceService ?? VoiceService() {
    this.voiceService.backendBaseUrl = this.apiService.baseUrl;
  }

  bool isAuthenticated = false;
  bool authInitialized = false;
  bool isEngineerPortal = false;
  bool loadingClimate = false;
  bool loadingDiagnosis = false;
  bool loadingVoiceReply = false;
  bool loadingEngineerCases = false;
  String? geminiApiKey;
  String appLang = 'ar';
  bool get isEnglish => appLang == 'en';

  AppUser farmer = const AppUser(
    id: 1,
    role: 'farmer',
    name: 'المزارع الذكي',
    phone: '01099887766',
    lat: 30.0444,
    lon: 31.2357,
    cropId: 'wheat',
    previousCropId: 'clover',
  );

  ClimateSummary climate = const ClimateSummary(
    days: 30,
    tAvg: 20.4,
    tMax: 25.2,
    tMin: 14.5,
    rainTotal: 2.1,
    rhAvg: 58.0,
    soilAvg: 0.27,
    elevation: 18.0,
    rainNext2d: 0.0,
  );

  IrrigationAlert? latestIrrigationAlert;
  VisionDiagnosisResult? latestDiagnosis;
  EngineerProfile? activeEngineer;
  List<ConsultationRequest> engineerCases = [];
  List<ConsultationRequest> sentFarmerConsultations = [];
  int voiceReplySeq = 0;
  String? latestVoiceReply;
  String? latestVoiceAudioUrl;
  List<String> recommendedAlternatives = const ['البرسيم', 'الفول البلدي', 'الطماطم'];

  final Map<String, List<VoiceChatMessage>> _farmerHistories = {};

  final List<AppUser> presetFarmerAccounts = const [
    AppUser(
      id: 1,
      role: 'farmer',
      name: 'الحاج محمود (المنوفية)',
      phone: '01099887766',
      lat: 30.5972,
      lon: 30.9876,
      cropId: 'wheat',
      previousCropId: 'clover',
    ),
    AppUser(
      id: 2,
      role: 'farmer',
      name: 'عم سعيد (كفر الشيخ)',
      phone: '01011223344',
      lat: 31.1107,
      lon: 30.9388,
      cropId: 'tomato',
      previousCropId: 'wheat',
    ),
    AppUser(
      id: 3,
      role: 'farmer',
      name: 'الحاج عبد الستار (المنيا)',
      phone: '01055667788',
      lat: 28.1099,
      lon: 30.7503,
      cropId: 'potato',
      previousCropId: 'faba_bean',
    ),
  ];

  final List<VoiceChatMessage> chatMessages = [
    VoiceChatMessage(
      isFarmer: false,
      text:
          'أهلاً بك يا أخي المزارع في تطبيق Terra Space 🛰️🌱! قولي اسمك وزرعت إيه، أو اسألني بالصوت عن ميعاد الزراعة، حالة الري والأمطار من ناسا، أو صوّر أي ضرر في المحصول.',
    ),
  ];

  Future<void> switchFarmerAccount(AppUser selectedFarmer) async {
    _farmerHistories[farmer.phone] = List<VoiceChatMessage>.from(chatMessages);
    voiceService.stop();
    farmer = selectedFarmer;
    final existing = _farmerHistories[farmer.phone];
    chatMessages.clear();
    if (existing != null && existing.isNotEmpty) {
      chatMessages.addAll(existing);
    } else {
      chatMessages.add(
        VoiceChatMessage(
          isFarmer: false,
          text:
              'أهلاً بيك يا ${farmer.name} في حسابك على Terra Space 🛰️🌱! أنا عارف موقع أرضك ومحصولك، اسألني بالصوت أو صوّر زرعتك لو فيها أي ضرر.',
        ),
      );
    }
    notifyListeners();
    await updateFarmerProfile(
      name: farmer.name,
      phone: farmer.phone,
      targetCrop: farmer.cropId ?? 'wheat',
      previousCrop: farmer.previousCropId,
      lat: farmer.lat,
      lon: farmer.lon,
    );
  }

  Future<void> initializeZeroLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('terra_app_lang');
      if (savedLang == 'en' || savedLang == 'ar') {
        appLang = savedLang!;
        voiceService.setSttLocale(isEnglish ? 'en-US' : 'ar-EG');
        if (isEnglish && farmer.name == 'المزارع الذكي') {
          farmer = farmer.copyWith(name: 'Smart Farmer');
        }
        if (isEnglish && chatMessages.length == 1 && !chatMessages.first.isFarmer) {
          chatMessages[0] = VoiceChatMessage(
            isFarmer: false,
            text:
                'Welcome to Terra Space 🛰️🌱! Tell me your name and crop, or ask by voice about planting timing, NASA climate & irrigation alerts, or upload a plant leaf photo for PlantDoc AI inspection.',
          );
        }
        if (isEnglish) {
          recommendedAlternatives = const ['Clover', 'Faba Bean', 'Tomato'];
        }
      }
      final loggedIn = prefs.getBool('terra_logged_in') ?? false;
      final role = prefs.getString('terra_user_role') ?? 'farmer';
      final savedToken = prefs.getString('terra_auth_token');
      final savedServerUrl = prefs.getString('terra_server_url');
      if (savedServerUrl != null && savedServerUrl.trim().isNotEmpty) {
        apiService.baseUrl = savedServerUrl.trim();
        voiceService.backendBaseUrl = savedServerUrl.trim();
      }
      geminiApiKey = prefs.getString('terra_gemini_key');
      if (savedToken != null && savedToken.isNotEmpty) {
        apiService.authToken = savedToken;
      }

      if (loggedIn) {
        isAuthenticated = true;
        if (role == 'engineer') {
          isEngineerPortal = true;
          final engId = prefs.getInt('terra_eng_id') ?? 1;
          final engName = prefs.getString('terra_eng_name') ?? 'مهندس زراعي';
          final engPhone = prefs.getString('terra_eng_phone') ?? '';
          final engLat = prefs.getDouble('terra_eng_lat') ?? 30.0444;
          final engLon = prefs.getDouble('terra_eng_lon') ?? 31.2357;
          final engSpec = prefs.getString('terra_eng_specialty') ?? 'أمراض نباتية';
          final engGov = prefs.getString('terra_eng_governorate') ?? 'القاهرة';
          final engExp = prefs.getInt('terra_eng_exp') ?? 8;
          activeEngineer = EngineerProfile(
            id: engId,
            name: engName,
            phone: engPhone,
            lat: engLat,
            lon: engLon,
            specialty: engSpec,
            governorate: engGov,
            yearsOfExp: engExp,
            distanceKm: 0.0,
          );
          authInitialized = true;
          notifyListeners();
          await loadEngineerCases();
          return;
        } else {
          isEngineerPortal = false;
          final savedId = prefs.getInt('terra_farmer_id') ?? 1;
          final savedName = prefs.getString('terra_farmer_name') ?? 'المزارع الذكي';
          final savedPhone = prefs.getString('terra_farmer_phone') ?? '01099887766';
          final savedCrop = prefs.getString('terra_target_crop') ?? 'wheat';
          final savedPrev = prefs.getString('terra_prev_crop') ?? 'clover';
          final savedLat = prefs.getDouble('terra_lat') ?? 30.0444;
          final savedLon = prefs.getDouble('terra_lon') ?? 31.2357;

          farmer = AppUser(
            id: savedId,
            role: 'farmer',
            name: savedName,
            phone: savedPhone,
            lat: savedLat,
            lon: savedLon,
            cropId: savedCrop,
            previousCropId: savedPrev,
          );
          authInitialized = true;
          notifyListeners();
          await refreshLocationAndClimate(autoGps: false);
          await _syncFarmerSessionFromBackend();
          return;
        }
      }
    } catch (_) {}

    authInitialized = true;
    notifyListeners();
  }

  Future<void> _syncFarmerSessionFromBackend() async {
    try {
      final res = await apiService.verifyFarmerWhatsappOtp(
        phone: farmer.phone,
        otpCode: '1234',
        name: farmer.name,
        lat: farmer.lat,
        lon: farmer.lon,
        targetCrop: farmer.cropId ?? 'wheat',
        previousCrop: farmer.previousCropId ?? 'clover',
      );
      _applyFarmerVerifyResponse(res);
    } catch (_) {}
  }

  String _welcomeGreeting(String farmerName) {
    if (isEnglish) {
      return 'Welcome $farmerName to your personal Terra Space 🛰️🌱 dashboard! I am ready to help with your land and crops — ask by voice or upload a leaf photo for any plant stress.';
    }
    return 'أهلاً بيك يا $farmerName في حسابك الشخصي على Terra Space 🛰️🌱! أنا جاهز أساعدك في أرضك ومحصولك، اسألني بالصوت أو صوّر أي ضرر في النبات.';
  }

  Future<void> setAppLanguage(String lang) async {
    final norm = lang.toLowerCase().startsWith('en') ? 'en' : 'ar';
    appLang = norm;
    voiceService.setSttLocale(isEnglish ? 'en-US' : 'ar-EG');

    if (isEnglish && farmer.name == 'المزارع الذكي') {
      farmer = farmer.copyWith(name: 'Smart Farmer');
    } else if (!isEnglish && farmer.name == 'Smart Farmer') {
      farmer = farmer.copyWith(name: 'المزارع الذكي');
    }

    if (chatMessages.length == 1 && !chatMessages.first.isFarmer) {
      chatMessages[0] = VoiceChatMessage(
        isFarmer: false,
        text: _welcomeGreeting(farmer.name),
      );
    }

    final crop = EmbeddedCropData.rotationById[farmer.cropId ?? 'wheat'] ??
        EmbeddedCropData.rotationCrops.first;
    latestIrrigationAlert = RotationEngine.computeIrrigationAlert(
      crop: crop,
      climate: climate,
      language: appLang,
    );
    if (isEnglish && recommendedAlternatives.first == 'البرسيم') {
      recommendedAlternatives = const ['Clover', 'Faba Bean', 'Tomato'];
    } else if (!isEnglish && recommendedAlternatives.first == 'Clover') {
      recommendedAlternatives = const ['البرسيم', 'الفول البلدي', 'الطماطم'];
    }
    evaluateWeatherNotification();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('terra_app_lang', norm);
    } catch (_) {}

    if (isAuthenticated && !isEngineerPortal) {
      latestIrrigationAlert = await apiService.getIrrigationStatus(
        farmerId: farmer.id,
        cropId: farmer.cropId ?? 'wheat',
        lat: farmer.lat,
        lon: farmer.lon,
        climate: climate,
        language: appLang,
      );
      evaluateWeatherNotification();
      notifyListeners();
    }
  }

  void _applyFarmerVerifyResponse(Map<String, dynamic> res) {
    final fMap = Map<String, dynamic>.from(res['farmer'] ?? {});
    if (fMap.isNotEmpty) {
      farmer = AppUser.fromJson(fMap);
    }
    final rawHist = res['chat_history'] as List<dynamic>? ?? [];
    chatMessages.clear();
    if (rawHist.isNotEmpty) {
      for (final item in rawHist) {
        final m = Map<String, dynamic>.from(item as Map);
        chatMessages.add(
          VoiceChatMessage(
            isFarmer: m['role'] == 'user',
            text: (m['text'] ?? '').toString(),
          ),
        );
      }
    } else {
      chatMessages.add(
        VoiceChatMessage(
          isFarmer: false,
          text: _welcomeGreeting(farmer.name),
        ),
      );
    }
    _farmerHistories[farmer.phone] = List<VoiceChatMessage>.from(chatMessages);
    notifyListeners();
  }

  Future<void> loginFarmerWithWhatsappOtp({
    required String phone,
    required String otpCode,
    required String name,
    required double lat,
    required double lon,
    String targetCrop = 'wheat',
    String previousCrop = 'clover',
  }) async {
    final res = await apiService.verifyFarmerWhatsappOtp(
      phone: phone,
      otpCode: otpCode,
      name: name,
      lat: lat,
      lon: lon,
      targetCrop: targetCrop,
      previousCrop: previousCrop,
    );
    _applyFarmerVerifyResponse(res);
    isEngineerPortal = false;
    isAuthenticated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terra_logged_in', true);
      await prefs.setString('terra_user_role', 'farmer');
      if (apiService.authToken != null) {
        await prefs.setString('terra_auth_token', apiService.authToken!);
      }
      await prefs.setInt('terra_farmer_id', farmer.id);
      await prefs.setString('terra_farmer_name', farmer.name);
      await prefs.setString('terra_farmer_phone', farmer.phone);
      await prefs.setString('terra_target_crop', farmer.cropId ?? 'wheat');
      await prefs.setString('terra_prev_crop', farmer.previousCropId ?? 'clover');
      await prefs.setDouble('terra_lat', farmer.lat);
      await prefs.setDouble('terra_lon', farmer.lon);
    } catch (_) {}

    notifyListeners();
    await refreshLocationAndClimate(autoGps: false);
  }

  Future<void> loginEngineerAccount({
    required String phone,
    required String password,
  }) async {
    final eng = await apiService.loginEngineer(
      phone: phone,
      password: password,
    );
    await _persistEngineerSession(eng);
  }

  Future<void> registerNewEngineerAccount({
    required String name,
    required String phone,
    required String password,
    required double lat,
    required double lon,
    required String specialty,
    required String governorate,
    required int yearsOfExp,
  }) async {
    final eng = await apiService.registerEngineer(
      name: name,
      phone: phone,
      password: password,
      lat: lat,
      lon: lon,
      specialty: specialty,
      governorate: governorate,
      yearsOfExp: yearsOfExp,
    );
    await _persistEngineerSession(eng);
  }

  Future<void> _persistEngineerSession(EngineerProfile eng) async {
    activeEngineer = eng;
    isEngineerPortal = true;
    isAuthenticated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terra_logged_in', true);
      await prefs.setString('terra_user_role', 'engineer');
      if (apiService.authToken != null) {
        await prefs.setString('terra_auth_token', apiService.authToken!);
      }
      await prefs.setInt('terra_eng_id', eng.id ?? 1);
      await prefs.setString('terra_eng_name', eng.name);
      await prefs.setString('terra_eng_phone', eng.phone);
      await prefs.setDouble('terra_eng_lat', eng.lat);
      await prefs.setDouble('terra_eng_lon', eng.lon);
      await prefs.setString('terra_eng_specialty', eng.specialty);
      await prefs.setString('terra_eng_governorate', eng.governorate);
      await prefs.setInt('terra_eng_exp', eng.yearsOfExp);
    } catch (_) {}
    notifyListeners();
    await loadEngineerCases();
  }

  Future<void> logout() async {
    voiceService.stop();
    isAuthenticated = false;
    isEngineerPortal = false;
    apiService.authToken = null;
    chatMessages.clear();
    sentFarmerConsultations.clear();
    latestDiagnosis = null;
    latestVoiceReply = null;
    latestVoiceAudioUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terra_logged_in', false);
      await prefs.remove('terra_user_role');
      await prefs.remove('terra_auth_token');
    } catch (_) {}
    notifyListeners();
  }

  void switchPortal(bool engineerMode) {
    isEngineerPortal = engineerMode;
    voiceService.stop();
    if (engineerMode && activeEngineer == null) {
      activeEngineer = EngineerProfile.fromJson(
        {...EmbeddedCropData.rawEngineers.first, 'distance_km': 0.0},
      );
      loadEngineerCases();
    }
    notifyListeners();
  }

  Future<void> updateFarmerProfile({
    required String name,
    String? phone,
    required String targetCrop,
    String? previousCrop,
    double? lat,
    double? lon,
  }) async {
    farmer = farmer.copyWith(
      name: name,
      phone: phone ?? farmer.phone,
      cropId: targetCrop,
      previousCropId: previousCrop,
      lat: lat,
      lon: lon,
    );
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('terra_farmer_name', farmer.name);
      await prefs.setString('terra_target_crop', farmer.cropId ?? 'wheat');
      if (farmer.previousCropId != null) {
        await prefs.setString('terra_prev_crop', farmer.previousCropId!);
      }
      await prefs.setDouble('terra_lat', farmer.lat);
      await prefs.setDouble('terra_lon', farmer.lon);
    } catch (_) {}

    farmer = await apiService.farmerOnboarding(
      name: farmer.name,
      phone: farmer.phone,
      lat: farmer.lat,
      lon: farmer.lon,
      targetCrop: farmer.cropId ?? 'wheat',
      previousCrop: farmer.previousCropId,
    );
    await refreshClimateOnly();
  }

  Future<void> refreshLocationAndClimate({bool autoGps = true}) async {
    if (autoGps) {
      final geo = await LocationService.detectFarmerLocation(
        fallbackLat: farmer.lat,
        fallbackLon: farmer.lon,
      );
      farmer = farmer.copyWith(lat: geo.lat, lon: geo.lon);
    }
    await refreshClimateOnly();
  }

  Future<void> refreshClimateOnly() async {
    loadingClimate = true;
    notifyListeners();
    climate = await apiService.fetchNasaPowerDirect(farmer.lat, farmer.lon);
    latestIrrigationAlert = await apiService.getIrrigationStatus(
      farmerId: farmer.id,
      cropId: farmer.cropId ?? 'wheat',
      lat: farmer.lat,
      lon: farmer.lon,
      climate: climate,
      language: appLang,
    );
    loadingClimate = false;
    evaluateWeatherNotification();
    notifyListeners();
  }

  Future<void> setServerUrl(String rawUrl) async {
    final clean = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty) return;
    apiService.baseUrl = clean;
    voiceService.backendBaseUrl = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('terra_server_url', clean);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String? key) async {
    geminiApiKey = (key ?? '').trim().isEmpty ? null : key!.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (geminiApiKey == null) {
        await prefs.remove('terra_gemini_key');
      } else {
        await prefs.setString('terra_gemini_key', geminiApiKey!);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> sendVoiceQuery(String queryText, {bool speakReply = true}) async {
    final trimmed = queryText.trim();
    if (trimmed.isEmpty) return;

    // فك قفل الصوت في متصفح Chrome لحظياً داخل حدث المستخدم قبل طلب الشبكة
    voiceService.unlockAudioOnGesture();

    final historyPayload = chatMessages
        .map(
          (m) => {
            'is_farmer': m.isFarmer,
            'role': m.isFarmer ? 'user' : 'model',
            'text': m.text,
          },
        )
        .toList();

    chatMessages.add(VoiceChatMessage(isFarmer: true, text: trimmed));
    loadingVoiceReply = true;
    notifyListeners();

    final reply = await apiService.voiceInteract(
      farmerId: farmer.id,
      farmerName: farmer.name,
      sessionId: 'farmer_${farmer.phone}_${farmer.id}',
      queryText: trimmed,
      targetCrop: farmer.cropId ?? 'wheat',
      previousCrop: farmer.previousCropId,
      lat: farmer.lat,
      lon: farmer.lon,
      climate: climate,
      history: historyPayload,
      geminiApiKey: geminiApiKey,
      language: appLang,
    );

    if (apiService.lastDetectedCropId != null &&
        apiService.lastDetectedCropId!.isNotEmpty) {
      EmbeddedCropData.ensureCropRegistered(
        cropId: apiService.lastDetectedCropId!,
        nameAr: apiService.lastDetectedCropNameAr,
        icon: apiService.lastDetectedCropIcon,
      );
    }
    if (apiService.lastDetectedFarmerName != null || apiService.lastDetectedCropId != null) {
      farmer = farmer.copyWith(
        name: apiService.lastDetectedFarmerName ?? farmer.name,
        cropId: apiService.lastDetectedCropId ?? farmer.cropId,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        if (farmer.cropId != null) {
          await prefs.setString('terra_target_crop', farmer.cropId!);
        }
      } catch (_) {}
      evaluateWeatherNotification();
    }
    if (apiService.lastRecommendedAlternatives.isNotEmpty) {
      recommendedAlternatives = apiService.lastRecommendedAlternatives;
    }

    final intent = apiService.lastVoiceIntent ?? '';
    final showEngCard = apiService.lastVoiceEngineer != null &&
        (intent == 'out_of_dataset' ||
            intent == 'engineer' ||
            intent == 'vision' ||
            reply.contains('مهندس') ||
            reply.toLowerCase().contains('engineer') ||
            reply.contains('010'));

    chatMessages.add(
      VoiceChatMessage(
        isFarmer: false,
        text: reply,
        recommendedEngineer: showEngCard ? apiService.lastVoiceEngineer : null,
        audioUrl: apiService.lastVoiceAudioUrl,
        audioUrls: apiService.lastVoiceAudioUrls,
      ),
    );
    latestVoiceReply = reply;
    latestVoiceAudioUrl = apiService.lastVoiceAudioUrl;
    voiceReplySeq++;
    loadingVoiceReply = false;
    notifyListeners();

    if (speakReply && voiceService.autoSpeakEnabled.value) {
      await voiceService.speak(
        reply,
        audioUrl: latestVoiceAudioUrl,
        audioUrls: apiService.lastVoiceAudioUrls,
      );
    }
  }

  /// رفع صورة المحصول مباشرة داخل شاشة المساعد الصوتي لفحص الضرر والرد صوتياً مع إظهار بيانات المهندس الزراعي عند الحاجة
  Future<void> sendCropImageInVoiceChat({
    required Uint8List imageBytes,
    required String filename,
    String? cropId,
    bool speakReply = true,
  }) async {
    voiceService.unlockAudioOnGesture();

    final targetCropId = cropId ?? farmer.cropId ?? 'tomato';
    chatMessages.add(
      VoiceChatMessage(
        isFarmer: true,
        text: isEnglish
            ? '📸 Uploaded a crop leaf photo to inspect for disease or stress'
            : '📸 رفعت صورة للمحصول عشان تشوف لو فيه ضرر وتقولي أعمل إيه',
        imageBytes: imageBytes,
      ),
    );
    loadingVoiceReply = true;
    loadingDiagnosis = true;
    notifyListeners();

    final result = await apiService.diagnosePlantImage(
      farmerId: farmer.id,
      cropId: targetCropId,
      lat: farmer.lat,
      lon: farmer.lon,
      imageBytes: imageBytes,
      filename: filename,
      language: appLang,
    );

    latestDiagnosis = result;
    final eng = result.recommendedEngineer ??
        RotationEngine.rankEngineers(lat: farmer.lat, lon: farmer.lon).first;

    if (result.escalateToEngineer) {
      sentFarmerConsultations.insert(
        0,
        ConsultationRequest(
          id: result.escalationRequestId ?? (sentFarmerConsultations.length + 1),
          farmerId: farmer.id,
          engineerId: eng.id ?? 1,
          cropId: result.cropId,
          diseaseClass: result.predictedClass,
          confidence: result.confidence,
          symptoms: result.symptomsAr,
          note: result.escalationReason ??
              (isEnglish
                  ? 'Automatic escalation from voice assistant after leaf inspection'
                  : 'تصعيد تلقائي من المساعد الصوتي بعد فحص صورة المحصول'),
          status: 'pending',
          createdAt: DateTime.now().toIso8601String(),
          otherName: eng.name,
          otherPhone: eng.phone,
          distanceKm: eng.distanceKm,
        ),
      );
    }

    final StringBuffer chatReply = StringBuffer();
    chatReply.writeln(result.voiceMessageAr);
    if (!result.isHealthy) {
      chatReply.writeln(
        isEnglish
            ? '\n• Observed symptoms: ${result.symptomsAr}'
            : '\n• شكل الضرر: ${result.symptomsAr}',
      );
      chatReply.writeln(
        isEnglish
            ? '• Immediate organic care: ${result.organicTreatmentAr}'
            : '• تعمل إيه دلوقتي: ${result.organicTreatmentAr}',
      );
    }
    if (result.escalateToEngineer && !result.voiceMessageAr.contains(eng.phone)) {
      chatReply.writeln(
        isEnglish
            ? '\n👨‍🌾 Nearest agronomist: ${eng.name} (${eng.specialty}) - Phone: ${eng.phone}'
            : '\n👨‍🌾 أقرب مهندس زراعي ليك: ${eng.name} (${eng.specialty}) - تليفون: ${eng.phone}',
      );
    }

    final finalReplyText = chatReply.toString().trim();
    chatMessages.add(
      VoiceChatMessage(
        isFarmer: false,
        text: finalReplyText,
        recommendedEngineer: result.escalateToEngineer ? eng : result.recommendedEngineer,
        audioUrl: result.audioUrl,
      ),
    );

    latestVoiceReply = result.voiceMessageAr;
    latestVoiceAudioUrl = result.audioUrl;
    voiceReplySeq++;
    loadingVoiceReply = false;
    loadingDiagnosis = false;
    notifyListeners();

    if (speakReply && voiceService.autoSpeakEnabled.value) {
      await voiceService.speak(result.voiceMessageAr, audioUrl: result.audioUrl);
    }
  }

  Future<void> runPlantDocDiagnosis({
    required String cropId,
    Uint8List? imageBytes,
    String? filename,
    String? hintClass,
    double? simulatedConfidence,
    bool autoSpeak = true,
  }) async {
    if (autoSpeak) {
      voiceService.unlockAudioOnGesture();
    }
    loadingDiagnosis = true;
    notifyListeners();

    final result = await apiService.diagnosePlantImage(
      farmerId: farmer.id,
      cropId: cropId,
      lat: farmer.lat,
      lon: farmer.lon,
      imageBytes: imageBytes,
      filename: filename,
      hintClass: hintClass,
      simulatedConfidence: simulatedConfidence,
      language: appLang,
    );

    latestDiagnosis = result;
    if (result.escalateToEngineer && result.recommendedEngineer != null) {
      final eng = result.recommendedEngineer!;
      sentFarmerConsultations.insert(
        0,
        ConsultationRequest(
          id: result.escalationRequestId ?? (sentFarmerConsultations.length + 1),
          farmerId: farmer.id,
          engineerId: eng.id ?? 1,
          cropId: result.cropId,
          diseaseClass: result.predictedClass,
          confidence: result.confidence,
          symptoms: result.symptomsAr,
          note: result.escalationReason ??
              (isEnglish
                  ? 'Automatic escalation from PlantDoc AI'
                  : 'تصعيد تلقائي من نظام PlantDoc'),
          status: 'pending',
          createdAt: DateTime.now().toIso8601String(),
          otherName: eng.name,
          otherPhone: eng.phone,
          distanceKm: eng.distanceKm,
        ),
      );
    }

    loadingDiagnosis = false;
    notifyListeners();

    if (autoSpeak) {
      await voiceService.speak(result.voiceMessageAr, audioUrl: result.audioUrl);
    }
  }

  void addFarmerConsultation(EngineerProfile eng, String note) {
    final req = ConsultationRequest(
      id: sentFarmerConsultations.length + 1,
      farmerId: farmer.id,
      engineerId: eng.id ?? 1,
      cropId: farmer.cropId ?? 'wheat',
      note: note.isEmpty
          ? (isEnglish
              ? 'Inspection & consultation request from farmer'
              : 'طلب معاينة واستشارة من المزارع')
          : note,
      status: 'pending',
      createdAt: DateTime.now().toIso8601String(),
      otherName: eng.name,
      otherPhone: eng.phone,
      distanceKm: eng.distanceKm,
    );
    sentFarmerConsultations.insert(0, req);
    notifyListeners();
  }

  Future<void> registerAndEnterEngineer({
    required String name,
    required String phone,
    String password = 'demo1234',
    required double lat,
    required double lon,
    required String specialty,
    required String governorate,
    required int yearsOfExp,
  }) async {
    activeEngineer = await apiService.registerEngineer(
      name: name,
      phone: phone,
      password: password,
      lat: lat,
      lon: lon,
      specialty: specialty,
      governorate: governorate,
      yearsOfExp: yearsOfExp,
    );
    await _persistEngineerSession(activeEngineer!);
  }

  Future<void> loadEngineerCases() async {
    loadingEngineerCases = true;
    notifyListeners();
    final remote = await apiService.getEngineerRequests(activeEngineer?.id ?? 0);
    if (remote.isNotEmpty) {
      engineerCases = remote;
    } else if (sentFarmerConsultations.isNotEmpty) {
      engineerCases = List.from(sentFarmerConsultations);
    }
    loadingEngineerCases = false;
    notifyListeners();
  }

  Future<void> replyAsEngineer({
    required int requestId,
    required String status,
    required String advice,
  }) async {
    await apiService.respondToRequest(
      requestId: requestId,
      engineerId: activeEngineer?.id ?? 1,
      status: status,
      advice: advice,
    );
    final idx = engineerCases.indexWhere((c) => c.id == requestId);
    if (idx != -1) {
      final old = engineerCases[idx];
      engineerCases[idx] = ConsultationRequest(
        id: old.id,
        farmerId: old.farmerId,
        engineerId: old.engineerId,
        cropId: old.cropId,
        diseaseClass: old.diseaseClass,
        confidence: old.confidence,
        symptoms: old.symptoms,
        note: old.note,
        engineerAdvice: advice,
        status: status,
        createdAt: old.createdAt,
        otherName: old.otherName,
        otherPhone: old.otherPhone,
        distanceKm: old.distanceKm,
      );
    }
    final fIdx = sentFarmerConsultations.indexWhere((c) => c.id == requestId);
    if (fIdx != -1) {
      final oldF = sentFarmerConsultations[fIdx];
      sentFarmerConsultations[fIdx] = ConsultationRequest(
        id: oldF.id,
        farmerId: oldF.farmerId,
        engineerId: oldF.engineerId,
        cropId: oldF.cropId,
        diseaseClass: oldF.diseaseClass,
        confidence: oldF.confidence,
        symptoms: oldF.symptoms,
        note: oldF.note,
        engineerAdvice: advice,
        status: status,
        createdAt: oldF.createdAt,
        otherName: oldF.otherName,
        otherPhone: oldF.otherPhone,
        distanceKm: oldF.distanceKm,
      );
    }
    notifyListeners();
  }

  // ── Weather & Irrigation Proactive Notifications ─────────────────────────
  String? weatherAlertTitle;
  String? weatherAlertBody;
  String weatherAlertType = 'urgent'; // 'urgent' (heat/dry) | 'rain' | 'ok'
  bool showWeatherBanner = true;

  String get locationLabel {
    double bestDist = 999999;
    String bestName = isEnglish
        ? 'GPS (${farmer.lat.toStringAsFixed(2)}, ${farmer.lon.toStringAsFixed(2)})'
        : 'مصر (${farmer.lat.toStringAsFixed(2)}, ${farmer.lon.toStringAsFixed(2)})';
    for (final loc in EmbeddedCropData.egyptLocations) {
      final dLat = (loc['lat'] as num).toDouble() - farmer.lat;
      final dLon = (loc['lon'] as num).toDouble() - farmer.lon;
      final dist = dLat * dLat + dLon * dLon;
      if (dist < bestDist) {
        bestDist = dist;
        bestName = isEnglish
            ? (loc['name_en'] ?? loc['name']).toString()
            : loc['name'].toString();
      }
    }
    if (bestDist > 4.0) {
      return isEnglish
          ? 'GPS (${farmer.lat.toStringAsFixed(2)}, ${farmer.lon.toStringAsFixed(2)})'
          : 'GPS (${farmer.lat.toStringAsFixed(2)}, ${farmer.lon.toStringAsFixed(2)})';
    }
    return bestName;
  }

  void dismissWeatherBanner() {
    showWeatherBanner = false;
    notifyListeners();
  }

  void evaluateWeatherNotification() {
    final cropItem = EmbeddedCropData.rotationById[farmer.cropId ?? 'wheat'];
    final cropName = isEnglish
        ? (cropItem?.nameEn ?? farmer.cropId ?? 'Crop')
        : (cropItem?.nameAr ?? farmer.cropId ?? 'المحصول');
    final rain2d = climate.rainNext2d ?? (climate.rainTotal / 15.0);
    final level = latestIrrigationAlert?.level ?? '';
    final waterLiters =
        (latestIrrigationAlert?.waterMm ?? 4.8).toStringAsFixed(1);
    final soilPct = (climate.soilAvg * 100).round();
    final tMaxVal = climate.tMax.toStringAsFixed(0);

    if (rain2d >= 2.5 || level == 'skip') {
      weatherAlertType = 'rain';
      weatherAlertTitle = isEnglish
          ? '🌧️ Weather Alert: Incoming Rain (${rain2d.toStringAsFixed(1)} mm)'
          : '🌧️ إشعار طقس مهم: أمطار قادمة (${rain2d.toStringAsFixed(1)} ملم)';
      weatherAlertBody = isEnglish
          ? '${farmer.name}, NASA/Open-Meteo forecasts rain over the next 48 hours at $locationLabel. Pause $cropName irrigation today and check field drainage to protect roots.'
          : 'يا ${farmer.name}، قمر ناسا متوقع مطرة خلال الـ 48 ساعة الجاية على $locationLabel. وقّف ري $cropName النهارده وتأكد من تسليك المصارف عشان تحمي الجذور وتبني محصول قوي.';
      showWeatherBanner = true;
    } else if (climate.tMax >= 30.0 ||
        climate.soilAvg < 0.25 ||
        level == 'urgent' ||
        level == 'wave') {
      weatherAlertType = 'urgent';
      weatherAlertTitle = isEnglish
          ? '🔥 Heat & Dryness Alert ($tMaxVal°C • Moisture $soilPct%)'
          : '🔥 تنبيه طقس حار وجفاف ($tMaxVal°م • رطوبة $soilPct%)';
      weatherAlertBody = isEnglish
          ? '${farmer.name}, hot and dry conditions for $cropName! Irrigate today early morning or late afternoon (~$waterLiters L/m²) and avoid midday watering.'
          : 'يا ${farmer.name}، الجو حر وجاف على $cropName! اروي النهارده الصبح بدري أو بعد العصر بمعدل $waterLiters لتر/م² وتجنب الري وقت الضهر عشان تحمي الزرعة وتبني محصول عالي الإنتاج.';
      showWeatherBanner = true;
    } else {
      weatherAlertType = 'ok';
      weatherAlertTitle = isEnglish
          ? '🌤️ Weather Update ($tMaxVal°C • Soil Moisture $soilPct%)'
          : '🌤️ متابعة الطقس للمحصول ($tMaxVal°م • رطوبة $soilPct%)';
      weatherAlertBody = isEnglish
          ? 'Today\'s weather is favorable for $cropName at $locationLabel. Maintain regular early morning irrigation for strong yield.'
          : 'حالة الجو النهارده مناسبة لـ $cropName في $locationLabel. حافظ على انتظام الري الصبح بدري لزيادة قوة المحصول.';
      showWeatherBanner = true;
    }
  }

  Future<void> triggerSimulatedWeatherAlert(String mode,
      {bool speakAlert = true}) async {
    final cropItem = EmbeddedCropData.rotationById[farmer.cropId ?? 'wheat'];
    final cropName = isEnglish
        ? (cropItem?.nameEn ?? farmer.cropId ?? 'Crop')
        : (cropItem?.nameAr ?? farmer.cropId ?? 'المحصول');
    if (mode == 'rain') {
      weatherAlertType = 'rain';
      weatherAlertTitle = isEnglish
          ? '🌧️ Urgent Alert: Heavy Rain & Weather Shift Ahead!'
          : '🌧️ تنبيه عاجل: أمطار وتقلبات جوية قادمة!';
      weatherAlertBody = isEnglish
          ? 'Alert for ${farmer.name}: Heavy rain expected soon. Stop $cropName irrigation immediately, delay ground fertilization today, and clear field drainage channels.'
          : 'تنبيه لـ ${farmer.name}: متوقع سقوط أمطار غزيرة خلال الساعات الجاية. وقّف ري $cropName فوراً، وامنع التسميد الأرضي النهارده، وجهّز مصارف الأرض عشان المية متكتمش على الجذور.';
    } else {
      weatherAlertType = 'urgent';
      weatherAlertTitle = isEnglish
          ? '🔥 Urgent Alert: Severe Heat Wave & Dry Soil!'
          : '🔥 تنبيه عاجل: موجة حرارة عالية وجفاف شديد!';
      weatherAlertBody = isEnglish
          ? 'Alert for ${farmer.name}: High heat and dry soil detected! Irrigate $cropName at dawn or dusk (~5.5 L/m²), and consider amino acids or potassium silicate foliar spray for heat resilience.'
          : 'تنبيه لـ ${farmer.name}: الحرارة مرتفعة جداً مع جفاف في التربة! اروي $cropName النهارده آخر النهار أو الفجر (حوالي 5.5 لتر/م²)، وممكن ترش أحماض أمينية أو سليكات بوتاسيوم عشان ترفع مناعة المحصول ضد الحر.';
    }
    showWeatherBanner = true;
    notifyListeners();
    if (speakAlert && weatherAlertBody != null) {
      voiceService.unlockAudioOnGesture();
      await voiceService.speak(weatherAlertBody!);
    }
  }

  Future<void> addAndSelectCustomCrop(String cropName) async {
    final clean = cropName.trim();
    if (clean.isEmpty) return;
    final cleanLow = clean.toLowerCase();

    // Check if it matches an existing crop Arabic or English name
    String? matchedId;
    for (final c in EmbeddedCropData.allFarmerCrops) {
      if (c.nameAr == clean ||
          clean.contains(c.nameAr) ||
          c.nameAr.contains(clean) ||
          c.nameEn.toLowerCase() == cleanLow ||
          cleanLow.contains(c.nameEn.toLowerCase()) ||
          c.nameEn.toLowerCase().contains(cleanLow)) {
        matchedId = c.id;
        break;
      }
    }
    final cropId = matchedId ?? 'custom_${clean.replaceAll(' ', '_')}';
    EmbeddedCropData.ensureCropRegistered(
      cropId: cropId,
      nameAr: clean,
      nameEn: clean,
      icon: '🌱',
    );
    await updateFarmerProfile(name: farmer.name, targetCrop: cropId);
    evaluateWeatherNotification();
    notifyListeners();
  }
}

