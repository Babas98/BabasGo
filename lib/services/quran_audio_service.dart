import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'file_system.dart';

class QuranAudioService {
  QuranAudioService() {
    _initAudioSession();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        onPlaybackCompleted?.call();
      }
    });
    _player.positionStream.listen((position) {
      onPositionChanged?.call(position);
    });
    _player.durationStream.listen((duration) {
      onDurationChanged?.call(duration);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Duration position = Duration.zero;

  Duration? duration;

  String? _lastError;
  String? get lastError => _lastError;

  void Function(String)? onError;

  int _currentSurahNumber = 1;
  int get currentSurahNumber => _currentSurahNumber;

  int _currentAyahNumber = 1;
  int get currentAyahNumber => _currentAyahNumber;

  String _qariCode = 'abdullah_basfar';
  String _qariName = 'Abdullah Basfar';
  String get qariCode => _qariCode;
  String get qariName => _qariName;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  bool _autoPlay = true;
  bool get autoPlay => _autoPlay;

  bool _repeatAyah = false;
  bool get repeatAyah => _repeatAyah;

  bool _repeatSurah = false;
  bool get repeatSurah => _repeatSurah;

  bool _shuffle = false;
  bool get shuffle => _shuffle;

  Future<void> setQari(String code, String name) async {
    _qariCode = code;
    _qariName = name;
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setSpeed(speed);
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
  }

  Future<void> setRepeatAyah(bool value) async {
    _repeatAyah = value;
    if (value) {
      await _player.setLoopMode(LoopMode.one);
    } else if (!_repeatSurah) {
      await _player.setLoopMode(LoopMode.off);
    }
  }

  Future<void> setRepeatSurah(bool value) async {
    _repeatSurah = value;
    if (value) {
      await _player.setLoopMode(LoopMode.off);
    } else if (!_repeatAyah) {
      await _player.setLoopMode(LoopMode.off);
    }
  }

  Future<void> setShuffle(bool value) async {
    _shuffle = value;
  }

  void Function()? onPlaybackCompleted;
  void Function(Duration)? onPositionChanged;
  void Function(Duration?)? onDurationChanged;
  void Function()? onPlaybackStateChanged;

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {}
  }

  Future<void> playAyah({
    required int surahNumber,
    required int ayahNumber,
    required int totalAyahs,
  }) async {
    _currentSurahNumber = surahNumber;
    _currentAyahNumber = ayahNumber;
    _isLoading = true;
    _lastError = null;
    onPlaybackStateChanged?.call();

    final localPath = await _buildLocalAudioPath(surahNumber: surahNumber, ayahNumber: ayahNumber);
    final isOffline = localPath.isNotEmpty && await fileExists(localPath);

    try {
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          if (isOffline) {
            await _player.setAudioSource(AudioSource.uri(Uri.file(localPath)));
          } else {
            final audioUrl = await resolveAudioUrl(surahNumber: surahNumber, ayahNumber: ayahNumber);
            if (audioUrl == null || audioUrl.isEmpty) {
              throw Exception('Tidak dapat menemukan URL audio.');
            }
            await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
          }
          await _player.setSpeed(_playbackSpeed);
          if (_repeatAyah) {
            await _player.setLoopMode(LoopMode.one);
          } else {
            await _player.setLoopMode(LoopMode.off);
          }
          await _player.play();
          _isPlaying = true;
          _isLoading = false;
          onPlaybackStateChanged?.call();
          return;
        } catch (error) {
          if (attempt == 2) {
            throw error;
          }
        }
      }
    } catch (error) {
      _lastError = error.toString();
      _isLoading = false;
      _isPlaying = false;
      onPlaybackStateChanged?.call();
      onError?.call(_lastError ?? 'Terjadi kesalahan pemutaran audio.');
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    onPlaybackStateChanged?.call();
  }

  Future<void> resume() async {
    if (_player.processingState == ProcessingState.idle) {
      await playAyah(
        surahNumber: _currentSurahNumber,
        ayahNumber: _currentAyahNumber,
        totalAyahs: 1,
      );
      return;
    }
    await _player.play();
    _isPlaying = true;
    onPlaybackStateChanged?.call();
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    position = Duration.zero;
    onPlaybackStateChanged?.call();
  }

  Future<void> seekTo(Duration newPosition) async {
    await _player.seek(newPosition);
    position = newPosition;
  }

  Future<void> nextAyah({required int totalAyahs}) async {
    final nextAyah = _currentAyahNumber + 1;
    if (nextAyah <= totalAyahs) {
      await playAyah(surahNumber: _currentSurahNumber, ayahNumber: nextAyah, totalAyahs: totalAyahs);
    }
  }

  Future<void> previousAyah({required int totalAyahs}) async {
    final previousAyah = _currentAyahNumber - 1;
    if (previousAyah >= 1) {
      await playAyah(surahNumber: _currentSurahNumber, ayahNumber: previousAyah, totalAyahs: totalAyahs);
    }
  }

  Future<void> downloadCurrentAudio() async {
    final localPath = await _buildLocalAudioPath(surahNumber: _currentSurahNumber, ayahNumber: _currentAyahNumber);
    final remoteUrl = await resolveAudioUrl(surahNumber: _currentSurahNumber, ayahNumber: _currentAyahNumber);
    if (remoteUrl == null || remoteUrl.isEmpty || localPath.isEmpty) {
      return;
    }
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode == 200) {
      await writeFile(localPath, response.bodyBytes);
    }
  }

  Future<void> deleteCurrentAudio() async {
    final localPath = await _buildLocalAudioPath(surahNumber: _currentSurahNumber, ayahNumber: _currentAyahNumber);
    if (localPath.isEmpty) {
      return;
    }
    await deleteFile(localPath);
  }

  Future<bool> isCurrentAudioAvailableOffline() async {
    final localPath = await _buildLocalAudioPath(surahNumber: _currentSurahNumber, ayahNumber: _currentAyahNumber);
    if (localPath.isEmpty) {
      return false;
    }
    return await fileExists(localPath);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<String> _buildLocalAudioPath({required int surahNumber, required int ayahNumber}) async {
    final dirPath = await getApplicationDocumentsDirectoryPath();
    if (dirPath.isEmpty) {
      return '';
    }
    return '$dirPath/quran_${_qariCode}_${surahNumber.toString().padLeft(3, '0')}_${ayahNumber.toString().padLeft(3, '0')}.mp3';
  }

  Future<String?> resolveAudioUrl({required int surahNumber, required int ayahNumber}) async {
    final editionCandidates = _editionCandidatesForQari();
    for (final edition in editionCandidates) {
      try {
        final url = 'https://api.alquran.cloud/v1/ayah/$surahNumber:$ayahNumber/$edition';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final data = decoded['data'];
            final audioUrl = data is Map<String, dynamic> ? data['audio']?.toString() : null;
            if (audioUrl != null && audioUrl.isNotEmpty) {
              return audioUrl;
            }
          }
        }
      } catch (_) {}
    }

    try {
      final verseNumber = await _readVerseNumberFromAsset(surahNumber: surahNumber, ayahNumber: ayahNumber);
      if (verseNumber > 0) {
        final edition = editionCandidates.firstWhere((candidate) => candidate.isNotEmpty, orElse: () => 'ar.alafasy');
        return 'https://cdn.islamic.network/quran/audio/128/$edition/$verseNumber.mp3';
      }
    } catch (_) {}

    return null;
  }

  Future<int> _readVerseNumberFromAsset({required int surahNumber, required int ayahNumber}) async {
    final raw = await rootBundle.loadString('assets/data/quran_complete.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return 0;
    }

    final data = decoded['data'];
    if (data is! List) {
      return 0;
    }

    for (final entry in data.whereType<Map<String, dynamic>>()) {
      final number = int.tryParse(entry['number']?.toString() ?? '') ?? 0;
      if (number == surahNumber) {
        final ayahs = entry['ayahs'];
        if (ayahs is List) {
          for (final ayah in ayahs.whereType<Map<String, dynamic>>()) {
            final currentAyahNumber = int.tryParse(ayah['numberInSurah']?.toString() ?? '') ?? 0;
            if (currentAyahNumber == ayahNumber) {
              return int.tryParse(ayah['number']?.toString() ?? '') ?? 0;
            }
          }
        }
        break;
      }
    }

    return 0;
  }

  List<String> _editionCandidatesForQari() {
    switch (_qariCode.toLowerCase()) {
      case 'abdullah_basfar':
      case 'abdullahbasfar':
        return <String>['ar.abdullahbasfar', 'ar.alafasy'];
      case 'mishary_alafasy':
      case 'alafasy':
        return <String>['ar.alafasy', 'ar.abdullahbasfar'];
      case 'sahl_yassin':
      case 'sahl':
      case 'sahlyassine':
        return <String>['ar.sahlyassine', 'ar.alafasy'];
      default:
        return <String>['ar.alafasy', 'ar.abdullahbasfar'];
    }
  }
}
