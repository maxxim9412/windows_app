import 'package:bible_reflection/data/report_repository.dart';
import 'package:bible_reflection/models/triad.dart';
import 'package:flutter_test/flutter_test.dart';

/// Тройка из [members] человек: uid'ы вида t1u0, t1u1… — чтобы у разных троек
/// участники не совпадали.
Triad triadOf(String id, int members) => Triad(
      id: id,
      createdBy: '${id}u0',
      memberUids: [for (var i = 0; i < members; i++) '${id}u$i'],
      members: {
        for (var i = 0; i < members; i++)
          '${id}u$i': TriadMember(
              uid: '${id}u$i', name: 'Имя $i', email: '$id$i@x.ru'),
      },
      inviteCode: 'ABC',
      joinRequests: const [],
      removalRequests: const [],
      churchId: 'c1',
    );

ChurchPerson person(String uid) =>
    ChurchPerson(uid: uid, name: 'Имя $uid', email: '$uid@x.ru');

void main() {
  group('ChurchReport', () {
    test('делит тройки на полные и неполные', () {
      final r = ChurchReport(
          triads: [triadOf('a', 3), triadOf('b', 2), triadOf('c', 1)]);
      expect(r.triadCount, 3);
      expect(r.fullTriads.length, 1);
      expect(r.incompleteTriads.length, 2);
    });

    test('считает людей во всех тройках', () {
      final r = ChurchReport(triads: [triadOf('a', 3), triadOf('b', 2)]);
      expect(r.peopleInTriads, 5);
    });

    test('без списка прихожан «без тройки» не выдумывается', () {
      final r = ChurchReport(triads: [triadOf('a', 3)]);
      expect(r.withoutTriad, isNull,
          reason: 'админу церкви профили закрыты — не показываем раздел');
      expect(r.totalMembers, isNull);
    });

    test('«без тройки» — это прихожане, которых нет ни в одной тройке', () {
      final r = ChurchReport(
        triads: [triadOf('a', 2)], // a u0, a u1
        members: [person('au0'), person('au1'), person('x'), person('y')],
      );
      expect(r.totalMembers, 4);
      expect(r.withoutTriad!.map((p) => p.uid).toList(), ['x', 'y']);
    });

    test('все в тройках — раздел «без тройки» пуст', () {
      final r = ChurchReport(
        triads: [triadOf('a', 2)],
        members: [person('au0'), person('au1')],
      );
      expect(r.withoutTriad, isEmpty);
    });

    test('пустая церковь не ломает подсчёт', () {
      final r = ChurchReport(triads: const [], members: [person('x')]);
      expect(r.triadCount, 0);
      expect(r.peopleInTriads, 0);
      expect(r.withoutTriad!.length, 1);
    });
  });
}
