import 'dart:convert';
import 'package:dio/dio.dart';
import '../../model/manga_translation.dart';
import '../log.dart';
import 'translation_engine_base.dart';

class FreeGoogleEngine implements TranslationEngine {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  @override
  String get id => 'free_google';

  @override
  String get name => 'Google 网页免费翻译 (免Key)';

  @override
  Future<List<MangaBubble>> translateBubbles({
    required List<MangaBubble> bubbles,
    required String targetLanguage,
  }) async {
    if (bubbles.isEmpty) return [];

    final String lang = _normalizeTargetLanguage(targetLanguage);
    final List<MangaBubble> results = [];

    // Translate each bubble sequentially or concurrently with small batches
    for (final bubble in bubbles) {
      final String raw = bubble.originalText.trim();
      if (raw.isEmpty) {
        results.add(bubble);
        continue;
      }

      try {
        final String translated = await _translateSingleText(raw, lang);
        results.add(bubble.copyWith(translatedText: translated.isNotEmpty ? translated : raw));
      } catch (e) {
        log.warning('Free Google translation failed for bubble: $raw', e);
        results.add(bubble);
      }
    }

    return results;
  }

  Future<String> _translateSingleText(String text, String targetLang) async {
    final response = await _dio.get(
      'https://translate.googleapis.com/translate_a/single',
      queryParameters: {
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLang,
        'dt': 't',
        'q': text,
      },
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        responseType: ResponseType.plain,
      ),
    );

    final raw = response.data?.toString();
    if (raw == null || raw.isEmpty) return '';

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
        final StringBuffer sb = StringBuffer();
        for (var part in decoded[0]) {
          if (part is List && part.isNotEmpty && part[0] != null) {
            sb.write(part[0].toString());
          }
        }
        return sb.toString().trim();
      }
    } catch (_) {}

    return '';
  }

  String _normalizeTargetLanguage(String code) {
    if (code.toLowerCase().startsWith('zh')) {
      if (code.toLowerCase().contains('tw') || code.toLowerCase().contains('hk')) {
        return 'zh-TW';
      }
      return 'zh-CN';
    }
    if (code.toLowerCase().startsWith('en')) {
      return 'en';
    }
    return 'zh-CN';
  }
}
