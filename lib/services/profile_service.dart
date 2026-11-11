import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'profile_photo_api.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore, ProfilePhotoApi? photoApi})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _photoApi = photoApi ?? ProfilePhotoApi();

  final FirebaseFirestore _firestore;

  /// Profile photos live in Cloudflare R2 via the Worker (no Firebase Storage).
  final ProfilePhotoApi _photoApi;

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

  /// Uploads to R2 (`profile-images/{uid}/…`) and stores the public URL in
  /// `users/{uid}.photoUrl`, the same field as before. The previous photo is
  /// replaced by the Worker.
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    String? fileName,
  }) async {
    if (bytes.isEmpty || bytes.length > kMaxProfileImageBytes) {
      throw ArgumentError('Profile photo must be smaller than 5 MB.');
    }
    final url = await _photoApi.upload(uid: uid, bytes: bytes);
    await _profileRef(uid).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return url;
  }

  /// Deletes the R2 photo(s), then clears `photoUrl`.
  Future<void> removeProfilePhoto(String uid) async {
    await _photoApi.delete(uid: uid);
    await _profileRef(uid).update({
      'photoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
