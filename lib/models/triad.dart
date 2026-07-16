import 'package:cloud_firestore/cloud_firestore.dart';

/// Профиль участника — денормализованная копия для отображения.
///
/// Копия, а не ссылка на профиль, потому что правила не дают участникам читать
/// профили друг друга. Значит, при смене имени или телефона копию надо
/// обновлять — см. TriadService.syncMyProfileToTriad.
class TriadMember {
  final String uid;
  final String name;
  final String email;
  final String phone;
  const TriadMember({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
  });
}

/// Заявка на вступление третьего участника (нужно одобрение существующих).
class JoinRequest {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final List<String> approvals;
  const JoinRequest({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    required this.approvals,
  });
}

/// Расписание звонков тройки (дни недели + время).
class CallSchedule {
  final List<int> days; // 1=Пн ... 7=Вс
  final int hour;
  final int minute;
  const CallSchedule(
      {required this.days, required this.hour, required this.minute});

  Map<String, dynamic> toMap() => {'days': days, 'hour': hour, 'minute': minute};

  static CallSchedule? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return CallSchedule(
      days: List<int>.from(m['days'] as List? ?? const []),
      hour: (m['hour'] as num?)?.toInt() ?? 0,
      minute: (m['minute'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Предложение изменить расписание (нужно одобрение остальных участников).
class ScheduleProposal {
  final List<int> days;
  final int hour;
  final int minute;
  final String by;
  final List<String> approvals;
  const ScheduleProposal({
    required this.days,
    required this.hour,
    required this.minute,
    required this.by,
    required this.approvals,
  });
  CallSchedule get schedule =>
      CallSchedule(days: days, hour: hour, minute: minute);
}

/// Запрос на удаление участника (нужно одобрение оставшегося).
class RemovalRequest {
  final String targetUid;
  final String targetName;
  final String by;
  final List<String> approvals;
  const RemovalRequest(
      {required this.targetUid,
      required this.targetName,
      required this.by,
      required this.approvals});
}

/// Тройка: до 3 участников, код приглашения, заявки/запросы.
class Triad {
  final String id;
  final String createdBy;
  final List<String> memberUids;
  final Map<String, TriadMember> members;
  final String inviteCode;
  final List<JoinRequest> joinRequests;
  final List<RemovalRequest> removalRequests;
  final CallSchedule? callSchedule;
  final ScheduleProposal? scheduleProposal;

  /// Церковь тройки: все её участники читают один график, значит church у всех
  /// одна. Хранится здесь, а не вычисляется по профилям: правила Firestore не
  /// дают читать чужой профиль, так что иначе проверить церковь было бы нечем.
  ///
  /// null — тройка создана до этого правила, проверить её состав уже не по чему.
  final String? churchId;

  const Triad({
    required this.id,
    required this.createdBy,
    required this.memberUids,
    required this.members,
    required this.inviteCode,
    required this.joinRequests,
    required this.removalRequests,
    this.callSchedule,
    this.scheduleProposal,
    this.churchId,
  });

  int get memberCount => memberUids.length;
  bool get isFull => memberCount >= 3;

  factory Triad.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    final members = <String, TriadMember>{};
    final rawMembers = (d['members'] as Map<String, dynamic>? ?? {});
    rawMembers.forEach((uid, v) {
      final m = v as Map<String, dynamic>;
      members[uid] = TriadMember(
        uid: uid,
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
      );
    });

    final joinRequests = <JoinRequest>[];
    (d['joinRequests'] as Map<String, dynamic>? ?? {}).forEach((uid, v) {
      final m = v as Map<String, dynamic>;
      joinRequests.add(JoinRequest(
        uid: uid,
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        approvals: List<String>.from(m['approvals'] as List? ?? const []),
      ));
    });

    final removalRequests = <RemovalRequest>[];
    (d['removalRequests'] as Map<String, dynamic>? ?? {}).forEach((uid, v) {
      final m = v as Map<String, dynamic>;
      removalRequests.add(RemovalRequest(
        targetUid: uid,
        targetName: (m['targetName'] as String?) ?? '',
        by: (m['by'] as String?) ?? '',
        approvals: List<String>.from(m['approvals'] as List? ?? const []),
      ));
    });

    final proposalMap = d['scheduleProposal'] as Map<String, dynamic>?;
    final proposal = proposalMap == null
        ? null
        : ScheduleProposal(
            days: List<int>.from(proposalMap['days'] as List? ?? const []),
            hour: (proposalMap['hour'] as num?)?.toInt() ?? 0,
            minute: (proposalMap['minute'] as num?)?.toInt() ?? 0,
            by: (proposalMap['by'] as String?) ?? '',
            approvals:
                List<String>.from(proposalMap['approvals'] as List? ?? const []),
          );

    return Triad(
      id: doc.id,
      createdBy: (d['createdBy'] as String?) ?? '',
      memberUids: List<String>.from(d['memberUids'] as List? ?? const []),
      members: members,
      inviteCode: (d['inviteCode'] as String?) ?? '',
      joinRequests: joinRequests,
      removalRequests: removalRequests,
      callSchedule:
          CallSchedule.fromMap(d['callSchedule'] as Map<String, dynamic>?),
      scheduleProposal: proposal,
      churchId: d['churchId'] as String?,
    );
  }
}
