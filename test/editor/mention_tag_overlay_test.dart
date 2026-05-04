import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MentionTagOverlay ignores stale mention search results',
      (tester) async {
    final searches = <String, Completer<List<MentionItem>>>{};

    Future<List<MentionItem>> mentionSearch(String query) {
      final completer = Completer<List<MentionItem>>();
      searches[query] = completer;
      return completer.future;
    }

    Widget buildOverlay(String query) {
      return MaterialApp(
        home: Scaffold(
          body: MentionTagOverlay(
            query: query,
            isMention: true,
            onSelectMention: (_) {},
            onSelectTag: (_) {},
            mentionSearch: mentionSearch,
            tagSearch: (_) async => const [],
            dollarSearch: (_) async => const [],
          ),
        ),
      );
    }

    await tester.pumpWidget(buildOverlay('a'));
    expect(searches.containsKey('a'), isTrue);

    await tester.pumpWidget(buildOverlay('ab'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(searches.containsKey('ab'), isTrue);

    searches['ab']!.complete(const [
      MentionItem(id: 'ab', name: 'AB'),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('@AB'), findsOneWidget);

    searches['a']!.complete(const [
      MentionItem(id: 'a', name: 'A'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('@AB'), findsOneWidget);
    expect(find.text('@A'), findsNothing);
  });

  testWidgets('MentionTagOverlay hides when search returns no results',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MentionTagOverlay(
            query: 'missing',
            isMention: true,
            onSelectMention: (_) {},
            onSelectTag: (_) {},
            mentionSearch: (_) async => const [],
            tagSearch: (_) async => const [],
            dollarSearch: (_) async => const [],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('MentionTagOverlay does not refresh for callback identity only',
      (tester) async {
    var searchCount = 0;

    Widget buildOverlay(MentionSearchCallback mentionSearch) {
      return MaterialApp(
        home: Scaffold(
          body: MentionTagOverlay(
            query: 'user',
            isMention: true,
            onSelectMention: (_) {},
            onSelectTag: (_) {},
            mentionSearch: mentionSearch,
            tagSearch: (_) async => const [],
            dollarSearch: (_) async => const [],
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildOverlay((_) async {
        searchCount++;
        return const [MentionItem(id: '1', name: 'User 1')];
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(searchCount, 1);
    expect(find.text('@User 1'), findsOneWidget);

    await tester.pumpWidget(
      buildOverlay((_) async {
        searchCount++;
        return const [MentionItem(id: '2', name: 'User 2')];
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(searchCount, 1);
    expect(find.text('@User 1'), findsOneWidget);
    expect(find.text('@User 2'), findsNothing);
  });
}
