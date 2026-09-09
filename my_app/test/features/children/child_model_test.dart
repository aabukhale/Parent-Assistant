import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/children/data/child_requests.dart';
import 'package:my_app/features/children/data/models/child.dart';
import 'package:my_app/features/children/data/models/interest.dart';

import '../../support/fixtures.dart';

void main() {
  group('Child.fromJson', () {
    test('parses birth_date, computed age, status and interest rows', () {
      final child = Child.fromJson(
        Fixtures.childJson(
          birthDate: '2017-05-04',
          age: 8,
          status: 'active',
          interests: [
            Fixtures.interestJson(id: 'int-animals', name: 'الحيوانات'),
            Fixtures.interestJson(id: 'int-drawing', name: 'الرسم'),
          ],
        ),
      );

      expect(child.birthDate, DateTime(2017, 5, 4));
      expect(child.age, 8);
      expect(child.status, ChildStatus.active);
      expect(child.gender, ChildGender.female);
      expect(child.interests.map((i) => i.id), ['int-animals', 'int-drawing']);
      expect(child.interestIds, ['int-animals', 'int-drawing']);
    });

    test('tolerates a null gender and empty interests', () {
      final child = Child.fromJson(
        Fixtures.childJson(gender: null, interests: []),
      );
      expect(child.gender, isNull);
      expect(child.interests, isEmpty);
    });

    test('archived status maps correctly', () {
      final child = Child.fromJson(Fixtures.childJson(status: 'archived'));
      expect(child.status, ChildStatus.archived);
    });
  });

  group('ChildInput.toJson', () {
    test(
      'trims name, sends birth_date as YYYY-MM-DD, always includes interest_ids',
      () {
        final json = ChildInput(
          name: '  Layan  ',
          birthDate: DateTime(2017, 5, 4),
          interestIds: const ['a', 'b'],
        ).toJson();

        expect(json['name'], 'Layan');
        expect(json['birth_date'], '2017-05-04');
        expect(json['interest_ids'], ['a', 'b']);
      },
    );

    test('omits gender and avatar_color when not set', () {
      final json = ChildInput(
        name: 'X',
        birthDate: DateTime(2018, 1, 2),
      ).toJson();
      expect(json.containsKey('gender'), isFalse);
      expect(json.containsKey('avatar_color'), isFalse);
      expect(json['interest_ids'], isEmpty);
    });

    test('includes gender wire value and avatar_color when set', () {
      final json = ChildInput(
        name: 'X',
        birthDate: DateTime(2018, 1, 2),
        gender: ChildGender.male,
        avatarColor: '#FFE4DF',
      ).toJson();
      expect(json['gender'], 'male');
      expect(json['avatar_color'], '#FFE4DF');
    });

    test('fromChild round-trips the writable fields', () {
      final child = Child.fromJson(Fixtures.childJson());
      final input = ChildInput.fromChild(child);
      expect(input.name, child.name);
      expect(input.birthDate, child.birthDate);
      expect(input.interestIds, child.interestIds);
    });
  });

  test('Interest equality is by id', () {
    expect(
      Interest.fromJson(Fixtures.interestJson(id: 'x', name: 'A')),
      Interest.fromJson(Fixtures.interestJson(id: 'x', name: 'B renamed')),
    );
  });
}
