import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:pug_dart/src/error/error.dart';

final pugMatchHtml = RegExp(r'["&<>]');

String pugClassesArray(List val, [List<bool> escaping]) {
  var classString = '';
  String className;
  var padding = '';
  var escapeEnabled = escaping != null;

  for (var i = 0; i < val.length; i++) {
    className = pugClasses(val[i]);
    if (className.isEmpty) continue;

    if (escapeEnabled && i < escaping.length && escaping[i] != null && escaping[i]) {
      className = pugEscape(className);
    }

    classString = '$classString$padding$className';
    padding = ' ';
  }

  return classString;
}

String pugClassesMap(Map<String, bool> val) {
  var classString = '', padding = '';
  val.forEach((key, value) {
    if (key != null && key.isNotEmpty && value != null && value) {
      classString = '$classString$padding$key';
      padding = ' ';
    }
  });

  return classString;
}

String pugClasses(dynamic val, [List<bool> escaping]) {
  if (val is List) {
    return pugClassesArray(val, escaping);
  } else if (val is Map) {
    return pugClassesMap(val);
  } else {
    return val ?? '';
  }
}

String pugStyle(dynamic val) {
  if (val == null) return '';
  if (val is Map) {
    var out = '';
    val.forEach((style, value) {
      out = '$out$style:$value;';
    });
    return out;
  } else {
    return '$val';
  }
}

String pugAttr(String key, [dynamic val, bool escaped, bool terse]) {
  escaped ??= false;
  terse ??= false;
  if (
    val == null ||
    (val is bool && val == false) ||
    (val is String && val.isEmpty && (key == 'class' || key == 'style'))
  ) {
    return '';
  }

  if (val is bool && val == true) {
    return ' ${terse ? key : '$key="$key"'}';
  }

  try {
    val = val.toJSON();
  } catch (err) {
    // unreachable
  }

  if (val is! String) {
    try {
      var encoder = JsonEncoder();
      val = encoder.convert(val);
    } catch (err) {
      val = val.toString();
    }

    if (!escaped && val.contains('"')) {
      return ' $key=\'${val.replaceAll(RegExp(r"\'"), '&#39;')}\'';
    }
  }
  
  if (escaped) val = pugEscape(val);

  return ' $key="$val"';
}

String pugAttrs(Map<String, dynamic> obj, [bool terse]) {
  var attrs = '';

  obj.forEach((key, value) {
    if (key == 'class') {
      value = pugClasses(value);
      attrs = pugAttr(key, value, false, terse) + attrs;
      return;
    }
    
    if (key == 'style') {
      value = pugStyle(value);
    }

    attrs = '$attrs${pugAttr(key, value, false, terse)}';
  });

  return attrs;
}

dynamic pugEscape(dynamic html_) {
  var html = '$html_';
  var regexResult = pugMatchHtml.firstMatch(html);
  if (regexResult == null) return html_;

  var result = '';
  var i = regexResult.start;
  var lastIndex = 0;
  String escape;
  for (; i < html.length; i++) {
    switch(html.codeUnitAt(i)) {
      case 34:
        escape = '&quot;';
        break;
      case 38:
        escape = '&amp;';
        break;
      case 60:
        escape = '&lt;';
        break;
      case 62:
        escape = '&gt;';
        break;
      default:
        continue;
    }

    if (lastIndex < i) {
      result += html.substring(lastIndex, i);
    }

    lastIndex = i + 1;
    result += escape;
  }

  if (lastIndex < i) {
    return result + html.substring(lastIndex, i);
  }

  return result;
}

void pugRethrow(dynamic err, [String filename, int lineno, String str]) {
  lineno ??= 0;
  if (err is! PugException) throw err;

  var e = err as PugException;
  if (filename == null && (str == null || str.isEmpty)) {
    e.message = '${e.message} on line $lineno';
    throw e;
  }

  try {
    str = str ?? File(filename).readAsStringSync();
  } catch (ex) {
    pugRethrow(ex, null, lineno);
  }

  var maxContext = 3;
  var lines = str.split('\n');
  var start = max(lineno - maxContext, 0);
  var end = min(lines.length, lineno + maxContext);

  var context = lines
    .sublist(start, end)
    .asMap()
    .entries
    .map((e) {
      var idx = e.key;
      var line = e.value;
      var curr = idx + start + 1;
      return '${(curr == lineno ? '  > ' : '    ')}$curr| $line';
    })
    .toList()
    .join('\n');

  e.path = filename;
  e.message = '${filename ?? 'Pug'}:$lineno\n$context\n\n${e.message}';
  throw e;
}

Map<String, dynamic> pugMerge(dynamic a, [Map<String, dynamic> b]) {
  if (b == null && a is List) {
    var attrs = a[0];

    for (var i = 1; i < a.length; i++) {
      attrs = pugMerge(attrs, a[i]);
    }

    return attrs;
  }

  b.forEach((key, value) {
    if (key == 'class') {
      var valA = a[key] ?? <dynamic>[];
      var valB = b[key] ?? <dynamic>[];
      a[key] = [
        ...(valA is List ? valA : [valA]),
        ...(valB is List ? valB : [valB]),
      ];
    } else if (key == 'style') {
      var valA = pugStyle(a[key]);
      valA = valA.isNotEmpty && valA[valA.length - 1] != ';' ? valA + ';' : valA;
      var valB = pugStyle(b[key]);
      valB = valB.isNotEmpty && valB[valB.length - 1] != ';' ? valB + ';' : valB;
      a[key] = valA + valB;
    } else {
      a[key] = b[key];
    }
  });

  return a;
}
