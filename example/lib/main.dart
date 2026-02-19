import 'dart:convert';
import 'dart:io' as io show Directory, File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:path/path.dart' as path;

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const HomePage(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// ---------------------------------------------------------------------------
// Demo data & pagination (type @ # $ in editor to see lists; scroll to load more)
// ---------------------------------------------------------------------------

const int _pageSize = 5;
const int _searchDelayMs = 200;
const int _loadMoreDelayMs = 400;

/// Returns a page of items from [list], filtered by [query]; [page] is 0-based.
List<T> _paginatedSearch<T>(
  List<T> list,
  String query,
  int page,
  String Function(T) getName,
) {
  final filtered = query.isEmpty
      ? list
      : list
          .where((x) => getName(x).toLowerCase().contains(query.toLowerCase()))
          .toList();
  final start = page * _pageSize;
  if (start >= filtered.length) return [];
  return filtered.sublist(start, (start + _pageSize).clamp(0, filtered.length));
}

String _hexColor(int i, {int a = 37, int b = 17, int c = 7}) {
  final r = ((i * a % 155) + 100).toRadixString(16).padLeft(2, '0');
  final g = ((i * b % 155) + 100).toRadixString(16).padLeft(2, '0');
  final bl = ((i * c % 155) + 100).toRadixString(16).padLeft(2, '0');
  return '#$r$g$bl';
}

const Widget _loadMoreIndicator = Padding(
  padding: EdgeInsets.all(12),
  child: Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  ),
);

final List<TagItem> _mainTagList = [
  TagItem(id: '1', name: 'flutter', count: 123),
  TagItem(id: '2', name: 'dart', count: 89),
  TagItem(id: '3', name: 'mobile', count: 45),
  TagItem(id: '4', name: 'development', count: 67),
  TagItem(id: '5', name: 'widgets', count: 56),
  TagItem(id: '6', name: 'state', count: 78),
  TagItem(id: '7', name: 'async', count: 34),
  TagItem(id: '8', name: 'testing', count: 91),
  TagItem(id: '9', name: 'ui', count: 112),
  TagItem(id: '10', name: 'api', count: 44),
  TagItem(id: '11', name: 'database', count: 33),
  TagItem(id: '12', name: 'navigation', count: 28),
  TagItem(id: '13', name: 'forms', count: 65),
  TagItem(id: '14', name: 'theme', count: 41),
  TagItem(id: '15', name: 'responsive', count: 19),
  TagItem(id: '16', name: 'performance', count: 52),
  TagItem(id: '17', name: 'plugins', count: 88),
  TagItem(id: '18', name: 'packages', count: 77),
  TagItem(id: '19', name: 'layout', count: 36),
  TagItem(id: '20', name: 'animations', count: 61),
  TagItem(id: '21', name: 'gestures', count: 24),
  TagItem(id: '22', name: 'platform', count: 43),
  TagItem(id: '23', name: 'web', count: 95),
  TagItem(id: '24', name: 'desktop', count: 31),
];

final List<MentionItem> _mainMentionList = List.generate(
  50,
  (i) => MentionItem(
    id: '${i + 1}',
    name: 'User ${i + 1}',
    avatarUrl: null,
  ),
);

final List<TagItem> _mainDollarList = List.generate(
  50,
  (i) => TagItem(
    id: '${i + 1}',
    name: 'Amount ${i + 1}',
    count: (i + 1) * 100,
  ),
);

Future<String?> _savePastedImageToTemp(Uint8List imageBytes) async {
  if (kIsWeb) return null;
  final name = 'image-file-${DateTime.now().toIso8601String()}.png';
  final file = await io.File(path.join(io.Directory.systemTemp.path, name))
      .writeAsBytes(imageBytes, flush: true);
  return file.path;
}

