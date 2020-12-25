import 'dart:math';

import 'package:meta/meta.dart';

import '../../pug_dart.dart';
import '../utils/character_parser.dart' as character_parser;
import '../utils/string.dart';

List<Token> lex(String str, LexerOptions options) {
  final lexer = Lexer(str, options: options);

  return lexer.getTokens();
}

class Lexer {
  Lexer(String str, {@required LexerOptions options}) {
    input = str
      ..replaceAll(RegExp(r'^\uFEFF'), '')
      ..replaceAll(RegExp(r'\r\n|\r'), '\n');
    originalInput = input;
    filename = options.filename;
    interpolated = options.interpolated ?? false;
    lineno = options.startingLine ?? 1;
    colno = options.startingColumn ?? 1;
  }

  String input;
  String originalInput;
  String filename;
  bool interpolated;
  int lineno;
  int colno;
  RegExp indentRe;
  var indentStack = <num>[0];
  var interpolationAllowed = true;
  var whitespaceRe = RegExp(r'[ \n\t]');
  List<Token> tokens = [];
  var ended = false;

  void error(String code, String message) {
    var err = makeError(
      code: code, 
      message: message, 
      options: {
        'line': lineno,
        'column': colno,
        'filename': filename,
        'src': originalInput,
      },
    );

    throw err;
  }

  void assertValue(dynamic value, String message) {
    if (value == null || value as bool == false) {
      error('ASSERT_FAILED', message);
    }
  }

  bool assertExpression(String exp, [dynamic value]) {
    return exp != null;
  }

  Token tok(String type, [String val]) {
    var res = Token(
      type: type,
      loc: TokenLoc(
        start: TokenLocPoint(
          line: lineno,
          column: colno,
        ),
        filename: filename,
      ),
    );

    if (val != null) {
      res.val = val;
    }

    return res;
  }

  Token tokEnd(Token token) {
    token.loc.end = TokenLocPoint(
      column: colno,
      line: lineno,
    );

    return token;
  }

  void incrementLine(int increment) {
    lineno += increment;
    if (increment > 0) {
      colno = 1;
    }
  }

  void incrementColumn(int increment) {
    colno += increment;
  }

  void consume(int len) {
    input = input.substr(len);
  }

  Token scan(RegExp regExp, [String type]) {
    var captures = regExp.firstMatch(input);

    if (captures != null) {
      var len = captures.group(0).length;
      var val = captures.groupCount >= 1 ? captures.group(1) : null;

      var diff = len - (val?.length ?? 0);
      var token = tok(type, val);
      consume(len);
      incrementColumn(diff);
      return token;
    }

    return null;
  }

  Token scanEndOfLine(RegExp regExp, String type) {
    var captures = regExp.firstMatch(input);

    if (captures != null) {
      var whitespaceLength = 0;
      var whitespace = RegExp(r'^([ ]+)([^ ]*)').firstMatch(captures.group(0));
      Token token;

      if (whitespace != null) {
        whitespaceLength = whitespace.group(1)?.length ?? 0;
        incrementColumn(whitespaceLength);
      }

      var res = captures.group(0);
      var newInput = input.substr(res.length);

      if (newInput.isNotEmpty && newInput[0] == ':') {
        input = newInput;
        token = tok(type, captures.groupCount >= 1 ? captures.group(1) : null);
        incrementColumn(captures.group(0).length - whitespaceLength);
        return token;
      }

      if (RegExp(r'^[ \t]*(\n|$)').hasMatch(newInput)) {
        input = newInput.substr(RegExp(r'^[ \t]*').firstMatch(newInput).group(0).length);
        token = tok(type, captures.groupCount >= 1 ? captures.group(1) : null);
        incrementColumn(captures.group(0).length - whitespaceLength);
        return token;
      }
    }

    return null;
  }

  character_parser.ParserResult bracketExpression([int skip]) {
    skip = skip ?? 0;

    var start = input[skip];

    assertValue(
      start == '(' || start == '{' || start == '[',
      'The start character should be "(", "{" or "["',
    );

    var end = character_parser.brackets[start];
    character_parser.ParserResult range;

    try {
      range = character_parser.parseUntil(input, end, character_parser.ParserOptions()..start = skip + 1);
    } on character_parser.ParserException catch (ex) {
      if (ex.index != null) {
        var idx = ex.index;
        var tmp = input.substr(skip).indexOf('\n');
        var nextNewline = tmp + skip;
        var ptr = 0;

        while (idx > nextNewline && tmp != -1) {
          incrementLine(1);
          idx -= nextNewline + 1;
          ptr += nextNewline + 1;
          tmp = nextNewline = input.substr(ptr).indexOf('\n');
        }

        incrementColumn(idx);
      }

      if (ex.code == 'CHARACTER_PARSER:END_OF_STRING_REACHED') {
        error(
          'NO_END_BRACKET',
          'The end of the string reached with no closing bracket $end found.',
        );
      } else if (ex.code == 'CHARACTER_PARSER:MISMATCHED_BRACKET') {
        error('BRACKET_MISMATCH', ex.message);
      }
      rethrow;
    }

    return range;
  }

  RegExpMatch scanIndentation() {
    RegExpMatch captures;
    RegExp re;

    if (indentRe != null) {
      captures = indentRe.firstMatch(input);
    } else {
      re = RegExp(r'^\n(\t*) *');
      captures = re.firstMatch(input);

      if (captures != null && captures.group(1).isEmpty) {
        re = RegExp(r'^\n( *)');
        captures = re.firstMatch(input);
      }

      if (captures != null && captures.group(1).isNotEmpty) {
        indentRe = re;
      }
    }

    return captures;
  }

