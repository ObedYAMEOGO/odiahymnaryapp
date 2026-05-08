import 'dart:async' show Future;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// Enum to identify the type of text block
enum LyricType { verse, refrain }

// A block holds both the text and its type
class LyricBlock {
  LyricBlock({required this.type, required this.text});
  final LyricType type;
  final String text;
}

class Song {
  Song(this.number, this.title, this.lyrics);

  final int number;
  final String title;
  // Changed from List<String> to List<LyricBlock>
  final List<LyricBlock> lyrics;
}

class ContentStorage {
  Future<Map<String, dynamic>?> readFile() async {
    try {
      String result = await rootBundle.loadString('assets/hymn.json');
      return json.decode(result);
    } catch (e) {
      debugPrint('Error reading hymn.json: $e');
      return null;
    }
  }
}