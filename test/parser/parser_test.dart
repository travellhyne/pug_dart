import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:pug_dart/pug_dart.dart';

import '../utils/matchSnapshot.dart';

void main() {
  group('Parser', () {
    final directory = Directory(Directory.current.path + '/test/parser/cases/');
    final decoder = JsonDecoder();

    directory.listSync(followLinks: false).forEach((entity) {
      if (RegExp(r'\.json$').hasMatch(entity.path)) {
        test(entity.path, () {
          var tokens = File(entity.path)
            .readAsStringSync()
            .split('\n')
            .map((e) => Token.fromJSON(decoder.convert(e)))
            .toList();
          var ast = parse(tokens, ParserOptions(filename: entity.path));
          expect(ast.toJSON(), matchSnapshot(entity));
        });
      }
    });
  });
}
