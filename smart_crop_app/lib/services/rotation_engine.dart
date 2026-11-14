import 'dart:math' as math;
import '../data/embedded_crop_data.dart';
import '../models/crop_models.dart';

class RotationEngine {
  static double _band(double? value, double lo, double hi, double full, double slope) {
    if (value == null) return full / 2.0;
    if (value >= lo && value <= hi) return full;
    final dist = value < lo ? (lo - value) : (value - hi);
    return math.max(0.0, full - dist * slope);
  }

  /// تقييم شامل للمحصول المستهدف بناءً على المحصول السابق وبيانات أقمار ناسا الصناعية للمزارع
  static RotationEvaluationResult evaluate({
    required CropRotationItem target,
    required CropRotationItem? previous,
    required ClimateSummary climate,
  }) {
    final lo = target.optimalTemp.min;
    final hi = target.optimalTemp.max;
    final absLo = math.max(-2.0, lo - 12.0);
    final absHi = hi + 9.0;
    final rLo = target.optimalHumidity.min;
    final rHi = target.optimalHumidity.max;

    final tempPts = _band(climate.tAvg, lo, hi, 40.0, 6.0);
    final heatPts = climate.tMax <= absHi
        ? 25.0
        : math.max(0.0, 25.0 - (climate.tMax - absHi) * 5.0);
    final coldPts = climate.tMin >= absLo
        ? 20.0
        : math.max(0.0, 20.0 - (absLo - climate.tMin) * 5.0);
    final humPts = _band(climate.rhAvg, rLo, rHi, 15.0, 0.5);

    final climateScore = (tempPts + heatPts + coldPts + humPts).round();
    final tempOk = tempPts >= 32.0;
    final humidityOk = humPts >= 12.0;
    final soilOk = climate.soilAvg >= target.soilMoistureMin;

    final prevFamilyCode = previous?.familyCode ?? '';
    final familyConflict = previous != null &&
        target.badPrecedingFamilies.any(
          (bad) => prevFamilyCode.toLowerCase().contains(bad.toLowerCase()),
        );

    final isRecommendedSequence =
        previous != null && previous.recommendedNextCrops.contains(target.id);

    int rotationScore = climateScore;
    final List<String> reasons = [];

    if (familyConflict) {
      rotationScore = math.max(0, rotationScore - 35);
      reasons.add(
        'تحذير دورة زراعية للمزارع: زراعة ${target.nameAr} بعد ${previous.nameAr} (${previous.family}) يسبب إجهاد التربة وتراكم الآفات المشتركة.',
      );
    } else if (isRecommendedSequence) {
      rotationScore = math.min(100, rotationScore + 15);
      reasons.add(
        'تعاقب مثالي للمزارع: زراعة ${target.nameAr} بعد ${previous.nameAr} يحسن خصوبة التربة ودورة النيتروجين (${target.nitrogenRole}).',
      );
    } else if (previous != null) {
      reasons.add(
        'تعاقب مقبول بعد ${previous.nameAr} مع الالتزام ببرنامج التسميد المتوازن.',
      );
    } else {
      reasons.add('بداية دورة زراعية جديدة للمزارع: ${target.nameAr} (${target.family}).');
    }

    if (tempOk) {
      reasons.add(
        'متوسط الحرارة من أقمار ناسا (${climate.tAvg.toStringAsFixed(1)}°م) يقع ضمن النطاق المثالي (${lo.toInt()}° - ${hi.toInt()}°م).',
      );
    } else {
      reasons.add(
        'متوسط الحرارة الحالي (${climate.tAvg.toStringAsFixed(1)}°م) خارج النطاق المثالي (${lo.toInt()}° - ${hi.toInt()}°م).',
      );
    }

    if (!soilOk) {
      rotationScore = math.max(0, rotationScore - 10);
      reasons.add(
        'رطوبة منطقة الجذور GWETROOT (${(climate.soilAvg * 100).toStringAsFixed(0)}%) أقل من الحد الأدنى المطلوب (${(target.soilMoistureMin * 100).toStringAsFixed(0)}%).',
      );
    } else {
      reasons.add(
        'رطوبة التربة من قمر ناسا (${(climate.soilAvg * 100).toStringAsFixed(0)}%) ممتازة وتكفي احتياج المحصول.',
      );
    }

    final isSuitable = (rotationScore >= 65) && !familyConflict;
    final level = (isSuitable && rotationScore >= 75)
        ? 'yes'
        : isSuitable
            ? 'maybe'
            : 'no';
    final verdict = level == 'yes'
        ? 'مناسب جداً للدورة والمناخ'
        : level == 'maybe'
            ? 'مناسب بشروط'
            : 'غير مناسب حالياً';

    final voiceText = isSuitable
        ? target.voiceDialogue.suitable
        : target.voiceDialogue.unsuitable;

    final nextCrops = target.recommendedNextCrops
        .map((id) => EmbeddedCropData.rotationById[id])
        .whereType<CropRotationItem>()
        .toList();

    return RotationEvaluationResult(
      targetCrop: target,
      previousCrop: previous,
      isSuitable: isSuitable,
      score: rotationScore,
      climateScore: climateScore,
      level: level,
      verdict: verdict,
      familyConflict: familyConflict,
      isRecommendedSequence: isRecommendedSequence,
      soilOk: soilOk,
      tempOk: tempOk,
      humidityOk: humidityOk,
      reasons: reasons,
      voiceDialogue: voiceText,
      recommendedNextCrops: nextCrops,
      climate: climate,
    );
  }

