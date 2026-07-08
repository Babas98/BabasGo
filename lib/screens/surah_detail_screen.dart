import 'package:flutter/material.dart';

import '../models/quran_model.dart';
import '../services/app_settings_service.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_service.dart';
import 'tafsir_screen.dart';

class SurahDetailScreen extends StatefulWidget {
  final SurahDetail detail;
  final int? initialAyahNumber;
  final int? initialPageNumber;

  const SurahDetailScreen({super.key, required this.detail, this.initialAyahNumber, this.initialPageNumber});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final QuranService _service = QuranService();
  final ScrollController _scrollController = ScrollController();
  final AppSettingsService _settingsService = AppSettingsService.instance;
  final QuranAudioService _audioService = QuranAudioService();
  late final PageController _mushafPageController;
  late final List<GlobalKey> _ayahKeys;
  final Map<int, QuranPage> _mushafPageCache = <int, QuranPage>{};
  bool _isSurahBookmarked = false;
  bool _isPageBookmarked = false;
  bool _isJuzBookmarked = false;
  bool _isAudioAvailableOffline = false;
  String? _audioErrorMessage;
  Set<String> _bookmarkedAyahs = <String>{};
  int _currentAyah = 1;
  bool _showMushafMode = true;
  double _mushafZoom = 1.0;
  int _mushafPage = 1;
  bool _isInitializingMushaf = true;
  bool _isLoadingPage = false;