  bool eos() {
    if (input.isNotEmpty) return false;
    if (interpolated) {
      error(
        'NO_END_BRACKET',
        'End of line was reached with no closing bracket for interpolation.'
      );
    }
    for (var indent in indentStack) {
      if (indent != null && indent != 0) {
        tokens.add(tokEnd(tok('outdent')));
      }
    }
    tokens.add(tokEnd(tok('eos')));
    ended = true;
    return true;
  }

  bool blank() {
    var captures = RegExp(r'^\n[ \t]*\n').firstMatch(input);

    if (captures != null) {
      consume(captures.group(0).length - 1);
      incrementLine(1);
      return true;
    }

    return false;
  }

  bool comment() {
    var captures = RegExp(r'^\/\/(-)?([^\n]*)').firstMatch(input);

    if (captures != null) {
      consume(captures.group(0).length);
      var token = tok('comment', captures.group(2))
        ..buffer = '-' != captures.group(1);
      interpolationAllowed = token.buffer;
      tokens.add(token);
      incrementColumn(captures.group(0).length);
      tokEnd(token);
      pipelessText();
      return true;
    }

    return false;
  }

  bool interpolation() {
    if (RegExp(r'^#\{').hasMatch(input)) {
      var match = bracketExpression(1);
      consume(match.end + 1);
      var token = tok('interpolation', match.src);
      tokens.add(token);
      incrementColumn(2); // '#{'
      // assertExpression(match.src);

      var splitted = match.src.split('\n');
      var lines = splitted.length - 1;
      incrementLine(lines);
      incrementColumn(splitted[lines].length + 1); // + 1 → '}'
      tokEnd(token);
      return true;
    }
    return false;
  }

  bool tag() {
    var captures = RegExp(r'^(\w(?:[-:\w]*\w)?)').firstMatch(input);

    if (captures != null) {
      var name = captures.group(1);
      var len = captures.group(0).length;
      consume(len);
      var token = tok('tag', name);
      tokens.add(token);
      incrementColumn(len);
      tokEnd(token);
      return true;
    }

    return false;
  }

  bool filter([FilterOpts opts]) {
    var token = scan(RegExp(r'^:([\w\-]+)'), 'filter');
    var inInclude = opts?.inInclude ?? false;

    if (token != null) {
      tokens.add(token);
      incrementColumn(token.val?.length ?? 0);
      tokEnd(token);
      attrs();

      if (!inInclude) {
        interpolationAllowed = true;
        pipelessText();
      }

      return true;
    }

    return false;
  }

  bool docType() {
    var node = scanEndOfLine(RegExp(r'^doctype *([^\n]*)'), 'doctype');

    if (node != null) {
      tokens.add(tokEnd(node));
      return true;
    }

    return false;
  }

  bool id() {
    var token = scan(RegExp(r'^#([\w-]+)'), 'id');

    if (token != null) {
      tokens.add(token);
      incrementColumn(token.val?.length ?? 0);
      tokEnd(token);

      return true;
    }

    if(RegExp(r'^#').hasMatch(input)) {
      var invalidId = RegExp(r'.[^ \t\(\#\.\:]*').firstMatch(input.substr(1)).group(0);
      error(
        'INVALID_ID',
        '"$invalidId" is not a valid ID.'
      );
    }

    return false;
  }

  bool className() {
    var token = scan(
      RegExp(r'^\.([_a-z0-9\-]*[_a-z][_a-z0-9\-]*)', caseSensitive: false),
      'class',
    );

    if (token != null) {
      tokens.add(token);
      incrementColumn(token.val?.length ?? 0);
      tokEnd(token);
      return true;
    }

    if (RegExp(r'^\.[_a-z0-9\-]+', caseSensitive: false).hasMatch(input)) {
      error(
        'INVALID_CLASS_NAME',
        'Class names must contain at least one letter or underscore.'
      );
    }

    if (RegExp(r'^\.').hasMatch(input)) {
      var invalidClassName = RegExp(r'.[^ \t\(\#\.\:]*').firstMatch(input.substr(1)).group(0);
      error(
        'INVALID_CLASS_NAME',
        '"$invalidClassName" is not a valid class name.  Class names can only contain "_", "-", a-z and 0-9, and must contain at least one of "_", or a-z'
      );
    }

    return false;
  }

  bool endInterpolation() {
    if (interpolated && input[0] == ']') {
      input = input.substr(1);
      ended = true;
      return true;
    }

    return false;
  }

