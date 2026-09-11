import 'dart:convert';
import 'package:flutter/material.dart';

/// Represents a single detected speech bubble / text region in a manga page.
class MangaBubble {
  /// Normalized coordinates in range [0, 1000]
  final double ymin;
  final double xmin;
  final double ymax;
  final double xmax;

  /// The original OCR extracted text (e.g. Japanese raw dialogue)
  final String originalText;

  /// The translated text (e.g. Chinese)
  final String translatedText;

  /// Whether the text in the original bubble is vertical
  final bool isVertical;

  /// Optional background color of the bubble (ARGB value)
  final int? bgColor;

  MangaBubble({
    required this.ymin,
    required this.xmin,
    required this.ymax,
    required this.xmax,
    required this.originalText,
    required this.translatedText,
    this.isVertical = false,
    this.bgColor,
  });

  /// Convert normalized coordinates to actual display Rect
  Rect toRect(Size displaySize) {
    double left = (xmin / 1000.0) * displaySize.width;
    double top = (ymin / 1000.0) * displaySize.height;
    double right = (xmax / 1000.0) * displaySize.width;
    double bottom = (ymax / 1000.0) * displaySize.height;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Map<String, dynamic> toJson() {
    return {
      'ymin': ymin,
      'xmin': xmin,
      'ymax': ymax,
      'xmax': xmax,
      'originalText': originalText,
      'translatedText': translatedText,
      'isVertical': isVertical,
      'bgColor': bgColor,
    };
  }

  factory MangaBubble.fromJson(Map<String, dynamic> json) {
    return MangaBubble(
      ymin: (json['ymin'] as num?)?.toDouble() ?? 0.0,
      xmin: (json['xmin'] as num?)?.toDouble() ?? 0.0,
      ymax: (json['ymax'] as num?)?.toDouble() ?? 0.0,
      xmax: (json['xmax'] as num?)?.toDouble() ?? 0.0,
      originalText: json['originalText'] as String? ?? '',
      translatedText: json['translatedText'] as String? ?? '',
      isVertical: json['isVertical'] as bool? ?? false,
      bgColor: json['bgColor'] as int?,
    );
  }

  MangaBubble copyWith({
    double? ymin,
    double? xmin,
    double? ymax,
    double? xmax,
    String? originalText,
    String? translatedText,
    bool? isVertical,
    int? bgColor,
  }) {
    return MangaBubble(
      ymin: ymin ?? this.ymin,
      xmin: xmin ?? this.xmin,
      ymax: ymax ?? this.ymax,
      xmax: xmax ?? this.xmax,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      isVertical: isVertical ?? this.isVertical,
      bgColor: bgColor ?? this.bgColor,
    );
  }
}

/// Represents the translation result for an entire manga page.
class PageTranslation {
  final int pageIndex;
  final List<MangaBubble> bubbles;
  final DateTime translatedAt;
  final String engine;

  PageTranslation({
    required this.pageIndex,
    required this.bubbles,
    required this.translatedAt,
    required this.engine,
  });

  Map<String, dynamic> toJson() {
    return {
      'pageIndex': pageIndex,
      'bubbles': bubbles.map((b) => b.toJson()).toList(),
      'translatedAt': translatedAt.toIso8601String(),
      'engine': engine,
    };
  }

  factory PageTranslation.fromJson(Map<String, dynamic> json) {
    return PageTranslation(
      pageIndex: json['pageIndex'] as int? ?? 0,
      bubbles: (json['bubbles'] as List<dynamic>?)
              ?.map((e) => MangaBubble.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      translatedAt: json['translatedAt'] != null
          ? DateTime.tryParse(json['translatedAt']) ?? DateTime.now()
          : DateTime.now(),
      engine: json['engine'] as String? ?? 'unknown',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PageTranslation.fromJsonString(String jsonString) {
    return PageTranslation.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
