import 'dart:io';
import '../../model/manga_translation.dart';

abstract class TranslationEngine {
  /// Unique identifier of this engine
  String get id;

  /// Human-readable name
  String get name;

  /// Translate a list of extracted text bubbles
  Future<List<MangaBubble>> translateBubbles({
    required List<MangaBubble> bubbles,
    required String targetLanguage,
  });
}
