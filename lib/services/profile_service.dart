import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_profile.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _profileRef(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null || data['profileCompleted'] != true) return null;
      return UserProfile.fromMap(data);
    });
  }

  Future<void> saveProfile(String uid, UserProfile profile) {
    // Photo changes have their own field-level writes. An editor or delayed
    // appearance save must not restore an older avatar.
    final fields = profile.toMap()..remove('photoUrl');
    return _profileRef(uid).set({
      ...fields,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty || bytes.length >= 5 * 1024 * 1024) {
      throw ArgumentError('Profile photo must be smaller than 5 MB.');
    }
    final extension = fileName.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    // Avoid cached avatars and preserve the old image until upload succeeds.
    final ref = _storage.ref(
      'profile_photos/$uid/avatar_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await _profileRef(uid).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return url;
  }

  Future<void> removeProfilePhoto(String uid) => _profileRef(uid).update({
    'photoUrl': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
