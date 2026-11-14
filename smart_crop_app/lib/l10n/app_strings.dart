import 'package:flutter/material.dart';
import '../models/crop_models.dart';

/// شارة شعار Terra Space الرسمية
class TerraLogoBadge extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showBorder;

  const TerraLogoBadge({
    super.key,
    this.size = 40,
    this.borderRadius = 10,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0E5B1C),
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.4)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/terra_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.satellite_alt_rounded,
            color: Colors.amberAccent,
            size: size * 0.58,
          ),
        ),
      ),
    );
  }
}

/// زر تبديل اللغة الكامل للتطبيق (عربي محلي 🇪🇬 / إنجليزي عالمي 🌐)
class AppLanguageToggle extends StatelessWidget {
  final bool isEn;
  final ValueChanged<String> onChanged;
  final bool compact;
  final bool darkBackground;

  const AppLanguageToggle({
    super.key,
    required this.isEn,
    required this.onChanged,
    this.compact = false,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = darkBackground
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFE8F5E9);
    final borderColor = darkBackground
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF1B5E20).withValues(alpha: 0.35);
    final inactiveTextColor = darkBackground ? Colors.white : const Color(0xFF1B5E20);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangPillOption(
            label: compact ? '🇪🇬 عربي' : '🇪🇬 عربي (محلي)',
            selected: !isEn,
            selectedColor: darkBackground ? Colors.white : const Color(0xFF1B5E20),
            selectedTextColor: darkBackground ? const Color(0xFF1B5E20) : Colors.white,
            unselectedTextColor: inactiveTextColor,
            compact: compact,
            onTap: () => onChanged('ar'),
          ),
          _LangPillOption(
            label: compact ? '🌐 EN' : '🌐 English (Global)',
            selected: isEn,
            selectedColor: darkBackground ? Colors.amberAccent : const Color(0xFF0D47A1),
            selectedTextColor: darkBackground ? const Color(0xFF0E3E12) : Colors.white,
            unselectedTextColor: inactiveTextColor,
            compact: compact,
            onTap: () => onChanged('en'),
          ),
        ],
      ),
    );
  }
}

