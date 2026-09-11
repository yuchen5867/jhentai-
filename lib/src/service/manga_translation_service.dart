import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import '../model/manga_translation.dart';
import '../setting/manga_translation_setting.dart';
import '../utils/eh_executor.dart';
import '../widget/loading_state_indicator.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';
import 'storage_service.dart';
import 'translation/free_google_engine.dart';
import 'translation/manga_image_translator_engine.dart';
import 'translation/manga_ocr_engine.dart';
import 'translation/openai_text_engine.dart';
import 'translation/translation_engine_base.dart';

MangaTranslationService mangaTranslationService = MangaTranslationService();

class MangaTranslationService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String translationUpdateId = 'translationUpdateId';

  final OpenAiTextEngine _openAiEngine = OpenAiTextEngine();
  final FreeGoogleEngine _googleEngine = FreeGoogleEngine();
  final MangaImageTranslatorEngine _mitEngine = MangaImageTranslatorEngine();

  final EHExecutor _executor = EHExecutor(concurrency: 2);

  final Map<String, PageTranslation> _memoryCache = {};
  final Map<String, LoadingState> _pageStates = {};
  final Map<String, Future<PageTranslation?>> _inFlightTasks = {};

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies
    ..add(storageService)
    ..add(pathService)
    ..add(mangaTranslationSetting);

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
    await mangaOcrEngine.isModelAvailable();
  }

  @override
  Future<void> doAfterBeanReady() async {}

  String _cacheKey(int gid, int pageIndex) => '${gid}_$pageIndex';

  LoadingState getLoadingState(int gid, int pageIndex) {
    return _pageStates[_cacheKey(gid, pageIndex)] ?? LoadingState.idle;
  }

  PageTranslation? getCachedTranslation(int gid, int pageIndex) {
    return _memoryCache[_cacheKey(gid, pageIndex)];
  }

  Future<File> _getCacheFile(int gid, int pageIndex) async {
    final Directory base = pathService.getVisibleDir();
    final Directory galleryDir = Directory(p.join(base.path, 'translation_cache', '$gid'));
    if (!await galleryDir.exists()) {
      await galleryDir.create(recursive: true);
    }
    return File(p.join(galleryDir.path, '$pageIndex.json'));
  }

  /// Request translation for a given page, using cache if available
  Future<PageTranslation?> translatePage({
    required int gid,
    required int pageIndex,
    required File imageFile,
    bool forceRefresh = false,
  }) async {
    final String key = _cacheKey(gid, pageIndex);

    if (!forceRefresh) {
      if (_memoryCache.containsKey(key)) {
        return _memoryCache[key];
      }

      // Check file cache on disk
      try {
        final File cacheFile = await _getCacheFile(gid, pageIndex);
        if (await cacheFile.exists()) {
          final String content = await cacheFile.readAsString();
          final translation = PageTranslation.fromJsonString(content);
          _memoryCache[key] = translation;
          _pageStates[key] = LoadingState.success;
          update(['$translationUpdateId::$gid::$pageIndex']);
          return translation;
        }
      } catch (e) {
        log.warn('Failed reading translation cache for gid=$gid, page=$pageIndex', e);
      }
    }

    if (_inFlightTasks.containsKey(key)) {
      return _inFlightTasks[key];
    }

    _pageStates[key] = LoadingState.loading;
    update(['$translationUpdateId::$gid::$pageIndex']);

    final future = _executor.scheduleTask(0, () async {
      try {
        final translation = await _executeTranslationPipeline(
          gid: gid,
          pageIndex: pageIndex,
          imageFile: imageFile,
        );

        if (translation != null) {
          _memoryCache[key] = translation;
          _pageStates[key] = LoadingState.success;

          // Write to disk cache
          try {
            final File cacheFile = await _getCacheFile(gid, pageIndex);
            await cacheFile.writeAsString(translation.toJsonString());
          } catch (e) {
            log.warn('Failed writing translation cache to disk', e);
          }
        } else {
          _pageStates[key] = LoadingState.idle;
        }

        return translation;
      } catch (e) {
        log.error('Translation failed for gid=$gid, page=$pageIndex', e);
        _pageStates[key] = LoadingState.error;
        return null;
      } finally {
        _inFlightTasks.remove(key);
        update(['$translationUpdateId::$gid::$pageIndex']);
      }
    });

    _inFlightTasks[key] = future;
    return future;
  }

  Future<PageTranslation?> _executeTranslationPipeline({
    required int gid,
    required int pageIndex,
    required File imageFile,
  }) async {
    final engineType = mangaTranslationSetting.engineType.value;
    final targetLang = mangaTranslationSetting.targetLanguage.value;

    List<MangaBubble> bubbles = [];

    // Branch 1: If user chose manga-image-translator dedicated server
    if (engineType == MangaTranslationEngineType.mangaImageTranslator) {
      bubbles = await _mitEngine.translateImageFile(
        imageFile: imageFile,
        targetLanguage: targetLang,
      );
      return PageTranslation(
        pageIndex: pageIndex,
        bubbles: bubbles,
        translatedAt: DateTime.now(),
        engine: _mitEngine.id,
      );
    }

    // Branch 2: Local OCR bubble detection first
    bubbles = await mangaOcrEngine.detectAndRecognize(imageFile: imageFile);

    if (bubbles.isEmpty) {
      return PageTranslation(
        pageIndex: pageIndex,
        bubbles: [],
        translatedAt: DateTime.now(),
        engine: 'empty',
      );
    }

    // Translate extracted text bubbles
    List<MangaBubble> translatedBubbles;
    String engineId;

    if (engineType == MangaTranslationEngineType.openaiText) {
      translatedBubbles = await _openAiEngine.translateBubbles(
        bubbles: bubbles,
        targetLanguage: targetLang,
      );
      engineId = _openAiEngine.id;
    } else {
      translatedBubbles = await _googleEngine.translateBubbles(
        bubbles: bubbles,
        targetLanguage: targetLang,
      );
      engineId = _googleEngine.id;
    }

    return PageTranslation(
      pageIndex: pageIndex,
      bubbles: translatedBubbles,
      translatedAt: DateTime.now(),
      engine: engineId,
    );
  }

  /// Preload next page translation silently in background
  void preloadNextPage({
    required int gid,
    required int nextPageIndex,
    File? nextImageFile,
  }) {
    if (!mangaTranslationSetting.autoPreloadNextPage.value) return;
    if (nextImageFile == null || !nextImageFile.existsSync()) return;

    final String key = _cacheKey(gid, nextPageIndex);
    if (_memoryCache.containsKey(key) || _inFlightTasks.containsKey(key)) return;

    translatePage(
      gid: gid,
      pageIndex: nextPageIndex,
      imageFile: nextImageFile,
    );
  }

  /// Clear disk and memory translation cache for a gallery
  Future<void> clearGalleryCache(int gid) async {
    _memoryCache.removeWhere((key, _) => key.startsWith('${gid}_'));
    _pageStates.removeWhere((key, _) => key.startsWith('${gid}_'));

    try {
      final Directory base = pathService.getVisibleDir();
      final Directory galleryDir = Directory(p.join(base.path, 'translation_cache', '$gid'));
      if (await galleryDir.exists()) {
        await galleryDir.delete(recursive: true);
      }
    } catch (e) {
      log.error('Failed clearing gallery translation cache for gid=$gid', e);
    }
  }
}
