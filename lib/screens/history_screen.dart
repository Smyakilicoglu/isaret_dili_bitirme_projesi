import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/translation_item.dart';
import '../services/database_helper.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TranslationItem> _translations = [];
  List<TranslationItem> _filteredTranslations = [];
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isLoading = true;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadTranslations();
    _initTTS();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _initTTS() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedVoice = prefs.getString('selectedVoice') ?? 'Kadın';
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setPitch(selectedVoice == 'Kadın' ? 1.2 : 0.8);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _loadTranslations() async {
    setState(() => _isLoading = true);
    final translations = await DatabaseHelper.instance.getAllTranslations();
    setState(() {
      _translations = translations;
      _filteredTranslations = translations;
      _isLoading = false;
    });
  }

  void _filterTranslations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTranslations = _translations;
      } else {
        _filteredTranslations = _translations
            .where((item) => item.text.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _deleteTranslation(int id) async {
    await DatabaseHelper.instance.deleteTranslation(id);
    _loadTranslations();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çeviri silindi'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteAllTranslations() async {
    await DatabaseHelper.instance.deleteAllTranslations();
    _loadTranslations();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm çeviriler silindi'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2a2a2a) : Colors.white,
        title: Text(
          'Tümünü Sil',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          'Tüm çeviri geçmişini silmek istediğinizden emin misiniz?',
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllTranslations();
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1a1a1a) : const Color(0xFFF5F5F5);
    final cardColor = isDarkMode ? const Color(0xFF2a2a2a) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

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
          'Geçmiş Çeviriler',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_translations.isNotEmpty)
            IconButton(
              icon: Icon(Icons.filter_list, color: textColor),
              onPressed: () {
                // Filtreleme seçenekleri
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ARAMA KUTUSU
          Container(
            padding: const EdgeInsets.all(16),
            color: cardColor,
            child: TextField(
              controller: _searchController,
              onChanged: _filterTranslations,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Çevirilerde ara...',
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // ÇEVİRİ LİSTESİ
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTranslations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Henüz çeviri geçmişi yok'
                        : 'Sonuç bulunamadı',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: _filteredTranslations.length,
              itemBuilder: (context, index) {
                final item = _filteredTranslations[index];
                final showDateHeader = index == 0 ||
                    _filteredTranslations[index - 1].date != item.date;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TARİH BAŞLIĞI
                    if (showDateHeader)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          item.date,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                    // ÇEVİRİ KARTI
                    Dismissible(
                      key: Key(item.id.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      onDismissed: (_) => _deleteTranslation(item.id!),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textColor,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.time,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.volume_up,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _flutterTts.speak(item.text);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // SİL BUTONU (SABİT)
      floatingActionButton: _translations.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _showDeleteAllDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.delete_sweep, color: Colors.white),
        label: const Text(
          'Tümünü Sil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      )
          : null,
    );
  }
}