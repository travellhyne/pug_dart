import 'dart:convert';

import 'package:pug_dart/pug_dart.dart';

void main() {
  var encoder = JsonEncoder.withIndent('    ');
  var str = '''
- var user = { name: 'tobi' }
foo(data-user=user)
foo(data-items=[1,2,3])
foo(data-username='tobi')
foo(data-escaped={message: "Let's rock!"})
foo(data-ampersand={message: "a quote: &quot; this & that"})
foo(data-epoc=new Date(0))
''';
  var tokens = lex(str, LexerOptions(filename: 'my-file.pug'));
  var ast = parse(tokens, ParserOptions(filename: 'my-file.pug'));
  print(encoder.convert(ast.toJSON()));
}
