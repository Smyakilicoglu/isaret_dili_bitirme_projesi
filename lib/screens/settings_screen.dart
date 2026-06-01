import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/translation_service.dart';
import 'history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;
  String selectedLanguage = 'Türkçe';
  String selectedVoice = 'Kadın'; // Kadın veya Erkek
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initTTS();
  }

  // AYARLARI YÜKLEMEK
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      selectedLanguage = prefs.getString('selectedLanguage') ?? 'Türkçe';
      selectedVoice = prefs.getString('selectedVoice') ?? 'Kadın';
    });
  }

  // AYARLARI KAYDETMEK
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    await prefs.setString('selectedLanguage', selectedLanguage);
    await prefs.setString('selectedVoice', selectedVoice);
  }

  // TTS BAŞLATMA
  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setPitch(selectedVoice == 'Kadın' ? 1.2 : 0.8);
    await _flutterTts.setSpeechRate(0.5);
  }

  // SES CİNSİYETİNİ DEĞİŞTİRMEK
  Future<void> _updateVoiceGender() async {
    await _flutterTts.setPitch(selectedVoice == 'Kadın' ? 1.2 : 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1a1a1a) : const Color(0xFFF5F5F5);
    final cardColor = isDarkMode ? const Color(0xFF2a2a2a) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          TranslationService.t('settings', AppSettings.instance.language),
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // GÖRÜNÜM BÖLÜMÜ
            _buildSectionHeader(TranslationService.t('appearance', AppSettings.instance.language), secondaryTextColor),
            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildThemeOption(textColor),
              ],
            ),

            const SizedBox(height: 24),

            // TERCİHLER BÖLÜMÜ
            _buildSectionHeader(TranslationService.t('preferences', AppSettings.instance.language), secondaryTextColor),
            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildSettingItem(
                  icon: Icons.volume_up,
                  iconColor: Colors.blue,
                  title: TranslationService.t('voice_options', AppSettings.instance.language),
                  textColor: textColor,
                  onTap: () {
                    _showVoiceOptionsDialog(cardColor, textColor);
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.history,
                  iconColor: Colors.green,
                  title: TranslationService.t('history', AppSettings.instance.language),
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HistoryScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _buildLanguageOption(textColor, secondaryTextColor),
              ],
            ),

            const SizedBox(height: 24),

            // DESTEK & BİLGİ BÖLÜMÜ
            _buildSectionHeader(TranslationService.t('support', AppSettings.instance.language), secondaryTextColor),
            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildSettingItem(
                  icon: Icons.info,
                  iconColor: Colors.grey.shade600,
                  title: TranslationService.t('about', AppSettings.instance.language),
                  textColor: textColor,
                  onTap: () {
                    _showAboutDialog(cardColor, textColor);
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.shield,
                  iconColor: Colors.grey.shade600,
                  title: TranslationService.t('privacy', AppSettings.instance.language),
                  textColor: textColor,
                  onTap: () {
                    // Gizlilik politikası sayfası
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),

            // VERSİYON BİLGİSİ
            Center(
              child: Text(
                'SIGN TRANSLATOR V2.4.0',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // BÖLÜM BAŞLIĞI
  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // AYARLAR KARTI
  Widget _buildSettingsCard({required Color cardColor, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // AYAR ÖĞESİ
  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  // TEMA SEÇENEĞİ
  Widget _buildThemeOption(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.palette, color: Colors.indigo, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              TranslationService.t('theme', AppSettings.instance.language),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          // AYDINLIK / KARANLIK TOGGLE
          Row(
            children: [
              _buildThemeToggle(TranslationService.t('light', AppSettings.instance.language), !isDarkMode, () {
                setState(() => isDarkMode = false);
                _saveSettings();
              }),
              const SizedBox(width: 8),
              _buildThemeToggle(TranslationService.t('dark', AppSettings.instance.language), isDarkMode, () {
                setState(() => isDarkMode = true);
                _saveSettings();
              }),
            ],
          ),
        ],
      ),
    );
  }

  // TEMA TOGGLE BUTONU
  Widget _buildThemeToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // DİL SEÇENEĞİ
  Widget _buildLanguageOption(Color textColor, Color secondaryTextColor) {
    return InkWell(
      onTap: () {
        _showLanguageDialog(isDarkMode ? const Color(0xFF2a2a2a) : Colors.white, textColor);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.translate, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                TranslationService.t('lang_settings', AppSettings.instance.language),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Text(
              selectedLanguage,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  // AYIRICI ÇİZGİ
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 84),
      child: Divider(color: Colors.grey.shade200, height: 1),
    );
  }

  // SES SEÇENEKLERİ DİYALOĞU
  void _showVoiceOptionsDialog(Color cardColor, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(TranslationService.t('voice_options', AppSettings.instance.language), style: TextStyle(color: textColor)),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVoiceOption('Kadın', setDialogState, textColor),
                const SizedBox(height: 8),
                _buildVoiceOption('Erkek', setDialogState, textColor),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _flutterTts.speak('Merhaba, ben ${selectedVoice.toLowerCase()} yapay zeka sesiyim.');
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Sesi Test Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveSettings();
            },
            child: Text(TranslationService.t('ok', AppSettings.instance.language)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // SES CİNSİYET SEÇENEĞİ
  Widget _buildVoiceOption(String voice, StateSetter setDialogState, Color textColor) {
    final isSelected = selectedVoice == voice;
    return InkWell(
      onTap: () {
        setState(() => selectedVoice = voice);
        setDialogState(() => selectedVoice = voice);
        _updateVoiceGender();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  voice == 'Kadın' ? Icons.woman : Icons.man,
                  color: isSelected ? Colors.blue : textColor,
                ),
                const SizedBox(width: 12),
                Text(
                  '$voice Ses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // DİL SEÇİMİ DİYALOĞU
  void _showLanguageDialog(Color cardColor, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(TranslationService.t('select_lang', AppSettings.instance.language), style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption2('Türkçe', textColor),
            _buildLanguageOption2('English', textColor),
            _buildLanguageOption2('Deutsch', textColor),
            _buildLanguageOption2('Français', textColor),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLanguageOption2(String language, Color textColor) {
    return InkWell(
      onTap: () {
        setState(() => selectedLanguage = language);
        _saveSettings();
        AppSettings.instance.language = language;
        AppSettings.instance.notify();
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              language,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            if (selectedLanguage == language)
              const Icon(Icons.check, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // HAKKINDA DİYALOĞU
  void _showAboutDialog(Color cardColor, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Uygulama Hakkında', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign Translator',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text('Versiyon: 2.4.0', style: TextStyle(color: textColor)),
            const SizedBox(height: 16),
            Text(
              'İşaret dili çeviri uygulaması ile işaret dilini anlık olarak metne çevirebilirsiniz.',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}