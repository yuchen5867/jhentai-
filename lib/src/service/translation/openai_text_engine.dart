import 'dart:convert';
import 'package:dio/dio.dart';
import '../../model/manga_translation.dart';
import '../../setting/manga_translation_setting.dart';
import '../log.dart';
import 'translation_engine_base.dart';

class OpenAiTextEngine implements TranslationEngine {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 40),
    ),
  );

  @override
  String get id => 'openai_text';

  @override
  String get name => 'OpenAI 兼容文本大模型';

  @override
  Future<List<MangaBubble>> translateBubbles({
    required List<MangaBubble> bubbles,
    required String targetLanguage,
  }) async {
    if (bubbles.isEmpty) return [];

    final String baseUrl = mangaTranslationSetting.openaiBaseUrl.value.trim().replaceAll(RegExp(r'/+$'), '');
    final String apiKey = mangaTranslationSetting.openaiApiKey.value.trim();
    final String model = mangaTranslationSetting.openaiModel.value.trim();
    final double temperature = mangaTranslationSetting.openaiTemperature.value;
    final String systemPrompt = mangaTranslationSetting.openaiSystemPrompt.value;

    final String endpoint = '$baseUrl/chat/completions';

    // Prepare batched inputs with unique IDs
    final List<Map<String, dynamic>> promptItems = [];
    for (int i = 0; i < bubbles.length; i++) {
      if (bubbles[i].originalText.trim().isNotEmpty) {
        promptItems.add({'id': i, 'text': bubbles[i].originalText.trim()});
      }
    }

    if (promptItems.isEmpty) return bubbles;

    final String userContent = '''
请将以下漫画气泡内的对白翻译为目标语言：$targetLanguage。
保持生动、贴合角色口吻，如果是拟声词或拟态词请做地道汉化。
请严格输出一个 JSON 数组，每个元素包含 id 和 text（翻译结果），不要输出任何其他解释或标记。

输入数据：
${jsonEncode(promptItems)}
''';

    try {
      final Map<String, dynamic> requestBody = {
        'model': model.isNotEmpty ? model : 'deepseek-chat',
        'temperature': temperature,
        'messages': [
          if (systemPrompt.isNotEmpty) {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
      };

      final response = await _dio.post(
        endpoint,
        data: requestBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
        ),
      );

      final responseData = response.data;
      String? rawContent;
      if (responseData is Map && responseData['choices'] is List && (responseData['choices'] as List).isNotEmpty) {
        rawContent = responseData['choices'][0]['message']?['content']?.toString();
      }

      if (rawContent == null || rawContent.isEmpty) {
        log.error('OpenAI translation response content is empty: $responseData');
        return bubbles;
      }

      // Parse JSON from response, stripping possible markdown wrappers
      final List<dynamic> parsedList = _parseJsonArray(rawContent);
      final Map<int, String> translationMap = {};
      for (var item in parsedList) {
        if (item is Map && item.containsKey('id') && item.containsKey('text')) {
          final int id = (item['id'] as num).toInt();
          final String text = item['text']?.toString() ?? '';
          translationMap[id] = text;
        }
      }

      final List<MangaBubble> result = [];
      for (int i = 0; i < bubbles.length; i++) {
        final String? translated = translationMap[i];
        if (translated != null && translated.isNotEmpty) {
          result.add(bubbles[i].copyWith(translatedText: translated));
        } else {
          result.add(bubbles[i]);
        }
      }
      return result;
    } catch (e) {
      log.error('OpenAI translation request error', e);
      rethrow;
    }
  }

  List<dynamic> _parseJsonArray(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      int firstLineBreak = cleaned.indexOf('\n');
      if (firstLineBreak != -1) {
        cleaned = cleaned.substring(firstLineBreak + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    int startIndex = cleaned.indexOf('[');
    int endIndex = cleaned.lastIndexOf(']');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      cleaned = cleaned.substring(startIndex, endIndex + 1);
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) return decoded;
    } catch (_) {}
    return [];
  }
}