  void addText(String type, String value, [String prefix, int escaped]) {
    Token token;

    if (prefix == null || value == null || (value + prefix) == '') return;

    prefix ??= '';
    escaped ??= 0;
    num indexOfEnd = interpolated ? value.indexOf(']') : -1;
    num indexOfStart = interpolationAllowed ? value.indexOf('#[') : -1;
    num indexOfEscaped = interpolationAllowed ? value.indexOf('\\#[') : -1;
    var matchOfStringInterp = RegExp(r'(\\)?([#!]){((?:.|\n)*)$').firstMatch(value);
    var indexOfStringInterp =
      interpolationAllowed && matchOfStringInterp != null
        ? matchOfStringInterp.start : double.infinity;

    if (indexOfEnd == -1) indexOfEnd = double.infinity;
    if (indexOfStart == -1) indexOfStart = double.infinity;
    if (indexOfEscaped == -1) indexOfEscaped = double.infinity;

    if (
      indexOfEscaped != double.infinity &&
      indexOfEscaped < indexOfEnd &&
      indexOfEscaped < indexOfStart &&
      indexOfEscaped < indexOfStringInterp
    ) {
      prefix = prefix + value.substring(0, indexOfEscaped) + '#[';
      return addText(
        type,
        value.substring(indexOfEscaped + 3),
        prefix,
        escaped + 1
      );
    }

    if (
      indexOfStart != double.infinity &&
      indexOfStart < indexOfEnd &&
      indexOfStart < indexOfEscaped &&
      indexOfStart < indexOfStringInterp
    ) {
      token = tok(type, prefix + value.substring(0, indexOfStart));
      incrementColumn(prefix.length + indexOfStart + escaped);
      tokens.add(tokEnd(token));
      token = tok('start-pug-interpolation');
      incrementColumn(2);
      tokens.add(tokEnd(token));
      var child = Lexer(
        value.substr(indexOfStart + 2),
        options: LexerOptions(
          filename: filename,
          interpolated: true,
          startingLine: lineno,
          startingColumn: colno,
        )
      );
      List<Token> interpolated;
      try {
        interpolated = child.getTokens();
      } on PugException catch (ex) {
        if (ex.code != null && RegExp(r'^PUG:').hasMatch(ex.code)) {
          colno = ex.column;
          error(ex.code.substr(4), ex.msg);
        }
        rethrow;
      }
      colno = child.colno;
      tokens += interpolated;
      token = tok('end-pug-interpolation');
      incrementColumn(1);
      tokens.add(tokEnd(token));
      addText(type, child.input);
      return;
    }

    if (
      indexOfEnd != double.infinity &&
      indexOfEnd < indexOfStart &&
      indexOfEnd < indexOfEscaped &&
      indexOfEnd < indexOfStringInterp
    ) {
      if ((prefix + value.substring(0, indexOfEnd)).isNotEmpty) {
        addText(type, value.substring(0, indexOfEnd), prefix);
      }
      ended = true;
      input = value.substr(value.indexOf(']') + 1) + input;
      return;
    }

    if (indexOfStringInterp != double.infinity) {
      if (matchOfStringInterp.group(1) != null) {
        prefix = prefix + value.substring(0, indexOfStringInterp) + '#{';
        return addText(
          type,
          value.substring(indexOfStringInterp + 3),
          prefix,
          escaped + 1
        );
      }
      var before = value.substr(0, indexOfStringInterp);
      if (prefix.isNotEmpty || before.isNotEmpty) {
        before = prefix + before;
        token = tok(type, before);
        incrementColumn(before.length + escaped);
        tokens.add(tokEnd(token));
      }

      var rest = matchOfStringInterp.group(3);
      var range;
      token = tok('interpolated-code');
      incrementColumn(2);
      try {
        range = character_parser.parseUntil(rest, '}');
      } on character_parser.ParserException catch (ex) {
        if (ex.index != null) {
          incrementColumn(ex.index);
        }
        if (ex.code == 'CHARACTER_PARSER:END_OF_STRING_REACHED') {
          error(
            'NO_END_BRACKET',
            'End of line was reached with no closing bracket for interpolation.'
          );
        } else if (ex.code == 'CHARACTER_PARSER:MISMATCHED_BRACKET') {
          error('BRACKET_MISMATCH', ex.message);
        } else {
          rethrow;
        }
      }
      token.mustEscape = matchOfStringInterp.group(2) == '#';
      token.buffer = true;
      token.val = range.src;
      // assertExpression(range.src);

      if (range.end + 1 < rest.length) {
        rest = rest.substr(range.end + 1);
        incrementColumn(range.end + 1);
        tokens.add(tokEnd(token));
        addText(type, rest);
      } else {
        incrementColumn(rest.length);
        tokens.add(tokEnd(token));
      }
      return;
    }

    value = prefix + value;
    token = tok(type, value);
    incrementColumn(value.length + escaped);
    tokens.add(tokEnd(token));
  }

  bool text() {
    var token =
      scan(RegExp(r'^(?:\| ?| )([^\n]+)'), 'text') ??
      scan(RegExp(r'^( )'), 'text') ??
      scan(RegExp(r'^\|( ?)'), 'text');
    if (token != null) {
      addText('text', token.val);
      return true;
    }

    return false;
  }

  bool textHtml() {
    var token = scan(RegExp(r'^(<[^\n]*)'), 'text-html');
    if (token != null) {
      addText('text-html', token.val);
      return true;
    }

    return false;
  }

  bool dot() {
    var token = scanEndOfLine(RegExp(r'^\.'), 'dot');
    if (token != null) {
      tokens.add(tokEnd(token));
      pipelessText();
      
      return true;
    }

    return false;
  }

  bool extends_() {
    var token = scan(RegExp(r'^extends?(?= |$|\n)'), 'extends');
    if (token != null) {
      tokens.add(tokEnd(token));
      if (path() == null) {
        error('NO_EXTENDS_PATH', 'missing path for extends');
      }
      return true;
    }
    if (scan(RegExp(r'^extends?\b')) != null) {
      error('MALFORMED_EXTENDS', 'malformed extends');
    }

    return false;
  }

