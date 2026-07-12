import 'package:cloud_firestore/cloud_firestore.dart';

/// Профиль участника (денормализованная копия для отображения).
class TriadMember {
  final String uid;
  final String name;
  final String email;
  const TriadMember(
      {required this.uid, required this.name, required this.email});
}

/// Заявка на вступление третьего участника (нужно одобрение существующих).
class JoinRequest {
  final String uid;
  final String name;
  final String email;
  final List<String> approvals;
  const JoinRequest(
      {required this.uid,
      required this.name,
      required this.email,
      required this.approvals});
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

  const Triad({
    required this.id,
    required this.createdBy,
    required this.memberUids,
    required this.members,
    required this.inviteCode,
    required this.joinRequests,
    required this.removalRequests,
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
      );
    });

    final joinRequests = <JoinRequest>[];
    (d['joinRequests'] as Map<String, dynamic>? ?? {}).forEach((uid, v) {
      final m = v as Map<String, dynamic>;
      joinRequests.add(JoinRequest(
        uid: uid,
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
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

    return Triad(
      id: doc.id,
      createdBy: (d['createdBy'] as String?) ?? '',
      memberUids: List<String>.from(d['memberUids'] as List? ?? const []),
      members: members,
      inviteCode: (d['inviteCode'] as String?) ?? '',
      joinRequests: joinRequests,
      removalRequests: removalRequests,
    );
  }
}
