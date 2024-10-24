String formatLastUpdated(String timestamp) {
  try {
    DateTime dateTime = DateTime.parse(timestamp);
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  } catch (e) {
    throw const FormatException('Invalid timestamp format');
  }
}
