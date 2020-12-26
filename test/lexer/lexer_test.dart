import 'dart:io';

import 'package:pug_dart/pug_dart.dart';
import 'package:test/test.dart';

import '../utils/matchSnapshot.dart';

void main() {
  group('Lexer', () {
    final directory = Directory(Directory.current.path + '/test/lexer/cases/');

    directory.listSync(followLinks: false).forEach((entity) {
      if (RegExp(r'\.pug$').hasMatch(entity.path)) {
        test(entity.path, () {
          var res = lex(File(entity.path).readAsStringSync(),
                  LexerOptions(filename: entity.path))
              .map((e) => e.toJSON())
              .toList();
          expect(res, matchSnapshot(entity));
        });
      }
    });
  });
}