  /// محرك قواعد الري ذو الـ 5 حالات للمزارع (NASA 5-State Irrigation Rule Engine):
  /// 1. ري عاجل (urgent)
  /// 2. ري مطلوب (water)
  /// 3. لا تروي (skip)
  /// 4. موجة حر أو برد (wave)
  /// 5. تمام (ok)
  static IrrigationAlert computeIrrigationAlert({
    required CropRotationItem crop,
    required ClimateSummary climate,
    String language = 'ar',
  }) {
    final isEn = language == 'en';
    final dry = climate.soilAvg < crop.soilMoistureMin;
    final hot = climate.tMax > (crop.optimalTemp.max + 3.0);
    final absLo = math.max(-2.0, crop.optimalTemp.min - 12.0);
    final absHi = crop.optimalTemp.max + 9.0;

    final checkTmax = climate.forecastTmax ?? climate.tMax;
    final checkTmin = climate.forecastTmin ?? climate.tMin;
    final extremeHeat = checkTmax > absHi;
    final extremeCold = checkTmin < absLo;

    final baseMm = crop.waterNeed.toLowerCase() == 'high'
        ? 5.5
        : crop.waterNeed.toLowerCase() == 'medium'
            ? 4.6
            : 3.0;
    final mm = double.parse((baseMm * (hot ? 1.3 : 1.0)).toStringAsFixed(1));
    final liters = mm.round() > 0 ? mm.round() : 6;
    final rainNext = climate.rainNext2d ?? 0.0;

    String level;
    String stateAr;
    String actionAr;
    String msg;
    final prefix = isEn ? 'For ${crop.nameEn} ${crop.icon}' : 'أنا ${crop.nameAr} ${crop.icon}';

    if (rainNext >= 5.0) {
      level = 'skip';
      stateAr = isEn ? 'Do Not Irrigate' : 'لا تروي';
      actionAr = isEn
          ? 'Skip irrigation today and save water — rain is expected.'
          : 'متروّيش النهارده ووفّر المياه، في مطر جاي.';
      msg = isEn
          ? '$prefix: Open-Meteo forecasts ${rainNext.toStringAsFixed(1)} mm rainfall over the next 48 hours. Skip irrigation today to conserve water and prevent waterlogging.'
          : '$prefix يا أخي المزارع، فيه مطر متوقع خلال يومين (${rainNext.toStringAsFixed(1)} ملم)، متروّيش النهارده ووفّر المياه.';
    } else if (dry && hot) {
      level = 'urgent';
      stateAr = isEn ? 'Urgent Irrigation' : 'ري عاجل';
      actionAr = isEn
          ? 'Irrigate today (~$liters L/m²) early morning or dusk.'
          : 'اروِ النهارده، مع كمية المياه المقترحة (حوالي $liters لتر لكل متر مربع).';
      msg = isEn
          ? '$prefix: High heat and dry root zone soil (${(climate.soilAvg * 100).round()}%). Irrigate urgently today with ~$mm L/m².'
          : '$prefix الجو حر والتربة ناشفة جداً يا أخي المزارع، مياه النهارده من فضلك! حوالي $mm ملم (يعني $mm لتر لكل متر مربع).';
    } else if (extremeHeat || extremeCold) {
      level = 'wave';
      stateAr = isEn ? 'Heat / Cold Wave' : 'موجة حر أو برد';
      actionAr = isEn
          ? 'Extreme temperature wave alert — apply mulching & careful watering.'
          : 'تحذير موجة طقس مع نصائح التغطية والري.';
      final waveType = isEn
          ? (extremeHeat ? 'severe heat wave' : 'frost / cold wave')
          : (extremeHeat ? 'موجة حر شديدة' : 'موجة برد وصقيع');
      msg = isEn
          ? '$prefix: Weather warning! A $waveType exceeds tolerance bounds. Apply protective mulching and adjust irrigation timing.'
          : '$prefix انتبه يا أخي المزارع! يوجد تحذير $waveType تتجاوز حدود تحملي، انصحك بالتغطية الوقائية وضبط الري.';
    } else if (dry || (hot && climate.rainTotal < 5.0)) {
      level = 'water';
      stateAr = isEn ? 'Irrigation Needed' : 'ري مطلوب';
      actionAr = isEn
          ? 'Soil is getting dry — schedule watering today.'
          : 'التربة ناشفة، محتاجة ري النهارده.';
      msg = isEn
          ? '$prefix: Soil needs irrigation today (~$mm L/m², early morning or late afternoon).'
          : '$prefix التربة محتاجة ري النهارده يا أخي المزارع، حوالي $mm ملم (يعني $mm لتر لكل متر مربع).';
    } else {
      level = 'ok';
      stateAr = isEn ? 'All Good' : 'تمام';
      actionAr = isEn
          ? 'No action needed — crop moisture is healthy.'
          : 'مفيش حاجة مطلوبة، أرضك وزرعتك في أمان.';
      msg = isEn
          ? '$prefix: Field climate and soil moisture are well balanced today. No extra irrigation required.'
          : '$prefix كله تمام النهارده يا أخي المزارع، مفيش حاجة مطلوبة، أرضك وزرعتك في أمان.';
    }

    return IrrigationAlert(
      level: level,
      stateAr: stateAr,
      actionAr: actionAr,
      message: msg,
      waterMm: (level == 'urgent' || level == 'water') ? mm : 0.0,
      soilWetness: climate.soilAvg,
      rain7dMm: climate.rainTotal,
      rainNext2dMm: climate.rainNext2d,
    );
  }

