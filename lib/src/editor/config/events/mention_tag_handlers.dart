import 'dart:async';

import 'package:flutter/material.dart';

import '../../../controller/quill_controller.dart';
import '../../../document/attribute.dart';
import '../../widgets/mention_tag_overlay.dart';
import '../mention_tag_config.dart';

/// State for managing mention/tag overlay
class MentionTagState {
  MentionTagState({
    required this.config,
    required this.controller,
    this.onVisibilityChanged,
  });

  final MentionTagConfig config;
  final QuillController controller;
  final void Function(bool visible, String query, bool isMention, String tagTrigger)? onVisibilityChanged;
  MentionTagOverlay? overlayWidget;
  final ValueKey _overlayKey = const ValueKey('mention_tag_overlay'); // Stable key to preserve widget state
  String currentQuery = '';
  bool isMention = false;
  int triggerPosition = -1;
  String tagTriggerChar = '#'; // Track which tag trigger was used (# or $)
  int _itemCount = 0; // Track number of items in overlay
  Timer? _searchDebounceTimer; // Debounce timer for search
  String? _pendingQuery; // Query waiting to be applied after debounce


  void showOverlay(bool isMentionMode, int position, String query,
      {String? tagTrigger}) {
    isMention = isMentionMode;
    triggerPosition = position;
    currentQuery = query;
    if (tagTrigger != null) {
      tagTriggerChar = tagTrigger;
    }

    // Cancel any pending debounce timer
    _searchDebounceTimer?.cancel();

    // Create widget immediately (no debounce for initial show)
    overlayWidget = MentionTagOverlay(
      key: _overlayKey, // Stable key preserves state across rebuilds
      query: query,
      isMention: isMentionMode,
      tagTrigger: tagTriggerChar,
      defaultMentionColor: config.defaultMentionColor,
      defaultHashTagColor: config.defaultHashTagColor,
      defaultDollarTagColor: config.defaultDollarTagColor,
      onSelectMention: _handleMentionSelected,
      onSelectTag: _handleTagSelected,
      mentionSearch: config.mentionSearch,
      tagSearch: config.tagSearch,
      dollarSearch: config.dollarSearch,
      maxHeight: config.maxHeight,
      mentionItemBuilder: config.mentionItemBuilder,
      tagItemBuilder: config.tagItemBuilder,
      customData: config.customData,
      onLoadMoreMentions: config.onLoadMoreMentions,
      onLoadMoreTags: config.onLoadMoreTags,
      onLoadMoreDollarTags: config.onLoadMoreDollarTags,
      loadMoreIndicatorBuilder: config.loadMoreIndicatorBuilder,
      suggestionListPadding: config.suggestionListPadding,
      decoration: config.decoration,
      onItemCountChanged: (count) {
        _itemCount = count;
      },
    );
    // Always notify visibility change to ensure wrapper rebuilds
    onVisibilityChanged?.call(true, query, isMentionMode, tagTriggerChar);
  }


