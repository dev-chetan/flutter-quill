import 'dart:async';

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
typedef MentionSearchCallback = Future<List<MentionItem>> Function(
    String query);

/// Callback for fetching tags based on query
typedef TagSearchCallback = Future<List<TagItem>> Function(String query);

/// Builder for custom mention item widget
typedef MentionItemBuilder = Widget Function(
  BuildContext context,
  MentionItem item,
  bool isSelected,
  VoidCallback onTap,
);

/// Builder for custom tag item widget
typedef TagItemBuilder = Widget Function(
  BuildContext context,
  TagItem item,
  bool isSelected,
  VoidCallback onTap,
);

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
    this.onItemCountChanged,
    this.mentionItemBuilder,
    this.tagItemBuilder,
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
  final void Function(int)?
      onItemCountChanged; // Callback when item count changes
  final MentionItemBuilder?
      mentionItemBuilder; // Custom builder for mention items
  final TagItemBuilder? tagItemBuilder; // Custom builder for tag items

  @override
  State<MentionTagOverlay> createState() => _MentionTagOverlayState();
}

class _MentionTagOverlayState extends State<MentionTagOverlay> {
  List<MentionItem> _mentions = [];
  List<TagItem> _tags = [];
  bool _isLoading = false;
  int _selectedIndex = 0;
  Timer? _searchDebounceTimer;
  Timer? _loadingIndicatorTimer; // Timer to delay showing loading indicator
  String _lastSearchedQuery = '';
  int _listVersion = 0; // Track list changes for animation

