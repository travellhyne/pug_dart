import 'dart:math';

class PugException implements Exception {
  PugException(this.message);

  final String message;
  String code;
  String msg;
  int line;
  int column;
  String filename;
  String src;

  Map<String, dynamic> toJSON() {
    return {
      'code': code,
      'msg': msg,
      'line': line,
      'column': column,
      'filename': filename,
    };
  }
}

PugException makeError({
  String code,
  String message,
  Map<String, dynamic> options,
}) {
  var line = options['line'] as int;
  var column = options['column'] as int;
  var filename = options['filename'] as String;
  var src = options['src'] as String;
  String fullMessage;
  var location = '$line${column != null ? ':$column' : ''}';
  if (src != null && line >= 1 && line <= src.split('\n').length) {
    var lines = src.split('\n');
    var start = max(line - 3, 0);
    var end = min(lines.length, line + 3);
    var context = lines
      .sublist(start, end)
      .asMap()
      .entries
      .map((e) {
        var text = e.value;
        var idx = e.key;
        var curr = idx + start + 1;
        var preamble = '${curr == line ? '  > ' : '    '}$curr| ';
        var out = '$preamble$text';
        if (curr == line && column > 0) {
          out = '$out\n';
          out = '$out${Iterable.generate(preamble.length + column).join('-')}^';
        }
        return out;
      })
      .toList()
      .join('\n');
    fullMessage = '${filename ?? 'Pug'}:$location\n$context\n\n$message';
  } else {
    fullMessage = '${filename ?? 'Pug'}:$location\n\n$message';
  }

  var err = PugException(fullMessage)
    ..code = 'PUG$code'
    ..msg = message
    ..line = line
    ..column = column
    ..filename = filename;

  return err;
}
