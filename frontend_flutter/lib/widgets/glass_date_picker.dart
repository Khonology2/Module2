import 'package:flutter/material.dart';

const Color _calendarAccentRed = Color(0xFFC10D00);

Future<DateTime?> showGlassDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
}) {
  final baseTheme = Theme.of(context);
  final isDark = baseTheme.brightness == Brightness.dark;

  final Color textColor = isDark ? Colors.white : const Color(0xFF151923);
  final Color mutedText = isDark
      ? Colors.white.withValues(alpha: 0.72)
      : const Color(0xFF2C3442);
  final Color borderColor =
      isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFD7DBE3);
  final Color popupBackground = isDark
      ? const Color(0xD91A1F29)
      : const Color(0xEAF7F9FC);

  MaterialStateProperty<Color?> redInteractiveBg() {
    return MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected) ||
          states.contains(MaterialState.hovered) ||
          states.contains(MaterialState.pressed) ||
          states.contains(MaterialState.focused)) {
        return _calendarAccentRed;
      }
      return Colors.transparent;
    });
  }

  DateTime selectedDate = initialDate;

  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: _calendarAccentRed,
          onPrimary: Colors.white,
          surface: popupBackground,
          onSurface: textColor,
        ),
        textTheme: baseTheme.textTheme.apply(
          fontFamily: 'Poppins',
          bodyColor: textColor,
          displayColor: textColor,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: popupBackground,
          elevation: 0,
          dayStyle: TextStyle(
            fontFamily: 'Poppins',
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
          weekdayStyle: TextStyle(
            fontFamily: 'Poppins',
            color: mutedText,
            fontWeight: FontWeight.w600,
          ),
          dayForegroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) {
              return textColor.withValues(alpha: 0.35);
            }
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            return textColor;
          }),
          dayBackgroundColor: redInteractiveBg(),
          dayOverlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.hovered) ||
                states.contains(MaterialState.focused) ||
                states.contains(MaterialState.pressed)) {
              return _calendarAccentRed;
            }
            return Colors.transparent;
          }),
          todayForegroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected) ||
                states.contains(MaterialState.hovered) ||
                states.contains(MaterialState.focused)) {
              return Colors.white;
            }
            return _calendarAccentRed;
          }),
          todayBackgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected) ||
                states.contains(MaterialState.hovered) ||
                states.contains(MaterialState.pressed) ||
                states.contains(MaterialState.focused)) {
              return _calendarAccentRed;
            }
            return _calendarAccentRed.withValues(alpha: 0.18);
          }),
          yearForegroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) return Colors.white;
            return textColor;
          }),
          yearBackgroundColor: redInteractiveBg(),
          yearStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      Widget popup = Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 360,
            minWidth: 320,
          ),
          child: StatefulBuilder(
            builder: (context, setInnerState) {
              return Container(
                decoration: BoxDecoration(
                  color: popupBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((helpText ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            helpText!,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    CalendarDatePicker(
                      initialDate: selectedDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      currentDate: currentDate,
                      initialCalendarMode:
                          initialEntryMode == DatePickerEntryMode.input
                              ? DatePickerMode.year
                              : DatePickerMode.day,
                      selectableDayPredicate: selectableDayPredicate,
                      onDateChanged: (value) {
                        setInnerState(() => selectedDate = value);
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(
                              cancelText ?? 'Cancel',
                              style: const TextStyle(fontFamily: 'Poppins'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(selectedDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _calendarAccentRed,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              confirmText ?? 'OK',
                              style: const TextStyle(fontFamily: 'Poppins'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      if (locale != null) {
        popup = Localizations.override(
          context: dialogContext,
          locale: locale,
          child: popup,
        );
      }

      return Theme(data: theme, child: popup);
    },
  );
}