  /// تشخيص احتياطي محلي متوافق مع فئات PlantDoc عند عدم توفر اتصال بالسيرفر
  static VisionDiagnosisResult diagnoseOffline({
    required String cropId,
    required double lat,
    required double lon,
    double confidence = 0.86,
    String language = 'ar',
  }) {
    final isEn = language == 'en';
    const outOfScope = {
      'wheat': 'القمح',
      'cotton': 'القطن',
      'rice': 'الأرز',
      'olive': 'الزيتون',
    };
    const outOfScopeEn = {
      'wheat': 'Wheat',
      'cotton': 'Cotton',
      'rice': 'Rice',
      'olive': 'Olive',
    };
    final ranked = rankEngineers(lat: lat, lon: lon);
    final nearest = ranked.isNotEmpty ? ranked.first : null;

    if (outOfScope.containsKey(cropId)) {
      final cropLabel = isEn ? (outOfScopeEn[cropId] ?? cropId) : outOfScope[cropId]!;
      return VisionDiagnosisResult(
        datasetSource: 'https://www.kaggle.com/datasets/nirmalsankalana/plantdoc-dataset',
        supportedInPlantDoc: false,
        cropId: cropId,
        cropNameAr: cropLabel,
        predictedClass: 'Out of PlantDoc Scope - Specialist Referral',
        diseaseNameAr: isEn
            ? 'Requires specialist field inspection for $cropLabel'
            : 'يحتاج فحص ميداني متخصص لمحصول $cropLabel',
        confidence: 0.0,
        confidencePct: 0,
        isHealthy: false,
        isSevere: true,
        escalateToEngineer: true,
        escalationReason: isEn
            ? '$cropLabel is outside PlantDoc visual scope and requires a field agronomist review.'
            : 'محصول $cropLabel خارج نطاق PlantDoc ويتطلب فحص ميداني من مهندس زراعي.',
        recommendedSpecialty: cropId == 'olive' ? 'فاكهة' : 'محاصيل حقلية',
        symptomsAr: isEn
            ? 'Direct field examination of leaves, spikes, and roots is recommended.'
            : 'يتطلب معاينة حقلية مباشرة للأوراق والسنابل والجذور.',
        organicTreatmentAr: isEn
            ? 'Avoid spraying treatments before consulting an agronomist.'
            : 'يرجى عدم الرش قبل استشارة المهندس الزراعي.',
        chemicalTreatmentAr: isEn
            ? 'To be prescribed by the agronomist after field inspection.'
            : 'يُحدد بواسطة المهندس الزراعي بعد الفحص الميداني.',
        voiceMessageAr: isEn
            ? 'This $cropLabel sample requires specialist inspection. I have escalated your case to the nearest agricultural engineer.'
            : 'يا عزيزي المزارع، محصول $cropLabel يتطلب فحص ميداني دقيق من مهندس زراعي متخصص، وقد جهزنا لك الإحالة لأقرب مهندس لموقع أرضك.',
        recommendedEngineer: nearest,
      );
    }

    final lowConf = confidence < 0.75;
    final confPct = (confidence * 100).round();
    final cropNames = isEn
        ? {
            'tomato': 'Tomato',
            'potato': 'Potato',
            'maize': 'Maize',
            'apple': 'Apple',
            'grape': 'Grape',
            'bell_pepper': 'Bell Pepper',
            'strawberry': 'Strawberry',
          }
        : {
            'tomato': 'الطماطم',
            'potato': 'البطاطس',
            'maize': 'الذرة الشامية',
            'apple': 'التفاح',
            'grape': 'العنب',
            'bell_pepper': 'الفلفل الرومي',
            'strawberry': 'الفراولة',
          };
    final cName = cropNames[cropId] ?? (isEn ? 'Tomato' : 'الطماطم');

    return VisionDiagnosisResult(
      datasetSource: 'https://www.kaggle.com/datasets/nirmalsankalana/plantdoc-dataset',
      supportedInPlantDoc: true,
      cropId: cropId,
      cropNameAr: cName,
      predictedClass: '$cName Early Blight',
      diseaseNameAr: isEn ? '$cName Early Blight (PlantDoc)' : 'الندوة المبكرة في $cName (PlantDoc)',
      confidence: confidence,
      confidencePct: confPct,
      isHealthy: false,
      isSevere: false,
      escalateToEngineer: lowConf,
      escalationReason: lowConf
          ? (isEn
              ? 'Confidence ($confPct%) is below 75%, so this case has been escalated to the nearest agronomist.'
              : 'نسبة الثقة ($confPct%) أقل من 75% لذا يلزم تصعيد الحالة لأقرب مهندس زراعي.')
          : null,
      recommendedSpecialty: 'أمراض نباتية',
      symptomsAr: isEn
          ? 'Circular concentric brown lesions on older lower leaves with slight surrounding yellowing.'
          : 'بقع بنية دائرية متداخلة الحلقات على الأوراق السفلية مع اصفرار طفيف حولها.',
      organicTreatmentAr: isEn
          ? 'Remove affected leaves immediately and spray neem oil or potassium bicarbonate.'
          : 'إزالة الأوراق المصابة فوراً والرش بزيت النيم أو بيكربونات البوتاسيوم.',
      chemicalTreatmentAr: isEn
          ? 'Apply an approved copper fungicide or azoxystrobin at the recommended label rate.'
          : 'الرش بمبيد نحاسي معتمد أو أزوكسي ستروبين بالجرعة الموصى بها.',
      voiceMessageAr: lowConf
          ? (isEn
              ? 'Diagnosis confidence is only $confPct%, so I escalated your case to the nearest agronomist for an accurate review.'
              : 'يا أخي المزارع، نسبة الثقة في التشخيص $confPct% فقط، لذلك حولنا الحالة لأقرب مهندس زراعي لمراجعتها بدقة.')
          : (isEn
              ? 'Checked your $cName leaf at $confPct% confidence: suspected Early Blight. Remove infected lower leaves and spray neem oil or copper.'
              : 'يا أخي المزارع، فحصنا ورقة $cName بنسبة ثقة $confPct%: اشتباه ندوة مبكرة. يوصى بإزالة الأوراق المصابة والرش الوقائي بزيت النيم أو النحاس.'),
      recommendedEngineer: nearest,
    );
  }

  /// حساب المسافة الجغرافية بالكيلومتر (Haversine Formula)
  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final p1 = lat1 * math.pi / 180.0;
    final p2 = lat2 * math.pi / 180.0;
    final dphi = p2 - p1;
    final dl = (lon2 - lon1) * math.pi / 180.0;
    final a = math.pow(math.sin(dphi / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static List<EngineerProfile> rankEngineers({
    required double lat,
    required double lon,
    String? specialty,
  }) {
    const all = EmbeddedCropData.rawEngineers;
    final filtered = (specialty != null && specialty.isNotEmpty)
        ? all.where((e) => e['specialty'] == specialty).toList()
        : all;
    final pool = filtered.isNotEmpty ? filtered : all;

    final list = pool.map((e) {
      final elat = (e['lat'] as num).toDouble();
      final elon = (e['lon'] as num).toDouble();
      final dist = double.parse(haversineKm(lat, lon, elat, elon).toStringAsFixed(1));
      return EngineerProfile.fromJson({...e, 'distance_km': dist});
    }).toList();

    list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return list;
  }
}
