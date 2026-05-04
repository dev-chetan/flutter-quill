import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/src/editor/config/events/mention_tag_handlers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('config updates preserve active tag selection state', () {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);

    controller.replaceText(
      0,
      0,
      '#Demo Tes',
      const TextSelection.collapsed(offset: 9),
    );

    final state = MentionTagState(
      config: MentionTagConfig(
        mentionSearch: (_) async => const [],
        tagSearch: (_) async => const [],
        dollarSearch: (_) async => const [],
      ),
      controller: controller,
    );

    state.showOverlay(false, 0, 'Demo Tes', tagTrigger: '#');

    state.updateConfig(
      MentionTagConfig(
        mentionSearch: (_) async => const [],
        tagSearch: (_) async => const [],
        dollarSearch: (_) async => const [],
      ),
    );

    state.overlayWidget?.onSelectTag(
      const TagItem(id: '1', name: 'Demo Test'),
    );

    expect(controller.document.toPlainText(), '#Demo Test \n');
  });
}
