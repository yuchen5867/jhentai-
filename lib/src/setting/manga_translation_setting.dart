import 'dart:convert';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/log.dart';

MangaTranslationSetting mangaTranslationSetting = MangaTranslationSetting();

enum MangaTranslationEngineType {
  openaiText('OpenAI 兼容文本大模型'),
  freeGoogle('Google 网页免费翻译 (免Key)'),
  mangaImageTranslator('manga-image-translator 服务端');

  final String label;
  const MangaTranslationEngineType(this.label);
}

enum MangaOcrEngineType {
  localMangaOcr('本地 Manga-OCR (离线识别)'),
  fastContour('轻量气泡几何检测');

  final String label;
  const MangaOcrEngineType(this.label);
}

class MangaTranslationSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxBool enableTranslation = false.obs;
  Rx<MangaTranslationEngineType> engineType = MangaTranslationEngineType.openaiText.obs;
  Rx<MangaOcrEngineType> ocrEngineType = MangaOcrEngineType.localMangaOcr.obs;

  /// OpenAI compatible text completion configuration
  RxString openaiBaseUrl = 'https://api.deepseek.com/v1'.obs;
  RxString openaiApiKey = ''.obs;
  RxString openaiModel = 'deepseek-chat'.obs;
  RxString openaiSystemPrompt =
      '你是一个专业的漫画汉化翻译助手。请将以下日文对白翻译为地道、自然的简体中文。注意结合漫画语境，准确传达角色的语气、情绪与俚语。直接按给定JSON格式输出，不要附加任何其他说明。'
          .obs;
  RxDouble openaiTemperature = 0.3.obs;

  /// manga-image-translator endpoint URL
  RxString mitServerUrl = 'http://127.0.0.1:5003'.obs;

  /// Local Manga-OCR model info
  RxnString localOcrModelPath = RxnString(null);
  RxBool isModelDownloaded = false.obs;

  /// Appearance and layout settings
  RxDouble bubbleOpacity = 0.95.obs;
  RxInt bubbleColor = 0xFFFFFFFF.obs;
  RxInt textColor = 0xFF000000.obs;
  RxDouble fontSizeScale = 1.0.obs;
  RxBool autoPreloadNextPage = true.obs;
  RxString targetLanguage = 'zh-CN'.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.mangaTranslationSetting;

  @override
  void applyBeanConfig(String configString) {
    try {
      Map<String, dynamic> map = jsonDecode(configString) as Map<String, dynamic>;

      enableTranslation.value = map['enableTranslation'] ?? false;
      if (map['engineType'] != null && map['engineType'] < MangaTranslationEngineType.values.length) {
        engineType.value = MangaTranslationEngineType.values[map['engineType']];
      }
      if (map['ocrEngineType'] != null && map['ocrEngineType'] < MangaOcrEngineType.values.length) {
        ocrEngineType.value = MangaOcrEngineType.values[map['ocrEngineType']];
      }

      openaiBaseUrl.value = map['openaiBaseUrl'] ?? openaiBaseUrl.value;
      openaiApiKey.value = map['openaiApiKey'] ?? openaiApiKey.value;
      openaiModel.value = map['openaiModel'] ?? openaiModel.value;
      openaiSystemPrompt.value = map['openaiSystemPrompt'] ?? openaiSystemPrompt.value;
      openaiTemperature.value = (map['openaiTemperature'] as num?)?.toDouble() ?? openaiTemperature.value;

      mitServerUrl.value = map['mitServerUrl'] ?? mitServerUrl.value;
      localOcrModelPath.value = map['localOcrModelPath'];
      isModelDownloaded.value = map['isModelDownloaded'] ?? false;

      bubbleOpacity.value = (map['bubbleOpacity'] as num?)?.toDouble() ?? bubbleOpacity.value;
      bubbleColor.value = map['bubbleColor'] ?? bubbleColor.value;
      textColor.value = map['textColor'] ?? textColor.value;
      fontSizeScale.value = (map['fontSizeScale'] as num?)?.toDouble() ?? fontSizeScale.value;
      autoPreloadNextPage.value = map['autoPreloadNextPage'] ?? autoPreloadNextPage.value;
      targetLanguage.value = map['targetLanguage'] ?? targetLanguage.value;
    } catch (e) {
      log.error('Apply MangaTranslationSetting failed', e);
    }
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'enableTranslation': enableTranslation.value,
      'engineType': engineType.value.index,
      'ocrEngineType': ocrEngineType.value.index,
      'openaiBaseUrl': openaiBaseUrl.value,
      'openaiApiKey': openaiApiKey.value,
      'openaiModel': openaiModel.value,
      'openaiSystemPrompt': openaiSystemPrompt.value,
      'openaiTemperature': openaiTemperature.value,
      'mitServerUrl': mitServerUrl.value,
      'localOcrModelPath': localOcrModelPath.value,
      'isModelDownloaded': isModelDownloaded.value,
      'bubbleOpacity': bubbleOpacity.value,
      'bubbleColor': bubbleColor.value,
      'textColor': textColor.value,
      'fontSizeScale': fontSizeScale.value,
      'autoPreloadNextPage': autoPreloadNextPage.value,
      'targetLanguage': targetLanguage.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveEnableTranslation(bool enable) async {
    enableTranslation.value = enable;
    await saveBeanConfig();
  }

  Future<void> saveEngineType(MangaTranslationEngineType type) async {
    engineType.value = type;
    await saveBeanConfig();
  }

  Future<void> saveOcrEngineType(MangaOcrEngineType type) async {
    ocrEngineType.value = type;
    await saveBeanConfig();
  }

  Future<void> saveOpenAiConfig({
    String? baseUrl,
    String? apiKey,
    String? model,
    String? systemPrompt,
    double? temperature,
  }) async {
    if (baseUrl != null) openaiBaseUrl.value = baseUrl;
    if (apiKey != null) openaiApiKey.value = apiKey;
    if (model != null) openaiModel.value = model;
    if (systemPrompt != null) openaiSystemPrompt.value = systemPrompt;
    if (temperature != null) openaiTemperature.value = temperature;
    await saveBeanConfig();
  }

  Future<void> saveMitServerUrl(String url) async {
    mitServerUrl.value = url;
    await saveBeanConfig();
  }

  Future<void> saveAppearanceConfig({
    double? opacity,
    int? bColor,
    int? tColor,
    double? scale,
    bool? preload,
  }) async {
    if (opacity != null) bubbleOpacity.value = opacity;
    if (bColor != null) bubbleColor.value = bColor;
    if (tColor != null) textColor.value = tColor;
    if (scale != null) fontSizeScale.value = scale;
    if (preload != null) autoPreloadNextPage.value = preload;
    await saveBeanConfig();
  }
}
