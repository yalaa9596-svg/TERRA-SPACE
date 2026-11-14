import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../providers/terra_provider.dart';
import '../services/location_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // 'farmer' or 'engineer'
  String _selectedRole = 'farmer';

  // Farmer fields
  final _farmerPhoneCtrl = TextEditingController();
  final _farmerOtpCtrl = TextEditingController();
  final _farmerNameCtrl = TextEditingController();
  bool _otpSent = false;
  bool _existingFarmer = false;
  String? _demoOtpCode;
  String? _whatsappMsg;
  double _farmerLat = 30.5972;
  double _farmerLon = 30.9876;
  String _farmerGov = 'المنوفية';

  // Engineer fields
  bool _engineerIsRegistering = false;
  final _engPhoneCtrl = TextEditingController();
  final _engPasswordCtrl = TextEditingController();
  final _engNameCtrl = TextEditingController();
  final _engExpCtrl = TextEditingController(text: '7');
  String _engSpecialty = 'أمراض نباتية';
  String _engGov = 'المنوفية';
  double _engLat = 30.5972;
  double _engLon = 30.9876;

  bool _loading = false;
  String? _errorMsg;

  static const Map<String, List<double>> _locationsMap = {
    'القاهرة': [30.0444, 31.2357],
    'الجيزة': [30.0131, 31.2089],
    'المنوفية': [30.5972, 30.9876],
    'الغربية': [30.7865, 31.0004],
    'الدقهلية': [31.0409, 31.3785],
    'كفر الشيخ': [31.1107, 30.9388],
    'الشرقية': [30.5877, 31.5020],
    'البحيرة': [31.0364, 30.4682],
    'القليوبية': [30.4660, 31.1848],
    'الفيوم': [29.3084, 30.8428],
    'بني سويف': [29.0661, 31.0994],
    'المنيا': [28.1099, 30.7503],
    'أسيوط': [27.1783, 31.1859],
    'سوهاج': [26.5591, 31.6957],
    'قنا': [26.1551, 32.7160],
    'الأقصر': [25.6872, 32.6396],
    'أسوان': [24.0889, 32.8998],
    'الإسماعيلية': [30.5965, 32.2715],
    'كاليفورنيا - أمريكا': [36.7378, -119.7871],
    'ألميريا - إسبانيا': [36.8340, -2.4637],
    'الخرج - الرياض، السعودية': [24.1554, 47.3345],
    'البنجاب - الهند': [30.9010, 75.8573],
    'ريفت فالي - كينيا': [-0.3031, 36.0800],
  };

  static const List<String> _specialties = [
    'أمراض نباتية',
    'محاصيل حقلية',
    'خضروات',
    'فاكهة',
    'ري وتربة',
  ];

  @override
  void dispose() {
    _farmerPhoneCtrl.dispose();
    _farmerOtpCtrl.dispose();
    _farmerNameCtrl.dispose();
    _engPhoneCtrl.dispose();
    _engPasswordCtrl.dispose();
    _engNameCtrl.dispose();
    _engExpCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectGps({required bool isFarmer, required AppStrings s}) async {
    setState(() => _loading = true);
    final pt = await LocationService.detectFarmerLocation(
      fallbackLat: isFarmer ? _farmerLat : _engLat,
      fallbackLon: isFarmer ? _farmerLon : _engLon,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (isFarmer) {
        _farmerLat = pt.lat;
        _farmerLon = pt.lon;
      } else {
        _engLat = pt.lat;
        _engLon = pt.lon;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            '📍 تم تحديث موقعك الجغرافي (${pt.lat.toStringAsFixed(4)}, ${pt.lon.toStringAsFixed(4)})',
            '📍 GPS coordinates updated (${pt.lat.toStringAsFixed(4)}, ${pt.lon.toStringAsFixed(4)})',
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20),
      ),
    );
  }

  Future<void> _sendFarmerOtp(TerraProvider tp, AppStrings s) async {
    final phone = _farmerPhoneCtrl.text.trim();
    if (phone.length < 8) {
      setState(
        () => _errorMsg = s.t(
          'من فضلك اكتب رقم تليفون صحيح (مثال: 01099887766)',
          'Please enter a valid phone number (e.g. +201099887766 or 01099887766)',
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final res = await tp.apiService.sendFarmerWhatsappOtp(phone);
      if (!mounted) return;
      final existing = res['existing_farmer'] == true;
      final existingName = (res['farmer_name'] ?? '').toString();
      final code = (res['demo_otp_code'] ?? '1234').toString();
      setState(() {
        _loading = false;
        _otpSent = true;
        _existingFarmer = existing;
        _demoOtpCode = code;
        _whatsappMsg = (res['whatsapp_message'] ??
                s.t('كود الدخول لتطبيق Terra Space هو: $code', 'Your Terra Space login code is: $code'))
            .toString();
        _farmerOtpCtrl.text = code;
        if (existingName.isNotEmpty && _farmerNameCtrl.text.trim().isEmpty) {
          _farmerNameCtrl.text = existingName;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _verifyFarmerOtpAndEnter(TerraProvider tp, AppStrings s) async {
    final phone = _farmerPhoneCtrl.text.trim();
    final otp = _farmerOtpCtrl.text.trim();
    final name = _farmerNameCtrl.text.trim();

    if (otp.isEmpty) {
      setState(() => _errorMsg = s.t('من فضلك أدخل كود الواتساب', 'Please enter the verification code'));
      return;
    }
    if (name.isEmpty) {
      setState(
        () => _errorMsg = s.t(
          'من فضلك اكتب اسمك علشان المساعد الذكي يناديك بيه ويحفظ تاريخ أرضك',
          'Please enter your name so the AI assistant remembers your farm profile',
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      tp.voiceService.unlockAudioOnGesture();
      await tp.loginFarmerWithWhatsappOtp(
        phone: phone,
        otpCode: otp,
        name: name,
        lat: _farmerLat,
        lon: _farmerLon,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _submitEngineerAuth(TerraProvider tp, AppStrings s) async {
    final phone = _engPhoneCtrl.text.trim();
    final password = _engPasswordCtrl.text.trim();

    if (phone.length < 8) {
      setState(() => _errorMsg = s.t('يرجى إدخال رقم هاتف صحيح', 'Please enter a valid phone number'));
      return;
    }
    if (password.length < 4) {
      setState(
        () => _errorMsg = s.t(
          'يرجى إدخال كلمة مرور لا تقل عن 4 أحرف أو أرقام',
          'Password must be at least 4 characters',
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      if (_engineerIsRegistering) {
        final name = _engNameCtrl.text.trim();
        if (name.isEmpty) {
          setState(() {
            _loading = false;
            _errorMsg = s.t('يرجى كتابة اسم المهندس الزراعي', 'Please enter the agronomist full name');
          });
          return;
        }
        final exp = int.tryParse(_engExpCtrl.text.trim()) ?? 7;
        await tp.registerNewEngineerAccount(
          name: name,
          phone: phone,
          password: password,
          lat: _engLat,
          lon: _engLon,
          specialty: _engSpecialty,
          governorate: _engGov,
          yearsOfExp: exp,
        );
      } else {
        await tp.loginEngineerAccount(
          phone: phone,
          password: password,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _openWhatsappWithCode(AppStrings s) async {
    final phone = _farmerPhoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final intl = phone.startsWith('0') ? '2$phone' : phone;
    final msg = Uri.encodeComponent(
      _whatsappMsg ?? s.t('كود الدخول لتطبيق Terra Space', 'Your Terra Space login code'),
    );
    final uri = Uri.parse('https://wa.me/$intl?text=$msg');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerraProvider>();
    final s = AppStrings(tp.isEnglish);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.t('🌍 محلي & عالمي', '🌍 Local & Global'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      AppLanguageToggle(
                        isEn: tp.isEnglish,
                        compact: false,
                        darkBackground: false,
                        onChanged: (lang) => tp.setAppLanguage(lang),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHeader(s),
                  const SizedBox(height: 16),
                  _buildRoleSelector(s),
                  const SizedBox(height: 16),
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                color: Color(0xFFB71C1C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_selectedRole == 'farmer')
                    _buildFarmerAuthCard(tp, s)
                  else
                    _buildEngineerAuthCard(tp, s),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showServerUrlDialog(context, tp, s),
                      icon: const Icon(Icons.dns_rounded, size: 16, color: Color(0xFF1B5E20)),
                      label: Text(
                        '🌐 ${s.t("رابط السيرفر", "Server URL")}: ${tp.apiService.baseUrl} (${s.t("تعديل", "Edit")})',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF1B5E20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showServerUrlDialog(
      BuildContext context, TerraProvider tp, AppStrings s) async {
    final ctrl = TextEditingController(text: tp.apiService.baseUrl);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          s.t('🌐 عنوان سيرفر Terra Space', '🌐 Terra Space Server URL'),
          style: const TextStyle(fontSize: 15),
        ),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: 'http://10.135.89.240:8000',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('إلغاء', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () async {
              await tp.setServerUrl(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E5B1C), Color(0xFF2E7D32)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TerraLogoBadge(size: 56, borderRadius: 14),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terra Space',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'NASA POWER • PlantDoc AI',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.t(
              'مساعدك الزراعي الذكي محلياً وعالمياً ببيانات أقمار ناسا الصناعية',
              'Your Smart Local & Global Agritech Assistant powered by NASA Satellites',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
          const SizedBox(height: 6),
          Text(
            s.t(
              'اختر نوع حسابك للدخول — سيبقى حسابك مفتوحاً دائماً حتى تقوم بتسجيل الخروج',
              'Choose your account role — your session stays signed in automatically',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC8E6C9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector(AppStrings s) {
    final isFarmer = _selectedRole == 'farmer';
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedRole = 'farmer';
              _errorMsg = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isFarmer ? const Color(0xFF1B5E20) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isFarmer ? const Color(0xFF1B5E20) : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: isFarmer
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.agriculture_rounded,
                    size: 32,
                    color: isFarmer ? Colors.amberAccent : const Color(0xFF1B5E20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.t('حساب مزارع 👨‍🌾', 'Farmer Account 👨‍🌾'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                      color: isFarmer ? Colors.white : const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.t('دخول سريع برقم التليفون وكود واتساب', 'Fast login via phone & OTP'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isFarmer ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedRole = 'engineer';
              _errorMsg = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: !isFarmer ? const Color(0xFF0D47A1) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: !isFarmer ? const Color(0xFF0D47A1) : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: !isFarmer
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0D47A1).withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.engineering_rounded,
                    size: 32,
                    color: !isFarmer ? Colors.amberAccent : const Color(0xFF0D47A1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.t('حساب مهندس زراعي 👨‍🔬', 'Agronomist Portal 👨‍🔬'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                      color: !isFarmer ? Colors.white : const Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.t('برقم الهاتف وكلمة المرور والتخصص', 'Phone, password & specialty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: !isFarmer ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFarmerAuthCard(TerraProvider tp, AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF1B5E20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.t(
                    'دخول المزارع (برقم الهاتف وكود الواتساب)',
                    'Farmer Login (Phone & WhatsApp Code)',
                  ),
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.t(
              'كل مزارع له حسابه المستقل وذاكرته الخاصة؛ المساعد الصوتي يتعرف عليك بالاسم ويحفظ تاريخ أرضك ومحاصيلك.',
              'Each farmer has a private account and long-term memory tracking farm coordinates, climate, and active crops.',
            ),
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _farmerPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: s.t('رقم تليفون المزارع (واتساب)', 'Farmer Phone Number (WhatsApp)'),
              hintText: s.t('مثال: 01099887766', 'Example: 01099887766 or +15550199'),
              prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF1B5E20)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          if (!_otpSent)
            FilledButton.icon(
              onPressed: _loading ? null : () => _sendFarmerOtp(tp, s),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.message_rounded),
              label: Text(
                s.t('إرسال كود التحقق على واتساب 💬', 'Send WhatsApp Verification Code 💬'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          if (_otpSent) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF25D366), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF1B5E20), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.t(
                            'تم إرسال كود واتساب للرقم ${_farmerPhoneCtrl.text} — الكود: ($_demoOtpCode)',
                            'Verification code ready for ${_farmerPhoneCtrl.text} — Code: ($_demoOtpCode)',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _openWhatsappWithCode(s),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(s.t('فتح رسالة واتساب', 'Open WhatsApp')),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _otpSent = false),
                        child: Text(s.t('تغيير الرقم', 'Change Phone')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _farmerOtpCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: s.t('كود التحقق المرسل على واتساب', 'Verification Code (OTP)'),
                hintText: s.t('مكون من 4 أرقام', '4-digit code'),
                prefixIcon: const Icon(Icons.lock_clock_rounded, color: Color(0xFF1B5E20)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _farmerNameCtrl,
              decoration: InputDecoration(
                labelText: _existingFarmer
                    ? s.t('اسمك المسجل لدى المساعد الذكي', 'Your Registered Name')
                    : s.t('اكتب اسمك (مثال: الحاج محمود)', 'Enter your name (e.g. John / Mahmoud)'),
                prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF1B5E20)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _farmerGov,
                    decoration: InputDecoration(
                      labelText: s.t('المنطقة / المحافظة (محلي وعالمي)', 'Region / Governorate (Local & Global)'),
                      prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF1B5E20)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: _locationsMap.keys
                        .map((g) => DropdownMenuItem(value: g, child: Text(s.locationName(g))))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final coords = _locationsMap[val]!;
                      setState(() {
                        _farmerGov = val;
                        _farmerLat = coords[0];
                        _farmerLon = coords[1];
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: s.t('تحديد موقع الأرض بـ GPS', 'Detect Farm Location via GPS'),
                  onPressed: _loading ? null : () => _detectGps(isFarmer: true, s: s),
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : () => _verifyFarmerOtpAndEnter(tp, s),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                s.t('تأكيد الكود وفتح حساب المزارع 🌱', 'Verify & Enter Farmer Dashboard 🌱'),
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEngineerAuthCard(TerraProvider tp, AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _engineerIsRegistering
                      ? s.t('إنشاء حساب مهندس زراعي جديد', 'Register New Agronomist Account')
                      : s.t('تسجيل دخول مهندس زراعي', 'Agronomist Sign In'),
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.t(
              'يظهر حسابك وتخصصك وموقعك الجغرافي للمزارعين القريبين منك لمساعدتهم عند حدوث إصابات أو مشاكل في المحصول.',
              'Your profile, specialty, and coordinates appear to nearby farmers for disease escalations and consultations.',
            ),
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(s.t('تسجيل دخول', 'Sign In')),
                icon: const Icon(Icons.login_rounded),
              ),
              ButtonSegment(
                value: true,
                label: Text(s.t('حساب مهندس جديد', 'New Account')),
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
            ],
            selected: {_engineerIsRegistering},
            onSelectionChanged: (sel) => setState(() {
              _engineerIsRegistering = sel.first;
              _errorMsg = null;
            }),
          ),
          const SizedBox(height: 14),
          if (_engineerIsRegistering) ...[
            TextField(
              controller: _engNameCtrl,
              decoration: InputDecoration(
                labelText: s.t('اسم المهندس الزراعي بالكامل', 'Agronomist Full Name'),
                hintText: s.t('مثال: م. أحمد عبد الرحمن', 'e.g. Eng. Ahmed / Dr. Sarah'),
                prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF0D47A1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _engPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: s.t('رقم الهاتف (الواتساب للتواصل مع المزارعين)', 'Phone Number (WhatsApp)'),
              hintText: s.t('مثال: 01001122334', 'e.g. 01001122334'),
              prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF0D47A1)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _engPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: s.t('كلمة المرور (Password)', 'Password'),
              hintText: s.t('أدخل كلمة المرور الخاصة بحسابك', 'Enter account password'),
              prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF0D47A1)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_engineerIsRegistering) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _engSpecialty,
                    decoration: InputDecoration(
                      labelText: s.t('التخصص الزراعي', 'Specialty'),
                      prefixIcon: const Icon(Icons.science_rounded, color: Color(0xFF0D47A1)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: _specialties
                        .map((sp) => DropdownMenuItem(value: sp, child: Text(s.specialty(sp))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _engSpecialty = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _engExpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: s.t('سنوات الخبرة', 'Years Exp.'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _engGov,
                    decoration: InputDecoration(
                      labelText: s.t('المنطقة / الموقع الجغرافي', 'Region / Location'),
                      prefixIcon: const Icon(Icons.pin_drop_rounded, color: Color(0xFF0D47A1)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: _locationsMap.keys
                        .map((g) => DropdownMenuItem(value: g, child: Text(s.locationName(g))))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final coords = _locationsMap[val]!;
                      setState(() {
                        _engGov = val;
                        _engLat = coords[0];
                        _engLon = coords[1];
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: s.t(
                    'تحديد موقعك الدقيق بـ GPS ليظهر للمزارعين القريبين',
                    'Detect exact GPS coordinates',
                  ),
                  onPressed: _loading ? null : () => _detectGps(isFarmer: false, s: s),
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              s.t(
                '📍 الإحداثيات المسجلة: (${_engLat.toStringAsFixed(4)}, ${_engLon.toStringAsFixed(4)}) — سيقترحك المساعد الذكي تلقائياً للمزارعين الأقرب إليك.',
                '📍 Saved Coordinates: (${_engLat.toStringAsFixed(4)}, ${_engLon.toStringAsFixed(4)}) — Farmers nearby will be matched to you automatically.',
              ),
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : () => _submitEngineerAuth(tp, s),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_engineerIsRegistering ? Icons.how_to_reg_rounded : Icons.login_rounded),
            label: Text(
              _engineerIsRegistering
                  ? s.t('تسجيل حساب المهندس والدخول للبوابة 👨‍🔬', 'Register & Enter Agronomist Portal 👨‍🔬')
                  : s.t('دخول لبوابة المهندس الزراعي 👨‍🔬', 'Sign In to Agronomist Portal 👨‍🔬'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
