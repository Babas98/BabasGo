import 'package:flutter/material.dart';

class SholatScreen extends StatelessWidget {
  const SholatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Sholat"),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text(
          "🕌 Jadwal Sholat\n\nSegera Hadir",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
                                                                                                                                        