  @override
  void initState() {
    super.initState();
    _lastSearchedQuery = widget.query;
    _searchWithQuery(widget.query);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _loadingIndicatorTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MentionTagOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only search if query actually changed and we haven't already searched for this query
    if (oldWidget.query != widget.query && widget.query != _lastSearchedQuery) {
      _selectedIndex = 0;
      // Debounce search to avoid rapid reloads
      _searchDebounceTimer?.cancel();
      final queryToSearch = widget.query; // Capture current query
      _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
        // Only search if query hasn't changed since we scheduled this search
        if (mounted &&
            widget.query == queryToSearch &&
            queryToSearch != _lastSearchedQuery) {
          _lastSearchedQuery = queryToSearch;
          _searchWithQuery(queryToSearch);
        }
      });
    }
  }

  Future<void> _searchWithQuery(String query) async {
    if (query.isEmpty) {
      _loadingIndicatorTimer?.cancel();
      setState(() {
        _mentions = [];
        _tags = [];
        _isLoading = false;
      });
      widget.onItemCountChanged?.call(0);
      return;
    }

    // Cancel any existing loading indicator timer
    _loadingIndicatorTimer?.cancel();

    // Only show loading indicator if search takes longer than 150ms
    // This prevents flickering for fast local searches
    _loadingIndicatorTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    });

    try {
      if (widget.isMention) {
        final results = await widget.mentionSearch(query);
        // Cancel loading indicator timer since we got results quickly
        _loadingIndicatorTimer?.cancel();
        if (mounted) {
          _updateMentionsList(results);
        }
      } else {
        // Use dollarSearch for $ tags, tagSearch for # tags
        final results = widget.tagTrigger == '\$'
            ? await widget.dollarSearch(query)
            : await widget.tagSearch(query);
        // Cancel loading indicator timer since we got results quickly
        _loadingIndicatorTimer?.cancel();
        if (mounted) {
          _updateTagsList(results);
        }
      }
    } catch (e) {
      _loadingIndicatorTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Incrementally update mentions list - preserve existing items, add new ones, remove old ones
  void _updateMentionsList(List<MentionItem> newResults) {
    // Cancel loading indicator timer since we have results
    _loadingIndicatorTimer?.cancel();

    // Create maps for quick lookup
    final oldMap = {for (var item in _mentions) item.id: item};
    final newIds = newResults.map((e) => e.id).toSet();

    // Find items that need to be removed (in old but not in new)
    final toRemove =
        _mentions.where((item) => !newIds.contains(item.id)).toList();

    // Find items that need to be added (in new but not in old)
    final toAdd =
        newResults.where((item) => !oldMap.containsKey(item.id)).toList();

    // Only update if there are actual changes
    if (toRemove.isEmpty && toAdd.isEmpty) {
      // Check if any existing items need updates
      bool needsUpdate = false;
      for (var newItem in newResults) {
        final oldItem = oldMap[newItem.id];
        if (oldItem != null && oldItem != newItem) {
          needsUpdate = true;
          break;
        }
      }
      if (!needsUpdate) {
        setState(() {
          _isLoading = false;
        });
        return; // No changes needed
      }
    }

    setState(() {
      // Remove items that are no longer in results
      _mentions.removeWhere((item) => toRemove.contains(item));

      // Build new list maintaining order from newResults
      final resultList = <MentionItem>[];
      final existingIds = <String>{};

      for (var newItem in newResults) {
        if (existingIds.contains(newItem.id)) continue;

        // Use existing item if available (preserves state), otherwise use new
        final existingItem = oldMap[newItem.id];
        resultList.add(existingItem ?? newItem);
        existingIds.add(newItem.id);
      }

      _mentions = resultList;
      _isLoading = false;
      _listVersion++; // Increment to trigger animation

      // Preserve selected index if still valid, otherwise reset to 0
      if (_selectedIndex >= _mentions.length) {
        _selectedIndex = 0;
      }
    });

    widget.onItemCountChanged?.call(_mentions.length);
  }

  // Incrementally update tags list - preserve existing items, add new ones, remove old ones
  void _updateTagsList(List<TagItem> newResults) {
    // Cancel loading indicator timer since we have results
    _loadingIndicatorTimer?.cancel();

    // Create maps for quick lookup
    final oldMap = {for (var item in _tags) item.id: item};
    final newIds = newResults.map((e) => e.id).toSet();

    // Find items that need to be removed (in old but not in new)
    final toRemove = _tags.where((item) => !newIds.contains(item.id)).toList();

    // Find items that need to be added (in new but not in old)
    final toAdd =
        newResults.where((item) => !oldMap.containsKey(item.id)).toList();

    // Only update if there are actual changes
    if (toRemove.isEmpty && toAdd.isEmpty) {
      // Check if any existing items need updates
      bool needsUpdate = false;
      for (var newItem in newResults) {
        final oldItem = oldMap[newItem.id];
        if (oldItem != null && oldItem != newItem) {
          needsUpdate = true;
          break;
        }
      }
      if (!needsUpdate) {
        setState(() {
          _isLoading = false;
        });
        return; // No changes needed
      }
    }

    setState(() {
      // Remove items that are no longer in results
      _tags.removeWhere((item) => toRemove.contains(item));

      // Build new list maintaining order from newResults
      final resultList = <TagItem>[];
      final existingIds = <String>{};

      for (var newItem in newResults) {
        if (existingIds.contains(newItem.id)) continue;

        // Use existing item if available (preserves state), otherwise use new
        final existingItem = oldMap[newItem.id];
        resultList.add(existingItem ?? newItem);
        existingIds.add(newItem.id);
      }

      _tags = resultList;
      _isLoading = false;
      _listVersion++; // Increment to trigger animation

      // Preserve selected index if still valid, otherwise reset to 0
      if (_selectedIndex >= _tags.length) {
        _selectedIndex = 0;
      }
    });

    widget.onItemCountChanged?.call(_tags.length);
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
    final isEmpty =
        (widget.isMention ? _mentions.isEmpty : _tags.isEmpty) && !_isLoading;

    // Hide only if query is empty, no items, and not loading
    // This allows showing loading state even when query is initially empty
    if (isEmpty && widget.query.isEmpty && !_isLoading) {
      return const SizedBox.shrink();
    }

    return /*_isLoading
        ? const Center(
            child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator()))
        : */
        isEmpty
            ? Container()
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: widget.isMention
                      ? ListView.builder(
                          key: ValueKey('mentions_list_v$_listVersion'),
                          itemCount: _mentions.length,
                          shrinkWrap: true,
                          itemExtent: widget.itemHeight,
                          itemBuilder: (context, index) {
                            final isSelected = index == _selectedIndex;
                            return _buildAnimatedItem(
                              context,
                              index,
                              isSelected,
                              key: ValueKey(_mentions[index].id),
                            );
                          },
                        )
                      : ListView.builder(
                          key: ValueKey('tags_list_v$_listVersion'),
                          itemCount: _tags.length,
                          shrinkWrap: true,
                          itemExtent: widget.itemHeight,
                          itemBuilder: (context, index) {
                            final isSelected = index == _selectedIndex;
                            return _buildAnimatedItem(
                              context,
                              index,
                              isSelected,
                              key: ValueKey(_tags[index].id),
                            );
                          },
                        ),
                ),
              );
  }

  Widget _buildAnimatedItem(BuildContext context, int index, bool isSelected,
      {Key? key}) {
    // Use AnimatedOpacity for smooth fade-in when items appear
    // The stable key ensures Flutter reuses widgets and only animates new items
    return AnimatedOpacity(
      key: key,
      opacity: 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: _buildItem(context, index, isSelected, key: key),
    );
  }

  Widget _buildItem(BuildContext context, int index, bool isSelected,
      {Key? key}) {
    if (widget.isMention) {
      final mention = _mentions[index];

      // Use custom builder if provided
      if (widget.mentionItemBuilder != null) {
        return widget.mentionItemBuilder!(
          context,
          mention,
          isSelected,
          () {
            setState(() {
              _selectedIndex = index;
            });
            _selectItem();
          },
        );
      }

      // Default mention item builder
      final mentionColor = _parseTagColor(mention.color, context);
      return InkWell(
        key: key,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          _selectItem();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
                  backgroundColor:
                      mentionColor ?? Theme.of(context).colorScheme.primary,
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
                          fontSize:
                              Theme.of(context).textTheme.bodyLarge?.fontSize,
                          fontWeight:
                              Theme.of(context).textTheme.bodyLarge?.fontWeight,
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

      // Use custom builder if provided
      if (widget.tagItemBuilder != null) {
        return widget.tagItemBuilder!(
          context,
          tag,
          isSelected,
          () {
            setState(() {
              _selectedIndex = index;
            });
            _selectItem();
          },
        );
      }

      // Default tag item builder
      return InkWell(
        key: key,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          _selectItem();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.tag,
                size: 20,
                color: _parseTagColor(tag.color, context) ??
                    Theme.of(context).colorScheme.primary,
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

  bool get hasItems =>
      widget.isMention ? _mentions.isNotEmpty : _tags.isNotEmpty;

  String _formatTagDisplay(String tagName, String trigger) {
    if (trigger == '\$') {
      // Format as currency if numeric
      final numericValue = double.tryParse(tagName);
      if (numericValue != null) {
        // Format with commas for thousands
        final formattedValue = numericValue.toStringAsFixed(
            numericValue.truncateToDouble() == numericValue ? 0 : 2);
        final parts = formattedValue.split('.');
        final integerPart = parts[0];
        final decimalPart = parts.length > 1 ? parts[1] : '';

        // Add commas for thousands
        String formattedInteger = '';
        for (int i = integerPart.length - 1; i >= 0; i--) {
          if ((integerPart.length - 1 - i) % 3 == 0 &&
              i < integerPart.length - 1) {
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
