import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

Matcher matchSnapshot(FileSystemEntity entity) => _SnapshotMatcher(entity);

class _SnapshotMatcher extends Matcher {
  const _SnapshotMatcher(this._entity);

  final FileSystemEntity _entity;

  @override
  bool matches(dynamic item, Map matchState) {
    final snapshotDirectory = Directory(_entity.parent.path + '/__snapshots__');
    var snapshotFile = File(snapshotDirectory.path + '/${_entity.uri.pathSegments.last}.snap');
    var encoder = JsonEncoder.withIndent('  ');
    var itemJSON = encoder.convert(item);

    if (!snapshotFile.existsSync()) {
      snapshotFile.createSync(recursive: true);
      snapshotFile.writeAsStringSync(itemJSON);
      return true;
    }

    final contentsToCompare = snapshotFile.readAsStringSync();
    return contentsToCompare == itemJSON;
  }

  @override
  Description describe(Description description) {
    return description.add('matches snapshot');
  }
}