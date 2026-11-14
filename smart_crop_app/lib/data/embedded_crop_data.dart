import '../models/crop_models.dart';

/// البيانات المعتمدة لـ Terra Space 🛰️🌱
/// - بيانات الدورة الزراعية (NASA Space Apps)
/// - محاصيل فحص الأمراض (Kaggle PlantDoc Dataset & خارج النطاق)
/// - قاعدة المهندسين الزراعيين في محافظات مصر
class EmbeddedCropData {
  static const List<Map<String, dynamic>> rawRotationCrops = [
    {
      "id": "wheat",
      "name_ar": "القمح",
      "name_en": "Wheat",
      "icon": "🌾",
      "family": "Poaceae (نجيليات)",
      "season": "Winter",
      "water_need": "Medium",
      "nitrogen_role": "Heavy Consumer",
      "optimal_temp": {"min": 15.0, "max": 25.0},
      "optimal_humidity": {"min": 40.0, "max": 70.0},
      "soil_moisture_min": 0.20,
      "bad_preceding_families": ["Poaceae"],
      "recommended_next_crops": ["faba_bean", "clover"],
      "voice_dialogue": {
        "suitable":
            "أهلاً بك يا عزيزي المزارع في تيرا سبيس! أنا القمح، جو أرضك ممتاز ورطوبة التربة ممتازة بحسب أقمار ناسا الصناعية. يلا جهز أرضك وتوكل على الله!",
        "unsuitable":
            "يا عزيزي المزارع الجو عندك حر والتربة مجهدة من زراعة النجيليات ورا بعض، محتاج نريح الأرض بمحصول بقولي الأول."
      }
    },
    {
      "id": "faba_bean",
      "name_ar": "الفول البلدي",
      "name_en": "Faba Bean",
      "icon": "🌱",
      "family": "Fabaceae (بقوليات)",
      "season": "Winter",
      "water_need": "Low-Medium",
      "nitrogen_role": "Nitrogen Fixer (مُثبت للنيتروجين)",
      "optimal_temp": {"min": 14.0, "max": 24.0},
      "optimal_humidity": {"min": 45.0, "max": 75.0},
      "soil_moisture_min": 0.18,
      "bad_preceding_families": ["Fabaceae"],
      "recommended_next_crops": ["maize", "tomato"],
      "voice_dialogue": {
        "suitable":
            "أهلاً يا أخي المزارع، أنا الفول البلدي! هغذي تربتك بالنيتروجين الطبيعي وأصلح اللي استنزفه المحصول اللي فات، وترشيد مية ممتاز!",
        "unsuitable":
            "يا عزيزي المزارع التربة رطبة زيادة عن اللزوم ومكتومة، محتاجين تصريف كويس للمية قبل ما تحط البذور."
      }
    },
    {
      "id": "maize",
      "name_ar": "الذرة الشامية",
      "name_en": "Maize",
      "icon": "🌽",
      "family": "Poaceae (نجيليات)",
      "season": "Summer",
      "water_need": "High",
      "nitrogen_role": "Heavy Consumer",
      "optimal_temp": {"min": 22.0, "max": 33.0},
      "optimal_humidity": {"min": 50.0, "max": 80.0},
      "soil_moisture_min": 0.22,
      "bad_preceding_families": ["Poaceae"],
      "recommended_next_crops": ["clover", "faba_bean"],
      "voice_dialogue": {
        "suitable":
            "أهلاً يا أخي المزارع، أنا عود الذرة البطل! بحب شمس أرضك ودفاها، بس خد بالك هحتاج ري منتظم عشان أطلع كيزان مليانة.",
        "unsuitable":
            "يا عزيزي المزارع الجو لسه برد والتربة مش دافية، استنى لما الصيف يدخل عشان البذور متعفنش."
      }
    },
    {
      "id": "tomato",
      "name_ar": "الطماطم",
      "name_en": "Tomato",
      "icon": "🍅",
      "family": "Solanaceae (باذنجانيات)",
      "season": "Fall/Spring",
      "water_need": "High",
      "nitrogen_role": "Heavy Feeder",
      "optimal_temp": {"min": 18.0, "max": 29.0},
      "optimal_humidity": {"min": 55.0, "max": 80.0},
      "soil_moisture_min": 0.25,
      "bad_preceding_families": ["Solanaceae"],
      "recommended_next_crops": ["maize", "faba_bean"],
      "voice_dialogue": {
        "suitable":
            "يا مرحب بك يا أخي المزارع! أنا حبة الطماطم، الحرارة ورطوبة أرضك ممتازة، ازرعني وتابع معايا الري أول بأول بالأقمار الصناعية!",
        "unsuitable":
            "يا عزيزي المزارع الأرض دي كان مزروع فيها باذنجانيات قريبة مني، في خطر فطريات وآفات مشتركة، بلاش تغامر!"
      }
    },
    {
      "id": "clover",
      "name_ar": "البرسيم",
      "name_en": "Clover",
      "icon": "☘️",
      "family": "Fabaceae (بقوليات)",
      "season": "Winter",
      "water_need": "Medium",
      "nitrogen_role": "Super Nitrogen Restorer",
      "optimal_temp": {"min": 12.0, "max": 22.0},
      "optimal_humidity": {"min": 50.0, "max": 80.0},
      "soil_moisture_min": 0.20,
      "bad_preceding_families": ["Fabaceae"],
      "recommended_next_crops": ["wheat", "maize"],
      "voice_dialogue": {
        "suitable":
            "أهلاً بك يا أخي المزارع، أنا البرسيم رفيق الأرض ومجدد نشاطها! هخلي تربتك غنية وخضرا وجاهزة لأي محصول بعدي.",
        "unsuitable": "يا عزيزي المزارع الحرارة عالية زيادة، أنا محتاج جو خريفي وشتوي لطيف."
      }
    }
  ];