  void updateQuery(String query) {
    // Update query without recreating widget
    if (currentQuery == query) return;
    
    currentQuery = query;
    
    // Cancel any pending debounce timer
    _searchDebounceTimer?.cancel();
    
    // Debounce widget update to avoid rapid rebuilds
    final queryToUpdate = query;
    _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (currentQuery == queryToUpdate && overlayWidget != null) {
        // Update the existing widget's query by recreating with same key
        // The stable key ensures Flutter reuses the state and calls didUpdateWidget
        overlayWidget = MentionTagOverlay(
          key: _overlayKey, // Same stable key preserves state
          query: queryToUpdate,
          isMention: isMention,
          tagTrigger: tagTriggerChar,
          defaultMentionColor: config.defaultMentionColor,
          defaultHashTagColor: config.defaultHashTagColor,
          defaultDollarTagColor: config.defaultDollarTagColor,
          onSelectMention: _handleMentionSelected,
          onSelectTag: _handleTagSelected,
          mentionSearch: config.mentionSearch,
          tagSearch: config.tagSearch,
          dollarSearch: config.dollarSearch,
          maxHeight: config.maxHeight,
          mentionItemBuilder: config.mentionItemBuilder,
          tagItemBuilder: config.tagItemBuilder,
          customData: config.customData,
          onLoadMoreMentions: config.onLoadMoreMentions,
          onLoadMoreTags: config.onLoadMoreTags,
          onLoadMoreDollarTags: config.onLoadMoreDollarTags,
          loadMoreIndicatorBuilder: config.loadMoreIndicatorBuilder,
          suggestionListPadding: config.suggestionListPadding,
          decoration: config.decoration,
          onItemCountChanged: (count) {
            _itemCount = count;
          },
        );
        // Notify visibility change to ensure wrapper rebuilds with updated widget
        // Use a flag to indicate this is just an update, not a show/hide
        onVisibilityChanged?.call(true, queryToUpdate, isMention, tagTriggerChar);
      }
    });
  }

  void hideOverlay() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _pendingQuery = null;
    overlayWidget = null;
    currentQuery = '';
    triggerPosition = -1;
    tagTriggerChar = '#';
    _itemCount = 0;
    onVisibilityChanged?.call(false, '', false, '#');
  }

  /// Refresh the suggestion list with current query
  /// Call this when the underlying data has changed and you want to update the list
  void refreshList() {
    if (overlayWidget != null) {
      // Recreate widget with same query but updated search callbacks
      // This will trigger didUpdateWidget which will detect the callback change and refresh
      // Works even with empty query (when showing all data)
      overlayWidget = MentionTagOverlay(
        key: _overlayKey,
        query: currentQuery,
        isMention: isMention,
        tagTrigger: tagTriggerChar,
        defaultMentionColor: config.defaultMentionColor,
        defaultHashTagColor: config.defaultHashTagColor,
        defaultDollarTagColor: config.defaultDollarTagColor,
        onSelectMention: _handleMentionSelected,
        onSelectTag: _handleTagSelected,
        mentionSearch: config.mentionSearch,
        tagSearch: config.tagSearch,
        dollarSearch: config.dollarSearch,
        maxHeight: config.maxHeight,
        mentionItemBuilder: config.mentionItemBuilder,
        tagItemBuilder: config.tagItemBuilder,
        customData: config.customData,
        onLoadMoreMentions: config.onLoadMoreMentions,
        onLoadMoreTags: config.onLoadMoreTags,
        onLoadMoreDollarTags: config.onLoadMoreDollarTags,
        loadMoreIndicatorBuilder: config.loadMoreIndicatorBuilder,
        suggestionListPadding: config.suggestionListPadding,
        decoration: config.decoration,
        onItemCountChanged: (count) {
          _itemCount = count;
        },
      );
      onVisibilityChanged?.call(true, currentQuery, isMention, tagTriggerChar);
    }
  }

  void _handleMentionSelected(MentionItem item) {
    if (triggerPosition == -1) return;

    // Hide overlay first with smooth animation
    hideOverlay();

    // Find the actual position in document
    final plainText = controller.document.toPlainText();
    var actualPosition = triggerPosition;

    // Search backwards from cursor to find @
    var searchPos = controller.selection.baseOffset - 1;
    while (searchPos >= 0 && searchPos < plainText.length) {
      if (plainText[searchPos] == '@') {
        actualPosition = searchPos;
        break;
      }
      if (plainText[searchPos] == ' ' || plainText[searchPos] == '\n') {
        break;
      }
      searchPos--;
    }

    // Calculate how much to delete
    final deleteLength = controller.selection.baseOffset - actualPosition;
    final mentionText = '@${item.name}';
    final shouldAppendSpace = config.appendSpaceAfterSelection;
    final insertedText = shouldAppendSpace ? '$mentionText ' : mentionText;
    final attribute = MentionAttribute(value: {
      'id': item.id,
      'name': item.name,
      if (item.avatarUrl != null) 'avatarUrl': item.avatarUrl,
      'color': config.defaultMentionColor,
    });

    // Insert text and apply mention attribute immediately so tag color is set
    // before any async callback (e.g. API in onMentionSelected) can trigger rebuild.
    Future.microtask(() {
      controller..replaceText(
        actualPosition,
        deleteLength,
        insertedText,
        TextSelection.collapsed(offset: actualPosition + insertedText.length),
      )
      ..formatText(
        actualPosition,
        mentionText.length,
        attribute,
      );
      config.onMentionSelected?.call(item);
      // Re-apply format after callback so color is not lost if callback triggers setState/rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.formatText(
          actualPosition,
          mentionText.length,
          attribute,
        );
      });
    });
  }

  void _handleTagSelected(TagItem item) {
    if (triggerPosition == -1) return;

    // Hide overlay first with smooth animation
    hideOverlay();

    // Find the actual position in document
    final plainText = controller.document.toPlainText();
    var actualPosition = triggerPosition;

    // Search backwards from cursor to find # or $
    var searchPos = controller.selection.baseOffset - 1;
    String? triggerChar;
    while (searchPos >= 0 && searchPos < plainText.length) {
      if (plainText[searchPos] == '#' || plainText[searchPos] == '\$') {
        actualPosition = searchPos;
        triggerChar = plainText[searchPos];
        break;
      }
      if (plainText[searchPos] == ' ' || plainText[searchPos] == '\n') {
        break;
      }
      searchPos--;
    }

    // Use the detected trigger character, default to # if not found
    triggerChar ??= '#';

    // Calculate how much to delete
    final deleteLength = controller.selection.baseOffset - actualPosition;

    // Format tag text
    String tagText;
    if (triggerChar == '\$') {
      // Keep raw text as-is for $ tags (no numeric formatting)
      tagText = '\$${item.name}';
    } else {
      // For # tags, use as is
      tagText = '$triggerChar${item.name}';
    }

    final shouldAppendSpace = config.appendSpaceAfterSelection;
    final insertedText = shouldAppendSpace ? '$tagText ' : tagText;
    final attribute = triggerChar == '\$'
        ? CurrencyAttribute(value: {
            'id': item.id,
            'name': item.name,
            if (item.count != null) 'count': item.count,
            'color': config.defaultDollarTagColor,
          })
        : TagAttribute(value: {
            'id': item.id,
            'name': item.name,
            if (item.count != null) 'count': item.count,
            'color': config.defaultHashTagColor,
          });

    // Insert text and apply tag attribute immediately so tag color is set
    // before any async callback (e.g. API in onTagSelected) can trigger rebuild.
    Future.microtask(() {
      controller.replaceText(
        actualPosition,
        deleteLength,
        insertedText,
        TextSelection.collapsed(offset: actualPosition + insertedText.length),
      );
      controller.formatText(actualPosition, tagText.length, attribute);
      config.onTagSelected?.call(item);
      // Re-apply format after callback so color is not lost if callback triggers setState/rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.formatText(actualPosition, tagText.length, attribute);
      });
    });
  }

  bool handleKeyEvent(KeyEvent event) {
    // Keyboard navigation is handled by the overlay widget itself
    // This method can be extended if needed
    return false;
  }

  void dispose() {
    hideOverlay();
  }
}