  bool prepend() {
    var captures = RegExp(r'^(?:block +)?prepend +([^\n]+)').firstMatch(input);
    if (captures != null) {
      var name = captures.group(1)?.trim();
      var comment = '';
      if (name.contains('//')) {
        comment =
          '//' +
          name
            .split('//')
            .sublist(1)
            .join('//');
        name = name.split('//')[0].trim();
      }
      if (name.isEmpty) return false;
      var token = tok('block', name);
      var len = captures.group(0).length - comment.length;
      while (whitespaceRe.hasMatch(input[len - 1])) {
        len -= 1;
      }
      incrementColumn(len);
      token.mode = 'prepend';
      tokens.add(tokEnd(token));
      consume(captures.group(0).length - comment.length);
      incrementColumn(captures.group(0).length - comment.length - len);
      return true;
    }

    return false;
  }

  bool append() {
    var captures = RegExp(r'^(?:block +)?append +([^\n]+)').firstMatch(input);
    if (captures != null) {
      var name = captures.group(1).trim();
      var comment = '';
      if (name.contains('//')) {
        comment =
          '//' +
          name
            .split('//')
            .sublist(1)
            .join('//');
        name = name.split('//')[0].trim();
      }
      if (name.isEmpty) return false;
      var token = tok('block', name);
      var len = captures.group(0).length - comment.length;
      while (whitespaceRe.hasMatch(input[len - 1])) {
        len -= 1;
      }
      incrementColumn(len);
      token.mode = 'append';
      tokens.add(tokEnd(token));
      consume(captures.group(0).length - comment.length);
      incrementColumn(captures.group(0).length - comment.length - len);
      return true;
    }

    return false;
  }

  bool block() {
    var captures = RegExp(r'^block +([^\n]+)').firstMatch(input);
    if (captures != null) {
      var name = captures.group(1).trim();
      var comment = '';
      if (name.contains('//')) {
        comment =
          '//' +
          name
            .split('//')
            .sublist(1)
            .join('//');
        name = name.split('//')[0].trim();
      }
      if (name.isEmpty) return false;
      var token = tok('block', name);
      var len = captures.group(0).length - comment.length;
      while (whitespaceRe.hasMatch(input[len - 1])) {
        len -= 1;
      }
      incrementColumn(len);
      token.mode = 'replace';
      tokens.add(tokEnd(token));
      consume(captures.group(0).length - comment.length);
      incrementColumn(captures.group(0).length - comment.length - len);
      return true;
    }

    return false;
  }

  bool mixinBlock() {
    var token = scanEndOfLine(RegExp(r'^block'), 'mixin-block');
    if (token != null) {
      tokens.add(tokEnd(token));
      return true;
    }
    return false;
  }

  bool yield_() {
    var token = scanEndOfLine(RegExp(r'^yield'), 'yield');
    if (token != null) {
      tokens.add(tokEnd(token));
      return true;
    }
    return false;
  }

  bool include() {
    var token = scan(RegExp(r'^include(?=:| |$|\n)'), 'include');
    if (token != null) {
      tokens.add(tokEnd(token));
      while (filter(FilterOpts(inInclude: true))) {}
      if (!path()) {
        if (RegExp(r'^[^ \n]+').hasMatch(input)) {
          // if there is more text
          fail();
        } else {
          // if not
          error('NO_INCLUDE_PATH', 'missing path for include');
        }
      }
      return true;
    }
    if (scan(RegExp(r'^include\b')) != null) {
      error('MALFORMED_INCLUDE', 'malformed include');
    }

    return false;
  }

  bool path() {
    var token = scanEndOfLine(RegExp(r'^ ([^\n]+)'), 'path');
    token.val = token.val?.trim();
    if (token.val?.isNotEmpty ?? false) {
      tokens.add(tokEnd(token));
      return true;
    }

    return false;
  }

  bool case_() {
    var token = scanEndOfLine(RegExp(r'^case +([^\n]+)'), 'case');
    if (token != null) {
      incrementColumn(-(token.val?.length ?? 0));
      // assertExpression(token.val);
      incrementColumn(token.val?.length ?? 0);
      tokens.add(tokEnd(token));
      return true;
    }
    if (scan(RegExp(r'^case\b')) != null) {
      error('NO_CASE_EXPRESSION', 'missing expression for case');
    }

    return false;
  }

  bool when() {
    var token = scanEndOfLine(RegExp(r'^when +([^:\n]+)'), 'when');
    if (token != null) {
      var parser = character_parser.parse(token.val);
      while (parser.isNesting() || parser.isString) {
        var rest = RegExp(r':([^:\n]+)').firstMatch(input);
        if (rest == null) break;

        token.val += rest[0];
        consume(rest[0].length);
        incrementColumn(rest[0].length);
        parser = character_parser.parse(token.val);
      }

      incrementColumn(-(token.val?.length ?? 0));
      // assertExpression(token.val);
      incrementColumn(token.val?.length ?? 0);
      tokens.add(tokEnd(token));
      return true;
    }
    if (scan(RegExp(r'^when\b')) != null) {
      error('NO_WHEN_EXPRESSION', 'missing expression for when');
    }

    return false;
  }

  bool default_() {
    var token = scanEndOfLine(RegExp(r'^default'), 'default');
    if (token != null) {
      tokens.add(tokEnd(token));
      return true;
    }
    if (scan(RegExp(r'^default\b')) != null) {
      error(
        'DEFAULT_WITH_EXPRESSION',
        'default should not have an expression'
      );
    }

    return false;
  }

