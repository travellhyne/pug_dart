import './string.dart';

const Map<String, String> brackets = {
  '{': '}',
  '[': ']',
  '(': ')',
};

const Map<String, String> bracketsReversed = {
  '}': '{',
  ']': '[',
  ')': '(',
};

enum TokenTypes {
  singleQuote,
  doubleQuote,
  lineComment,
  blockComment,
  templateQuote,
  regexp,
}

extension on TokenTypes {
  String get value {
    switch(this) {
      case TokenTypes.doubleQuote:
        return '"';
      case TokenTypes.singleQuote:
        return '\'';
      case TokenTypes.blockComment:
        return '/**/';
      case TokenTypes.lineComment:
        return '//';
      case TokenTypes.templateQuote:
        return '`';
      case TokenTypes.regexp:
        return '//g';
      default:
        return '';
    }
  }
}

_State parse(String src, [_State state, ParserOptions options]) {
  state ??= defaultState();
  options ??= ParserOptions();

  var start = options.start ?? 0;
  var end = options.end ?? src?.length ?? 0;
  var index = start;

  while (index < end) {
    try {
      parseChar(src[index], state);
    } on ParserException catch (ex) {
      ex.index = index;
      rethrow;
    }
    index += 1;
  }

  return state;
}

ParserResult parseUntil(String src, Pattern delimiter, [ParserOptions options]) {
  options = options ?? ParserOptions();

  var start = options.start ?? 0;
  var index = start;
  var state = defaultState();

  while (index < src.length) {
    if ((options.ignoreNesting) || !state.isNesting(options) && matches(src, delimiter, index)) {
      var end = index;

      return ParserResult(
        start: start,
        end: end,
        src: src.substring(start, end),
      );
    }

    try {
      parseChar(src[index], state);
    } on ParserException catch (ex) {
      ex.index = index;
      rethrow;
    } catch (ex) {
      rethrow;
    }

    index += 1;
  }

  var err = ParserException('The end of the string was reached with no closing bracket found.')
    ..code = 'CHARACTER_PARSER:END_OF_STRING_REACHED'
    ..index = index;
  throw err;
}

_State parseChar(String character, _State state) {
  if (character.length != 1) {
    var err = ParserException(
      'Character must be a string of length 1',
      name: 'InvalidArgumentError',
      code: 'CHARACTER_PARSER:CHAR_LENGTH_NOT_ONE',
    );

    throw err;
  }

  state = state ?? defaultState();
  state.src = '${state.src}$character';
  var wasComment = state.isComment;
  var lastChar = state.history.isNotEmpty ? state.history[0] : '';

  if (state.regexpStart) {
    if (character == '/' || character == '*') {
      state.stack.removeLast();
    }
    state.regexpStart = false;
  }

  if (state.current == TokenTypes.lineComment.value) {
    if (character == '\n') {
      state.stack.removeLast();
    }
  } else if (state.current == TokenTypes.blockComment.value) {
    if (state.lastChar == '*' && character == '/') {
      state.stack.removeLast();
    }
  } else if (state.current == TokenTypes.singleQuote.value) {
    if (character == '\'' && !state.escaped) {
      state.stack.removeLast();
    } else if (character == '\\' && !state.escaped) {
      state.escaped = true;
    } else {
      state.escaped = false;
    }
  } else if (state.current == TokenTypes.doubleQuote.value) {
    if (character == '"' && !state.escaped) {
      state.stack.removeLast();
    } else if (character == '\\' && !state.escaped) {
      state.escaped = true;
    } else {
      state.escaped = false;
    }
  } else if (state.current == TokenTypes.templateQuote.value) {
    if (character == '`' && !state.escaped) {
      state.stack.removeLast();
      state.hasDollar = false;
    } else if (character == '\\' && !state.escaped) {
      state.escaped = true;
      state.hasDollar = false;
    } else if (character == r'$' && !state.escaped) {
      state.hasDollar = true;
    } else if (character == '{' && state.hasDollar) {
      state.stack.add(brackets[character]);
    } else {
      state.escaped = false;
      state.hasDollar = false;
    }
  } else if (state.current == TokenTypes.regexp.value) {
    if (character == '/' && !state.escaped) {
      state.stack.removeLast();
    } else if (character == '\\' && !state.escaped) {
      state.escaped = true;
    } else {
      state.escaped = false;
    }
  } else {
    if (brackets.containsKey(character)) {
      state.stack.add(brackets[character]);
    } else if (bracketsReversed.containsKey(character)) {
      if (state.current != character) {
        var err = ParserException(
          'Mismatched bracker: $character',
          code: 'CHARACTER_PARSER:MISMATCHED_BRACKET',
        );
        throw err;
      }
      state.stack.removeLast();
    } else if (lastChar == '/' && character == '/') {
      // Don't include comments in history
      state.history = state.history.substr(1);
      state.stack.add(TokenTypes.lineComment.value);
    } else if (lastChar == '/' && character == '*') {
      // Don't include comment in history
      state.history = state.history.substr(1);
      state.stack.add(TokenTypes.blockComment.value);
    } else if (character == '\'') {
      state.stack.add(TokenTypes.singleQuote.value);
    } else if (character == '"') {
      state.stack.add(TokenTypes.doubleQuote.value);
    } else if (character == '`') {
      state.stack.add(TokenTypes.templateQuote.value);
    }
  }

  if (!state.isComment && !wasComment) {
    state.history = '$character${state.history}';
  }

  state.lastChar = character;
  return state;
}

