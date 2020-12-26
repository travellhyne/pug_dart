import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

Matcher matchSnapshot(FileSystemEntity entity) {
  final snapshotDirectory = Directory(entity.parent.path + '/__snapshots__');
  var snapshotFile =
      File(snapshotDirectory.path + '/${entity.uri.pathSegments.last}.snap');

  if (!snapshotFile.existsSync()) {
    return _SnapshotMatcher(entity);
  } else {
    var decoder = JsonDecoder();
    var contents = snapshotFile.readAsStringSync();
    var contentsJSON = decoder.convert(contents);
    return equals(contentsJSON);
  }
}

class _SnapshotMatcher extends Matcher {
  const _SnapshotMatcher(this._entity);

  final FileSystemEntity _entity;

  @override
  bool matches(dynamic item, Map matchState) {
    final snapshotDirectory = Directory(_entity.parent.path + '/__snapshots__');
    var snapshotFile =
        File(snapshotDirectory.path + '/${_entity.uri.pathSegments.last}.snap');
    var encoder = JsonEncoder();
    var itemJSON = encoder.convert(item);

    assert(!snapshotFile.existsSync());
    snapshotFile.createSync(recursive: true);
    snapshotFile.writeAsStringSync(itemJSON);
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('matches snapshot');
  }
}