  static final List<CropRotationItem> rotationCrops =
      rawRotationCrops.map((e) => CropRotationItem.fromJson(e)).toList();

  static final Map<String, CropRotationItem> rotationById = {
    for (final c in rotationCrops) c.id: c
  };

  /// محاصيل إضافية متاحة للمزارع + أي محصول جديد يقوله للإيجينت يتضاف تلقائياً هنا
  static final List<CropRotationItem> extraFarmerCrops = [
    const CropRotationItem(
      id: 'potato',
      nameAr: 'البطاطس',
      nameEn: 'Potato',
      icon: '🥔',
      family: 'Solanaceae (باذنجانيات)',
      season: 'Winter/Spring',
      waterNeed: 'Medium',
      nitrogenRole: 'Heavy Feeder',
      optimalTemp: RangeBounds(min: 15.0, max: 24.0),
      optimalHumidity: RangeBounds(min: 55.0, max: 80.0),
      soilMoistureMin: 0.25,
      badPrecedingFamilies: ['Solanaceae'],
      recommendedNextCrops: ['clover', 'faba_bean'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً يا أخي المزارع، أنا البطاطس ومناخ أرضك مناسب جداً ليا!',
        unsuitable: 'يا عزيزي المزارع الجو حر زيادة عن اللزوم، استنى لما الجو يعتدل.',
      ),
    ),
    const CropRotationItem(
      id: 'orange',
      nameAr: 'البرتقال',
      nameEn: 'Orange',
      icon: '🍊',
      family: 'Rutaceae (موالح)',
      season: 'All Year',
      waterNeed: 'Medium',
      nitrogenRole: 'Moderate Feeder',
      optimalTemp: RangeBounds(min: 16.0, max: 30.0),
      optimalHumidity: RangeBounds(min: 45.0, max: 75.0),
      soilMoistureMin: 0.22,
      badPrecedingFamilies: [],
      recommendedNextCrops: ['clover', 'faba_bean'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً بك يا أخي المزارع، أنا شجرة البرتقال، جو أرضك ممتاز للتزهير والعقد!',
        unsuitable: 'يا عزيزي المزارع خلي بالك من موجات الحر والعطش وقت التزهير.',
      ),
    ),
    const CropRotationItem(
      id: 'grape',
      nameAr: 'العنب',
      nameEn: 'Grape',
      icon: '🍇',
      family: 'Vitaceae (عنبيات)',
      season: 'Spring/Summer',
      waterNeed: 'Medium',
      nitrogenRole: 'Moderate Feeder',
      optimalTemp: RangeBounds(min: 18.0, max: 32.0),
      optimalHumidity: RangeBounds(min: 40.0, max: 70.0),
      soilMoistureMin: 0.20,
      badPrecedingFamilies: [],
      recommendedNextCrops: ['clover', 'faba_bean'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً يا أخي المزارع، أنا العنب! جو أرضك دافي وممتاز لنمو العناقيد.',
        unsuitable: 'يا عزيزي المزارع خلي بالك من الرطوبة العالية عشان البياض الدقيقي.',
      ),
    ),
    const CropRotationItem(
      id: 'rice',
      nameAr: 'الأرز',
      nameEn: 'Rice',
      icon: '🍚',
      family: 'Poaceae (نجيليات)',
      season: 'Summer',
      waterNeed: 'High',
      nitrogenRole: 'Heavy Consumer',
      optimalTemp: RangeBounds(min: 22.0, max: 34.0),
      optimalHumidity: RangeBounds(min: 60.0, max: 85.0),
      soilMoistureMin: 0.40,
      badPrecedingFamilies: ['Poaceae'],
      recommendedNextCrops: ['clover', 'faba_bean'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً يا أخي المزارع، أنا الأرز! بحب الدفا والمية الوفيرة في أرضك.',
        unsuitable: 'يا عزيزي المزارع أنا محتاج مية متوفرة وجو صيفي دافي.',
      ),
    ),
    const CropRotationItem(
      id: 'cotton',
      nameAr: 'القطن',
      nameEn: 'Cotton',
      icon: '☁️',
      family: 'Malvaceae (خبازيات)',
      season: 'Summer',
      waterNeed: 'Medium',
      nitrogenRole: 'Heavy Consumer',
      optimalTemp: RangeBounds(min: 22.0, max: 35.0),
      optimalHumidity: RangeBounds(min: 40.0, max: 70.0),
      soilMoistureMin: 0.22,
      badPrecedingFamilies: [],
      recommendedNextCrops: ['wheat', 'clover'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً يا أخي المزارع، أنا القطن المصري الذهب الأبيض! شمس أرضك ممتازة ليا.',
        unsuitable: 'يا عزيزي المزارع الجو بارد عليا دلوقتي، ميعادي في الربيع والصيف.',
      ),
    ),
    const CropRotationItem(
      id: 'onion',
      nameAr: 'البصل',
      nameEn: 'Onion',
      icon: '🧅',
      family: 'Amaryllidaceae (نرجسيات)',
      season: 'Winter',
      waterNeed: 'Medium',
      nitrogenRole: 'Moderate Feeder',
      optimalTemp: RangeBounds(min: 13.0, max: 26.0),
      optimalHumidity: RangeBounds(min: 45.0, max: 70.0),
      soilMoistureMin: 0.22,
      badPrecedingFamilies: [],
      recommendedNextCrops: ['maize', 'clover'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً يا أخي المزارع، أنا البصل! جو أرضك المعتدل ممتاز لتكوين الرؤوس.',
        unsuitable: 'يا عزيزي المزارع خلي بالك من زيادة الرطوبة عشان عفن الجذور.',
      ),
    ),
    const CropRotationItem(
      id: 'mango',
      nameAr: 'المانجو',
      nameEn: 'Mango',
      icon: '🥭',
      family: 'Anacardiaceae (مانجو)',
      season: 'Summer',
      waterNeed: 'Medium',
      nitrogenRole: 'Moderate Feeder',
      optimalTemp: RangeBounds(min: 20.0, max: 36.0),
      optimalHumidity: RangeBounds(min: 40.0, max: 70.0),
      soilMoistureMin: 0.20,
      badPrecedingFamilies: [],
      recommendedNextCrops: ['clover', 'faba_bean'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً يا أخي المزارع، أنا المانجو! الدفا والشمس عندك ممتازين للتزهير والعقد.',
        unsuitable: 'يا عزيزي المزارع احميني من الصقيع والرياح السخنة وقت التزهير.',
      ),
    ),
    const CropRotationItem(
      id: 'strawberry',
      nameAr: 'الفراولة',
      nameEn: 'Strawberry',
      icon: '🍓',
      family: 'Rosaceae (ورديات)',
      season: 'Winter/Spring',
      waterNeed: 'Medium',
      nitrogenRole: 'Moderate Feeder',
      optimalTemp: RangeBounds(min: 14.0, max: 25.0),
      optimalHumidity: RangeBounds(min: 50.0, max: 75.0),
      soilMoistureMin: 0.25,
      badPrecedingFamilies: [],
      recommendedNextCrops: ['clover', 'faba_bean'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً يا أخي المزارع، أنا الفراولة! جوك المعتدل هيطلع أحلى ثمار.',
        unsuitable: 'يا عزيزي المزارع أنا حساسة للملوحة والحر الشديد، اظبط الري بالتنقيط.',
      ),
    ),
  ];

