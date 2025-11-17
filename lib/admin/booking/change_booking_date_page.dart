import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../public/config.dart';
import '../../utils/themed_datetime_picker.dart';
import '../../utils/hall_header.dart';
import 'pdf/change_date_pdf.dart';
import '../../public/main_navigation.dart';
// import 'booking_date_calender.dart';
// import 'package:table_calendar/table_calendar.dart';
import '../../utils/tamil_date_utils.dart';

class ChangeBookingDatePage extends StatefulWidget {
  final int hallId;
  final int bookingId;

  const ChangeBookingDatePage({
    super.key,
    required this.hallId,
    required this.bookingId,
  });

  @override
  State<ChangeBookingDatePage> createState() => _ChangeBookingDatePageState();
}

class _ChangeBookingDatePageState extends State<ChangeBookingDatePage> {
  bool _loading = true;
  Map<String, dynamic>? booking;
  Map<String, dynamic>? _hallDetails;
  Map<String, dynamic> calendarData = {};

  void prepareCalendarData() {
    calendarData.clear();
    for (var fdate in otherFunctionDates) {
      final key = fdate.toIso8601String().split('T')[0];
      calendarData[key] = {
        "booked": [true], // mark booked
        "billed": [true],
        "peakHours": [],
      };
    }

    for (var d in fullyBookedDates) {
      final key = d.toIso8601String().split('T')[0];
      calendarData[key] = {
        "booked": [true],
        "billed": [true],
        "peakHours": [],
      };
    }
  }


  DateTime? functionDate;
  DateTime? allotedFrom;
  DateTime? allotedTo;
  String? tamilDate;
  String? tamilMonth;

// Tamil months list
  final List<String> tamilMonths = [
    "சித்திரை",
    "வைகாசி",
    "ஆனி",
    "ஆடி",
    "ஆவணி",
    "புரட்டாசி",
    "ஐப்பசி",
    "கார்த்திகை",
    "மார்கழி",
    "தை",
    "மாசி",
    "பங்குனி"
  ];


  DateTime? originalFunctionDate;
  DateTime? originalAllotedFrom;
  DateTime? originalAllotedTo;

