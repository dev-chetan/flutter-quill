# Mentions and Tags Feature

This document explains how to use the mention (@) and tag (#) functionality in Flutter Quill.

## Overview

The mention and tag feature allows users to:
- Type `@` to mention users - shows a list of users above the keyboard
- Type `#` to add hashtags - shows a list of tags above the keyboard
- Select items from the list to insert them with proper attributes

## Setup

### 1. Wrap your QuillEditor with MentionTagWrapper

```dart
import 'package:flutter_quill/flutter_quill.dart';

MentionTagWrapper(
  controller: _controller,
  config: MentionTagConfig(
    mentionSearch: (query) async {
      // Your user search logic here
      // Return a list of MentionItem objects
      return [
        MentionItem(id: '1', name: 'John Doe'),
        MentionItem(id: '2', name: 'Jane Smith'),
      ];
    },
    tagSearch: (query) async {
      // Your tag search logic here
      // Return a list of TagItem objects
      return [
        TagItem(id: '1', name: 'flutter', count: 123),
        TagItem(id: '2', name: 'dart', count: 89),
      ];
    },
    onMentionSelected: (mention) {
      print('Mention selected: ${mention.name}');
    },
    onTagSelected: (tag) {
      print('Tag selected: ${tag.name}');
    },
  ),
  child: QuillEditor(
    controller: _controller,
    config: QuillEditorConfig(
      placeholder: 'Type @ for mentions or # for tags',
    ),
  ),
)
```

### 2. Configure MentionTagConfig

The `MentionTagConfig` requires:
- `mentionSearch`: Async function that searches for users based on query string
- `tagSearch`: Async function that searches for tags based on query string

Optional parameters:
- `maxHeight`: Maximum height of the overlay (default: 200)
- `itemHeight`: Height of each item in the list (default: 48)
- `onMentionSelected`: Callback when a mention is selected
- `onTagSelected`: Callback when a tag is selected

## Data Models

### MentionItem

```dart
class MentionItem {
  final String id;
  final String name;
  final String? avatarUrl; // Optional avatar URL
  final String? color; // Optional color as hex string (e.g., "#FF5733") or color name
}
```

### TagItem

```dart
class TagItem {
  final String id;
  final String name;
  final int? count; // Optional tag count
}
```

## Attributes

When a mention or tag is inserted, it's automatically formatted with attributes:

### Mention Attribute

```json
{
  "attributes": {
    "mention": {
      "id": "123",
      "name": "John Doe",
      "avatarUrl": "https://example.com/avatar.jpg",
      "color": "#FF5733"
    }
  }
}
```

### Tag Attribute

```json
{
  "attributes": {
    "tag": {
      "id": "456",
      "name": "flutter",
      "count": 123
    }
  }
}
```

## Usage Example

```dart
class MyEditor extends StatefulWidget {
  @override
  _MyEditorState createState() => _MyEditorState();
}

class _MyEditorState extends State<MyEditor> {
  final QuillController _controller = QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Mock user data
  final List<MentionItem> _users = [
    MentionItem(id: '1', name: 'John Doe'),
    MentionItem(id: '2', name: 'Jane Smith'),
    MentionItem(id: '3', name: 'Bob Johnson'),
  ];

  // Mock tag data
  final List<TagItem> _tags = [
    TagItem(id: '1', name: 'flutter', count: 123),
    TagItem(id: '2', name: 'dart', count: 89),
    TagItem(id: '3', name: 'mobile', count: 45),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuillSimpleToolbar(controller: _controller),
        Expanded(
          child: MentionTagWrapper(
            controller: _controller,
            config: MentionTagConfig(
              mentionSearch: (query) async {
                // Simulate network delay
                await Future.delayed(Duration(milliseconds: 300));
                
                if (query.isEmpty) return _users;
                
                return _users
                    .where((user) =>
                        user.name.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              },
              tagSearch: (query) async {
                // Simulate network delay
                await Future.delayed(Duration(milliseconds: 300));
                
                if (query.isEmpty) return _tags;
                
                return _tags
                    .where((tag) =>
                        tag.name.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              },
              onMentionSelected: (mention) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Mentioned: ${mention.name}')),
                );
              },
              onTagSelected: (tag) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tagged: #${tag.name}')),
                );
              },
            ),
            child: QuillEditor(
              focusNode: _focusNode,
              scrollController: _scrollController,
              controller: _controller,
              config: QuillEditorConfig(
                placeholder: 'Type @ for mentions or # for tags',
                padding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
```

## How It Works

1. **Trigger Detection**: When the user types `@` or `#`, the system detects the trigger character
2. **Query Extraction**: As the user continues typing, the query text is extracted
3. **Search**: The `mentionSearch` or `tagSearch` callback is called with the query
4. **Display**: Results are shown in an overlay above the keyboard
5. **Selection**: When a user selects an item:
   - The trigger character and query are replaced with the selected item's name
   - The text is formatted with the appropriate attribute (mention or tag)
   - The overlay is hidden

## Keyboard Navigation

The overlay supports keyboard navigation:
- **Arrow Up/Down**: Navigate through the list
- **Enter/Tab**: Select the highlighted item
- **Escape**: Close the overlay (handled automatically when typing continues)

## Customization

You can customize the appearance by modifying the `MentionTagOverlay` widget or by providing custom builders in the future.

## Notes

- The overlay appears above the keyboard automatically
- The search is debounced to avoid excessive API calls
- Mentions and tags are stored as inline attributes in the document
- The feature works on all platforms (iOS, Android, Web, Desktop)
