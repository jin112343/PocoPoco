import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:poco/services/storage_service.dart';
import 'test_helpers.dart';

class _FailOnceStore extends InMemorySharedPreferencesStore {
  _FailOnceStore(super.data, this.failedKey, {this.throwError = false})
      : super.withData();
  final String failedKey;
  final bool throwError;
  bool failed = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == failedKey && !failed) {
      failed = true;
      if (throwError) throw StateError('Simulated disk failure');
      return false;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key == failedKey && !failed) {
      failed = true;
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  setUpAll(setUpTestEnvironment);
  setUp(clearStoredData);
  for (final failure in ['project', 'corrupted', 'remove', 'throw']) {
    test('Migration preserves durable data and retries after $failure failure',
        () async {
      final original =
          buildProject(id: 'legacy', rows: [8, 12], memo: 'needle 6');
      final legacy = [jsonEncode(original.toJson()), '{invalid-json'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('crochet_projects', legacy);
      final prior = SharedPreferencesStorePlatform.instance;
      final failedKey = failure == 'corrupted'
          ? 'flutter.crochet_projects_corrupted'
          : failure == 'remove'
              ? 'flutter.crochet_projects'
              : 'flutter.crochet_project_legacy';
      final disk = _FailOnceStore(
          {'flutter.crochet_projects': legacy}, failedKey,
          throwError: failure == 'throw');
      SharedPreferencesStorePlatform.instance = disk;
      try {
        await expectLater(StorageService().loadProjects(), throwsStateError);
        expect((await disk.getAll())['flutter.crochet_projects'], legacy);
        final restored = (await StorageService().loadProjects()).single;
        expect(restored.toJson(), original.toJson());
        final durable = await disk.getAll();
        expect(durable.containsKey('flutter.crochet_projects'), false);
        expect(durable['flutter.crochet_project_legacy'], legacy.first);
        expect(
            durable['flutter.crochet_projects_corrupted'], ['{invalid-json']);
      } finally {
        SharedPreferencesStorePlatform.instance = prior;
        await prefs.reload();
      }
    });
  }
  test('Concurrent migration callers retain every project and history',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final originals = List.generate(5,
        (i) => buildProject(id: 'legacy$i', rows: [i + 1, 12], memo: 'memo$i'));
    await prefs.setStringList('crochet_projects',
        originals.map((p) => jsonEncode(p.toJson())).toList());
    final results = await Future.wait(
        List.generate(4, (_) => StorageService().loadProjects()));
    for (final result in results) {
      expect(result.length, 5);
      for (final original in originals) {
        expect(result.singleWhere((p) => p.id == original.id).toJson(),
            original.toJson());
      }
    }
    expect(prefs.containsKey('crochet_projects'), false);
  });
}