  List<Map<String, DateTime>> otherBookedRanges = [];
  List<DateTime> fullyBookedDates = [];
  List<DateTime> otherFunctionDates = [];

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFECE5D8);
  final Color cardColor = const Color(0xFFD8C9A9);

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _loadHallDetails();
  }

  Future<void> _loadHallDetails() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/halls/${widget.hallId}'));
      if (res.statusCode == 200) {
        setState(() {
          _hallDetails = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading hall details: $e");
    }
  }

  Future<void> _loadBooking() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/bookings/${widget.hallId}/${widget.bookingId}'),
      );

      if (res.statusCode == 200) {
        booking = jsonDecode(res.body);

        functionDate = DateTime.parse(booking!['function_date']);
        allotedFrom =
            DateTime.parse(booking!['alloted_datetime_from']);
        allotedTo = DateTime.parse(booking!['alloted_datetime_to']);
        tamilDate = booking!['tamil_date'];
        tamilMonth = booking!['tamil_month'];

        originalFunctionDate = functionDate;
        originalAllotedFrom = allotedFrom;
        originalAllotedTo = allotedTo;

        await _loadOtherBookings();

        setState(() => _loading = false);
      } else {
        throw Exception('Booking not found');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading booking: $e")));
      Navigator.pop(context);
    }
  }

  Future<void> _loadOtherBookings() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/bookings/${widget.hallId}'),
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        Map<String, int> bookingCount = {};
        List<Map<String, DateTime>> ranges = [];
        List<DateTime> funcDates = [];

        for (var b in data) {
          if (b['booking_id'] == widget.bookingId) continue;

          final from = DateTime.parse(b['alloted_datetime_from']).toLocal();
          final to = DateTime.parse(b['alloted_datetime_to']).toLocal();
          final fdate = DateTime.parse(b['function_date']).toLocal();

          ranges.add({"from": from, "to": to});
          funcDates.add(fdate);

          final dayKey = DateFormat('yyyy-MM-dd').format(from);
          bookingCount[dayKey] = (bookingCount[dayKey] ?? 0) + 1;
        }

        final fullyBooked = bookingCount.entries
            .where((e) => e.value >= 3)
            .map((e) => DateFormat('yyyy-MM-dd').parse(e.key))
            .toList();

        otherBookedRanges = ranges;
        fullyBookedDates = fullyBooked;
        otherFunctionDates = funcDates;
      }
    } catch (e) {
      debugPrint("Error loading other bookings: $e");
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    return await ThemedDateTimePicker.pick(
      context: context,
      initialDate: initial ?? DateTime.now(),
      primaryColor: primaryColor,
      backgroundColor: cardColor,
    );
  }

  Future<void> _pickAllotedFrom() async {
    final picked = await _pickDateTime(allotedFrom);
    if (picked != null) setState(() => allotedFrom = picked);
  }

  Future<void> _pickAllotedTo() async {
    final picked = await _pickDateTime(allotedTo);
    if (picked != null) setState(() => allotedTo = picked);
  }

  Future<void> _pickFunctionDate() async {
    DateTime today = DateTime.now();

    // Fetch calendar data
    Map<String, dynamic> calendarData = {};
    try {
      final res = await http.get(Uri.parse('$baseUrl/calendar/${widget.hallId}'));
      if (res.statusCode == 200) {
        calendarData = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Error fetching calendar: $e");
    }

    DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        DateTime selectedDay = functionDate ?? today;
        int initialPage = (selectedDay.year - today.year) * 12 + (selectedDay.month - today.month);
        PageController pageController = PageController(initialPage: initialPage);

        int displayedMonth = selectedDay.month;
        int displayedYear = selectedDay.year;

        final Color oliveGreen = const Color(0xFF5B6547);
        final Color lightTan = const Color(0xFFF3E2CB);
        final Color parchment = const Color(0xFFECE5D8);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            pageController.addListener(() {
              double? page = pageController.page;
              if (page != null) {
                int totalMonths = today.month + page.round();
                DateTime newDate = DateTime(today.year, totalMonths);
                if (newDate.month != displayedMonth || newDate.year != displayedYear) {
                  setStateDialog(() {
                    displayedMonth = newDate.month;
                    displayedYear = newDate.year;
                  });
                }
              }
            });

            Widget legendItem(Color color, String text) {
              return Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: oliveGreen, width: 1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: TextStyle(fontWeight: FontWeight.bold, color: oliveGreen),
                  ),
                ],
              );
            }

            Color getDayColor(DateTime day) {
              if (day.isBefore(DateTime(today.year, today.month, today.day))) {
                return Colors.grey.shade400;
              }
              final key = DateFormat('yyyy-MM-dd').format(day);
              final data = calendarData[key];
              if (data != null &&
                  ((data['booked']?.isNotEmpty ?? false) ||
                      (data['billed']?.isNotEmpty ?? false))) {
                return Colors.red.shade300;
              }
              return Colors.green.shade400;
            }

            Widget buildDayCell(DateTime day) {
              final color = getDayColor(day);
              final isSelectable = color == Colors.green.shade400;

              final isSelected = day.day == selectedDay.day &&
                  day.month == selectedDay.month &&
                  day.year == selectedDay.year;

              return GestureDetector(
                onTap: isSelectable ? () => setStateDialog(() => selectedDay = day) : null,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? oliveGreen.withValues(alpha:0.7)
                        : color.withValues(alpha:0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: oliveGreen, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isSelected ? lightTan : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }

            Widget buildMonth(DateTime month) {
              DateTime firstDay = DateTime(month.year, month.month, 1);
              int offset = firstDay.weekday % 7;
              int daysInMonth = DateTime(month.year, month.month + 1, 0).day;

              List<Widget> dayWidgets = [];
              for (int i = 0; i < offset; i++) {
                dayWidgets.add(Container());
              }

              for (int day = 1; day <= daysInMonth; day++) {
                DateTime current = DateTime(month.year, month.month, day);

                if (!current.isBefore(DateTime(today.year, today.month, today.day))) {
                  // ✅ Future or today — normal colored day cell
                  dayWidgets.add(buildDayCell(current));
                } else {
                  // ✅ Past days — same background as parchment, grey text only
                  dayWidgets.add(Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.transparent, // No grey shading
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: Colors.grey.shade500, // Only the number is grey
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ));
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: dayWidgets,
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: parchment,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(8),
              content: SizedBox(
                width: double.maxFinite,
                height: 390,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lightTan,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: oliveGreen.withValues(alpha:0.5)),
                      ),
                      child: Column(
                        children: [
                          // Month & Year selectors
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DropdownButton<int>(
                                dropdownColor: lightTan,
                                value: displayedMonth,
                                style: TextStyle(color: oliveGreen, fontWeight: FontWeight.bold),
                                items: List.generate(12, (i) {
                                  return DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(
                                      DateFormat('MMMM').format(DateTime(0, i + 1)),
                                    ),
                                  );
                                }),
                                onChanged: (m) {
                                  if (m != null) {
                                    setStateDialog(() {
                                      displayedMonth = m;
                                      pageController.jumpToPage(
                                        (displayedYear - today.year) * 12 +
                                            (displayedMonth - today.month),
                                      );
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<int>(
                                dropdownColor: lightTan,
                                value: displayedYear,
                                style: TextStyle(color: oliveGreen, fontWeight: FontWeight.bold),
                                items: List.generate(10, (i) => today.year + i)
                                    .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text('$y'),
                                ))
                                    .toList(),
                                onChanged: (y) {
                                  if (y != null) {
                                    setStateDialog(() {
                                      displayedYear = y;
                                      pageController.jumpToPage(
                                        (displayedYear - today.year) * 12 +
                                            (displayedMonth - today.month),
                                      );
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                                .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: oliveGreen,
                                  ),
                                ),
                              ),
                            ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 230,
                            child: PageView.builder(
                              controller: pageController,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final monthToShow =
                                DateTime(today.year, today.month + index);
                                return buildMonth(monthToShow);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        legendItem(Colors.green.shade400, "Available"),
                        legendItem(Colors.red.shade300, "Booked"),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: oliveGreen)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oliveGreen,
                    foregroundColor: lightTan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context, selectedDay),
                  child: const Text("Select"),
                ),
              ],
            );
          },
        );
      },
    );


    if (picked != null) {
      setState(() {
        functionDate = picked;

        // Auto-set Alloted From/To whenever function date changes
        allotedFrom = DateTime(picked.year, picked.month, picked.day - 1, 17, 0);
        allotedTo = DateTime(picked.year, picked.month, picked.day, 17, 0);

        // Auto-calculate Tamil date and month
        final tamil = TamilDateUtils.getTamilDate(picked);
        tamilDate = tamil['tamilDate'];
        tamilMonth = tamil['tamilMonth'];
      });
    }

  }

  // Future<void> _pickFunctionDate() async {
  //   final picked = await showDatePicker(
  //     context: context,
  //     initialDate: functionDate ?? DateTime.now(),
  //     firstDate: DateTime.now(),
  //     lastDate: DateTime(2100),
  //     builder: (context, child) => Theme(
  //       data: Theme.of(context).copyWith(
  //         colorScheme: ColorScheme.light(
  //           primary: primaryColor,
  //           onPrimary: backgroundColor,
  //           surface: cardColor,
  //           onSurface: primaryColor,
  //         ),
  //         dialogBackgroundColor: cardColor,
  //       ),
  //       child: child!,
  //     ),
  //   );
  //
  //   if (picked != null) {
  //     if (fullyBookedDates.any((d) =>
  //     d.year == picked.year &&
  //         d.month == picked.month &&
  //         d.day == picked.day)) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("This date is fully booked")),
  //       );
  //       return;
  //     }
  //
  //     if (otherFunctionDates.any((d) =>
  //     d.year == picked.year &&
  //         d.month == picked.month &&
  //         d.day == picked.day)) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("This function date is already booked")),
  //       );
  //       return;
  //     }
  //
  //     setState(() => functionDate = picked);
  //   }
  // }

  bool _checkConflict(DateTime start, DateTime end) {
    for (var range in otherBookedRanges) {
      final bookedFrom = range['from']!;
      final bookedTo = range['to']!;
      if (start.isBefore(bookedTo) && end.isAfter(bookedFrom)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Conflict with existing booking:\n"
                  "${DateFormat('yyyy-MM-dd hh:mm a').format(bookedFrom)} to "
                  "${DateFormat('yyyy-MM-dd hh:mm a').format(bookedTo)}",
            ),
          ),
        );
        return true;
      }
    }

    if (fullyBookedDates.any((d) =>
    d.year == start.year &&
        d.month == start.month &&
        d.day == start.day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This date is fully booked")),
      );
      return true;
    }

    return false;
  }

  bool _saved = false; // add at state level
  Map<String, dynamic>? updatedBooking;

  Future<void> _submitChange() async {
    if (functionDate == null || allotedFrom == null || allotedTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select all dates and times")),
      );
      return;
    }
    if (!allotedFrom!.isBefore(allotedTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alloted From must be before Alloted To")),
      );
      return;
    }
    if (functionDate!.isBefore(allotedFrom!) || functionDate!.isAfter(allotedTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Function date must be on or between allotted from–to")),
      );
      return;
    }
    if (_checkConflict(allotedFrom!, allotedTo!)) return;

    setState(() => _loading = true);

    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/bookings/${widget.hallId}/${widget.bookingId}/time'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'function_date': DateFormat('yyyy-MM-dd').format(functionDate!),
          'alloted_datetime_from': allotedFrom!.toIso8601String(),
          'alloted_datetime_to': allotedTo!.toIso8601String(),
          'tamil_date': tamilDate,
          'tamil_month': tamilMonth,
        }),
      );

      if (res.statusCode == 200) {
        updatedBooking = jsonDecode(res.body); // store updated info
        setState(() => _saved = true); // enable PDF button

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking date/time updated successfully")),
        );
      } else {
        final error = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error['message'] ?? res.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }


  // Widget _infoRow(String label, String value) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 6),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           flex: 3,
  //           child: Text(label,
  //               style:
  //               TextStyle(fontWeight: FontWeight.w600, color: primaryColor)),
  //         ),
  //         Expanded(
  //             flex: 5,
  //             child: Text(value,
  //                 style: TextStyle(color: primaryColor, fontSize: 15))),
  //       ],
  //     ),
  //   );
  // }

  Widget _plainRowWithTanValue(String label, {Widget? child, String? value}) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Container(
            width: screenWidth * 0.35, // 35% for label
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Value container
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: child ?? Text(
                value ?? "—",
                style: TextStyle(color: primaryColor),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha:0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: cardColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: backgroundColor, // same as page background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: primaryColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Widget _sectionHeader(String title) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 16.0),
  //     child: Center(
  //       child: Text(
  //         title,
  //         style: TextStyle(
  //             fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, true); // send refresh signal
          return false; // prevent default pop (we already did it)
        },child:Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Change Booking Date/Time",
            style: TextStyle(color: Color(0xFFD8C7A5))),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: cardColor),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: cardColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_hallDetails != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: HallHeader(
                  hallDetails: _hallDetails!,
                  oliveGreen: primaryColor,
                  tan: cardColor,
                ),
              ),
            const SizedBox(height: 20),
            if (_saved && booking != null && _hallDetails != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 90),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sectionContainer("GENERATE BILL", [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Generate the updated bill and view it as a PDF document.",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Center(
                          child: SizedBox(
                            width: 220,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChangeDatePdfPage(
                                      bookingData: booking!,
                                      hallDetails: _hallDetails!,
                                      updatedFunctionDate: functionDate!,
                                      updatedFrom: allotedFrom!,
                                      updatedTo: allotedTo!,
                                      updatedTamilDate: tamilDate!,   // ✅ updated Tamil date
                                      updatedTamilMonth: tamilMonth!, // ✅ updated Tamil month
                                      oliveGreen: primaryColor,
                                      tan: cardColor,
                                      beigeBackground: backgroundColor,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.picture_as_pdf, size: 20),
                              label: const Text(
                                "Generate Bill & View PDF",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: cardColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

            if (_saved && booking != null && _hallDetails != null)
              const SizedBox(height: 20),
            if(!_saved)
              _sectionContainer(
              "CHANGE DATE/TIME",
              [
                // Function Date
                _plainRowWithTanValue(
                  "FUNCTION DATE",
                  child: InkWell(
                    onTap: _saved ? null : _pickFunctionDate, // disable after save
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        functionDate != null
                            ? DateFormat('dd-MM-yyyy').format(functionDate!)
                            : "Select Date",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                // Tamil Date (editable text)


// Tamil Month (dropdown)
                // Tamil Date (editable text)
                _plainRowWithTanValue(
                  "TAMIL DATE",
                  child: _saved
                      ? Text(
                    tamilDate ?? "—",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: TextEditingController(text: tamilDate),
                      decoration: InputDecoration(
                        hintText: "Enter Tamil Date",
                        hintStyle: TextStyle(color: primaryColor.withValues(alpha:0.6)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (val) => tamilDate = val,
                    ),
                  ),
                ),

// Tamil Month (dropdown)
                _plainRowWithTanValue(
                  "TAMIL MONTH",
                  child: _saved
                      ? Text(
                    tamilMonth ?? "—",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: tamilMonth != null && tamilMonths.contains(tamilMonth)
                          ? tamilMonth
                          : null,
                      hint: Text(
                        "Select Tamil Month",
                        style: TextStyle(color: primaryColor.withValues(alpha:0.6)),
                      ),
                      dropdownColor: cardColor,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                      items: tamilMonths
                          .map((month) => DropdownMenuItem(
                        value: month,
                        child: Center(
                          child: Text(
                            month,
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ))
                          .toList(),
                      onChanged: (val) => setState(() => tamilMonth = val),
                    ),
                  ),
                ),

// Alloted To// Alloted From
_plainRowWithTanValue(
  "ALLOTED FROM",
  child: InkWell(
    onTap: _saved ? null : _pickAllotedFrom, // disable after save
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          allotedFrom != null
              ? DateFormat('dd-MM-yyyy').format(allotedFrom!)
              : "Select Date",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        ),
        Text(
          allotedFrom != null
              ? DateFormat('hh:mm a').format(allotedFrom!)
              : "Select Time",
          style: TextStyle(color: primaryColor),
        ),
      ],
    ),
  ),
),
const SizedBox(height: 12),
                _plainRowWithTanValue(
                  "ALLOTED TO",
                  child: InkWell(
                    onTap: _saved ? null : _pickAllotedTo, // disable after save
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          allotedTo != null
                              ? DateFormat('dd-MM-yyyy').format(allotedTo!)
                              : "Select Date",
                          style: TextStyle(
                              color: primaryColor, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          allotedTo != null
                              ? DateFormat('hh:mm a').format(allotedTo!)
                              : "Select Time",
                          style: TextStyle(color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (!_saved)
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5, // 50% of screen width
                    child: ElevatedButton(
                      onPressed: _submitChange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(fontSize: 15, color: Color(0xFFD8C7A5)),
                      ),
                    ),
                  ),
              ],
            ),
            if(!_saved)
              const SizedBox(height: 20),
            if(!_saved)
              _sectionContainer(
              "BOOKING DETAILS",
              [
                _plainRowWithTanValue(
                  "BOOKING ID",
                  value: booking!['booking_id'].toString(),
                ),
                _plainRowWithTanValue(
                  "NAME",
                  value: booking!['name'],
                ),
                _plainRowWithTanValue(
                  "PHONE",
                  value: booking!['phone'],
                ),
                if (booking!['email'] != null)
                  _plainRowWithTanValue(
                    "EMAIL",
                    value: booking!['email'],
                  ),
                if (booking!['address'] != null)
                  _plainRowWithTanValue(
                    "ADDRESS",
                    value: booking!['address'],
                  ),
                _plainRowWithTanValue(
                  "EVENT",
                  value: booking!['event_type'] ?? "N/A",
                ),
                _plainRowWithTanValue(
                  "EVENT DATE",
                  value: functionDate != null
                      ? DateFormat('yyyy-MM-dd').format(originalFunctionDate!)
                      : "—",
                ),
                _plainRowWithTanValue(
                  "ALLOTED FROM",
                  child: originalAllotedFrom!= null
                      ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd-MM-yyyy').format(originalAllotedFrom!),
                        style: TextStyle(color: primaryColor),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(originalAllotedFrom!),
                        style: TextStyle(color: primaryColor),
                      ),
                    ],
                  )
                      : Text("—", style: TextStyle(color: primaryColor)),
                ),
                _plainRowWithTanValue(
                  "ALLOTED TO",
                  child: originalAllotedTo!= null
                      ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd-MM-yyyy').format(originalAllotedTo!),
                        style: TextStyle(color: primaryColor),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(originalAllotedTo!),
                        style: TextStyle(color: primaryColor),
                      ),
                    ],
                  )
                      : Text("—", style: TextStyle(color: primaryColor)),
                ),
                _plainRowWithTanValue(
                  "TAMIL DATE",
                  value: booking!['tamil_date'] ?? "N/A",
                ),
                _plainRowWithTanValue(
                "TAMIL MONTH",
                value: booking!['tamil_month'] ?? "N/A",
              ),
              ],
            ),
            if(!_saved)
              const SizedBox(height: 20),
            if(!_saved)
              const SizedBox(height: 60)
          ],
        ),
      ),
    ),
    );
  }
}