/// Handler for @ character to trigger mention overlay
bool handleMentionTrigger(QuillController controller) {
  final selection = controller.selection;
  if (!selection.isCollapsed) return false;

  final plainText = controller.document.toPlainText();
  if (plainText.isEmpty || selection.baseOffset == 0) return false;

  // Check if @ was just typed
  final charBefore =
      selection.baseOffset > 0 ? plainText[selection.baseOffset - 1] : null;

  if (charBefore != '@') return false;

  // Check if there's a space or newline before @ (start of word)
  if (selection.baseOffset > 1) {
    final charBeforeAt = plainText[selection.baseOffset - 2];
    if (charBeforeAt != ' ' && charBeforeAt != '\n') {
      return false;
    }
  }

  return true;
}

/// Handler for # character to trigger tag overlay
bool handleTagTrigger(QuillController controller) {
  final selection = controller.selection;
  if (!selection.isCollapsed) return false;

  final plainText = controller.document.toPlainText();
  if (plainText.isEmpty || selection.baseOffset == 0) return false;

  // Check if # was just typed
  final charBefore =
      selection.baseOffset > 0 ? plainText[selection.baseOffset - 1] : null;

  if (charBefore != '#') return false;

  // Check if there's a space or newline before # (start of word)
  if (selection.baseOffset > 1) {
    final charBeforeHash = plainText[selection.baseOffset - 2];
    if (charBeforeHash != ' ' && charBeforeHash != '\n') {
      return false;
    }
  }

  return true;
}

/// Handler for $ character to trigger tag overlay
bool handleDollarTagTrigger(QuillController controller) {
  final selection = controller.selection;
  if (!selection.isCollapsed) return false;

  final plainText = controller.document.toPlainText();
  if (plainText.isEmpty || selection.baseOffset == 0) return false;

  // Check if $ was just typed
  final charBefore =
      selection.baseOffset > 0 ? plainText[selection.baseOffset - 1] : null;

  if (charBefore != '\$') return false;

  // Check if there's a space or newline before $ (start of word)
  if (selection.baseOffset > 1) {
    final charBeforeDollar = plainText[selection.baseOffset - 2];
    if (charBeforeDollar != ' ' && charBeforeDollar != '\n') {
      return false;
    }
  }

  return true;
}

/// Extract query text after @, #, or $
String extractQuery(QuillController controller, bool isMention,
    {String? tagTrigger}) {
  final selection = controller.selection;
  final plainText = controller.document.toPlainText();

  if (selection.baseOffset == 0) return '';

  var startPos = selection.baseOffset - 1;
  final triggerChar = isMention ? '@' : (tagTrigger ?? '#');

  // Find the trigger character
  while (startPos >= 0 && plainText[startPos] != triggerChar) {
    // For mentions and $ tags allow spaces in the query (names with spaces).
    // For # tags, a space ends the query.
    if ((!isMention && triggerChar == '#' && plainText[startPos] == ' ') ||
        plainText[startPos] == '\n') {
      return '';
    }
    startPos--;
  }

  if (startPos < 0 || plainText[startPos] != triggerChar) {
    return '';
  }

  // Extract text after trigger
  final query = plainText.substring(startPos + 1, selection.baseOffset);
  return query;
}
