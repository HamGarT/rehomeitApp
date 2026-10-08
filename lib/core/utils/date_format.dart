// Sin `intl`: los formatos son pocos y fijos, y así no se carga ninguna tabla
// de locales.

String _two(int value) => value.toString().padLeft(2, '0');

/// Tiempo transcurrido en español: "Hace un momento", "Hace 55 min",
/// "Hace 1 día", "Hace 3 semanas".
String timeAgo(DateTime since, {DateTime? now}) {
  // Ambos en UTC: los Timestamp de Firestore no llevan la zona del dispositivo.
  final elapsed = (now ?? DateTime.now()).toUtc().difference(since.toUtc());
  if (elapsed.inMinutes < 1) return 'Hace un momento';
  if (elapsed.inMinutes < 60) return 'Hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) {
    final hours = elapsed.inHours;
    return 'Hace $hours ${hours == 1 ? 'hora' : 'horas'}';
  }
  if (elapsed.inDays < 7) {
    final days = elapsed.inDays;
    return 'Hace $days ${days == 1 ? 'día' : 'días'}';
  }
  final weeks = (elapsed.inDays / 7).floor();
  return 'Hace $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
}

/// "07/10/2026 14:05", en hora local.
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// "07/10 14:05", en hora local. Para listas donde el año no aporta.
String formatShortDateTime(DateTime date) {
  final local = date.toLocal();
  return '${_two(local.day)}/${_two(local.month)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Solo la hora si la fecha es de hoy; "07/10" en otro caso.
String formatCompactDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final isToday =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  if (isToday) return '${_two(local.hour)}:${_two(local.minute)}';
  return '${_two(local.day)}/${_two(local.month)}';
}
