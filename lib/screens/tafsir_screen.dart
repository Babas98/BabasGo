import 'package:flutter/material.dart';

import '../models/tafsir_model.dart';
import '../services/tafsir_service.dart';

class TafsirScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;

  const TafsirScreen({super.key, required this.surahNumber, required this.surahName});

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  final TafsirService _service = TafsirService();
  late final Future<List<TafsirEntry>> _tafsirFuture;

  @override
  void initState() {
    super.initState();
    _tafsirFuture = _service.fetchTafsirForSurah(widget.surahNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tafsir ${widget.surahName}')),
      body: FutureBuilder<List<TafsirEntry>>(
        future: _tafsirFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat tafsir. ${snapshot.error}'));
          }

          final entries = snapshot.data ?? const <TafsirEntry>[];
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Tafsir untuk surah ini belum tersedia. Struktur UI sudah siap untuk ditambahkan nanti.'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(entry.content),
                      const SizedBox(height: 8),
                      Text(entry.source, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
