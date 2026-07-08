import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/tafsir_model.dart';

class TafsirService {
  Future<List<TafsirEntry>> fetchTafsirForSurah(int surahNumber) async {
    try {
      final raw = await rootBundle.loadString('assets/data/tafsir_jalalain.json');
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(TafsirEntry.fromJson)
            .where((entry) => entry.surahNumber == surahNumber)
            .toList();
      }

      if (decoded is Map<String, dynamic>) {
        final surahs = decoded['surahs'];
        if (surahs is List) {
          final surahJson = surahs.whereType<Map<String, dynamic>>().firstWhere(
                (entry) => _parseInt(entry['number']) == surahNumber,
                orElse: () => <String, dynamic>{},
              );

          if (surahJson.isNotEmpty) {
            final ayahs = surahJson['ayahs'] is List ? surahJson['ayahs'] as List : <dynamic>[];
            return ayahs
                .whereType<Map<String, dynamic>>()
                .map((entry) => TafsirEntry(
                      surahNumber: surahNumber,
                      ayahNumber: _parseInt(entry['ayah']),
                      title: 'Ayat ${_parseInt(entry['ayah'])}',
                      content: entry['text']?.toString() ?? '',
                    ))
                .toList();
          }
        }

        final entries = decoded['data'];
        if (entries is List) {
          return entries
              .whereType<Map<String, dynamic>>()
              .map(TafsirEntry.fromJson)
              .where((entry) => entry.surahNumber == surahNumber)
              .toList();
        }
      }
    } catch (_) {
      // Tafsir dataset belum tersedia; UI will display a safe placeholder.
    }

    return const <TafsirEntry>[];
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