  static List<CropRotationItem> get allFarmerCrops => [
        ...rotationCrops,
        ...extraFarmerCrops,
      ];

  static CropRotationItem ensureCropRegistered({
    required String cropId,
    String? nameAr,
    String? nameEn,
    String? icon,
  }) {
    if (rotationById.containsKey(cropId)) {
      return rotationById[cropId]!;
    }
    final existingIdx = extraFarmerCrops.indexWhere((c) => c.id == cropId);
    if (existingIdx != -1) {
      return extraFarmerCrops[existingIdx];
    }
    final fallback = cropId.replaceAll('custom_', '').replaceAll('_', ' ');
    final labelAr = (nameAr != null && nameAr.trim().isNotEmpty)
        ? nameAr.trim()
        : fallback;
    final labelEn = (nameEn != null && nameEn.trim().isNotEmpty)
        ? nameEn.trim()
        : labelAr;
    final newCrop = CropRotationItem(
      id: cropId,
      nameAr: labelAr,
      nameEn: labelEn,
      icon: (icon != null && icon.trim().isNotEmpty) ? icon.trim() : '🌱',
      family: 'محصول مضاف للمزارع',
      season: 'All',
      waterNeed: 'Medium',
      nitrogenRole: 'Moderate Feeder',
      optimalTemp: const RangeBounds(min: 16.0, max: 30.0),
      optimalHumidity: const RangeBounds(min: 40.0, max: 75.0),
      soilMoistureMin: 0.22,
      badPrecedingFamilies: const [],
      recommendedNextCrops: const ['clover', 'faba_bean'],
      voiceDialogue: VoiceDialogue(
        suitable: 'أهلاً بك يا أخي المزارع! أنا محصول $labelAr، تم إضافتي لقائمة محاصيل أرضك.',
        unsuitable: 'يا عزيزي المزارع تابع حالة الري والحرارة لمحصول $labelAr من قمر ناسا.',
      ),
    );
    extraFarmerCrops.insert(0, newCrop);
    rotationById[cropId] = newCrop;
    return newCrop;
  }

