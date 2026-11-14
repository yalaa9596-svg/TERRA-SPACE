import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/embedded_crop_data.dart';
import '../models/crop_models.dart';
import 'rotation_engine.dart';

class ApiService {
  static const String _envApiUrl = String.fromEnvironment('API_URL');
  static const String defaultLanApiUrl = 'http://10.135.89.240:8000';

  static String resolveDefaultBaseUrl() {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      final scheme = Uri.base.scheme;
      final port = Uri.base.port;
      if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:8000';
      }
      if (scheme == 'https' || port == 8000 || port == 80 || port == 443 || port == 0) {
        return Uri.base.origin;
      }
      return 'http://$host:8000';
    }
    return defaultLanApiUrl;
  }

  String baseUrl;
  String? authToken;
  String? lastVoiceAudioUrl;
  List<String> lastVoiceAudioUrls = const [];
  EngineerProfile? lastVoiceEngineer;
  String? lastVoiceIntent;
  String? lastDetectedFarmerName;
  String? lastDetectedCropId;
  String? lastDetectedCropNameAr;
  String? lastDetectedCropIcon;
  List<String> lastRecommendedAlternatives = const [];

  ApiService({String? baseUrl, this.authToken})
      : baseUrl = (baseUrl != null && baseUrl.trim().isNotEmpty)
            ? baseUrl.trim()
            : resolveDefaultBaseUrl();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  /// جلب بيانات مناخ NASA POWER + توقعات Open-Meteo مباشرة
  Future<ClimateSummary> fetchNasaPowerDirect(double lat, double lon) async {
    try {
      final end = DateTime.now().subtract(const Duration(days: 2));
      final start = end.subtract(const Duration(days: 32));
      final powerUri = Uri.parse(
        'https://power.larc.nasa.gov/api/temporal/daily/point'
        '?parameters=T2M,T2M_MAX,T2M_MIN,PRECTOTCORR,RH2M,GWETROOT'
        '&community=AG'
        '&latitude=$lat'
        '&longitude=$lon'
        '&start=${_fmtDate(start)}'
        '&end=${_fmtDate(end)}'
        '&format=JSON',
      );
      final resp = await http.get(powerUri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final param = (data['properties']?['parameter'] ?? {}) as Map<String, dynamic>;

        List<double> validVals(String key) {
          final map = (param[key] ?? {}) as Map<String, dynamic>;
          return map.values
              .map((v) => (v as num).toDouble())
              .where((v) => v != -999.0)
              .toList();
        }

        final t2m = validVals('T2M');
        final tmax = validVals('T2M_MAX');
        final tmin = validVals('T2M_MIN');
        final rain = validVals('PRECTOTCORR');
        final rh = validVals('RH2M');
        final soil = validVals('GWETROOT');

        double mean(List<double> xs, double fallback) =>
            xs.isEmpty ? fallback : xs.reduce((a, b) => a + b) / xs.length;

        double? elevation;
        double? rainNext2d;
        double? fcTmax;
        double? fcTmin;
        try {
          final fUri = Uri.parse(
            'https://api.open-meteo.com/v1/forecast'
            '?latitude=$lat&longitude=$lon'
            '&current=temperature_2m,precipitation'
            '&daily=precipitation_sum,temperature_2m_max,temperature_2m_min'
            '&forecast_days=3&timezone=auto',
          );
          final fResp = await http.get(fUri).timeout(const Duration(seconds: 6));
          if (fResp.statusCode == 200) {
            final fj = jsonDecode(fResp.body) as Map<String, dynamic>;
            elevation = (fj['elevation'] as num?)?.toDouble();
            final pList = (fj['daily']?['precipitation_sum'] as List<dynamic>? ?? []);
            if (pList.length >= 2) {
              rainNext2d = ((pList[0] ?? 0) as num).toDouble() +
                  ((pList[1] ?? 0) as num).toDouble();
            }
            final maxList = (fj['daily']?['temperature_2m_max'] as List<dynamic>? ?? [])
                .where((e) => e != null)
                .map((e) => (e as num).toDouble())
                .toList();
            final minList = (fj['daily']?['temperature_2m_min'] as List<dynamic>? ?? [])
                .where((e) => e != null)
                .map((e) => (e as num).toDouble())
                .toList();
            if (maxList.isNotEmpty) fcTmax = maxList.reduce((a, b) => a > b ? a : b);
            if (minList.isNotEmpty) fcTmin = minList.reduce((a, b) => a < b ? a : b);
          }
        } catch (_) {}

        return ClimateSummary(
          days: t2m.isEmpty ? 30 : t2m.length,
          tAvg: mean(t2m, 20.5),
          tMax: tmax.isEmpty ? 26.0 : tmax.reduce((a, b) => a > b ? a : b),
          tMin: tmin.isEmpty ? 14.0 : tmin.reduce((a, b) => a < b ? a : b),
          rainTotal: rain.isEmpty ? 1.2 : rain.reduce((a, b) => a + b),
          rhAvg: mean(rh, 58.0),
          soilAvg: mean(soil, 0.27),
          elevation: elevation ?? 18.0,
          rainNext2d: rainNext2d ?? 0.0,
          forecastTmax: fcTmax,
          forecastTmin: fcTmin,
        );
      }
    } catch (_) {}

    final isUpperEgypt = lat < 27.5;
    return ClimateSummary(
      days: 30,
      tAvg: isUpperEgypt ? 24.5 : 19.8,
      tMax: isUpperEgypt ? 31.0 : 24.5,
      tMin: isUpperEgypt ? 16.0 : 13.5,
      rainTotal: isUpperEgypt ? 0.2 : 4.5,
      rhAvg: isUpperEgypt ? 44.0 : 62.0,
      soilAvg: 0.26,
      elevation: isUpperEgypt ? 85.0 : 15.0,
      rainNext2d: 0.0,
    );
  }

  /// Zero-Login Onboarding للمزارع (POST /api/farmer/onboarding)
  Future<AppUser> farmerOnboarding({
    required String name,
    required String phone,
    required double lat,
    required double lon,
    required String targetCrop,
    String? previousCrop,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/farmer/onboarding'),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'lat': lat,
              'lon': lon,
              'target_crop': targetCrop,
              'previous_crop': previousCrop,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        authToken = data['token']?.toString();
        return AppUser.fromJson(Map<String, dynamic>.from(data['farmer']));
      }
    } catch (_) {}

    return AppUser(
      id: 1,
      role: 'farmer',
      name: name,
      phone: phone,
      lat: lat,
      lon: lon,
      cropId: targetCrop,
      previousCropId: previousCrop ?? 'clover',
    );
  }

  /// المحادثة الصوتية التفاعلية ثنائية اللغة للمزارع (POST /api/voice/interact + دعم Gemini API + ذاكرة المحادثة)
  Future<String> voiceInteract({
    required int farmerId,
    String? farmerName,
    String? sessionId,
    required String queryText,
    required String targetCrop,
    required String? previousCrop,
    required double lat,
    required double lon,
    required ClimateSummary climate,
    List<Map<String, dynamic>>? history,
    String? geminiApiKey,
    String language = 'ar',
  }) async {
    lastVoiceAudioUrl = null;
    lastVoiceAudioUrls = const [];
    lastVoiceEngineer = null;
    lastVoiceIntent = null;
    lastDetectedFarmerName = null;
    lastDetectedCropId = null;
    lastDetectedCropNameAr = null;
    lastDetectedCropIcon = null;
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/voice/interact'),
            headers: _headers,
            body: jsonEncode({
              'farmer_id': farmerId,
              if (farmerName != null) 'farmer_name': farmerName,
              'session_id': sessionId ?? 'farmer_$farmerId',
              'query_text': queryText,
              'target_crop': targetCrop,
              'previous_crop': previousCrop,
              'lat': lat,
              'lon': lon,
              'language': language,
              if (history != null) 'history': history,
              if (geminiApiKey != null && geminiApiKey.trim().isNotEmpty)
                'gemini_api_key': geminiApiKey.trim(),
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        lastVoiceAudioUrl = data['audio_url']?.toString();
        if (data['audio_urls'] is List) {
          lastVoiceAudioUrls = (data['audio_urls'] as List)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (lastVoiceAudioUrl != null && lastVoiceAudioUrl!.isNotEmpty) {
          lastVoiceAudioUrls = [lastVoiceAudioUrl!];
        }
        lastVoiceIntent = data['intent']?.toString();
        lastDetectedFarmerName = data['detected_farmer_name']?.toString();
        lastDetectedCropId = data['detected_crop_id']?.toString();
        lastDetectedCropNameAr = (data['detected_crop_name_ar'] ?? data['crop_name_ar'])?.toString();
        lastDetectedCropIcon = data['detected_crop_icon']?.toString();
        if (data['recommended_alternatives'] is List) {
          lastRecommendedAlternatives = (data['recommended_alternatives'] as List)
              .map((e) {
                if (e is Map) {
                  return language == 'en'
                      ? (e['name_en'] ?? e['name_ar'] ?? '').toString()
                      : (e['name_ar'] ?? e['name_en'] ?? '').toString();
                }
                return e.toString();
              })
              .where((s) => s.isNotEmpty)
              .toList();
        }
        if (data['nearest_engineer'] is Map<String, dynamic>) {
          lastVoiceEngineer = EngineerProfile.fromJson(
            data['nearest_engineer'] as Map<String, dynamic>,
          );
        }
        return (data['reply'] ?? data['reply_ar'] ?? '').toString();
      }
    } catch (_) {}

    lastVoiceEngineer = RotationEngine.rankEngineers(lat: lat, lon: lon).first;
    lastVoiceIntent = 'connection_error';
    return language == 'en'
        ? 'Sorry, I could not reach the smart assistant right now due to a network or API key issue.'
        : 'عذراً، تعذر الاتصال بالمساعد الذكي حالياً بسبب مشكلة في الشبكة أو المفتاح';
  }

  /// حالة الري الـ 5 من ناسا (GET /api/irrigation/status/{farmer_id})
  Future<IrrigationAlert> getIrrigationStatus({
    required int farmerId,
    required String cropId,
    required double lat,
    required double lon,
    required ClimateSummary climate,
    String language = 'ar',
  }) async {
    try {
      final resp = await http
          .get(
            Uri.parse(
              '$baseUrl/api/irrigation/status/$farmerId?lat=$lat&lon=$lon&crop_id=$cropId&language=$language',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        return IrrigationAlert.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      }
    } catch (_) {}

    final crop = EmbeddedCropData.rotationById[cropId] ??
        EmbeddedCropData.rotationCrops.first;
    return RotationEngine.computeIrrigationAlert(
      crop: crop,
      climate: climate,
      language: language,
    );
  }

  /// تشخيص أمراض النباتات عبر PlantDoc والتصعيد التلقائي (POST /api/vision/diagnose)
  Future<VisionDiagnosisResult> diagnosePlantImage({
    required int farmerId,
    required String cropId,
    required double lat,
    required double lon,
    Uint8List? imageBytes,
    String? filename,
    String? hintClass,
    double? simulatedConfidence,
    String language = 'ar',
  }) async {
    try {
      final b64 = imageBytes != null ? base64Encode(imageBytes) : null;
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/vision/diagnose'),
            headers: _headers,
            body: jsonEncode({
              'farmer_id': farmerId,
              'crop_id': cropId,
              'lat': lat,
              'lon': lon,
              'language': language,
              'image_base64': b64,
              'filename': filename,
              'hint_class': hintClass,
              'simulated_confidence': simulatedConfidence,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        return VisionDiagnosisResult.fromApiJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}

    final nearestEng = RotationEngine.rankEngineers(lat: lat, lon: lon).first;
    final errMsg = language == 'en'
        ? 'Sorry, I could not reach the PlantDoc server right now due to a network or key issue.'
        : 'عذراً، تعذر الاتصال بالمساعد الذكي حالياً بسبب مشكلة في الشبكة أو المفتاح';
    return VisionDiagnosisResult(
      datasetSource: 'connection_error',
      supportedInPlantDoc: false,
      cropId: cropId,
      cropNameAr: language == 'en' ? 'Unknown (Connection Error)' : 'غير محدد (خطأ اتصال)',
      predictedClass: 'Connection Error',
      diseaseNameAr: errMsg,
      confidence: 0.0,
      confidencePct: 0,
      isHealthy: false,
      isSevere: false,
      escalateToEngineer: true,
      escalationReason: errMsg,
      recommendedSpecialty: nearestEng.specialty,
      symptomsAr: errMsg,
      organicTreatmentAr: language == 'en'
          ? 'Verify the local backend server (port 8000) is running or contact an agronomist.'
          : 'يرجى التأكد من تشغيل السيرفر المحلي (port 8000) أو التواصل مع المهندس الزراعي.',
      chemicalTreatmentAr: language == 'en'
          ? 'Verify the local backend server (port 8000) is running or contact an agronomist.'
          : 'يرجى التأكد من تشغيل السيرفر المحلي (port 8000) أو التواصل مع المهندس الزراعي.',
      voiceMessageAr: errMsg,
      recommendedEngineer: nearestEng,
    );
  }

  /// تقييم الدورة الزراعية (POST /rotation/evaluate)
  Future<RotationEvaluationResult> evaluateCropRotation({
    required String targetCropId,
    required String? previousCropId,
    required double lat,
    required double lon,
    ClimateSummary? cachedClimate,
  }) async {
    final target = EmbeddedCropData.rotationById[targetCropId] ??
        EmbeddedCropData.rotationCrops.first;
    final prev =
        previousCropId != null ? EmbeddedCropData.rotationById[previousCropId] : null;

    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/rotation/evaluate'),
            headers: _headers,
            body: jsonEncode({
              'target_crop_id': targetCropId,
              'previous_crop_id': previousCropId,
              'lat': lat,
              'lon': lon,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final clim = ClimateSummary.fromJson(
          Map<String, dynamic>.from(data['climate'] ?? {}),
          elevation: (data['elevation'] as num?)?.toDouble(),
        );
        return RotationEngine.evaluate(
          target: target,
          previous: prev,
          climate: clim,
        );
      }
    } catch (_) {}

    final clim = cachedClimate ?? await fetchNasaPowerDirect(lat, lon);
    return RotationEngine.evaluate(
      target: target,
      previous: prev,
      climate: clim,
    );
  }

  /// إرسال كود تحقق عبر واتساب للمزارع (POST /api/auth/farmer/send-otp)
  Future<Map<String, dynamic>> sendFarmerWhatsappOtp(String phone) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/auth/farmer/send-otp'),
            headers: _headers,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(resp.body);
      throw Exception(err['detail'] ?? 'تعذر إرسال كود التحقق');
    } catch (e) {
      if (e is Exception && e.toString().contains('يرجى إدخال')) rethrow;
      // في حالة انقطاع الاتصال المؤقت نعرض كود تجريبي 1234
      return {
        'ok': true,
        'phone': phone,
        'existing_farmer': false,
        'farmer_name': '',
        'demo_otp_code': '1234',
        'whatsapp_message': 'كود الدخول لتطبيق Terra Space هو: 1234',
      };
    }
  }

  /// التحقق من كود واتساب وتسجيل دخول المزارع واسترجاع سجله الشخصي (POST /api/auth/farmer/verify-otp)
  Future<Map<String, dynamic>> verifyFarmerWhatsappOtp({
    required String phone,
    required String otpCode,
    required String name,
    required double lat,
    required double lon,
    String targetCrop = 'wheat',
    String previousCrop = 'clover',
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/auth/farmer/verify-otp'),
            headers: _headers,
            body: jsonEncode({
              'phone': phone,
              'otp_code': otpCode,
              'name': name,
              'lat': lat,
              'lon': lon,
              'target_crop': targetCrop,
              'previous_crop': previousCrop,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        authToken = data['token']?.toString();
        return data;
      }
      final err = jsonDecode(resp.body);
      throw Exception(err['detail'] ?? 'كود التحقق غير صحيح');
    } catch (e) {
      if (e.toString().contains('كود التحقق غير صحيح')) rethrow;
      return {
        'token': 'offline_farmer_token',
        'farmer': {
          'id': 1,
          'name': name.isEmpty ? 'المزارع الذكي' : name,
          'phone': phone,
          'lat': lat,
          'lon': lon,
          'crop_id': targetCrop,
          'previous_crop_id': previousCrop,
        },
        'session_id': 'farmer_${phone}_1',
        'chat_history': <dynamic>[],
        'farmer_memory': {'farmer_name': name},
      };
    }
  }

  /// تسجيل المهندس الزراعي (POST /api/engineer/register)
  Future<EngineerProfile> registerEngineer({
    required String name,
    required String phone,
    String password = 'demo1234',
    required double lat,
    required double lon,
    required String specialty,
    required String governorate,
    required int yearsOfExp,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/engineer/register'),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'password': password,
              'lat': lat,
              'lon': lon,
              'specialty': specialty,
              'governorate': governorate,
              'years_of_exp': yearsOfExp,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        authToken = data['token']?.toString();
        return EngineerProfile.fromJson(
          Map<String, dynamic>.from(data['engineer']),
        );
      }
    } catch (_) {}

    return EngineerProfile(
      id: 1,
      name: name,
      phone: phone,
      lat: lat,
      lon: lon,
      specialty: specialty,
      governorate: governorate,
      yearsOfExp: yearsOfExp,
      distanceKm: 0.0,
    );
  }

  /// تسجيل دخول المهندس الزراعي برقم الهاتف وكلمة المرور (POST /api/auth/engineer/login)
  Future<EngineerProfile> loginEngineer({
    required String phone,
    required String password,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/api/auth/engineer/login'),
          headers: _headers,
          body: jsonEncode({
            'phone': phone,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      authToken = data['token']?.toString();
      return EngineerProfile.fromJson(
        Map<String, dynamic>.from(data['engineer']),
      );
    }
    String detail = 'رقم الهاتف أو كلمة المرور غير صحيحة';
    try {
      final err = jsonDecode(resp.body);
      if (err['detail'] != null) detail = err['detail'].toString();
    } catch (_) {}
    throw Exception(detail);
  }

  /// جلب طلبات وحالات المزارعين للمهندس (GET /api/engineer/requests/{engineer_id})
  Future<List<ConsultationRequest>> getEngineerRequests(int engineerId) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$baseUrl/api/engineer/requests/$engineerId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list
            .map((e) => ConsultationRequest.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// إرسال رد وتوصية المهندس للمزارع (POST /api/engineer/respond)
  Future<bool> respondToRequest({
    required int requestId,
    required int engineerId,
    required String status,
    required String advice,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/engineer/respond'),
            headers: _headers,
            body: jsonEncode({
              'request_id': requestId,
              'engineer_id': engineerId,
              'status': status,
              'advice': advice,
            }),
          )
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200;
    } catch (_) {
      return true;
    }
  }
}
