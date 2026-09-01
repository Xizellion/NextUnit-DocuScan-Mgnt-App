import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get currentRecordingPath => _currentRecordingPath;
  AudioPlayer get audioPlayer => _audioPlayer;

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String?> startRecording({String? customFileName}) async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      final dir = await getApplicationDocumentsDirectory();
      final name = customFileName ?? 'voice_note_${DateTime.now().millisecondsSinceEpoch}';
      final path = '${dir.path}/$name.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: path);
      _isRecording = true;
      _currentRecordingPath = path;
      return path;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      final path = await _audioRecorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  Future<void> playAudio(String filePath, {Function()? onComplete}) async {
    try {
      await _audioPlayer.stop();
      _audioPlayer.onPlayerComplete.listen((event) {
        _isPlaying = false;
        if (onComplete != null) onComplete();
      });
      await _audioPlayer.play(DeviceFileSource(filePath));
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
    }
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
    _isPlaying = false;
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _isPlaying = false;
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}