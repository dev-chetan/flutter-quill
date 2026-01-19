import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/utils/color.dart';

/// Represents a user mention item
class MentionItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? color; // Color as hex string (e.g., "#FF5733") or color name

  const MentionItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.color,
  });
}

/// Represents a hashtag item
class TagItem {
  final String id;
  final String name;
  final int? count;
  final String? color; // Color as hex string (e.g., "#FF5733") or color name

  const TagItem({
    required this.id,
    required this.name,
    this.count,
    this.color,
  });
}

/// Callback for fetching users based on query
typedef MentionSearchCallback = Future<List<MentionItem>> Function(String query);

/// Callback for fetching tags based on query
typedef TagSearchCallback = Future<List<TagItem>> Function(String query);

/// Overlay widget that shows mention/tag list above keyboard
class MentionTagOverlay extends StatefulWidget {
  const MentionTagOverlay({
    required this.query,
    required this.isMention,
    required this.onSelectMention,
    required this.onSelectTag,
    required this.mentionSearch,
    required this.tagSearch,
    required this.dollarSearch,
    this.maxHeight = 200,
    this.itemHeight = 48,
    this.tagTrigger = '#',
    super.key,
  });

  final String query;
  final bool isMention;
  final void Function(MentionItem) onSelectMention;
  final void Function(TagItem) onSelectTag;
  final MentionSearchCallback mentionSearch;
  final TagSearchCallback tagSearch;
  final TagSearchCallback dollarSearch;
  final double maxHeight;
  final double itemHeight;
  final String tagTrigger; // Tag trigger character (# or $)

  @override
  State<MentionTagOverlay> createState() => _MentionTagOverlayState();
}

class _MentionTagOverlayState extends State<MentionTagOverlay> {
  List<MentionItem> _mentions = [];
  List<TagItem> _tags = [];
  bool _isLoading = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(MentionTagOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _selectedIndex = 0;
      _search();
    }
  }

  void updateQuery(String newQuery) {
    if (widget.query != newQuery) {
      _selectedIndex = 0;
      // Update the query by rebuilding with new query
      // Note: This requires the parent to rebuild with new query value
      _search();
    }
  }

  Future<void> _search() async {
    if (widget.query.isEmpty) {
      setState(() {
        _mentions = [];
        _tags = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isMention) {
        final results = await widget.mentionSearch(widget.query);
        if (mounted) {
          setState(() {
            _mentions = results;
            _isLoading = false;
            _selectedIndex = 0;
          });
        }
      } else {
        // Use dollarSearch for $ tags, tagSearch for # tags
        final results = widget.tagTrigger == '\$'
            ? await widget.dollarSearch(widget.query)
            : await widget.tagSearch(widget.query);
        if (mounted) {
          setState(() {
            _tags = results;
            _isLoading = false;
            _selectedIndex = 0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectItem() {
    if (widget.isMention && _selectedIndex < _mentions.length) {
      widget.onSelectMention(_mentions[_selectedIndex]);
    } else if (!widget.isMention && _selectedIndex < _tags.length) {
      widget.onSelectTag(_tags[_selectedIndex]);
    }
  }

  void _moveSelection(int delta) {
    final maxIndex = widget.isMention ? _mentions.length : _tags.length;
    if (maxIndex == 0) return;

    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, maxIndex - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.isMention ? _mentions : _tags;
    final isEmpty = items.isEmpty && !_isLoading;

    if (isEmpty && widget.query.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: widget.maxHeight,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.isMention
                          ? 'No users found'
                          : 'No tags found',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemExtent: widget.itemHeight,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedIndex;
                      return _buildItem(context, index, isSelected);
                    },
                  ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, bool isSelected) {
    if (widget.isMention) {
      final mention = _mentions[index];
      final mentionColor = _parseTagColor(mention.color, context);
      return InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          _selectItem();
        },
        child: Container(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (mention.avatarUrl != null)
                CircleAvatar(
                  radius: 16.0,
                  backgroundImage: NetworkImage(mention.avatarUrl!),
                )
              else
                CircleAvatar(
                  radius: 16.0,
                  backgroundColor: mentionColor ?? Theme.of(context).colorScheme.primary,
                  child: Text(
                    mention.name.isNotEmpty
                        ? mention.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '@${mention.name}',
                  style: mentionColor != null
                      ? TextStyle(
                          color: mentionColor,
                          fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
                          fontWeight: Theme.of(context).textTheme.bodyLarge?.fontWeight,
                        )
                      : Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final tag = _tags[index];
      return InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          _selectItem();
        },
        child: Container(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.tag,
                size: 20,
                color: _parseTagColor(tag.color, context) ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    tag.name,
                  //_formatTagDisplay(tag.name, widget.tagTrigger),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _parseTagColor(tag.color, context),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tag.count != null)
                Text(
                  '${tag.count}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
      );
    }
  }

  /// Handle keyboard navigation
  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _moveSelection(1);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _moveSelection(-1);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        _selectItem();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Close overlay - handled by parent
        return false;
      }
    }
    return false;
  }

  bool get hasItems => widget.isMention ? _mentions.isNotEmpty : _tags.isNotEmpty;

  String _formatTagDisplay(String tagName, String trigger) {
    if (trigger == '\$') {
      // Format as currency if numeric
      final numericValue = double.tryParse(tagName);
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
        
        return '\$$formattedInteger${decimalPart.isNotEmpty ? '.$decimalPart' : ''}';
      } else {
        // Not numeric, just use name as is
        return '\$$tagName';
      }
    } else {
      // For # tags, use as is
      return '$trigger$tagName';
    }
  }

  Color? _parseTagColor(String? colorString, BuildContext context) {
    if (colorString == null || colorString.isEmpty) return null;
    
    try {
      // Use the existing stringToColor utility
      final color = stringToColor(colorString, null, null);
      return color;
    } catch (e) {
      // If parsing fails, try to parse as hex directly
      try {
        var hex = colorString.trim();
        if (!hex.startsWith('#')) {
          hex = '#$hex';
        }
        if (hex.length == 7) {
          // 6-digit hex, add alpha
          hex = 'ff${hex.substring(1)}';
        } else if (hex.length == 4) {
          // 3-digit hex, expand and add alpha
          final r = hex[1];
          final g = hex[2];
          final b = hex[3];
          hex = 'ff$r$r$g$g$b$b';
        }
        final val = int.parse(hex, radix: 16);
        return Color(val);
      } catch (e2) {
        // If all parsing fails, return null to use default color
        return null;
      }
    }
  }
}
