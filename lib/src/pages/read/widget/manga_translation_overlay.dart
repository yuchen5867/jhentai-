import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../model/manga_translation.dart';
import '../../../service/manga_translation_service.dart';
import '../../../setting/manga_translation_setting.dart';
import '../../../utils/toast_util.dart';
import '../../../widget/loading_state_indicator.dart';

class MangaTranslationOverlay extends StatelessWidget {
  final int gid;
  final int pageIndex;
  final double containerWidth;
  final double containerHeight;
  final File? imageFile;

  const MangaTranslationOverlay({
    Key? key,
    required this.gid,
    required this.pageIndex,
    required this.containerWidth,
    required this.containerHeight,
    this.imageFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!mangaTranslationSetting.enableTranslation.value) {
        return const SizedBox();
      }

      return GetBuilder<MangaTranslationService>(
        id: '${MangaTranslationService.translationUpdateId}::$gid::$pageIndex',
        builder: (service) {
          final PageTranslation? translation = service.getCachedTranslation(gid, pageIndex);
          final LoadingState state = service.getLoadingState(gid, pageIndex);

          // If no cache and not loading, trigger translation automatically if image exists
          if (translation == null && state == LoadingState.idle && imageFile != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              service.translatePage(gid: gid, pageIndex: pageIndex, imageFile: imageFile!);
            });
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Bubble inpainting and text overlays
              if (translation != null && translation.bubbles.isNotEmpty)
                for (final bubble in translation.bubbles)
                  _buildBubbleOverlay(context, bubble),

              // Status indicator (loading / error) in upper-right corner
              if (state == LoadingState.loading)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildLoadingBadge(),
                ),

              if (state == LoadingState.error)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildErrorBadge(service),
                ),
            ],
          );
        },
      );
    });
  }

  Widget _buildBubbleOverlay(BuildContext context, MangaBubble bubble) {
    final double left = (bubble.xmin / 1000.0) * containerWidth;
    final double top = (bubble.ymin / 1000.0) * containerHeight;
    final double width = ((bubble.xmax - bubble.xmin) / 1000.0) * containerWidth;
    final double height = ((bubble.ymax - bubble.ymin) / 1000.0) * containerHeight;

    if (width <= 0 || height <= 0) return const SizedBox();

    final Color bgColor = Color(bubble.bgColor ?? mangaTranslationSetting.bubbleColor.value)
        .withOpacity(mangaTranslationSetting.bubbleOpacity.value);
    final Color textColor = Color(mangaTranslationSetting.textColor.value);
    final double baseFontSize = (13.0 * mangaTranslationSetting.fontSizeScale.value).clamp(9.0, 24.0);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onLongPress: () => _showBubbleDetailsDialog(context, bubble),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.black.withOpacity(0.12),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bubble.translatedText.isNotEmpty ? bubble.translatedText : bubble.originalText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: baseFontSize,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text('translating'.tr, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildErrorBadge(MangaTranslationService service) {
    return GestureDetector(
      onTap: () {
        if (imageFile != null) {
          service.translatePage(
            gid: gid,
            pageIndex: pageIndex,
            imageFile: imageFile!,
            forceRefresh: true,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text('translationFailed'.tr, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showBubbleDetailsDialog(BuildContext context, MangaBubble bubble) {
    Get.dialog(
      AlertDialog(
        title: Text('dialogueDetail'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('originalText'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            SelectableText(
              bubble.originalText.isNotEmpty ? bubble.originalText : '(无)',
              style: const TextStyle(fontSize: 14),
            ),
            const Divider(height: 20),
            Text('translatedText'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            SelectableText(
              bubble.translatedText.isNotEmpty ? bubble.translatedText : '(无)',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: bubble.translatedText));
              toast('copied'.tr);
              Get.back();
            },
            child: Text('copyTranslation'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: Text('close'.tr),
          ),
        ],
      ),
    );
  }
}
