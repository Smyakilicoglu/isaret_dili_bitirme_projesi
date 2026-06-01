class TranslationItem {
  final int? id;
  final String text;
  final String date; // Örn: "BUGÜN", "DÜN", "22 EKİM"
  final String time; // Örn: "14:20"
  final DateTime timestamp;

  TranslationItem({
    this.id,
    required this.text,
    required this.date,
    required this.time,
    required this.timestamp,
  });

  // Veritabanından Map'e dönüştürme
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'date': date,
      'time': time,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  // Map'ten TranslationItem'a dönüştürme
  factory TranslationItem.fromMap(Map<String, dynamic> map) {
    return TranslationItem(
      id: map['id'],
      text: map['text'],
      date: map['date'],
      time: map['time'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }

  // Tarih formatını otomatik oluştur
  static String getDateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (checkDate == today) {
      return 'BUGÜN';
    } else if (checkDate == yesterday) {
      return 'DÜN';
    } else {
      // Tarih formatı: "22 EKİM"
      final months = [
        'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
        'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]}';
    }
  }

  // Saat formatını oluştur
  static String getTimeLabel(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}