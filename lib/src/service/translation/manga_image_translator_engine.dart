import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../model/manga_translation.dart';
import '../../setting/manga_translation_setting.dart';
import '../log.dart';
import 'translation_engine_base.dart';

class MangaImageTranslatorEngine implements TranslationEngine {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  @override
  String get id => 'manga_image_translator';

  @override
  String get name => 'manga-image-translator 专用服务端';

  @override
  Future<List<MangaBubble>> translateBubbles({
    required List<MangaBubble> bubbles,
    required String targetLanguage,
  }) async {
    // If bubbles are already detected, this engine can also pass through text
    return bubbles;
  }

  /// Translate an entire image file through the manga-image-translator server
  Future<List<MangaBubble>> translateImageFile({
    required File imageFile,
    required String targetLanguage,
  }) async {
    final String serverUrl = mangaTranslationSetting.mitServerUrl.value.trim().replaceAll(RegExp(r'/+$'), '');
    if (serverUrl.isEmpty) {
      throw Exception('manga-image-translator server URL is empty');
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path),
        'target_lang': _mapLanguageCode(targetLanguage),
      });

      final response = await _dio.post(
        '$serverUrl/api/translate',
        data: formData,
        options: Options(responseType: ResponseType.json),
      );

      final data = response.data;
      final List<MangaBubble> bubbles = [];

      if (data is Map && data['result'] is List) {
        for (var item in data['result']) {
          if (item is Map) {
            final List<dynamic>? box = item['box'];
            if (box != null && box.length >= 4) {
              bubbles.add(
                MangaBubble(
                  ymin: (box[0] as num).toDouble(),
                  xmin: (box[1] as num).toDouble(),
                  ymax: (box[2] as num).toDouble(),
                  xmax: (box[3] as num).toDouble(),
                  originalText: item['text']?.toString() ?? '',
                  translatedText: item['translation']?.toString() ?? '',
                  isVertical: item['vertical'] as bool? ?? false,
                ),
              );
            }
          }
        }
      }

      return bubbles;
    } catch (e) {
      log.error('manga-image-translator request failed', e);
      rethrow;
    }
  }

  String _mapLanguageCode(String lang) {
    if (lang.contains('TW') || lang.contains('HK')) return 'CHT';
    if (lang.contains('zh')) return 'CHS';
    if (lang.contains('en')) return 'ENG';
    return 'CHS';
  }
}