class _HomePageState extends State<HomePage> {
  late final QuillController _controller = QuillController.basic(
    config: QuillControllerConfig(
      clipboardConfig: QuillClipboardConfig(
        enableExternalRichPaste: true,
        onImagePaste: _savePastedImageToTemp,
      ),
    ),
  );
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load document
    _controller.document = Document();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Quill Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.output),
            tooltip: 'Print Delta JSON to log',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('The JSON Delta has been printed to the console.')));
              debugPrint(jsonEncode(_controller.document.toDelta().toJson()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          /*QuillSimpleToolbar(
            controller: _controller,
            config: QuillSimpleToolbarConfig(
              embedButtons: FlutterQuillEmbeds.toolbarButtons(),
              showClipboardPaste: true,
              customButtons: [
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.add_alarm_rounded),
                  onPressed: () {
                    _controller.document.insert(
                      _controller.selection.extentOffset,
                      TimeStampEmbed(
                        DateTime.now().toString(),
                      ),
                    );

                    _controller.updateSelection(
                      TextSelection.collapsed(
                        offset: _controller.selection.extentOffset + 1,
                      ),
                      ChangeSource.local,
                    );
                  },
                ),
              ],
              buttonOptions: QuillSimpleToolbarButtonOptions(
                base: QuillToolbarBaseButtonOptions(
                  afterButtonPressed: () {
                    final isDesktop = {
                      TargetPlatform.linux,
                      TargetPlatform.windows,
                      TargetPlatform.macOS
                    }.contains(defaultTargetPlatform);
                    if (isDesktop) {
                      _editorFocusNode.requestFocus();
                    }
                  },
                ),
                linkStyle: QuillToolbarLinkStyleButtonOptions(
                  validateLink: (link) {
                    // Treats all links as valid. When launching the URL,
                    // `https://` is prefixed if the link is incomplete (e.g., `google.com` → `https://google.com`)
                    // however this happens only within the editor.
                    return true;
                  },
                ),
              ),
            ),
          ),*/
          Expanded(
            child: MentionTagWrapper(
              controller: _controller,

              config: MentionTagConfig(
                  defaultMentionColor: '#FFC0CB',
                  defaultHashTagColor: '#FF0000',
                  defaultDollarTagColor: '#0000FF',

                  decoration: BoxDecoration(color: Colors.white),
                  suggestionListPadding: EdgeInsets.symmetric(vertical: 30),
                  mentionSearch: (query) async {
                    await Future.delayed(
                        const Duration(milliseconds: _searchDelayMs));
                    print("@@@@@@@@@ mentionSearch (){...}");
                    return _paginatedSearch(
                        _mainMentionList, query, 0, (u) => u.name);
                  },
                  onLoadMoreMentions: (query, currentItems, currentPage) async {
                    await Future.delayed(
                        const Duration(milliseconds: _loadMoreDelayMs));
                    print("@@@@@@@@@ onLoadMoreMentions (){...}");
                    var paginatedSearch = _paginatedSearch(_mainMentionList,
                        query, currentPage + 1, (u) => u.name);
                    List<MentionItem> temp = [];
                    for (var action in paginatedSearch) {
                      temp.add(MentionItem(id: action.id, name: action.name));
                    }
                    return temp;
                    //return _paginatedSearch(_mainMentionList, query, currentPage + 1, (u) => u.name);
                  },
                  itemHeight: 20,
                  tagSearch: (query) async {
                    await Future.delayed(
                        const Duration(milliseconds: _searchDelayMs));
                    print("\$\$\$\$\$\$ tagSearch (){...}");
                    return _paginatedSearch(
                        _mainTagList, query, 0, (t) => t.name);
                  },
                  onLoadMoreTags: (query, currentItems, currentPage) async {
                    await Future.delayed(
                        const Duration(milliseconds: _loadMoreDelayMs));
                    print("\$\$\$\$\$\$ onLoadMoreTags (){...}");
                    return _paginatedSearch(
                        _mainTagList, query, currentPage + 1, (t) => t.name);
                  },
                  loadMoreIndicatorBuilder: (context, isMention, tagTrigger) =>
                      _loadMoreIndicator,
                  dollarSearch: (query) async {
                    await Future.delayed(
                        const Duration(milliseconds: _searchDelayMs));
                    return _paginatedSearch(
                        _mainDollarList, query, 0, (t) => t.name);
                  },
                  onLoadMoreDollarTags:
                      (query, currentItems, currentPage) async {
                    await Future.delayed(
                        const Duration(milliseconds: _loadMoreDelayMs));
                    return _paginatedSearch(
                        _mainDollarList, query, currentPage + 1, (t) => t.name);
                  },
                  onMentionSelected: (mention) {
                    debugPrint('Mention selected: ${mention.name}');
                  },
                  onTagTypingChanged: (bool isTypingTag) {
                    // true  → user is typing a tag/mention (e.g. after @, #, or $)
                    // false → user is not in tag-typing mode
                    print('isTypingTag : $isTypingTag');
                    if (isTypingTag) {
                      // e.g. hide toolbar, show different UI
                      // _controller.requestShowCaretOnScreen = true;
                      // _controller.notifyListeners();
                    } else {
                      // e.g. show normal toolbar
                    }
                  },
                  onTagSelected: (tag) {
                    debugPrint('Tag selected: ${tag.name}');
                  },
                  tagItemBuilder: (context, item, isSelected, onTap, _) {
                    // return Container(
                    //     color: Colors.red, child: Text(item.name));
                    return ListTile(
                        //leading: Icon(Icons.tag),
                        title: Text(item.name),
                        trailing:
                            item.count != null ? Text('${item.count}') : null,
                        selected: isSelected,
                        onTap: onTap);
                  },
                  mentionItemBuilder: (context, item, isSelected, onTap, _) {
                    // return Container(
                    //     color: Colors.red, child: Text('@${item.name}'));
                    return ListTile(
                        //leading: CircleAvatar(child: Text(item.name[0])),
                        title: Text('@${item.name}'),
                        selected: isSelected,
                        onTap: onTap);
                  }),
              child: QuillEditor(
                focusNode: _editorFocusNode,
                scrollController: _editorScrollController,
                controller: _controller,
                config: QuillEditorConfig(
                  placeholder: 'Start writing your notes...',
                  hidePlaceholderOnFormat: true,
                  padding: const EdgeInsets.all(16),
                  embedBuilders: [
                    ...FlutterQuillEmbeds.editorBuilders(
                      imageEmbedConfig: QuillEditorImageEmbedConfig(
                        imageProviderBuilder: (context, imageUrl) {
                          // https://pub.dev/packages/flutter_quill_extensions#-image-assets
                          if (imageUrl.startsWith('assets/')) {
                            return AssetImage(imageUrl);
                          }
                          return null;
                        },
                      ),
                      videoEmbedConfig: QuillEditorVideoEmbedConfig(
                        customVideoBuilder: (videoUrl, readOnly) {
                          // To load YouTube videos https://github.com/singerdmx/flutter-quill/releases/tag/v10.8.0
                          return null;
                        },
                      ),
                    ),
                    TimeStampEmbedBuilder(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }
}

class TimeStampEmbed extends Embeddable {
  const TimeStampEmbed(
    String value,
  ) : super(timeStampType, value);

  static const String timeStampType = 'timeStamp';

  static TimeStampEmbed fromDocument(Document document) =>
      TimeStampEmbed(jsonEncode(document.toDelta().toJson()));

  Document get document => Document.fromJson(jsonDecode(data));
}

class TimeStampEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'timeStamp';

  @override
  String toPlainText(Embed node) {
    return node.value.data;
  }

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    return Row(
      children: [
        const Icon(Icons.access_time_rounded),
        Text(embedContext.node.value.data as String),
      ],
    );
  }
}
