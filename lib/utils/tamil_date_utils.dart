class TamilDateUtils {
  static const List<String> tamilMonths = [
    'சித்திரை', 'வைகாசி', 'ஆனி', 'ஆடி', 'ஆவணி',
    'புரட்டாசி', 'ஐப்பசி', 'கார்த்திகை', 'மார்கழி', 'தை',
    'மாசி', 'பங்குனி'
  ];

  /// Approximate Tamil month start dates (solar ingress) for any year
  static List<DateTime> getTamilMonthStart(int year) {
    return [
      DateTime(year, 4, 14),  // சித்திரை
      DateTime(year, 5, 15),  // வைகாசி
      DateTime(year, 6, 15),  // ஆனி
      DateTime(year, 7, 16),  // ஆடி
      DateTime(year, 8, 16),  // ஆவணி
      DateTime(year, 9, 17),  // புரட்டாசி
      DateTime(year, 10, 18), // ஐப்பசி
      DateTime(year, 11, 16), // கார்த்திகை
      DateTime(year, 12, 16), // மார்கழி
      DateTime(year + 1, 1, 14), // தை
      DateTime(year + 1, 2, 13), // மாசி
      DateTime(year + 1, 3, 15), // பங்குனி
    ];
  }

  static Map<String, String> getTamilDate(DateTime date) {
    int year = date.year;
    List<DateTime> startDates = getTamilMonthStart(year);

    if (date.isBefore(startDates.first)) {
      startDates = getTamilMonthStart(year - 1);
    }

    int tamilMonthIndex = 0;

    for (int i = 0; i < startDates.length; i++) {
      if (date.isBefore(startDates[i])) {
        tamilMonthIndex = (i - 1 + 12) % 12;
        break;
      }
      tamilMonthIndex = i;
    }

    if (date.isAfter(startDates.last)) {
      tamilMonthIndex = 11; // பங்குனி
    }

    DateTime tamilStartDate = startDates[tamilMonthIndex];
    int tamilDay = date.difference(tamilStartDate).inDays + 1;

    if (tamilDay <= 0) {
      tamilMonthIndex = (tamilMonthIndex - 1 + 12) % 12;
      tamilStartDate = startDates[tamilMonthIndex];
      tamilDay = date.difference(tamilStartDate).inDays + 1;
    }

    return {
      'tamilDate': tamilDay.toString(),
      'tamilMonth': tamilMonths[tamilMonthIndex],
    };
  }
}