  bool call() {
    var captures = RegExp(r'^\+(\s*)(([-\w]+)|(#\{))').firstMatch(input);
    var token, increment;
    if (captures != null) {
      // try to consume simple or interpolated call
      if (captures.group(3) != null) {
        // simple call
        increment = captures.group(0).length;
        consume(increment);
        token = tok('call', captures.group(3));
      } else {
        // interpolated call
        var match = bracketExpression(2 + captures.group(1).length);
        increment = match.end + 1;
        consume(increment);
        // assertExpression(match.src);
        token = tok('call', '#{${match.src}}');
      }

      incrementColumn(increment);

      token.args = null;
      // Check for args (not attributes)
      captures = RegExp(r'^ *\(').firstMatch(input);
      if (captures != null) {
        var range = bracketExpression(captures.group(0).length - 1);
        if (!RegExp(r'^\s*[-\w]+ *=').hasMatch(range.src)) {
          // not attributes
          incrementColumn(1);
          consume(range.end + 1);
          token.args = range.src;
          // assertExpression('[' + token.args + ']');
          for (var i = 0; i <= token.args.length; i++) {
            if (i < token.args.length && token.args[i] == '\n') {
              incrementLine(1);
            } else {
              incrementColumn(1);
            }
          }
        }
      }
      tokens.add(tokEnd(token));
      return true;
    }

    return false;
  }

  bool mixin_() {
    var captures = RegExp(r'^mixin +([-\w]+)(?: *\((.*)\))? *').firstMatch(input);
    if (captures != null) {
      consume(captures.group(0).length);
      var token = tok('mixin', captures.group(1));
      token.args = captures.group(2);
      incrementColumn(captures.group(0).length);
      tokens.add(tokEnd(token));
      return true;
    }
    return false;
  }

  bool conditional() {
    var captures = RegExp(r'^(if|unless|else if|else)\b([^\n]*)').firstMatch(input);
    if (captures != null) {
      consume(captures.group(0).length);
      var type = captures.group(1).replaceAll(RegExp(r' '), '-');
      var stmt = captures.group(2)?.trim();
      // type can be "if", "else-if" and "else"
      var token = tok(type, stmt);
      incrementColumn(captures.group(0).length - stmt.length);

      switch (type) {
        case 'if':
        case 'else-if':
          assertExpression(stmt);
          break;
        case 'unless':
          assertExpression(stmt);
          token.val = '!(' + stmt + ')';
          token.type = 'if';
          break;
        case 'else':
          if (stmt != null && stmt.isNotEmpty) {
            error(
              'ELSE_CONDITION',
              '`else` cannot have a condition, perhaps you meant `else if`'
            );
          }
          break;
      }
      incrementColumn(stmt.length);
      tokens.add(tokEnd(token));
      return true;
    }

    return false;
  }

  bool while_() {
    var captures = RegExp(r'^while +([^\n]+)').firstMatch(input);
    if (captures != null) {
      consume(captures.group(0).length);
      assertExpression(captures.group(1));
      var token = tok('while', captures.group(1));
      incrementColumn(captures.group(0).length);
      tokens.add(tokEnd(token));
      return true;
    }
    if (scan(RegExp(r'^while\b')) != null) {
      error('NO_WHILE_EXPRESSION', 'missing expression for while');
    }

    return false;
  }

  bool each() {
    var captures = RegExp(r'^(?:each|for) +([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? * in *([^\n]+)').firstMatch(input);
    if (captures != null) {
      consume(captures.group(0).length);
      var token = tok('each', captures.group(1));
      token.key = captures.group(2);
      incrementColumn(captures.group(0).length - captures.group(3).length);
      assertExpression(captures.group(3));
      token.code = captures.group(3);
      incrementColumn(captures.group(3).length);
      tokens.add(tokEnd(token));
      return true;
    }
    final name = RegExp(r'^each\b').hasMatch(input) ? 'each' : 'for';
    if (scan(RegExp(r'^(?:each|for)\b')) != null) {
      error(
        'MALFORMED_EACH',
        'This `$name` has a syntax error. `$name` statements should be of the form: `$name VARIABLE_NAME of JS_EXPRESSION`'
      );
    }

    captures = RegExp(r'^- *(?:each|for) +([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? +in +([^\n]+)').firstMatch(input);
    if (captures != null) {
      error(
        'MALFORMED_EACH',
        'Pug each and for should no longer be prefixed with a dash ("-"). They are pug keywords and not part of JavaScript.'
      );
    }

    return false;
  }

  bool eachOf() {
    var captures = RegExp(r'^(?:each|for) (.*) of *([^\n]+)').firstMatch(input);
    if (captures != null) {
      consume(captures.group(0).length);
      var token = tok('eachOf', captures.group(1));
      token.value = captures.group(1);
      incrementColumn(captures.group(0).length - captures.group(2).length);
      assertExpression(captures.group(2));
      token.code = captures.group(2);
      incrementColumn(captures.group(2).length);
      tokens.add(tokEnd(token));

      if (
        !(
          RegExp(r'^[a-zA-Z_$][\w$]*$').hasMatch(token.value.trim()) ||
          RegExp(r'^\[ *[a-zA-Z_$][\w$]* *\, *[a-zA-Z_$][\w$]* *\]$').hasMatch(
            token.value.trim()
          )
        )
      ) {
        error(
          'MALFORMED_EACH_OF_LVAL',
          'The value variable for each must either be a valid identifier (e.g. `item`) or a pair of identifiers in square brackets (e.g. `[key, value]`).'
        );
      }

      return true;
    }

    if (RegExp(r'^- *(?:each|for) +([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? +of +([^\n]+)').hasMatch(input)) {
      error(
        'MALFORMED_EACH',
        'Pug each and for should not be prefixed with a dash ("-"). They are pug keywords and not part of JavaScript.'
      );
    }

    return false;
  }

