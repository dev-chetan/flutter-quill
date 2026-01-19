import 'dart:async';

import 'package:flutter/material.dart';

import '../../controller/quill_controller.dart';
import '../../document/document.dart';
import '../../document/structs/doc_change.dart';
import '../config/events/mention_tag_handlers.dart';
import '../config/mention_tag_config.dart';

/// Wrapper widget that adds mention/tag functionality to QuillEditor
class MentionTagWrapper extends StatefulWidget {
  const MentionTagWrapper({
    required this.controller,
    required this.child,
    required this.config,
    super.key,
  });

  final QuillController controller;
  final Widget child;
  final MentionTagConfig config;

  @override
  State<MentionTagWrapper> createState() => _MentionTagWrapperState();
}

/// Result of query extraction for a trigger character
class _TriggerQueryResult {
  final String query;
  final int position;
  
  _TriggerQueryResult(this.query, this.position);
}

class _MentionTagWrapperState extends State<MentionTagWrapper> {
  MentionTagState? _mentionTagState;
  StreamSubscription<DocChange>? _changeSubscription;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _mentionTagState = MentionTagState(
      config: widget.config,
      controller: widget.controller,
    );

    // Listen to document changes to detect @, #, and $ triggers
    _changeSubscription = widget.controller.document.changes.listen((change) {
      if (change.source == ChangeSource.local) {
        _checkForMentionOrTag();
      }
    });
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    _mentionTagState?.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _checkForMentionOrTag() {
    if (!mounted) return;

    final selection = widget.controller.selection;
    if (!selection.isCollapsed) {
      _hideOverlay();
      return;
    }

    final plainText = widget.controller.document.toPlainText();
    if (plainText.isEmpty || selection.baseOffset == 0) {
      _hideOverlay();
      return;
    }

    // Check for @ mention
    if (handleMentionTrigger(widget.controller)) {
      final query = extractQuery(widget.controller, true);
      if (_overlayEntry == null || _mentionTagState?.isMention != true) {
        _showOverlay(true, selection.baseOffset - 1, query);
      } else {
        _mentionTagState?.updateQuery(query);
      }
      return;
    }

    // Check for # tag
    if (handleTagTrigger(widget.controller)) {
      final query = extractQuery(widget.controller, false);
      if (_overlayEntry == null || _mentionTagState?.isMention != false) {
        _showOverlay(false, selection.baseOffset - 1, query, tagTrigger: '#');
      } else {
        _mentionTagState?.updateQuery(query);
      }
      return;
    }

    // Check for $ tag
    if (handleDollarTagTrigger(widget.controller)) {
      final query = extractQuery(widget.controller, false, tagTrigger: '\$');
      if (_overlayEntry == null || _mentionTagState?.isMention != false) {
        _showOverlay(false, selection.baseOffset - 1, query, tagTrigger: '\$');
      } else {
        _mentionTagState?.updateQuery(query);
      }
      return;
    }

    // Check if we're still in a mention/tag context
    // This handles the case where overlay was hidden but user is editing within a tag/mention
    final mentionResult = _getCurrentQueryForTrigger('@');
    final tagHashResult = _getCurrentQueryForTrigger('#');
    final tagDollarResult = _getCurrentQueryForTrigger('\$');
    
    if (mentionResult != null) {
      // We're in a mention context
      final mentionQuery = mentionResult.query;
      final mentionPosition = mentionResult.position;
      if (_overlayEntry == null || _mentionTagState?.isMention != true) {
        _showOverlay(true, mentionPosition, mentionQuery);
      } else {
        _mentionTagState?.updateQuery(mentionQuery);
      }
      return;
    }
    
    // Check for # tag context
    if (tagHashResult != null) {
      // We're in a # tag context
      final tagQuery = tagHashResult.query;
      final tagPosition = tagHashResult.position;
      if (_overlayEntry == null || _mentionTagState?.isMention != false) {
        _showOverlay(false, tagPosition, tagQuery, tagTrigger: '#');
      } else {
        _mentionTagState?.updateQuery(tagQuery);
      }
      return;
    }
    
    // Check for $ tag context
    if (tagDollarResult != null) {
      // We're in a $ tag context
      final tagQuery = tagDollarResult.query;
      final tagPosition = tagDollarResult.position;
      if (_overlayEntry == null || _mentionTagState?.isMention != false) {
        _showOverlay(false, tagPosition, tagQuery, tagTrigger: '\$');
      } else {
        _mentionTagState?.updateQuery(tagQuery);
      }
      return;
    }

    // Not in any mention/tag context, hide overlay if it exists
    if (_overlayEntry != null) {
      _hideOverlay();
    }
  }

  String? _getCurrentQuery() {
    final selection = widget.controller.selection;
    final plainText = widget.controller.document.toPlainText();
    
    if (selection.baseOffset == 0) return null;
    
    var pos = selection.baseOffset - 1;
    final triggerChar = _mentionTagState?.isMention == true ? '@' : '#';
    
    // Find trigger character
    while (pos >= 0 && plainText[pos] != triggerChar) {
      if (plainText[pos] == ' ' || plainText[pos] == '\n') {
        return null;
      }
      pos--;
    }
    
    if (pos < 0 || plainText[pos] != triggerChar) {
      return null;
    }
    
    // Extract query
    final query = plainText.substring(pos + 1, selection.baseOffset);
    return query;
  }

  /// Get current query for a specific trigger character, checking if we're in that context
  _TriggerQueryResult? _getCurrentQueryForTrigger(String triggerChar) {
    final selection = widget.controller.selection;
    final plainText = widget.controller.document.toPlainText();
    
    if (selection.baseOffset == 0) return null;
    
    var pos = selection.baseOffset - 1;
    
    // Find trigger character
    while (pos >= 0 && plainText[pos] != triggerChar) {
      if (plainText[pos] == ' ' || plainText[pos] == '\n') {
        return null;
      }
      pos--;
    }
    
    if (pos < 0 || plainText[pos] != triggerChar) {
      return null;
    }
    
    // Check if there's a space or newline before the trigger (start of word)
    if (pos > 0) {
      final charBeforeTrigger = plainText[pos - 1];
      if (charBeforeTrigger != ' ' && charBeforeTrigger != '\n') {
        return null;
      }
    }
    
    // Extract query
    final query = plainText.substring(pos + 1, selection.baseOffset);
    return _TriggerQueryResult(query, pos);
  }

  void _showOverlay(bool isMention, int position, String query, {String? tagTrigger}) {
    if (!mounted) return;

    _mentionTagState?.showOverlay(context, isMention, position, tagTrigger: tagTrigger);
    _overlayEntry = _mentionTagState?.overlayEntry;
  }

  void _hideOverlay() {
    _mentionTagState?.hideOverlay();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (_mentionTagState?.handleKeyEvent(event) == true) {
          return;
        }
      },
      child: widget.child,
    );
  }
}
