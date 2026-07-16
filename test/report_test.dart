import 'package:bible_reflection/data/report_repository.dart';
import 'package:bible_reflection/models/triad.dart';
import 'package:flutter_test/flutter_test.dart';

Triad triadOf(String id, int members) => Triad(
      id: id,
      createdBy: 'u1',
      memberUids: [for (var i = 0; i < members; i++) 'u$i'],
      members: {
        for (var i = 0; i < members; i++)
          'u$i': TriadMember(uid: 'u$i', name: 'Имя $i', email: 'u$i@x.ru'),
      },
      inviteCode: 'ABC',
      joinRequests: const [],
      removalRequests: const [],
      churchId: 'c1',
    );

void main() {
  group('ChurchReport', () {
    test('делит тройки на полные и неполные', () {
      final r = ChurchReport(
        triads: [triadOf('a', 3), triadOf('b', 2), triadOf('c', 1)],
        totalMembers: null,
      );
      expect(r.triadCount, 3);
      expect(r.fullTriads.length, 1);
      expect(r.incompleteTriads.length, 2);
    });

    test('считает людей во всех тройках', () {
      final r = ChurchReport(
        triads: [triadOf('a', 3), triadOf('b', 2)],
        totalMembers: null,
      );
      expect(r.peopleInTriads, 5);
    });

    test('без общего числа людей «без тройки» не выдумывается', () {
      final r = ChurchReport(triads: [triadOf('a', 3)], totalMembers: null);
      expect(r.peopleWithoutTriad, isNull,
          reason: 'админу церкви общее число неизвестно — не показываем строку');
    });

    test('с общим числом людей считает, кто ещё без тройки', () {
      final r = ChurchReport(
        triads: [triadOf('a', 3), triadOf('b', 2)],
        totalMembers: 8,
      );
      expect(r.peopleWithoutTriad, 3);
    });

    test('пустая церковь не ломает подсчёт', () {
      const r = ChurchReport(triads: [], totalMembers: 4);
      expect(r.triadCount, 0);
      expect(r.peopleInTriads, 0);
      expect(r.peopleWithoutTriad, 4);
    });
  });
}
