import 'dart:async';

import 'package:flutter/material.dart';

import '../../../controller/quill_controller.dart';
import '../../../document/attribute.dart';
import '../../../document/style.dart';
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
  final void Function(
          bool visible, String query, bool isMention, String tagTrigger)?
      onVisibilityChanged;
  MentionTagOverlay? overlayWidget;
  final ValueKey _overlayKey = const ValueKey(
      'mention_tag_overlay'); // Stable key to preserve widget state
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
      onItemCountChanged: _handleItemCountChanged,
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
          onItemCountChanged: _handleItemCountChanged,
        );
        // Notify visibility change to ensure wrapper rebuilds with updated widget
        // Use a flag to indicate this is just an update, not a show/hide
        onVisibilityChanged?.call(
            true, queryToUpdate, isMention, tagTriggerChar);
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
        onItemCountChanged: _handleItemCountChanged,
      );
      onVisibilityChanged?.call(true, currentQuery, isMention, tagTriggerChar);
    }
  }

  void _handleItemCountChanged(int count) {
    if (_itemCount == count) return;

    _itemCount = count;
    if (overlayWidget == null) return;

    onVisibilityChanged?.call(
      count > 0,
      currentQuery,
      isMention,
      tagTriggerChar,
    );
  }

  void _handleMentionSelected(MentionItem item) {
    if (triggerPosition == -1) return;

    // Hide overlay first with smooth animation
    hideOverlay();

    // Find the actual position in document
    final plainText = controller.document.toPlainText();
    var actualPosition = _resolveTriggerPosition('@', plainText);
    if (actualPosition < 0 || actualPosition >= plainText.length) return;

    // Calculate how much to delete from the stored trigger/query. This stays
    // stable even if tapping a paginated suggestion changes editor selection.
    final deleteLength = _queryLengthFromTrigger(
      plainText,
      actualPosition,
      currentQuery,
    );
    final mentionText = '@${item.name}';
    final shouldAppendSpace = config.appendSpaceAfterSelection;
    final insertedText = shouldAppendSpace ? '$mentionText ' : mentionText;
    final attribute = MentionAttribute(value: {
      'id': item.id,
      'name': item.name,
      if (item.avatarUrl != null) 'avatarUrl': item.avatarUrl,
      'color': config.defaultMentionColor,
    });

    // Apply synchronously so the next typed character cannot inherit stale style.
    _resetToggledStyleSilently();
    controller
      ..replaceText(
        actualPosition,
        deleteLength,
        insertedText,
        TextSelection.collapsed(offset: actualPosition + insertedText.length),
        shouldNotifyListeners: false,
      )
      ..formatText(
        actualPosition,
        mentionText.length,
        attribute,
        shouldNotifyListeners: false,
      );
    if (config.tagStyle.isNotEmpty) {
      _applyInlineStyleWithoutNotify(
        actualPosition,
        mentionText.length,
        config.tagStyle,
      );
    }
    if (shouldAppendSpace) {
      _clearTagStyleFromTrailingSpace(actualPosition + mentionText.length);
    }
    _resetToggledStyleSilently();
    _resetTypingStyleAfterSelection();
    controller.notifyListeners();
    config.onMentionSelected?.call(item);
  }

  void _handleTagSelected(TagItem item) {
    if (triggerPosition == -1) return;

    // Hide overlay first with smooth animation
    hideOverlay();

    // Find the actual position in document
    final plainText = controller.document.toPlainText();
    var actualPosition = _resolveTriggerPosition(tagTriggerChar, plainText);
    if (actualPosition < 0 || actualPosition >= plainText.length) return;

    // Search backwards from cursor to find # or $
    String? triggerChar =
        actualPosition < plainText.length ? plainText[actualPosition] : null;

    // Use the detected trigger character, default to # if not found
    triggerChar = triggerChar == '\$' ? '\$' : '#';

    // Calculate how much to delete
    final deleteLength = _queryLengthFromTrigger(
      plainText,
      actualPosition,
      currentQuery,
    );

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

    // Apply synchronously so the next typed character cannot inherit stale style.
    _resetToggledStyleSilently();
    controller.replaceText(
      actualPosition,
      deleteLength,
      insertedText,
      TextSelection.collapsed(offset: actualPosition + insertedText.length),
      shouldNotifyListeners: false,
    );
    controller.formatText(
      actualPosition,
      tagText.length,
      attribute,
      shouldNotifyListeners: false,
    );
    if (config.tagStyle.isNotEmpty) {
      _applyInlineStyleWithoutNotify(
        actualPosition,
        tagText.length,
        config.tagStyle,
      );
    }
    if (shouldAppendSpace) {
      _clearTagStyleFromTrailingSpace(actualPosition + tagText.length);
    }
    _resetToggledStyleSilently();
    _resetTypingStyleAfterSelection();
    controller.notifyListeners();
    config.onTagSelected?.call(item);
  }

  void _resetToggledStyleSilently() {
    controller.toggledStyle = const Style();
  }

  int _resolveTriggerPosition(String triggerChar, String plainText) {
    if (triggerPosition >= 0 &&
        triggerPosition < plainText.length &&
        plainText[triggerPosition] == triggerChar) {
      return triggerPosition;
    }

    final selectionOffset = controller.selection.baseOffset;
    var searchPos = selectionOffset - 1;
    while (searchPos >= 0 && searchPos < plainText.length) {
      if (plainText[searchPos] == triggerChar) {
        return searchPos;
      }
      if (plainText[searchPos] == '\n') {
        break;
      }
      searchPos--;
    }

    return triggerPosition;
  }

  int _queryLengthFromTrigger(
    String plainText,
    int actualPosition,
    String query,
  ) {
    final queryEnd = actualPosition + 1 + query.length;
    if (actualPosition >= 0 &&
        queryEnd <= plainText.length &&
        plainText.substring(actualPosition + 1, queryEnd) == query) {
      return 1 + query.length;
    }

    final selectionOffset = controller.selection.baseOffset;
    if (selectionOffset > actualPosition) {
      return selectionOffset - actualPosition;
    }

    return 1;
  }

  /// Ensure next typed character uses default style after selecting a token.
  void _resetTypingStyleAfterSelection() {
    controller.toggledStyle = const Style();
  }

  void _applyInlineStyleWithoutNotify(int offset, int length, Style style) {
    for (final attr in style.values) {
      if (!attr.isInline) continue;
      controller.formatText(
        offset,
        length,
        attr,
        shouldNotifyListeners: false,
      );
    }
  }

  Map<String, Attribute> _tokenStyleClearCandidates() {
    final clearByKey = <String, Attribute>{
      Attribute.mention.key: const MentionAttribute(value: null),
      Attribute.tag.key: const TagAttribute(value: null),
      Attribute.currency.key: const CurrencyAttribute(value: null),
      Attribute.bold.key: Attribute.clone(Attribute.bold, null),
      Attribute.italic.key: Attribute.clone(Attribute.italic, null),
      Attribute.underline.key: Attribute.clone(Attribute.underline, null),
      Attribute.strikeThrough.key:
          Attribute.clone(Attribute.strikeThrough, null),
      Attribute.font.key: Attribute.clone(Attribute.font, null),
      Attribute.fontWeight.key: const FontWeightAttribute(null),
      Attribute.size.key: Attribute.clone(Attribute.size, null),
      Attribute.color.key: Attribute.clone(Attribute.color, null),
      Attribute.background.key: Attribute.clone(Attribute.background, null),
    };

    for (final attr in config.tagStyle.values) {
      if (!attr.isInline || attr.value == null) continue;
      clearByKey[attr.key] = Attribute.clone(attr, null);
    }

    return clearByKey;
  }

  Iterable<Attribute> _tokenStyleClearAttributesForStyle(Style style) {
    final candidates = _tokenStyleClearCandidates();
    return style.attributes.keys
        .where(candidates.containsKey)
        .map((key) => candidates[key]!);
  }

  void _clearTagStyleFromTrailingSpace(int offset) {
    final style = controller.document.collectStyle(offset, 1);
    for (final attr in _tokenStyleClearAttributesForStyle(style)) {
      controller.formatText(
        offset,
        1,
        attr,
        shouldNotifyListeners: false,
      );
    }
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