  bool code() {
    var captures = RegExp(r'^(!?=|-)[ \t]*([^\n]+)').firstMatch(input);
    if (captures != null) {
      var flags = captures.group(1);
      var code = captures.group(2);
      var shortened = 0;
      if (interpolated) {
        var parsed;
        try {
          parsed = character_parser.parseUntil(code, ']');
        } on character_parser.ParserException catch (err) {
          if (err.index != null) {
            incrementColumn(captures.group(0).length - code.length + err.index);
          }
          if (err.code == 'CHARACTER_PARSER:END_OF_STRING_REACHED') {
            error(
              'NO_END_BRACKET',
              'End of line was reached with no closing bracket for interpolation.'
            );
          } else if (err.code == 'CHARACTER_PARSER:MISMATCHED_BRACKET') {
            error('BRACKET_MISMATCH', err.message);
          } else {
            rethrow;
          }
        }
        shortened = code.length - parsed.end;
        code = parsed.src;
      }
      var consumed = captures.group(0).length - shortened;
      consume(consumed);
      var token = tok('code', code);
      token.mustEscape = flags[0] == '=';
      token.buffer = flags[0] == '=' || (flags.length > 1 ? flags[1] == '=' : false);

      // p #[!=    abc] hey
      //     ^              original colno
      //     -------------- captures.group(0)
      //           -------- captures.group(2)
      //     ------         captures.group(0) - captures.group(2)
      //           ^        after colno

      // =   abc
      // ^                  original colno
      // -------            captures.group(0)
      //     ---            captures.group(2)
      // ----               captures.group(0) - captures.group(2)
      //     ^              after colno
      incrementColumn(captures.group(0).length - captures.group(2).length);
      if (token.buffer) assertExpression(code);
      tokens.add(token);

      // p #[!=    abc] hey
      //           ^        original colno
      //              ----- shortened
      //           ---      code
      //              ^     after colno

      // =   abc
      //     ^              original colno
      //                    shortened
      //     ---            code
      //        ^           after colno
      incrementColumn(code.length);
      tokEnd(token);
      return true;
    }

    return false;
  }

  bool blockCode() {
    var token = scanEndOfLine(RegExp(r'^-'), 'blockcode');
    if (token != null) {
      tokens.add(tokEnd(token));
      interpolationAllowed = false;
      pipelessText();
      return true;
    }

    return false;
  }

  String attribute(String str) {
    var quote = '';
    var quoteRe = RegExp('[\'"]');
    var key = '';
    int i;

    // consume all whitespace before the key
    for (i = 0; i < str.length; i++) {
      if (!whitespaceRe.hasMatch(str[i])) break;
      if (str[i] == '\n') {
        incrementLine(1);
      } else {
        incrementColumn(1);
      }
    }

    if (i == str.length) {
      return '';
    }

    var token = tok('attribute');

    // quote?
    if (quoteRe.hasMatch(str[i])) {
      quote = str[i];
      incrementColumn(1);
      i++;
    }

    // start looping through the key
    for (; i < str.length; i++) {
      if (quote.isNotEmpty) {
        if (str[i] == quote) {
          incrementColumn(1);
          i++;
          break;
        }
      } else {
        if (
          whitespaceRe.hasMatch(str[i]) ||
          str[i] == '!' ||
          str[i] == '=' ||
          str[i] == ','
        ) {
          break;
        }
      }

      key += str[i];

      if (str[i] == '\n') {
        incrementLine(1);
      } else {
        incrementColumn(1);
      }
    }

    token.name = key;

    var valueResponse = attributeValue(str.substr(i));

    if (valueResponse.val != null && valueResponse.val.isNotEmpty) {
      token.val = valueResponse.val;
      token.mustEscape = valueResponse.mustEscape;
    } else {
      // was a boolean attribute (ex: `input(disabled)`)
      token.val = true;
      token.mustEscape = true;
    }

    str = valueResponse.remainingSource;

    tokens.add(tokEnd(token));

    for (i = 0; i < str.length; i++) {
      if (!whitespaceRe.hasMatch(str[i])) {
        break;
      }
      if (str[i] == '\n') {
        incrementLine(1);
      } else {
        incrementColumn(1);
      }
    }

    if (i < str.length && str[i] == ',') {
      incrementColumn(1);
      i++;
    }

    return str.substr(i);
  }

