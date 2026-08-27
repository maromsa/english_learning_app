// test/support/fake_firebase_services.dart
//
// Shared test doubles for the Firestore-backed dependency chain that several
// services build by default (UserDataService -> FirebaseFirestore.instance).
// Any test that constructs one of these services — or a subclass of one,
// even via an implicit no-arg `super()` — without overriding every level of
// this chain will crash with:
//   [core/no-app] No Firebase App '[DEFAULT]' has been created
// because the real constructor eagerly evaluates `FirebaseFirestore.instance`
// even if the resulting object is never actually used.
//
// Use these helpers anywhere a service in that chain is constructed in a
// test, so the whole chain is backed by an in-memory FakeFirebaseFirestore
// instead of reaching for a real (uninitialized) Firebase app.

import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/services/map_bridge_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:english_learning_app/services/word_mastery_cloud_sync_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// A [UserDataService] backed by an in-memory fake Firestore — safe to
/// construct in widget/unit tests without calling Firebase.initializeApp().
UserDataService fakeUserDataService() =>
    UserDataService(firestore: FakeFirebaseFirestore());

/// A [WordMasteryCloudSyncService] whose [UserDataService] is faked out.
WordMasteryCloudSyncService fakeCloudSyncService() =>
    WordMasteryCloudSyncService(userDataService: fakeUserDataService());

/// A [LevelProgressService] whose Firestore-touching dependency
/// ([WordMasteryCloudSyncService] -> [UserDataService]) is fully faked out.
///
/// Pass [wordMasteryService] / [mapBridgeService] to further stub behaviour,
/// same as the real constructor.
LevelProgressService fakeLevelProgressService({
  WordMasteryService? wordMasteryService,
  MapBridgeService? mapBridgeService,
}) =>
    LevelProgressService(
      wordMasteryService: wordMasteryService,
      mapBridgeService: mapBridgeService,
      cloudSyncService: fakeCloudSyncService(),
    );
