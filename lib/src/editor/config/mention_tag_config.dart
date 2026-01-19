import 'package:flutter/material.dart';

import '../widgets/mention_tag_overlay.dart';

/// Configuration for mention and tag functionality
@immutable
class MentionTagConfig {
  const MentionTagConfig({
    required this.mentionSearch,
    required this.tagSearch,
    required this.dollarSearch,
    this.maxHeight = 200,
    this.itemHeight = 48,
    this.onMentionSelected,
    this.onTagSelected,
  });

  /// Callback to search for users when @ is typed
  final MentionSearchCallback mentionSearch;

  /// Callback to search for tags when # is typed
  final TagSearchCallback tagSearch;

  /// Callback to search for currency tags when $ is typed
  final TagSearchCallback dollarSearch;

  /// Maximum height of the mention/tag overlay
  final double maxHeight;

  /// Height of each item in the overlay
  final double itemHeight;

  /// Optional callback when a mention is selected
  final void Function(MentionItem)? onMentionSelected;

  /// Optional callback when a tag is selected
  final void Function(TagItem)? onTagSelected;
}
