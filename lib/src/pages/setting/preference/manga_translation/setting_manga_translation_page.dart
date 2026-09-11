import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/manga_translation_service.dart';
import 'package:jhentai/src/service/translation/manga_ocr_engine.dart';
import 'package:jhentai/src/setting/manga_translation_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';

class SettingMangaTranslationPage extends StatefulWidget {
  const SettingMangaTranslationPage({Key? key}) : super(key: key);

  @override
  State<SettingMangaTranslationPage> createState() => _SettingMangaTranslationPageState();
}

class _SettingMangaTranslationPageState extends State<SettingMangaTranslationPage> {
  double _downloadProgress = 0.0;
  String _downloadInfo = '';
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('mangaTranslation'.tr),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            _buildEnableTranslation(),
            const Divider(),
            _buildEngineType(),
            if (mangaTranslationSetting.engineType.value == MangaTranslationEngineType.openaiText) ...[
              _buildOpenAiBaseUrl(),
              _buildOpenAiApiKey(),
              _buildOpenAiModel(),
              _buildOpenAiTemperature(),
              _buildOpenAiSystemPrompt(),
            ],
            if (mangaTranslationSetting.engineType.value == MangaTranslationEngineType.mangaImageTranslator) ...[
              _buildMitServerUrl(),
            ],
            const Divider(),
            _buildMangaOcrModel(),
            const Divider(),
            _buildAppearanceSection(),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildEnableTranslation() {
    return SwitchListTile(
      title: Text('enableMangaTranslation'.tr),
      subtitle: Text('enableMangaTranslationHint'.tr),
      value: mangaTranslationSetting.enableTranslation.value,
      onChanged: (val) => mangaTranslationSetting.saveEnableTranslation(val),
    );
  }

