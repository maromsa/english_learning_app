/// Sanitizes user-provided display names for UI and AI prompts.
String sanitizeDisplayName(String? raw, {int maxLength = 30}) {
  if (raw == null || raw.trim().isEmpty) {
    return '';
  }

  final cleaned = raw.replaceAll(RegExp(r'[\n\r\t{}"\\\[\]<>]'), '').trim();
  if (cleaned.isEmpty) {
    return '';
  }

  if (cleaned.length <= maxLength) {
    return cleaned;
  }
  return cleaned.substring(0, maxLength);
}