  /// محاصيل فحص الأمراض (PlantDoc + محاصيل تحتاج إحالة مهندس)
  static const List<Map<String, String>> visionCrops = [
    {"id": "tomato", "name_ar": "الطماطم (PlantDoc)", "name_en": "Tomato (PlantDoc AI)", "icon": "🍅"},
    {"id": "potato", "name_ar": "البطاطس (PlantDoc)", "name_en": "Potato (PlantDoc AI)", "icon": "🥔"},
    {"id": "maize", "name_ar": "الذرة الشامية (PlantDoc)", "name_en": "Maize / Corn (PlantDoc AI)", "icon": "🌽"},
    {"id": "apple", "name_ar": "التفاح (PlantDoc)", "name_en": "Apple (PlantDoc AI)", "icon": "🍎"},
    {"id": "grape", "name_ar": "العنب (PlantDoc)", "name_en": "Grape (PlantDoc AI)", "icon": "🍇"},
    {"id": "bell_pepper", "name_ar": "الفلفل الرومي (PlantDoc)", "name_en": "Bell Pepper (PlantDoc AI)", "icon": "🫑"},
    {"id": "strawberry", "name_ar": "الفراولة (PlantDoc)", "name_en": "Strawberry (PlantDoc AI)", "icon": "🍓"},
    {"id": "wheat", "name_ar": "القمح (فحص متخصص)", "name_en": "Wheat (Specialist Review)", "icon": "🌾"},
    {"id": "cotton", "name_ar": "القطن (فحص متخصص)", "name_en": "Cotton (Specialist Review)", "icon": "☁️"},
    {"id": "rice", "name_ar": "الأرز (فحص متخصص)", "name_en": "Rice (Specialist Review)", "icon": "🍚"},
    {"id": "olive", "name_ar": "الزيتون (فحص متخصص)", "name_en": "Olive (Specialist Review)", "icon": "🫒"},
  ];

  static const List<Map<String, dynamic>> egyptLocations = [
    {"name": "القاهرة / الدلتا الجنوبية", "name_en": "Cairo / South Delta, Egypt", "lat": 30.0444, "lon": 31.2357},
    {"name": "المنصورة - الدقهلية", "name_en": "Mansoura - Dakahlia, Egypt", "lat": 31.0409, "lon": 31.3785},
    {"name": "طنطا - الغربية", "name_en": "Tanta - Gharbia, Egypt", "lat": 30.7865, "lon": 31.0004},
    {"name": "دمنهور - البحيرة", "name_en": "Damanhour - Beheira, Egypt", "lat": 31.0341, "lon": 30.4682},
    {"name": "النوبارية الجديدة", "name_en": "New Nubaria, Egypt", "lat": 30.8700, "lon": 29.9500},
    {"name": "الزقازيق - الشرقية", "name_en": "Zagazig - Sharqia, Egypt", "lat": 30.5877, "lon": 31.5020},
    {"name": "الفيوم", "name_en": "Fayoum, Egypt", "lat": 29.3084, "lon": 30.8428},
    {"name": "المنيا - الصعيد الأوسط", "name_en": "Minya - Middle Egypt", "lat": 28.1099, "lon": 30.7503},
    {"name": "أسيوط", "name_en": "Asyut, Egypt", "lat": 27.1783, "lon": 31.1859},
    {"name": "الأقصر", "name_en": "Luxor, Egypt", "lat": 25.6872, "lon": 32.6396},
    {"name": "أسوان", "name_en": "Aswan, Egypt", "lat": 24.0889, "lon": 32.8998},
    {"name": "كاليفورنيا - أمريكا", "name_en": "California - Central Valley, USA", "lat": 36.7378, "lon": -119.7871},
    {"name": "ألميريا - إسبانيا", "name_en": "Almeria - Andalusia, Spain", "lat": 36.8340, "lon": -2.4637},
    {"name": "الخرج - الرياض، السعودية", "name_en": "Al-Kharj - Riyadh, Saudi Arabia", "lat": 24.1554, "lon": 47.3345},
    {"name": "البنجاب - الهند", "name_en": "Punjab - Ludhiana, India", "lat": 30.9010, "lon": 75.8573},
    {"name": "ريفت فالي - كينيا", "name_en": "Rift Valley - Nakuru, Kenya", "lat": -0.3031, "lon": 36.0800},
  ];

