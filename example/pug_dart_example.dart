import 'dart:convert';
import 'dart:io';

import 'package:pug_dart/pug_dart.dart';

void main() {
  var encoder = JsonEncoder.withIndent('    ');
  var str = '''
:markdown-it
      code sample

  # Heading
  ''';
  var res = lex(str, LexerOptions(filename: 'my-file.pug'));
  print(encoder.convert(res));
  print(File(Directory.current.path + '/pug_dart_example.dart'));
}
