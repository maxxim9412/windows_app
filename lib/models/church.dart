import 'package:cloud_firestore/cloud_firestore.dart';

/// Церковь: своё название, свой график и свои админы.
class Church {
  final String id;
  final String name;
  final List<String> adminUids;

  const Church({required this.id, required this.name, required this.adminUids});

  factory Church.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Church(
      id: doc.id,
      name: (m['name'] as String?) ?? '',
      adminUids: List<String>.from(m['adminUids'] as List? ?? const []),
    );
  }
}