  Widget _buildEngineType() {
    return ListTile(
      title: Text('translationEngine'.tr),
      subtitle: Text(mangaTranslationSetting.engineType.value.label),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Get.dialog(
          SimpleDialog(
            title: Text('selectEngine'.tr),
            children: MangaTranslationEngineType.values
                .map(
                  (engine) => RadioListTile<MangaTranslationEngineType>(
                    title: Text(engine.label),
                    value: engine,
                    groupValue: mangaTranslationSetting.engineType.value,
                    onChanged: (val) {
                      if (val != null) {
                        mangaTranslationSetting.saveEngineType(val);
                        Get.back();
                      }
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildOpenAiBaseUrl() {
    return ListTile(
      title: const Text('API Base URL'),
      subtitle: Text(
        mangaTranslationSetting.openaiBaseUrl.value.isNotEmpty
            ? mangaTranslationSetting.openaiBaseUrl.value
            : '未设置 (默认 https://api.deepseek.com/v1)',
      ),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: () => _showTextInputDialog(
        title: '设置 API Base URL',
        initialValue: mangaTranslationSetting.openaiBaseUrl.value,
        hintText: '如 https://api.deepseek.com/v1 或 本地反代',
        onConfirm: (val) => mangaTranslationSetting.saveOpenAiConfig(baseUrl: val.trim()),
      ),
    );
  }

  Widget _buildOpenAiApiKey() {
    final String key = mangaTranslationSetting.openaiApiKey.value;
    final String masked = key.isEmpty
        ? '未配置 (点击输入)'
        : (key.length > 8 ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}' : '********');

    return ListTile(
      title: const Text('API Key'),
      subtitle: Text(masked),
      trailing: const Icon(Icons.key, size: 18),
      onTap: () => _showTextInputDialog(
        title: '设置 API Key',
        initialValue: key,
        hintText: 'sk-...',
        isPassword: true,
        onConfirm: (val) => mangaTranslationSetting.saveOpenAiConfig(apiKey: val.trim()),
      ),
    );
  }

  Widget _buildOpenAiModel() {
    return ListTile(
      title: const Text('模型名称 (Model)'),
      subtitle: Text(mangaTranslationSetting.openaiModel.value),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: () => _showTextInputDialog(
        title: '设置模型名称',
        initialValue: mangaTranslationSetting.openaiModel.value,
        hintText: '如 deepseek-chat, qwen-2.5-72b, gpt-4o-mini',
        onConfirm: (val) => mangaTranslationSetting.saveOpenAiConfig(model: val.trim()),
      ),
    );
  }

  Widget _buildOpenAiTemperature() {
    return ListTile(
      title: const Text('采样温度 (Temperature)'),
      subtitle: Text('${mangaTranslationSetting.openaiTemperature.value.toStringAsFixed(2)} (越低越稳定精准)'),
      trailing: SizedBox(
        width: 160,
        child: Slider(
          value: mangaTranslationSetting.openaiTemperature.value,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          onChanged: (val) => mangaTranslationSetting.saveOpenAiConfig(temperature: val),
        ),
      ),
    );
  }

  Widget _buildOpenAiSystemPrompt() {
    return ListTile(
      title: const Text('系统提示词 (Prompt)'),
      subtitle: Text(
        mangaTranslationSetting.openaiSystemPrompt.value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: () => _showTextInputDialog(
        title: '自定义系统提示词',
        initialValue: mangaTranslationSetting.openaiSystemPrompt.value,
        maxLines: 5,
        onConfirm: (val) => mangaTranslationSetting.saveOpenAiConfig(systemPrompt: val.trim()),
      ),
    );
  }

  Widget _buildMitServerUrl() {
    return ListTile(
      title: const Text('manga-image-translator 端点'),
      subtitle: Text(mangaTranslationSetting.mitServerUrl.value),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: () => _showTextInputDialog(
        title: '设置 MIT 服务地址',
        initialValue: mangaTranslationSetting.mitServerUrl.value,
        hintText: 'http://192.168.1.100:5003',
        onConfirm: (val) => mangaTranslationSetting.saveMitServerUrl(val.trim()),
      ),
    );
  }

  Widget _buildMangaOcrModel() {
    final bool isDownloaded = mangaTranslationSetting.isModelDownloaded.value;

    return ListTile(
      title: const Text('离线 Manga-OCR 模型'),
      subtitle: _isDownloading
          ? Text('正在下载: $_downloadInfo (${(_downloadProgress * 100).toStringAsFixed(1)}%)')
          : Text(isDownloaded ? '已下载并就绪 (支持离线高精度识别)' : '未下载 (约 45MB，点击一键下载)'),
      trailing: _isDownloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : IconButton(
              icon: Icon(isDownloaded ? Icons.check_circle : Icons.download, color: isDownloaded ? Colors.green : null),
              onPressed: _startDownloadOcrModel,
            ),
    );
  }

  void _startDownloadOcrModel() {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadInfo = '准备下载...';
    });

    mangaOcrEngine.downloadModel(
      onProgress: (progress, info) {
        setState(() {
          _downloadProgress = progress;
          _downloadInfo = info;
        });
      },
      onSuccess: () {
        setState(() {
          _isDownloading = false;
        });
        toast('Manga-OCR 模型下载完成');
      },
      onError: (err) {
        setState(() {
          _isDownloading = false;
        });
        toast('下载失败: $err');
      },
    );
  }

  Widget _buildAppearanceSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('静默预加载下一页翻译'),
          subtitle: const Text('翻页时后台预先完成下一页翻译，阅读更连贯'),
          value: mangaTranslationSetting.autoPreloadNextPage.value,
          onChanged: (val) => mangaTranslationSetting.saveAppearanceConfig(preload: val),
        ),
        ListTile(
          title: const Text('气泡涂白遮罩不透明度'),
          subtitle: Text('${(mangaTranslationSetting.bubbleOpacity.value * 100).toInt()}%'),
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: mangaTranslationSetting.bubbleOpacity.value,
              min: 0.4,
              max: 1.0,
              divisions: 6,
              onChanged: (val) => mangaTranslationSetting.saveAppearanceConfig(opacity: val),
            ),
          ),
        ),
        ListTile(
          title: const Text('译文字号缩放比例'),
          subtitle: Text('${(mangaTranslationSetting.fontSizeScale.value * 100).toInt()}%'),
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: mangaTranslationSetting.fontSizeScale.value,
              min: 0.8,
              max: 1.5,
              divisions: 7,
              onChanged: (val) => mangaTranslationSetting.saveAppearanceConfig(scale: val),
            ),
          ),
        ),
      ],
    );
  }

  void _showTextInputDialog({
    required String title,
    required String initialValue,
    String? hintText,
    bool isPassword = false,
    int maxLines = 1,
    required Function(String) onConfirm,
  }) {
    final TextEditingController controller = TextEditingController(text: initialValue);

    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          maxLines: isPassword ? 1 : maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              onConfirm(controller.text);
              Get.back();
            },
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
  }
}
