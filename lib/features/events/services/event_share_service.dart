import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class EventShareService {
  const EventShareService();

  Future<void> shareCardImage(Uint8List pngBytes) async {
    final Directory dir = await getTemporaryDirectory();
    final File image = File('${dir.path}/event_counter_share.png');
    await image.writeAsBytes(pngBytes, flush: true);

    await Share.shareXFiles(
      <XFile>[XFile(image.path)],
      text: 'Shared from Event Counter',
    );
  }

  Widget buildShareCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: 1080,
      height: 1350,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[color.withValues(alpha: 0.85), const Color(0xFF0B2524)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Spacer(),
          Text(emoji, style: const TextStyle(fontSize: 96)),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 36),
          ),
          const Spacer(),
          const Text(
            'Event Counter',
            style: TextStyle(color: Colors.white70, fontSize: 28),
          ),
        ],
      ),
    );
  }
}
