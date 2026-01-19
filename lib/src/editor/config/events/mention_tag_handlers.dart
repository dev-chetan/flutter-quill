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
  });

  final MentionTagConfig config;
  final QuillController controller;
  OverlayEntry? overlayEntry;
  MentionTagOverlay? overlayWidget;
  String currentQuery = '';
  bool isMention = false;
  int triggerPosition = -1;
  String tagTriggerChar = '#'; // Track which tag trigger was used (# or $)

  void showOverlay(BuildContext context, bool isMentionMode, int position, {String? tagTrigger}) {
    if (overlayEntry != null) {
      hideOverlay();
    }

    isMention = isMentionMode;
    triggerPosition = position;
    currentQuery = '';
    if (tagTrigger != null) {
      tagTriggerChar = tagTrigger;
    }

    overlayWidget = MentionTagOverlay(
      query: currentQuery,
      isMention: isMentionMode,
      tagTrigger: tagTriggerChar,
      onSelectMention: _handleMentionSelected,
      onSelectTag: _handleTagSelected,
      mentionSearch: config.mentionSearch,
      tagSearch: config.tagSearch,
      dollarSearch: config.dollarSearch,
      maxHeight: config.maxHeight,
      itemHeight: config.itemHeight,
    );

    overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(context),
    );

    Overlay.of(context, rootOverlay: true).insert(overlayEntry!);
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: overlayWidget!,
      ),
    );
  }

  void updateQuery(String query) {
    if (overlayWidget != null) {
      currentQuery = query;
      overlayWidget = MentionTagOverlay(
        query: query,
        isMention: isMention,
        tagTrigger: tagTriggerChar,
        onSelectMention: _handleMentionSelected,
        onSelectTag: _handleTagSelected,
        mentionSearch: config.mentionSearch,
        tagSearch: config.tagSearch,
        dollarSearch: config.dollarSearch,
        maxHeight: config.maxHeight,
        itemHeight: config.itemHeight,
      );
      overlayEntry?.markNeedsBuild();
    }
  }

  void hideOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
    overlayWidget = null;
    currentQuery = '';
    triggerPosition = -1;
    tagTriggerChar = '#';
  }

  void _handleMentionSelected(MentionItem item) {
    if (triggerPosition == -1) return;

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

    // Insert mention text with attribute
    final mentionText = '@${item.name}';
    controller.replaceText(
      actualPosition,
      deleteLength,
      mentionText,
      TextSelection.collapsed(offset: actualPosition + mentionText.length),
    );

    // Apply mention attribute
    controller.formatText(
      actualPosition,
      mentionText.length,
      MentionAttribute(value: {
        'id': item.id,
        'name': item.name,
        if (item.avatarUrl != null) 'avatarUrl': item.avatarUrl,
        if (item.color != null) 'color': item.color,
      }),
    );

    config.onMentionSelected?.call(item);
    hideOverlay();
  }

  void _handleTagSelected(TagItem item) {
    if (triggerPosition == -1) return;

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

    // Format tag text - for $ tags, format as currency if name is numeric
    String tagText;
    if (triggerChar == '\$') {
      // Try to parse as number and format as currency
      final numericValue = double.tryParse(item.name);
      if (numericValue != null) {
        // Format with commas for thousands
        final formattedValue = numericValue.toStringAsFixed(numericValue.truncateToDouble() == numericValue ? 0 : 2);
        final parts = formattedValue.split('.');
        final integerPart = parts[0];
        final decimalPart = parts.length > 1 ? parts[1] : '';
        
        // Add commas for thousands
        String formattedInteger = '';
        for (int i = integerPart.length - 1; i >= 0; i--) {
          if ((integerPart.length - 1 - i) % 3 == 0 && i < integerPart.length - 1) {
            formattedInteger = ',$formattedInteger';
          }
          formattedInteger = integerPart[i] + formattedInteger;
        }
        
        tagText = '\$$formattedInteger${decimalPart.isNotEmpty ? '.$decimalPart' : ''}';
      } else {
        // Not numeric, just use name as is
        tagText = '\$${item.name}';
      }
    } else {
      // For # tags, use as is
      tagText = '$triggerChar${item.name}';
    }
    
    controller.replaceText(
      actualPosition,
      deleteLength,
      tagText,
      TextSelection.collapsed(offset: actualPosition + tagText.length),
    );

    // Apply tag attribute - use CurrencyAttribute for $ tags, TagAttribute for # tags
    if (triggerChar == '\$') {
      controller.formatText(
        actualPosition,
        tagText.length,
        CurrencyAttribute(value: {
          'id': item.id,
          'name': item.name,
          if (item.count != null) 'count': item.count,
          if (item.color != null) 'color': item.color,
        }),
      );
    } else {
      controller.formatText(
        actualPosition,
        tagText.length,
        TagAttribute(value: {
          'id': item.id,
          'name': item.name,
          if (item.count != null) 'count': item.count,
          if (item.color != null) 'color': item.color,
        }),
      );
    }

    config.onTagSelected?.call(item);
    hideOverlay();
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
  final charBefore = selection.baseOffset > 0
      ? plainText[selection.baseOffset - 1]
      : null;

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
  final charBefore = selection.baseOffset > 0
      ? plainText[selection.baseOffset - 1]
      : null;

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
  final charBefore = selection.baseOffset > 0
      ? plainText[selection.baseOffset - 1]
      : null;

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
String extractQuery(QuillController controller, bool isMention, {String? tagTrigger}) {
  final selection = controller.selection;
  final plainText = controller.document.toPlainText();
  
  if (selection.baseOffset == 0) return '';
  
  var startPos = selection.baseOffset - 1;
  final triggerChar = isMention ? '@' : (tagTrigger ?? '#');
  
  // Find the trigger character
  while (startPos >= 0 && plainText[startPos] != triggerChar) {
    if (plainText[startPos] == ' ' || plainText[startPos] == '\n') {
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
