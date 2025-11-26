import 'package:just_audio/just_audio.dart';

class BytesAudioSource extends StreamAudioSource {
  BytesAudioSource(
    List<int> bytes, {
    String tag = 'BytesAudioSource',
    this.contentType = 'audio/mpeg',
  })  : _bytes = List<int>.unmodifiable(bytes),
        super(tag: tag);

  final List<int> _bytes;
  final String contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? _bytes.length;
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