bool matches(String str, Pattern matcher, int index) {
  if (matcher is RegExp) {
    return matcher.hasMatch(str.substr(index ?? 0));
  } else {
    return str.substr(index ?? 0, (matcher as String).length) == matcher;
  }
}

bool isPunctuator(String c) {
  if (c == null || c.isEmpty) return true;

  final code = c.codeUnitAt(0);

  switch (code) {
    case 46:   // . dot
    case 40:   // ( open bracket
    case 41:   // ) close bracket
    case 59:   // ; semicolon
    case 44:   // , comma
    case 123:  // { open curly brace
    case 125:  // } close curly brace
    case 91:   // [
    case 93:   // ]
    case 58:   // :
    case 63:   // ?
    case 126:  // ~
    case 37:   // %
    case 38:   // &
    case 42:   // *:
    case 43:   // +
    case 45:   // -
    case 47:   // /
    case 60:   // <
    case 62:   // >
    case 94:   // ^
    case 124:  // |
    case 33:   // !
    case 61:   // =
      return true;
    default:
      return false;
  }
}

_State defaultState() => _State();

class ParserOptions {
  int start;
  int end;

  bool ignoreNesting = false;
  bool ignoreLineComment = false;
}

class ParserResult {
  ParserResult({
    this.start,
    this.end,
    this.src,
  });

  final int start;
  final int end;
  final String src;
}

class _State {
  List<String> stack = [];

  bool regexpStart = false;
  bool escaped = false;
  bool hasDollar = false;

  String src = '';
  String history = '';
  String lastChar = '';

  String get current => stack.isNotEmpty ? stack.last : null;

  bool get isString => (
    current == TokenTypes.singleQuote.value ||
    current == TokenTypes.doubleQuote.value
  );

  bool get isComment => (
    current == TokenTypes.lineComment.value || current == TokenTypes.blockComment.value
  );

  bool isNesting([ParserOptions options]) {
    if (
      (options?.ignoreLineComment ?? false) &&
      stack.length == 1 &&
      stack[0] == TokenTypes.lineComment.value
    ) {
      return false;
    }

    return stack.isNotEmpty;
  }
}

class ParserException implements Exception {
  ParserException(this.message, {this.name, this.code});

  final String message;
  String name;
  String code;
  int index;
}
