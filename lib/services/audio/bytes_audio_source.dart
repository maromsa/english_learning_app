import 'package:just_audio/just_audio.dart';

// just_audio has no stable (non-experimental) API for serving in-memory byte
// audio, so StreamAudioSource/StreamAudioResponse are the only option here.
// ignore: experimental_member_use
class BytesAudioSource extends StreamAudioSource {
  BytesAudioSource(
    List<int> bytes, {
    String super.tag = 'BytesAudioSource',
    this.contentType = 'audio/mpeg',
  }) : _bytes = List<int>.unmodifiable(bytes);

  final List<int> _bytes;
  final String contentType;

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? _bytes.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: effectiveEnd - effectiveStart,
      offset: effectiveStart,
      stream: Stream<List<int>>.value(
        _bytes.sublist(effectiveStart, effectiveEnd),
      ),
      contentType: contentType,
    );
  }
}
