import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/deep_links.dart';

void main() {
  group('DeepLinks.isAllowed', () {
    test('a child session only opens child routes', () {
      expect(DeepLinks.isAllowed('/child/tasks/t1', isChild: true), isTrue);
      expect(DeepLinks.isAllowed('/child/requests', isChild: true), isTrue);
      expect(DeepLinks.isAllowed('/parent/inbox', isChild: true), isFalse);
      expect(
        DeepLinks.isAllowed('/parent/children/c1/checkins', isChild: true),
        isFalse,
      );
    });

    test('a parent session only opens parent routes', () {
      expect(DeepLinks.isAllowed('/parent/inbox', isChild: false), isTrue);
      expect(DeepLinks.isAllowed('/child/tasks/t1', isChild: false), isFalse);
    });

    test('rejects anything that is not an in-app path', () {
      for (final route in [
        'https://evil.example/parent/inbox',
        'mamily://open/parent/inbox',
        '//evil.example/parent/inbox',
        '',
        '/',
        '/settings',
        'parent/inbox/../../child',
      ]) {
        expect(
          DeepLinks.isAllowed(route, isChild: false),
          isFalse,
          reason: route,
        );
      }
    });
  });
}
