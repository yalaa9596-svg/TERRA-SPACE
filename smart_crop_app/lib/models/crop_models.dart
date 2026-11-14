class RangeBounds {
  final double min;
  final double max;

  const RangeBounds({required this.min, required this.max});

  factory RangeBounds.fromJson(Map<String, dynamic> json) {
    return RangeBounds(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}

class VoiceDialogue {
  final String suitable;
  final String unsuitable;

  const VoiceDialogue({required this.suitable, required this.unsuitable});

  factory VoiceDialogue.fromJson(Map<String, dynamic> json) {
    return VoiceDialogue(
      suitable: json['suitable']?.toString() ?? '',
      unsuitable: json['unsuitable']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'suitable': suitable,
        'unsuitable': unsuitable,
      };
}

class CropRotationItem {
  final String id;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String family;
  final String season;
  final String waterNeed;
  final String nitrogenRole;
  final RangeBounds optimalTemp;
  final RangeBounds optimalHumidity;
  final double soilMoistureMin;
  final List<String> badPrecedingFamilies;
  final List<String> recommendedNextCrops;
  final VoiceDialogue voiceDialogue;

  const CropRotationItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.family,
    required this.season,
    required this.waterNeed,
    required this.nitrogenRole,
    required this.optimalTemp,
    required this.optimalHumidity,
    required this.soilMoistureMin,
    required this.badPrecedingFamilies,
    required this.recommendedNextCrops,
    required this.voiceDialogue,
  });

  String get familyCode => family.split('(').first.trim();

  String get seasonAr {
    switch (season.toLowerCase()) {
      case 'winter':
        return 'شتوي';
      case 'summer':
        return 'صيفي';
      case 'fall/spring':
        return 'خريفي / ربيعي';
      default:
        return season;
    }
  }

  String get waterNeedAr {
    switch (waterNeed.toLowerCase()) {
      case 'low':
        return 'منخفض';
      case 'low-medium':
        return 'منخفض - متوسط';
      case 'medium':
        return 'متوسط';
      case 'high':
        return 'مرتفع';
      default:
        return waterNeed;
    }
  }

  factory CropRotationItem.fromJson(Map<String, dynamic> json) {
    return CropRotationItem(
      id: json['id'].toString(),
      nameAr: json['name_ar'].toString(),
      nameEn: json['name_en'].toString(),
      icon: (json['icon'] ?? json['emoji'] ?? '🌱').toString(),
      family: (json['family'] ?? 'غير محدد').toString(),
      season: (json['season'] ?? 'All').toString(),
      waterNeed: (json['water_need'] ?? 'Medium').toString(),
      nitrogenRole: (json['nitrogen_role'] ?? 'متوازن').toString(),
      optimalTemp: json['optimal_temp'] != null
          ? RangeBounds.fromJson(Map<String, dynamic>.from(json['optimal_temp']))
          : const RangeBounds(min: 15.0, max: 28.0),
      optimalHumidity: json['optimal_humidity'] != null
          ? RangeBounds.fromJson(Map<String, dynamic>.from(json['optimal_humidity']))
          : const RangeBounds(min: 40.0, max: 75.0),
      soilMoistureMin: ((json['soil_moisture_min'] ?? 0.20) as num).toDouble(),
      badPrecedingFamilies: (json['bad_preceding_families'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      recommendedNextCrops: (json['recommended_next_crops'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      voiceDialogue: json['voice_dialogue'] != null
          ? VoiceDialogue.fromJson(Map<String, dynamic>.from(json['voice_dialogue']))
          : VoiceDialogue(
              suitable: 'أهلاً بك يا أخي المزارع! أنا ${json['name_ar']}، جو أرضك ممتاز ومناسب للزراعة!',
              unsuitable: 'يا عزيزي المزارع، أنا ${json['name_ar']}، الظروف الحالية غير مناسبة لزراعتي.',
            ),
    );
  }
}

class ClimateSummary {
  final int days;
  final double tAvg;
  final double tMax;
  final double tMin;
  final double rainTotal;
  final double rhAvg;
  final double soilAvg;
  final double? elevation;
  final double? rainNext2d;
  final double? forecastTmax;
  final double? forecastTmin;

  const ClimateSummary({
    required this.days,
    required this.tAvg,
    required this.tMax,
    required this.tMin,
    required this.rainTotal,
    required this.rhAvg,
    required this.soilAvg,
    this.elevation,
    this.rainNext2d,
    this.forecastTmax,
    this.forecastTmin,
  });

  factory ClimateSummary.fromJson(
    Map<String, dynamic> json, {
    double? elevation,
    double? rainNext2d,
    double? forecastTmax,
    double? forecastTmin,
  }) {
    return ClimateSummary(
      days: (json['days'] as num? ?? 30).toInt(),
      tAvg: (json['t_avg'] as num? ?? 21.0).toDouble(),
      tMax: (json['t_max'] as num? ?? 27.0).toDouble(),
      tMin: (json['t_min'] as num? ?? 14.0).toDouble(),
      rainTotal: (json['rain_total'] as num? ?? 2.5).toDouble(),
      rhAvg: (json['rh_avg'] as num? ?? 58.0).toDouble(),
      soilAvg: (json['soil_avg'] as num? ?? 0.28).toDouble(),
      elevation: elevation ?? (json['elevation'] as num?)?.toDouble(),
      rainNext2d: rainNext2d ?? (json['rain_next_2d'] as num?)?.toDouble(),
      forecastTmax: forecastTmax ?? (json['forecast_tmax'] as num?)?.toDouble(),
      forecastTmin: forecastTmin ?? (json['forecast_tmin'] as num?)?.toDouble(),
    );
  }
}

class RotationEvaluationResult {
  final CropRotationItem targetCrop;
  final CropRotationItem? previousCrop;
  final bool isSuitable;
  final int score;
  final int climateScore;
  final String level; // yes | maybe | no
  final String verdict;
  final bool familyConflict;
  final bool isRecommendedSequence;
  final bool soilOk;
  final bool tempOk;
  final bool humidityOk;
  final List<String> reasons;
  final String voiceDialogue;
  final List<CropRotationItem> recommendedNextCrops;
  final ClimateSummary climate;

  const RotationEvaluationResult({
    required this.targetCrop,
    required this.previousCrop,
    required this.isSuitable,
    required this.score,
    required this.climateScore,
    required this.level,
    required this.verdict,
    required this.familyConflict,
    required this.isRecommendedSequence,
    required this.soilOk,
    required this.tempOk,
    required this.humidityOk,
    required this.reasons,
    required this.voiceDialogue,
    required this.recommendedNextCrops,
    required this.climate,
  });
}

class IrrigationAlert {
  final String level; // urgent | water | skip | wave | ok
  final String stateAr; // ري عاجل | ري مطلوب | لا تروي | موجة حر أو برد | تمام
  final String actionAr;
  final String message;
  final double waterMm;
  final double soilWetness;
  final double rain7dMm;
  final double? rainNext2dMm;

  const IrrigationAlert({
    required this.level,
    required this.stateAr,
    required this.actionAr,
    required this.message,
    required this.waterMm,
    required this.soilWetness,
    required this.rain7dMm,
    this.rainNext2dMm,
  });

  factory IrrigationAlert.fromJson(Map<String, dynamic> json) {
    final lvl = (json['level'] ?? 'ok').toString();
    final defaultState = {
          'urgent': 'ري عاجل',
          'water': 'ري مطلوب',
          'skip': 'لا تروي',
          'wave': 'موجة حر أو برد',
          'ok': 'تمام',
        }[lvl] ??
        'تمام';
    return IrrigationAlert(
      level: lvl,
      stateAr: (json['state_ar'] ?? defaultState).toString(),
      actionAr: (json['action_ar'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      waterMm: ((json['water_mm'] ?? 0.0) as num).toDouble(),
      soilWetness: ((json['soil_wetness'] ?? 0.25) as num).toDouble(),
      rain7dMm: ((json['rain_7d_mm'] ?? 0.0) as num).toDouble(),
      rainNext2dMm: (json['rain_next_2d_mm'] as num?)?.toDouble(),
    );
  }
}

class EngineerProfile {
  final int? id;
  final String name;
  final String phone;
  final double lat;
  final double lon;
  final String specialty;
  final String governorate;
  final int yearsOfExp;
  final double distanceKm;

  const EngineerProfile({
    this.id,
    required this.name,
    required this.phone,
    required this.lat,
    required this.lon,
    required this.specialty,
    required this.governorate,
    this.yearsOfExp = 8,
    required this.distanceKm,
  });

  factory EngineerProfile.fromJson(Map<String, dynamic> json) {
    return EngineerProfile(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      lat: ((json['lat'] ?? 30.0444) as num).toDouble(),
      lon: ((json['lon'] ?? 31.2357) as num).toDouble(),
      specialty: (json['specialty'] ?? 'استشاري زراعي').toString(),
      governorate: (json['governorate'] ?? 'مصر').toString(),
      yearsOfExp: ((json['years_of_exp'] ?? 8) as num).toInt(),
      distanceKm: ((json['distance_km'] ?? 0.0) as num).toDouble(),
    );
  }
}

class VisionDiagnosisResult {
  final String datasetSource;
  final bool supportedInPlantDoc;
  final String cropId;
  final String cropNameAr;
  final String predictedClass;
  final String diseaseNameAr;
  final double confidence;
  final int confidencePct;
  final bool isHealthy;
  final bool isSevere;
  final bool escalateToEngineer;
  final String? escalationReason;
  final String recommendedSpecialty;
  final String symptomsAr;
  final String organicTreatmentAr;
  final String chemicalTreatmentAr;
  final String voiceMessageAr;
  final String? audioUrl;
  final EngineerProfile? recommendedEngineer;
  final int? escalationRequestId;

  const VisionDiagnosisResult({
    required this.datasetSource,
    required this.supportedInPlantDoc,
    required this.cropId,
    required this.cropNameAr,
    required this.predictedClass,
    required this.diseaseNameAr,
    required this.confidence,
    required this.confidencePct,
    required this.isHealthy,
    required this.isSevere,
    required this.escalateToEngineer,
    this.escalationReason,
    required this.recommendedSpecialty,
    required this.symptomsAr,
    required this.organicTreatmentAr,
    required this.chemicalTreatmentAr,
    required this.voiceMessageAr,
    this.audioUrl,
    this.recommendedEngineer,
    this.escalationRequestId,
  });

  factory VisionDiagnosisResult.fromApiJson(Map<String, dynamic> wrapper) {
    final json = wrapper['diagnosis'] != null
        ? Map<String, dynamic>.from(wrapper['diagnosis'])
        : wrapper;
    final recEng = wrapper['recommended_engineer'] != null
        ? EngineerProfile.fromJson(Map<String, dynamic>.from(wrapper['recommended_engineer']))
        : null;
    final rawConf = ((json['confidence'] ?? 0.85) as num).toDouble();
    final normConf = rawConf > 1.0 ? (rawConf / 100.0) : rawConf;
    return VisionDiagnosisResult(
      datasetSource: (json['dataset_source'] ?? 'https://www.kaggle.com/datasets/nirmalsankalana/plantdoc-dataset').toString(),
      supportedInPlantDoc: json['supported_in_plantdoc'] as bool? ?? true,
      cropId: (json['crop_id'] ?? 'tomato').toString(),
      cropNameAr: (json['crop_name_ar'] ?? json['crop_name'] ?? 'الطماطم').toString(),
      predictedClass: (json['predicted_class'] ?? json['disease_name'] ?? 'Tomato Early Blight').toString(),
      diseaseNameAr: (json['disease_name_ar'] ?? json['disease_name'] ?? '').toString(),
      confidence: normConf,
      confidencePct: ((json['confidence_pct'] ?? (normConf * 100).round()) as num).toInt(),
      isHealthy: json['is_healthy'] as bool? ?? false,
      isSevere: json['is_severe'] as bool? ?? false,
      escalateToEngineer: json['escalate_to_engineer'] as bool? ?? false,
      escalationReason: json['escalation_reason']?.toString(),
      recommendedSpecialty: (json['recommended_specialty'] ?? 'أمراض نباتية').toString(),
      symptomsAr: (json['symptoms_ar'] ?? '').toString(),
      organicTreatmentAr: (json['organic_treatment_ar'] ?? json['treatment_ar'] ?? '').toString(),
      chemicalTreatmentAr: (json['chemical_treatment_ar'] ?? '').toString(),
      voiceMessageAr: (json['voice_message_ar'] ?? json['voice_summary_ar'] ?? '').toString(),
      audioUrl: (json['audio_url'] ?? wrapper['audio_url'])?.toString(),
      recommendedEngineer: recEng,
      escalationRequestId: (wrapper['escalation_request_id'] as num?)?.toInt(),
    );
  }
}

class AppUser {
  final int id;
  final String role; // farmer | engineer
  final String name;
  final String phone;
  final double lat;
  final double lon;
  final String? specialty;
  final String? cropId;
  final String? previousCropId;
  final String? plantedAt;

  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    required this.lat,
    required this.lon,
    this.specialty,
    this.cropId,
    this.previousCropId,
    this.plantedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: ((json['id'] ?? 1) as num).toInt(),
      role: (json['role'] ?? 'farmer').toString(),
      name: (json['name'] ?? 'المزارع الذكي').toString(),
      phone: (json['phone'] ?? '01000000000').toString(),
      lat: ((json['lat'] ?? 30.0444) as num).toDouble(),
      lon: ((json['lon'] ?? 31.2357) as num).toDouble(),
      specialty: json['specialty']?.toString(),
      cropId: json['crop_id']?.toString(),
      previousCropId: json['previous_crop_id']?.toString(),
      plantedAt: json['planted_at']?.toString(),
    );
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? role,
    String? cropId,
    String? previousCropId,
    double? lat,
    double? lon,
  }) {
    return AppUser(
      id: id,
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      specialty: specialty,
      cropId: cropId ?? this.cropId,
      previousCropId: previousCropId ?? this.previousCropId,
      plantedAt: plantedAt,
    );
  }
}

class ConsultationRequest {
  final int id;
  final int farmerId;
  final int engineerId;
  final String? cropId;
  final String? diseaseClass;
  final double? confidence;
  final String? symptoms;
  final String? note;
  final String? engineerAdvice;
  final String status; // pending | accepted | rejected | done
  final String createdAt;
  final String otherName;
  final String otherPhone;
  final double? distanceKm;

  const ConsultationRequest({
    required this.id,
    required this.farmerId,
    required this.engineerId,
    this.cropId,
    this.diseaseClass,
    this.confidence,
    this.symptoms,
    this.note,
    this.engineerAdvice,
    required this.status,
    required this.createdAt,
    required this.otherName,
    required this.otherPhone,
    this.distanceKm,
  });

  String get statusAr {
    switch (status) {
      case 'accepted':
        return 'تم القبول ✅';
      case 'rejected':
        return 'معتذر ❌';
      case 'done':
        return 'تم إرسال التوصية 🌟';
      default:
        return 'قيد المراجعة ⏳';
    }
  }

  factory ConsultationRequest.fromJson(Map<String, dynamic> json) {
    return ConsultationRequest(
      id: ((json['id'] ?? json['request_id'] ?? 1) as num).toInt(),
      farmerId: ((json['farmer_id'] ?? 1) as num).toInt(),
      engineerId: ((json['engineer_id'] ?? 1) as num).toInt(),
      cropId: json['crop_id']?.toString(),
      diseaseClass: json['disease_class']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      symptoms: json['symptoms']?.toString(),
      note: json['note']?.toString(),
      engineerAdvice: json['engineer_advice']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: (json['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      otherName: (json['farmer_name'] ?? json['other_name'] ?? json['engineer']?['name'] ?? 'المزارع الذكي').toString(),
      otherPhone: (json['farmer_phone'] ?? json['other_phone'] ?? json['engineer']?['phone'] ?? '01000000001').toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