class _LangPillOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final bool compact;
  final VoidCallback onTap;

  const _LangPillOption({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 11,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.bold,
            color: selected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}

/// قاموس الترجمة المزدوج (عربي / English) لدعم النمط المحلي والعالمي في Terra Space
class AppStrings {
  final bool isEn;

  const AppStrings(this.isEn);

  String t(String ar, String en) => isEn ? en : ar;

  String cropName(CropRotationItem crop) => isEn ? crop.nameEn : crop.nameAr;

  String cropFamily(CropRotationItem crop) {
    if (!isEn) return crop.family;
    final enPart = crop.family.split('(').first.trim();
    return enPart.isEmpty ? 'Custom Crop' : enPart;
  }

  static const Map<String, String> _specialtyEnMap = {
    'الكل': 'All',
    'أمراض نباتية': 'Plant Pathology',
    'محاصيل حقلية': 'Field Crops',
    'خضروات': 'Vegetables',
    'فاكهة': 'Fruits & Orchards',
    'ري وتربة': 'Irrigation & Soil',
  };

  String specialty(String raw) {
    if (!isEn) return raw;
    return _specialtyEnMap[raw] ?? raw;
  }

  static const Map<String, String> _locationEnMap = {
    'القاهرة': 'Cairo (Egypt)',
    'القاهرة / الدلتا الجنوبية': 'Cairo / South Delta, Egypt',
    'الجيزة': 'Giza, Egypt',
    'المنوفية': 'Monufia, Egypt',
    'الغربية': 'Gharbia, Egypt',
    'الدقهلية': 'Dakahlia, Egypt',
    'كفر الشيخ': 'Kafr El-Sheikh, Egypt',
    'الشرقية': 'Sharqia, Egypt',
    'البحيرة': 'Beheira, Egypt',
    'القليوبية': 'Qalyubia, Egypt',
    'المنصورة - الدقهلية': 'Mansoura - Dakahlia, Egypt',
    'طنطا - الغربية': 'Tanta - Gharbia, Egypt',
    'دمنهور - البحيرة': 'Damanhour - Beheira, Egypt',
    'النوبارية الجديدة': 'New Nubaria, Egypt',
    'النوبارية': 'Nubaria, Egypt',
    'الزقازيق - الشرقية': 'Zagazig - Sharqia, Egypt',
    'الفيوم': 'Fayoum, Egypt',
    'بني سويف': 'Beni Suef, Egypt',
    'المنيا': 'Minya, Egypt',
    'المنيا - الصعيد الأوسط': 'Minya - Middle Egypt',
    'أسيوط': 'Asyut, Egypt',
    'سوهاج': 'Sohag, Egypt',
    'قنا': 'Qena, Egypt',
    'الأقصر': 'Luxor, Egypt',
    'أسوان': 'Aswan, Egypt',
    'الإسماعيلية': 'Ismailia, Egypt',
    'الإسكندرية': 'Alexandria, Egypt',
    'كاليفورنيا - أمريكا': 'California - Central Valley, USA',
    'ألميريا - إسبانيا': 'Almeria - Andalusia, Spain',
    'الخرج - الرياض، السعودية': 'Al-Kharj - Riyadh, Saudi Arabia',
    'البنجاب - الهند': 'Punjab - Ludhiana, India',
    'ريفت فالي - كينيا': 'Rift Valley - Nakuru, Kenya',
    'ساو باولو - البرازيل': 'Sao Paulo - Brazil',
  };

  String locationName(String raw) {
    if (!isEn) return raw;
    return _locationEnMap[raw] ?? raw;
  }

  static const Map<String, String> _engineerEnMap = {
    'م. أحمد سعيد': 'Eng. Ahmed Saeed',
    'م. منى عبد الله': 'Eng. Mona Abdullah',
    'م. محمود فاروق': 'Eng. Mahmoud Farouk',
    'م. هبة السيد': 'Eng. Heba El-Sayed',
    'م. كريم حسن': 'Eng. Karim Hassan',
    'م. سارة إبراهيم': 'Eng. Sara Ibrahim',
    'م. عمر يوسف': 'Eng. Omar Youssef',
    'م. نورهان مصطفى': 'Eng. Nourhan Mostafa',
    'م. طارق عادل': 'Eng. Tarek Adel',
    'م. دعاء رمضان': 'Eng. Doaa Ramadan',
    'م. إسلام جمال': 'Eng. Islam Gamal',
    'م. آية محمد': 'Eng. Aya Mohamed',
    'م. ياسر عبد الرحمن': 'Eng. Yasser Abdelrahman',
    'م. ريم خالد': 'Eng. Reem Khaled',
    'م. بلال شريف': 'Eng. Belal Sherif',
  };

  String engineerName(String raw) {
    if (!isEn) return raw;
    return _engineerEnMap[raw] ?? raw;
  }

  String irrigationState(IrrigationAlert alert) {
    if (!isEn) return alert.stateAr;
    switch (alert.level) {
      case 'skip':
        return 'Do Not Irrigate';
      case 'urgent':
        return 'Urgent Irrigation';
      case 'wave':
        return 'Heat / Cold Wave';
      case 'water':
        return 'Irrigation Needed';
      default:
        return 'All Good';
    }
  }

  String irrigationAction(IrrigationAlert alert) {
    if (!isEn) return alert.actionAr;
    final liters = alert.waterMm > 0 ? alert.waterMm.round() : 5;
    switch (alert.level) {
      case 'skip':
        return 'Skip watering today and save water — rain is forecasted.';
      case 'urgent':
        return 'Irrigate today (~$liters L/m²) before peak heat.';
      case 'wave':
        return 'Weather wave alert — apply mulching & protective irrigation.';
      case 'water':
        return 'Soil is dry; schedule watering today (~${alert.waterMm.toStringAsFixed(1)} L/m²).';
      default:
        return 'No irrigation needed today — field moisture is balanced.';
    }
  }

  String consultationStatus(ConsultationRequest req) {
    if (!isEn) return req.statusAr;
    switch (req.status) {
      case 'accepted':
        return 'Accepted ✅';
      case 'rejected':
        return 'Declined ❌';
      case 'done':
        return 'Advice Sent 🌟';
      default:
        return 'Pending ⏳';
    }
  }

  String visionCropTitle(Map<String, String> cropMap) {
    if (!isEn) return '${cropMap['icon']} ${cropMap['name_ar']}';
    return '${cropMap['icon']} ${cropMap['name_en'] ?? cropMap['name_ar']}';
  }
}