  @override
  void initState() {
    super.initState();
    _ayahKeys = List.generate(widget.detail.arabicAyahs.length, (_) => GlobalKey());
    _settingsService.addListener(_refreshSettings);
    _audioService.onPlaybackStateChanged = _refreshAudioUi;
    _audioService.onPlaybackCompleted = _handlePlaybackCompleted;
    _audioService.onPositionChanged = (position) {
      if (mounted) {
        setState(() => _audioService.position = position);
      }
    };
    _audioService.onDurationChanged = (duration) {
      if (mounted) {
        setState(() => _audioService.duration = duration);
      }
    };
    _audioService.onError = (message) {
      if (mounted) {
        setState(() => _audioErrorMessage = message);
      }
    };
    _mushafPageController = PageController(initialPage: (widget.initialPageNumber ?? 1).clamp(1, 604) - 1);
    _loadPersistedState();
    _applyPersistedAudioPreferences();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_refreshSettings);
    _service.dispose();
    _audioService.dispose();
    _scrollController.dispose();
    _mushafPageController.dispose();
    super.dispose();
  }

  void _refreshSettings() {
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshAudioUi() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPersistedState() async {
    final isBookmarked = await _service.isSurahBookmarked(widget.detail.summary.number);
    final bookmarkedAyahs = await _service.getBookmarkedAyahs();
    final lastRead = await _service.getLastRead();
    final isPageBookmarked = await _service.isPageBookmarked(widget.detail.summary.number, _mushafPage);
    final isJuzBookmarked = await _service.isJuzBookmarked(widget.detail.summary.number);

    final initialAyah = widget.initialAyahNumber ?? 1;
    final currentAyah = (lastRead != null && lastRead['surahNumber'] == widget.detail.summary.number)
        ? (lastRead['ayahNumber'] as int? ?? initialAyah)
        : initialAyah;
    final initialPage = widget.initialPageNumber ?? ((lastRead != null && lastRead['surahNumber'] == widget.detail.summary.number) ? (lastRead['pageNumber'] as int? ?? 1) : await _service.resolvePageForAyah(widget.detail.summary.number, currentAyah));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSurahBookmarked = isBookmarked;
      _bookmarkedAyahs = bookmarkedAyahs;
      _currentAyah = currentAyah;
      _isPageBookmarked = isPageBookmarked;
      _isJuzBookmarked = isJuzBookmarked;
      _mushafPage = initialPage.clamp(1, 604);
      _isInitializingMushaf = false;
    });

    if (_mushafPage > 0) {
      await _loadMushafPage(_mushafPage);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentAyah > 0) {
        _scrollToAyah(_currentAyah);
      }
    });
  }

  Future<void> _toggleSurahBookmark() async {
    await _service.toggleSurahBookmark(widget.detail.summary.number);
    final isBookmarked = await _service.isSurahBookmarked(widget.detail.summary.number);
    if (!mounted) {
      return;
    }
    setState(() => _isSurahBookmarked = isBookmarked);
  }

  Future<void> _toggleAyahBookmark(int ayahNumber) async {
    await _service.toggleAyahBookmark(widget.detail.summary.number, ayahNumber);
    final bookmarkedAyahs = await _service.getBookmarkedAyahs();
    if (!mounted) {
      return;
    }
    setState(() => _bookmarkedAyahs = bookmarkedAyahs);
  }

  Future<void> _togglePageBookmark() async {
    await _service.togglePageBookmark(widget.detail.summary.number, _mushafPage);
    final isPageBookmarked = await _service.isPageBookmarked(widget.detail.summary.number, _mushafPage);
    if (!mounted) {
      return;
    }
    setState(() => _isPageBookmarked = isPageBookmarked);
  }

  Future<void> _toggleJuzBookmark() async {
    await _service.toggleJuzBookmark(widget.detail.summary.number);
    final isJuzBookmarked = await _service.isJuzBookmarked(widget.detail.summary.number);
    if (!mounted) {
      return;
    }
    setState(() => _isJuzBookmarked = isJuzBookmarked);
  }

  Future<void> _markLastRead(int ayahNumber, {int? pageNumber}) async {
    await _service.saveLastRead(widget.detail.summary.number, ayahNumber, widget.detail.summary.englishName, pageNumber: pageNumber);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentAyah = ayahNumber;
      if (pageNumber != null) {
        _mushafPage = pageNumber;
      }
    });
  }

  Future<void> _playAyah(int ayahNumber, {int? pageNumber}) async {
    await _service.markAyahRead(widget.detail.summary.number, ayahNumber);
    await _audioService.playAyah(
      surahNumber: widget.detail.summary.number,
      ayahNumber: ayahNumber,
      totalAyahs: widget.detail.summary.numberOfAyahs,
    );
    await _markLastRead(ayahNumber, pageNumber: pageNumber);
    _scrollToAyah(ayahNumber);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkOfflineAvailability() async {
    final available = await _audioService.isCurrentAudioAvailableOffline();
    if (mounted) {
      setState(() => _isAudioAvailableOffline = available);
    }
  }

  Future<void> _applyPersistedAudioPreferences() async {
    final settings = _settingsService.currentSettings;
    await _audioService.setQari(settings.qariCode, settings.qariName);
    await _audioService.setPlaybackSpeed(settings.playbackSpeed);
    await _checkOfflineAvailability();
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_audioService.repeatSurah) {
      await _audioService.playAyah(
        surahNumber: widget.detail.summary.number,
        ayahNumber: 1,
        totalAyahs: widget.detail.summary.numberOfAyahs,
      );
      return;
    }
    if (_audioService.autoPlay && _audioService.currentAyahNumber < widget.detail.summary.numberOfAyahs) {
      final nextAyah = _audioService.currentAyahNumber + 1;
      final pageNumber = await _service.resolvePageForAyah(widget.detail.summary.number, nextAyah);
      await _playAyah(nextAyah, pageNumber: pageNumber);
      return;
    }
    await _audioService.stop();
  }

  Future<void> _showAsbabunNuzul(int ayahNumber) async {
    final text = await _service.fetchAsbabunNuzul(widget.detail.summary.number, ayahNumber);
    if (!mounted) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asbabun Nuzul Ayat $ayahNumber', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    text ?? 'Asbabun Nuzul belum tersedia untuk ayat ini.',
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleMushafMode() {
    setState(() {
      _showMushafMode = !_showMushafMode;
      if (_showMushafMode) {
        _mushafPageController.jumpToPage((_mushafPage - 1).clamp(0, 603));
      }
    });
  }

  void _scrollToAyah(int ayahNumber) {
    final index = ayahNumber - 1;
    if (index < 0 || index >= _ayahKeys.length) {
      return;
    }

    final targetContext = _ayahKeys[index].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
      return;
    }

    _scrollController.animateTo(
      index * 140.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<QuranPage> _loadMushafPage(int pageNumber) async {
    if (_mushafPageCache.containsKey(pageNumber)) {
      return _mushafPageCache[pageNumber]!;
    }

    setState(() => _isLoadingPage = true);
    final page = await _service.fetchPage(pageNumber);
    _mushafPageCache[pageNumber] = page;
    if (!mounted) {
      return page;
    }
    setState(() {
      _isLoadingPage = false;
      _mushafPage = pageNumber;
    });
    return page;
  }

  Widget _buildMushafView(BuildContext context, AppSettings settings) {
    final totalPages = 604;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _mushafPage > 1
                    ? () async {
                        final nextPage = _mushafPage - 1;
                        await _loadMushafPage(nextPage);
                        _mushafPageController.jumpToPage(nextPage - 1);
                      }
                    : null,
              ),
              Expanded(
                child: Text(
                  'Halaman $_mushafPage / $totalPages',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _mushafPage < totalPages
                    ? () async {
                        final nextPage = _mushafPage + 1;
                        await _loadMushafPage(nextPage);
                        _mushafPageController.jumpToPage(nextPage - 1);
                      }
                    : null,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Zoom', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _mushafZoom,
                  min: 0.9,
                  max: 1.8,
                  divisions: 9,
                  label: '${_mushafZoom.toStringAsFixed(1)}x',
                  onChanged: (value) => setState(() => _mushafZoom = value),
                ),
              ),
              Text('${_mushafZoom.toStringAsFixed(1)}x'),
            ],
          ),
        ),
        if (_isLoadingPage)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                SizedBox(width: 12),
                Text('Memuat halaman mushaf...'),
              ],
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _mushafPageController,
            itemCount: totalPages,
            onPageChanged: (page) async {
              final pageNumber = page + 1;
              setState(() => _mushafPage = pageNumber);
              await _loadMushafPage(pageNumber);
            },
            itemBuilder: (context, pageIndex) {
              final pageNumber = pageIndex + 1;
              final pageData = _mushafPageCache[pageNumber];
              if (pageData == null) {
                return FutureBuilder<QuranPage>(
                  future: _loadMushafPage(pageNumber),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final loadedPage = snapshot.data;
                    if (loadedPage == null) {
                      return const Center(child: Text('Halaman mushaf tidak tersedia.'));
                    }
                    return _buildMushafPageCard(context, settings, loadedPage);
                  },
                );
              }
              return _buildMushafPageCard(context, settings, pageData);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMushafPageCard(BuildContext context, AppSettings settings, QuranPage page) {
    final ayahs = page.ayahs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Text(
                    widget.detail.summary.englishName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Juz ${page.juzNumber > 0 ? page.juzNumber : 1}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Halaman ${page.number}', style: const TextStyle(fontSize: 13)),
                      FilledButton.icon(
                        onPressed: _togglePageBookmark,
                        icon: Icon(_isPageBookmarked ? Icons.bookmark : Icons.bookmark_border),
                        label: Text(_isPageBookmarked ? 'Tersimpan' : 'Bookmark'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: ListView.separated(
                  itemCount: ayahs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ayah = ayahs[index];
                    final isCurrentPlayingAyah = _audioService.currentSurahNumber == widget.detail.summary.number && _audioService.currentAyahNumber == ayah.numberInSurah;
                    return InkWell(
                      onTap: () async {
                        await _playAyah(ayah.numberInSurah, pageNumber: page.number);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCurrentPlayingAyah ? Theme.of(context).colorScheme.primaryContainer : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ayat ${ayah.numberInSurah}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('Juz ${ayah.juz}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ayah.text,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: settings.fontSizeArabic * _mushafZoom,
                                height: 1.7,
                                fontFamily: settings.arabicFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.detail.summary;
    final settings = _settingsService.currentSettings;
    return Scaffold(
      appBar: AppBar(
        title: Text(summary.englishName),
        actions: [
          IconButton(
            icon: Icon(_isSurahBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSurahBookmark,
            tooltip: 'Bookmark surah',
          ),
          IconButton(
            icon: Icon(_showMushafMode ? Icons.view_list : Icons.chrome_reader_mode),
            onPressed: _toggleMushafMode,
            tooltip: 'Mode Mushaf',
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TafsirScreen(
                    surahNumber: summary.number,
                    surahName: summary.englishName,
                  ),
                ),
              );
            },
            tooltip: 'Tafsir',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.englishName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(summary.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('Arti: ${summary.englishNameTranslation}', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text('Jumlah ayat: ${summary.numberOfAyahs}', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text('Makkiyah/Madaniyah: ${summary.revelationType}', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TafsirScreen(
                              surahNumber: summary.number,
                              surahName: summary.englishName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Lihat Tafsir'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _togglePageBookmark,
                      icon: Icon(_isPageBookmarked ? Icons.bookmark : Icons.bookmark_border),
                      label: const Text('Bookmark Halaman'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _toggleJuzBookmark,
                      icon: Icon(_isJuzBookmarked ? Icons.bookmark : Icons.bookmark_border),
                      label: const Text('Bookmark Juz'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Qari: ${_audioService.qariName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(onPressed: _audioService.togglePlayPause, icon: Icon(_audioService.isPlaying ? Icons.pause : Icons.play_arrow)),
                    IconButton(onPressed: _audioService.stop, icon: const Icon(Icons.stop)),
                    IconButton(onPressed: () => _audioService.previousAyah(totalAyahs: widget.detail.summary.numberOfAyahs), icon: const Icon(Icons.skip_previous)),
                    IconButton(onPressed: () => _audioService.nextAyah(totalAyahs: widget.detail.summary.numberOfAyahs), icon: const Icon(Icons.skip_next)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_audioService.isLoading)
                  Row(
                    children: const [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      SizedBox(width: 12),
                      Text('Memuat audio...'),
                    ],
                  ),
                if (!_audioService.isLoading) ...[
                  Slider(
                    value: _audioService.position.inMilliseconds.toDouble().clamp(0, (_audioService.duration?.inMilliseconds.toDouble() ?? 1)),
                    max: (_audioService.duration?.inMilliseconds.toDouble() ?? 1),
                    onChanged: (value) async {
                      await _audioService.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_audioService.position.toString().split('.').first),
                      Text((_audioService.duration ?? Duration.zero).toString().split('.').first),
                    ],
                  ),
                ],
                if (_audioErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Audio gagal: $_audioErrorMessage',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(label: const Text('Auto play'), selected: _audioService.autoPlay, onSelected: (value) async => _audioService.setAutoPlay(value)),
                    ChoiceChip(label: const Text('Repeat ayat'), selected: _audioService.repeatAyah, onSelected: (value) async => _audioService.setRepeatAyah(value)),
                    ChoiceChip(label: const Text('Repeat surah'), selected: _audioService.repeatSurah, onSelected: (value) async => _audioService.setRepeatSurah(value)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final speed in <double>[0.75, 1.0, 1.25, 1.5, 2.0])
                      ChoiceChip(
                        label: Text('${speed.toStringAsFixed(2).replaceAll('.00', '')}x'),
                        selected: (_audioService.playbackSpeed - speed).abs() < 0.001,
                        onSelected: (_) async => _audioService.setPlaybackSpeed(speed),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _audioService.qariCode,
                        decoration: const InputDecoration(labelText: 'Pilih Qari'),
                        items: const [
                          DropdownMenuItem(value: 'abdullah_basfar', child: Text('Abdullah Basfar')),
                          DropdownMenuItem(value: 'mishary_alafasy', child: Text('Mishary Alafasy')),
                          DropdownMenuItem(value: 'sahl_yassin', child: Text('Sahl Yassin')),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            final name = value == 'abdullah_basfar'
                                ? 'Abdullah Basfar'
                                : value == 'mishary_alafasy'
                                    ? 'Mishary Alafasy'
                                    : 'Sahl Yassin';
                            await _audioService.setQari(value, name);
                            await _settingsService.updateQari(value, name);
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.detail.arabicAyahs.isEmpty
                ? const Center(child: Text('Data teks surah belum tersedia untuk surah ini.'))
                : _showMushafMode
                    ? _buildMushafView(context, settings)
                    : Scrollbar(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: widget.detail.arabicAyahs.length,
                          itemBuilder: (context, index) {
                            final arab = widget.detail.arabicAyahs[index];
                            final translit = index < widget.detail.transliterationAyahs.length
                                ? widget.detail.transliterationAyahs[index]
                                : QuranAyah(number: index + 1, numberInSurah: index + 1, juz: 0, text: '');
                            final translation = index < widget.detail.translationAyahs.length
                                ? widget.detail.translationAyahs[index]
                                : QuranAyah(number: index + 1, numberInSurah: index + 1, juz: 0, text: '');
                            final isAyahBookmarked = _bookmarkedAyahs.contains('${summary.number}:${arab.numberInSurah}');
                            final isCurrentPlayingAyah = _audioService.currentSurahNumber == widget.detail.summary.number && _audioService.currentAyahNumber == arab.numberInSurah;
                            return Container(
                              key: _ayahKeys[index],
                              child: Card(
                                color: isCurrentPlayingAyah ? Theme.of(context).colorScheme.primaryContainer : null,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: InkWell(
                                  onTap: () async {
                                    await _markLastRead(arab.numberInSurah);
                                    await _playAyah(arab.numberInSurah);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Ayat ${arab.numberInSurah}',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _showAsbabunNuzul(arab.numberInSurah),
                                              icon: const Icon(Icons.lightbulb_outline),
                                              label: const Text('Asbabun Nuzul'),
                                            ),
                                            IconButton(
                                              icon: Icon(isAyahBookmarked ? Icons.bookmark : Icons.bookmark_border),
                                              onPressed: () => _toggleAyahBookmark(arab.numberInSurah),
                                              tooltip: 'Bookmark ayat',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          arab.text,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: settings.fontSizeArabic,
                                            height: 1.6,
                                            fontFamily: settings.arabicFontFamily,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          translit.text,
                                          style: TextStyle(
                                            fontSize: settings.fontSizeLatin,
                                            color: Colors.black87,
                                            fontFamily: settings.appFontFamily,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          translation.text,
                                          style: TextStyle(
                                            fontSize: settings.fontSizeTranslation,
                                            color: Colors.black54,
                                            fontFamily: settings.appFontFamily,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