  _AttributeValueResponse attributeValue(String str) {
    var quoteRe = RegExp('[\'"]');
    var val = '';
    int i;
    var done, x;
    var escapeAttr = true;
    var state = character_parser.defaultState();
    var col = colno;
    var line = lineno;

    // consume all whitespace before the equals sign
    for (i = 0; i < str.length; i++) {
      if (!whitespaceRe.hasMatch(str[i])) break;
      if (str[i] == '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
    }

    if (i == str.length) {
      return _AttributeValueResponse(remainingSource: str);
    }

    if (str[i] == '!') {
      escapeAttr = false;
      col++;
      i++;
      if (str[i] != '=') {
        error(
          'INVALID_KEY_CHARACTER',
          'Unexpected character ${str[i]} expected `=`'
        );
      }
    }

    if (str[i] != '=') {
      // check for anti-pattern `div("foo"bar)`
      if (i == 0 && str.isNotEmpty && !whitespaceRe.hasMatch(str[0]) && str[0] != ',') {
        error(
          'INVALID_KEY_CHARACTER',
          'Unexpected character ' + str[0] + ' expected `=`'
        );
      } else {
        return _AttributeValueResponse(remainingSource: str);
      }
    }

    lineno = line;
    colno = col + 1;
    i++;

    // consume all whitespace before the value
    for (; i < str.length; i++) {
      if (!whitespaceRe.hasMatch(str[i])) break;
      if (str[i] == '\n') {
        incrementLine(1);
      } else {
        incrementColumn(1);
      }
    }

    line = lineno;
    col = colno;

    // start looping through the value
    for (; i < str.length; i++) {
      // if the character is in a string or in parentheses/brackets/braces
      if (!(state.isNesting() || state.isString)) {
        if (whitespaceRe.hasMatch(str[i])) {
          done = false;

          // find the first non-whitespace character
          for (x = i; x < str.length; x++) {
            if (!whitespaceRe.hasMatch(str[x])) {
              // if it is a JavaScript punctuator, then assume that it is
              // a part of the value
              final isNotPunctuator = !character_parser.isPunctuator(str[x]);
              final isQuote = quoteRe.hasMatch(str[x]);
              final isColon = str[x] == ':';
              final isSpreadOperator = x < str.length - 3 &&
                str[x] + str[x + 1] + str[x + 2] == '...';
              if (
                (isNotPunctuator || isQuote || isColon || isSpreadOperator) &&
                assertExpression(val, true)
              ) {
                done = true;
              }
              break;
            }
          }

          // if everything else is whitespace, return now so last attribute
          // does not include trailing whitespace
          if (done || x == str.length) {
            break;
          }
        }

        // if there's no whitespace and the character is not ',', the
        // attribute did not end.
        if (str[i] == ',' && assertExpression(val, true)) {
          break;
        }
      }

      state = character_parser.parseChar(str[i], state);
      val += str[i];

      if (str[i] == '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
    }

    assertExpression(val);

    lineno = line;
    colno = col;

    return _AttributeValueResponse(
      val: val,
      mustEscape: escapeAttr,
      remainingSource: str.substr(i),
    );
  }

  bool attrs() {
    Token token;

    if ('(' == input[0]) {
      token = tok('start-attributes');
      var index = bracketExpression().end;
      var str = input.substr(1, index - 1);

      incrementColumn(1);
      tokens.add(tokEnd(token));
      // assertNestingCorrect(str);
      consume(index + 1);

      while (str.isNotEmpty) {
        str = attribute(str);
      }

      token = tok('end-attributes');
      incrementColumn(1);
      tokens.add(tokEnd(token));
      return true;
    }

    return false;
  }

  bool attributesBlock() {
    if (RegExp(r'^&attributes\b').hasMatch(input)) {
      var consumed = 11;
      consume(consumed);
      var token = tok('&attributes');
      incrementColumn(consumed);
      var args = bracketExpression();
      consumed = args.end + 1;
      consume(consumed);
      token.val = args.src;
      incrementColumn(consumed);
      tokens.add(tokEnd(token));
      return true;
    }

    return false;
  }

  bool indent() {
    var captures = scanIndentation();
    Token token;

    if (captures != null) {
      var indents = captures.group(1).length;

      incrementLine(1);
      consume(indents + 1);

      if (input.isNotEmpty && (' ' == input[0] || '\t' == input[0])) {
        error(
          'INVALID_INDENTATION',
          'Invalid indentation, you can use tabs or spaces but not both'
        );
      }

      // blank line
      if (input.isNotEmpty && '\n' == input[0]) {
        interpolationAllowed = true;
        tokEnd(tok('newline'));
        return true;
      }

      // outdent
      if (indents < indentStack[0]) {
        var outdent_count = 0;
        while (indentStack[0] > indents) {
          if (indentStack[1] < indents) {
            error(
              'INCONSISTENT_INDENTATION',
              'Inconsistent indentation. Expecting either ${indentStack[1]} or ${indentStack[0]} spaces/tabs.'
            );
          }
          outdent_count++;
          indentStack.removeAt(0);
        }
        while (outdent_count-- > 0) {
          colno = 1;
          token = tok('outdent');
          colno = indentStack[0] + 1;
          tokens.add(tokEnd(token));
        }
        // indent
      } else if (indents != 0 && indents != indentStack[0]) {
        token = tok('indent', '$indents');
        colno = 1 + indents;
        tokens.add(tokEnd(token));
        indentStack.insert(0, indents);
        // newline
      } else {
        token = tok('newline');
        colno = 1 + min(indentStack[0] ?? 0, indents);
        tokens.add(tokEnd(token));
      }

      interpolationAllowed = true;
      return true;
    }

    return false;
  }

  bool pipelessText([int indents]) {
    while (blank()) {}

    var captures = scanIndentation();

    indents = indents ?? captures?.group(1)?.length ?? 0;
    if (indents > indentStack[0]) {
      tokens.add(tokEnd(tok('start-pipeless-text')));
      var tokenValues = <String>[];
      var token_indent = <bool>[];
      bool isMatch;
      // Index in this.input. Can't use this.consume because we might need to
      // retry lexing the block.
      var stringPtr = 0;
      do {
        // text has `\n` as a prefix
        var i = input.substr(stringPtr + 1).indexOf('\n');
        if (-1 == i) i = input.length - stringPtr - 1;
        var str = input.substr(stringPtr + 1, i);
        var lineCaptures = indentRe.firstMatch('\n' + str);
        var lineIndents = lineCaptures?.group(1)?.length;
        isMatch = lineIndents >= indents;
        token_indent.add(isMatch);
        isMatch = isMatch || str.trim().isEmpty;
        if (isMatch) {
          // consume test along with `\n` prefix if match
          stringPtr += str.length + 1;
          tokenValues.add(str.substr(indents));
        } else if (lineIndents > indentStack[0]) {
          // line is indented less than the first line but is still indented
          // need to retry lexing the text block
          tokens.removeLast();
          return pipelessText(lineCaptures.group(1).length);
        }
      } while ((input.length - stringPtr) > 0 && isMatch);
      consume(stringPtr);
      while (input.isEmpty && tokenValues[tokenValues.length - 1] == '') {
        tokenValues.removeLast();
      }

      tokenValues.asMap().forEach(
        (i, token) {
          var tok;
          incrementLine(1);
          if (i != 0) tok = this.tok('newline');
          if (token_indent[i] != null && token_indent[i]) incrementColumn(indents);
          if (tok != null && token.isNotEmpty) tokens.add(tokEnd(tok));
          addText('text', token);
        }
      );
      tokens.add(tokEnd(tok('end-pipeless-text')));
      return true;
    }

    return false;
  }

  bool slash() {
    var token = scan(RegExp(r'^\/'), 'slash');
    if (token != null) {
      tokens.add(tokEnd(token));
      return true;
    }

    return false;
  }

  bool colon() {
    var token = scan(RegExp(r'^: +'), ':');
    if (token != null) {
      tokens.add(tokEnd(token));
      return true;
    }

    return false;
  }

  bool fail() {
    error(
      'UNEXPECTED_TEXT',
      'unexpected text "${input.substr(0, 5)}"'
    );
    return false;
  }

  bool _advance() {
    return (
      blank() ||
      eos() ||
      endInterpolation() ||
      yield_() ||
      docType() ||
      interpolation() ||
      case_() ||
      when() ||
      default_() ||
      extends_() ||
      append() ||
      prepend() ||
      block() ||
      mixinBlock() ||
      include() ||
      mixin_() ||
      call() ||
      conditional() ||
      eachOf() ||
      each() ||
      while_() ||
      tag() ||
      filter() ||
      blockCode() ||
      code() ||
      id() ||
      dot() ||
      className() ||
      attrs() ||
      attributesBlock() ||
      indent() ||
      text() ||
      textHtml() ||
      comment() ||
      slash() ||
      colon() ||
      fail()
    );
  }

  List<Token> getTokens() {
    while (!ended) {
      _advance();
    }

    return tokens;
  }
}

class LexerOptions {
  LexerOptions({
    @required this.filename,
    this.interpolated,
    this.startingLine,
    this.startingColumn,
  });

  final String filename;
  final bool interpolated;
  final int startingLine;
  final int startingColumn;
}

class FilterOpts {
  FilterOpts({this.inInclude});

  final bool inInclude;
}

class Token {
  Token({
    this.type,
    this.loc,
    this.filename,
    this.val,
  });

  Token.fromJSON(Map<String, dynamic> json) {
    type = json['type'] as String;
    filename = json['filename'] as String;
    loc = TokenLoc.fromJSON(json['loc'] as Map<String, dynamic>);
    val = json['val'];
    buffer = json['buffer'] as bool;
    mustEscape = json['mustEscape'] as bool;
    mode = json['mode'] as String;
    args = json['args'] as String;
    key = json['key'] as String;
    code = json['code'] as String;
    value = json['value'] as String;
    name = json['name'] as String;
  }

  String type;
  String filename;
  TokenLoc loc;
  dynamic val;
  bool buffer;
  bool mustEscape;
  String mode;
  String args;
  String key;
  String code;
  String value;
  String name;

  Map<String, dynamic> toJSON() {
    return {
      'type': type,
      'loc': loc.toJSON(),
      'val': val,
      'buffer': buffer,
      'mustEscape': mustEscape,
      'mode': mode,
      'args': args,
      'key': key,
      'code': code,
      'value': value,
      'name': name,
      'filename': filename,
    }..removeWhere((key, value) => key == null || value == null);
  }
}

class TokenLoc {
  TokenLoc({
    this.start,
    this.filename,
  });

  TokenLoc.fromJSON(Map<String, dynamic> json) {
    filename = json['filename'] as String;
    start = TokenLocPoint.fromJSON(json['start'] as Map<String, dynamic>);
    end = TokenLocPoint.fromJSON(json['end'] as Map<String, dynamic>);
  }

  TokenLocPoint start;
  String filename;
  TokenLocPoint end;

  Map<String, dynamic> toJSON() => {
    'filename': filename,
    'start': start.toJSON(),
    'end': end?.toJSON()
  };
}

class TokenLocPoint {
  TokenLocPoint({
    this.line,
    this.column,
  });

  TokenLocPoint.fromJSON(Map<String, dynamic> json) {
    line = json['line'] as int;
    column = json['column'] as int;
  }

  int line;
  int column;

  Map<String, int> toJSON() => {
    'line': line,
    'column': column,
  };
}

class _AttributeValueResponse {
  _AttributeValueResponse({
    this.val,
    this.mustEscape,
    this.remainingSource,
  });

  String val;
  bool mustEscape;
  String remainingSource;
}
