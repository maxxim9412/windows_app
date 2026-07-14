import 'package:audioplayers/audioplayers.dart';

/// Проигрывает звук входящего звонка (в цикле), пока не остановят.
class RingService {
  RingService._();
  static final RingService instance = RingService._();

  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/ring.wav'));
    } catch (_) {
      _playing = false;
    }
  }

  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }
}
