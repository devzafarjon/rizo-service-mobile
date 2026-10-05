import 'package:intl/intl.dart';

import 'i18n.dart';

const _uzMonths = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];

String _two(int v) => v.toString().padLeft(2, '0');

List<String> _months() {
  final list = Translator.I.list('format.monthsShort');
  return list != null && list.length == 12 ? list : _uzMonths;
}

String _intlLocale() => switch (Translator.I.locale) { 'ru' => 'ru_RU', 'en' => 'en_GB', _ => 'en_GB' };

String formatNumber(num value) {
  final fixed = NumberFormat.decimalPattern('en_US').format(value.round());
  return fixed.replaceAll(',', ' ');
}

String formatMoney(num value) => '${formatNumber(value)} ${tr('common.som')}';

String formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('998') && digits.length == 12) {
    return '+998 ${digits.substring(3, 5)} ${digits.substring(5, 8)} ${digits.substring(8, 10)} ${digits.substring(10)}';
  }
  return phone.startsWith('+') ? phone : '+$digits';
}

/// The phone number as a tel: link.
Uri telUri(String phone) => Uri.parse('tel:+${phone.replaceAll(RegExp(r'\D'), '')}');

String normalizeDisplayId(String value) => value.replaceFirst(RegExp(r'^#'), '').replaceAll(RegExp(r'\s+'), '');

String formatRequestId(String displayId) {
  final raw = normalizeDisplayId(displayId);
  return raw.isEmpty ? displayId : '#$raw';
}

String _datePart(DateTime d) {
  if (Translator.I.locale == 'uz') return '${_two(d.day)}-${_months()[d.month - 1]} ${d.year}';
  final month = _months()[d.month - 1];
  return '${_two(d.day)} $month ${d.year}';
}

/// A date-only value ("2026-10-05") shown without any time-zone shift.
String formatDate(String value) {
  final parsed = DateTime.tryParse(value.length >= 10 ? value.substring(0, 10) : value);
  return parsed == null ? value : _datePart(parsed);
}

String formatDateTime(DateTime? value) => value == null ? tr('common.dash') : _datePart(value.toLocal());

String formatStamp(DateTime? value) {
  if (value == null) return tr('common.dash');
  final d = value.toLocal();
  return '${_datePart(d)}, ${_two(d.hour)}:${_two(d.minute)}';
}

String formatTime(DateTime value) {
  final d = value.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

String formatDurationMs(int ms) {
  final totalMinutes = (ms / 60000).round().clamp(0, 1 << 30);
  if (totalMinutes < 1) return tr('format.lessMinute');
  if (totalMinutes < 60) return tr('format.min', params: {'count': totalMinutes});
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours < 24) {
    return minutes > 0 ? tr('format.hm', params: {'hours': hours, 'minutes': minutes}) : tr('format.h', params: {'hours': hours});
  }
  final days = hours ~/ 24;
  final rest = hours % 24;
  return rest > 0 ? tr('format.dh', params: {'days': days, 'hours': rest}) : tr('format.d', params: {'days': days});
}

String formatDurationHours(double? hours) {
  if (hours == null || hours.isNaN || hours < 0) return tr('common.dash');
  if (hours < 1) return tr('format.minutes', params: {'count': (hours * 60).round().clamp(1, 59)});
  if (hours < 24) return tr('format.hoursValue', params: {'value': hours < 10 ? hours.toStringAsFixed(1) : hours.round().toString()});
  final days = hours / 24;
  return tr('format.daysValue', params: {'value': days < 10 ? days.toStringAsFixed(1) : days.round().toString()});
}

/// Used by tests and date inputs.
String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String intlLocaleName() => _intlLocale();