  static const List<Map<String, dynamic>> rawEngineers = [
    {"id": 1, "name": "م. أحمد سعيد", "phone": "01000000001", "lat": 30.0444, "lon": 31.2357, "specialty": "محاصيل حقلية", "governorate": "القاهرة", "years_of_exp": 9},
    {"id": 2, "name": "م. منى عبد الله", "phone": "01000000002", "lat": 30.0131, "lon": 31.2089, "specialty": "خضروات", "governorate": "الجيزة", "years_of_exp": 7},
    {"id": 3, "name": "م. محمود فاروق", "phone": "01000000003", "lat": 31.2001, "lon": 29.9187, "specialty": "فاكهة", "governorate": "الإسكندرية", "years_of_exp": 11},
    {"id": 4, "name": "م. هبة السيد", "phone": "01000000004", "lat": 31.0341, "lon": 30.4682, "specialty": "ري وتربة", "governorate": "البحيرة", "years_of_exp": 8},
    {"id": 5, "name": "م. كريم حسن", "phone": "01000000005", "lat": 30.8700, "lon": 29.9500, "specialty": "فاكهة", "governorate": "النوبارية", "years_of_exp": 10},
    {"id": 6, "name": "م. سارة إبراهيم", "phone": "01000000006", "lat": 30.7865, "lon": 31.0004, "specialty": "محاصيل حقلية", "governorate": "الغربية", "years_of_exp": 6},
    {"id": 7, "name": "م. عمر يوسف", "phone": "01000000007", "lat": 31.0409, "lon": 31.3785, "specialty": "أمراض نباتية", "governorate": "الدقهلية", "years_of_exp": 12},
    {"id": 8, "name": "م. نورهان مصطفى", "phone": "01000000008", "lat": 30.5877, "lon": 31.5020, "specialty": "خضروات", "governorate": "الشرقية", "years_of_exp": 7},
    {"id": 9, "name": "م. طارق عادل", "phone": "01000000009", "lat": 29.3084, "lon": 30.8428, "specialty": "ري وتربة", "governorate": "الفيوم", "years_of_exp": 13},
    {"id": 10, "name": "م. دعاء رمضان", "phone": "01000000010", "lat": 28.1099, "lon": 30.7503, "specialty": "محاصيل حقلية", "governorate": "المنيا", "years_of_exp": 8},
    {"id": 11, "name": "م. إسلام جمال", "phone": "01000000011", "lat": 27.1783, "lon": 31.1859, "specialty": "فاكهة", "governorate": "أسيوط", "years_of_exp": 9},
    {"id": 12, "name": "م. آية محمد", "phone": "01000000012", "lat": 26.5591, "lon": 31.6957, "specialty": "أمراض نباتية", "governorate": "سوهاج", "years_of_exp": 10},
    {"id": 13, "name": "م. ياسر عبد الرحمن", "phone": "01000000013", "lat": 25.6872, "lon": 32.6396, "specialty": "محاصيل حقلية", "governorate": "الأقصر", "years_of_exp": 14},
    {"id": 14, "name": "م. ريم خالد", "phone": "01000000014", "lat": 24.0889, "lon": 32.8998, "specialty": "ري وتربة", "governorate": "أسوان", "years_of_exp": 7},
    {"id": 15, "name": "م. بلال شريف", "phone": "01000000015", "lat": 30.5965, "lon": 32.2715, "specialty": "خضروات", "governorate": "الإسماعيلية", "years_of_exp": 9}
  ];
}
