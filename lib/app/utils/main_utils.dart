import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainUtils {
  String formatIsoDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';

    final dt = DateTime.parse(isoString).toLocal();
    return DateFormat('hh:mm a, d MMM yyyy').format(dt);
  }

  static String convertToTimeString(String time) {
    DateTime parsedTime = DateFormat("HH:mm:ss").parse(time);
    return DateFormat("hh:mm a")
        .format(parsedTime); // Converts to 12-hour format with AM/PM
  }

  static String formatDate(DateTime dateTime) {
    try {
      return DateFormat('yyyy-MM-dd hh:mm:ss a').format(dateTime);
    } catch (e) {
      return "";
    }
  }

  static String dateToTimeOnly(DateTime dateTime) {
    try {
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return "";
    }
  }

  static String formatChatDate(DateTime messageDate) {
    final now = DateTime.now();

    // Normalize date times to ignore time portion
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );

    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference > 1 && difference <= 7) {
      // Get day of the week name
      String dayName = DateFormat.EEEE().format(
        messageDate,
      ); // Monday, Tuesday, etc.
      return dayName;
    } else {
      // Return date in MM/dd/yyyy or dd/MM/yyyy format as needed
      return DateFormat('MM/dd/yyyy').format(messageDate);
    }
  }

  static String formatFeedDate(DateTime messageDate) {
    final now = DateTime.now();
    final diff = now.difference(messageDate);

    final minutes = diff.inMinutes;
    final hours = diff.inHours;

    // Less than 1 minute
    if (minutes < 1) {
      return 'just now';
    }

    // Less than 60 minutes
    if (minutes < 60) {
      return '$minutes m';
    }

    // Less than 24 hours
    if (hours < 24) {
      return '$hours h';
    }

    // Older posts → Example: "Oct 29 at 11:16PM"
    return DateFormat("MMM d 'at' h:mm a").format(messageDate);
  }

  static String dateToTime24(DateTime dateTime) {
    try {
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return "";
    }
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final difference = now.difference(dateTime.toUtc());

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y';
    }
  }

  static String dateToDateAndTime(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate).toLocal(); // ✅ convert to local
      final datePart = DateFormat('d MMM yyyy').format(dateTime);
      final timePart = DateFormat('hh:mm a').format(dateTime);
      return '$datePart at ${timePart.toLowerCase()}';
    } catch (e) {
      return "";
    }
  }

  static String dateToDateAndTime2(DateTime dateTime) {
    try {
      return DateFormat('dd MMM, yyyy \'at\' HH:mm').format(dateTime);
    } catch (e) {
      return "";
    }
  }

  static String getMonth(String dateTime) {
    try {
      return DateFormat(
        'MMM yyyy',
      ).format(DateFormat('yyyy-MM-dd').parse(dateTime));
    } catch (e) {
      return "";
    }
  }

  static String dateTimeStringToDateTime(String dateTime) {
    try {
      return DateFormat(
        'dd MMM yyyy  hh:mm a',
      ).format(DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime));
    } catch (e) {
      return "";
    }
  }

  static String estimatedDate(DateTime? dateTime) {
    try {
      if (dateTime == null) return '';
      return DateFormat('dd MMM, yyyy').format(dateTime);
    } catch (e) {
      return "Unknown date";
    }
  }

  static DateTime? convertStringToDatetime(String dateTime) {
    try {
      return DateFormat("yyyy-MM-ddTHH:mm:ss.SSS").parse(dateTime);
    } catch (e) {
      return null;
    }
  }

  static DateTime? isoStringToLocalDate(String dateTime) {
    try {
      return DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').parse(dateTime);
    } catch (e) {
      return null;
    }
  }

  static String isoStringToDateTimeString(String dateTime) {
    try {
      final parsed = isoStringToLocalDate(dateTime);
      return parsed != null
          ? DateFormat('dd MMM yyyy  hh:mm a').format(parsed)
          : "";
    } catch (e) {
      return "";
    }
  }

  static String isoStringToLocalDateOnly(String dateTime) {
    try {
      final parsed = isoStringToLocalDate(dateTime);
      return parsed != null ? DateFormat('dd MMM yyyy').format(parsed) : "";
    } catch (e) {
      return "";
    }
  }

  static String stringToLocalDateOnly(String dateTime) {
    try {
      return DateFormat(
        'dd MMM yyyy',
      ).format(DateFormat('yyyy-MM-dd').parse(dateTime));
    } catch (e) {
      return "";
    }
  }

  static String localDateToIsoString(DateTime? dateTime) {
    try {
      if (dateTime == null) return "";
      return DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(dateTime);
    } catch (e) {
      return "";
    }
  }

  static String convertTimeToTime(String time) {
    try {
      return DateFormat('hh:mm a').format(DateFormat('HH:mm').parse(time));
    } catch (e) {
      return "";
    }
  }

  static String convertDateTimeToTime(String time) {
    try {
      return DateFormat(
        'hh:mm a',
      ).format(DateFormat('yyyy-MM-dd HH:mm:ss').parse(time));
    } catch (e) {
      return "";
    }
  }

  static DateTime? convertStringTimeToDate(String time) {
    try {
      return DateFormat('HH:mm').parse(time);
    } catch (e) {
      return null;
    }
  }

  static DateTime? stringTimeToDateTime(String time) {
    try {
      return DateFormat('HH:mm:ss').parse(time);
    } catch (e) {
      return null;
    }
  }

  static String stringToStringTime(String dateTime) {
    try {
      final inputDate = DateFormat('HH:mm:ss').parse(dateTime);
      return DateFormat('hh:mm a').format(inputDate);
    } catch (e) {
      return "";
    }
  }

  static TimeOfDay? convertStringToTimeOfDay(String timeString) {
    try {
      List<String> parts = timeString.split(":");
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  // 🕒 Extension Methods converted to static

  static String toCalendarDay(DateTime? dateTime) {
    try {
      return DateFormat.d().format(dateTime!);
    } catch (e) {
      return "";
    }
  }

  static String toCalendarMonth(DateTime? dateTime) {
    try {
      return DateFormat.MMM().format(dateTime!).toUpperCase();
    } catch (e) {
      return "";
    }
  }

  static String toCalendarMonthDay(DateTime? dateTime) {
    try {
      return DateFormat.MMMMd().format(dateTime!).toUpperCase();
    } catch (e) {
      return "";
    }
  }

  static String toDefaultFormattedDate(DateTime? dateTime) {
    try {
      return DateFormat('yyyy-MM-dd').format(dateTime!);
    } catch (e) {
      return "";
    }
  }

  static String toDate(DateTime? dateTime) {
    try {
      return DateFormat.yMMMMd().format(dateTime!);
    } catch (e) {
      return "";
    }
  }

  static String toTime(DateTime? dateTime) {
    try {
      return DateFormat.yMMMMd().add_jm().format(dateTime!);
    } catch (e) {
      return "";
    }
  }
}

String formatValue(dynamic value) {
  if (value == null) return "";

  if (value is int) {
    return value.toString();
  }

  if (value is double) {
    return value.toStringAsFixed(2);
  }

  return value.toString();
}

String capitalizeEachWord(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map(
        (word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '',
      )
      .join(' ');
}

String formatStatus(String status) {
  status = status.replaceAll('_', ' ');
  return status[0].toUpperCase() + status.substring(1).toUpperCase();
}

String formatPrice(double price) {
  if (price == price.truncateToDouble()) {
    return price.toInt().toString();
  } else {
    return price.toStringAsFixed(2);
  }
}

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) {
    hex = "FF$hex"; // add alpha if missing
  }
  return Color(int.parse(hex, radix: 16));
}
