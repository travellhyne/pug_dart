class Node {
  Node({
    this.nodes,
    this.line,
    this.column,
    this.filename,
  });

  String type;
  List<Node> nodes;
  int line;
  int column;
  String filename;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'nodes': nodes?.map((e) => e?.toJSON())?.toList(),
      'line': line,
      'column': column,
      'filename': filename,
    };
  }

  Map<String, dynamic> toJSON() {
    return toMap()..removeWhere((key, value) => key == null || value == null);
  }
}

class Block extends Node {
  Block({
    this.mode,
    this.name,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  String type = 'Block';
  String mode;
  String name;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      if (type == 'NamedBlock') 'mode': mode,
      if (type == 'NamedBlock') 'name': name,
    };
  }
}

class Text extends Node {
  Text({
    this.val,
    this.isHtml,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Text';
  String val;
  bool isHtml = false;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'val': val,
      'isHtml': isHtml,
    };
  }
}

class Code extends Node {
  Code({
    this.val,
    this.buffer,
    this.mustEscape,
    this.isInline,
    this.block,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Code';
  String val;
  bool buffer;
  bool mustEscape;
  bool isInline;
  Node block;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'val': val,
      'buffer': buffer,
      'mustEscape': mustEscape,
      'isInline': isInline,
      'block': block?.toJSON(),
    };
  }
}

class Case extends Node {
  Case({
    this.expr,
    this.block,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Case';
  dynamic expr;
  Node block;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'expr': expr,
      'block': block?.toJSON(),
    };
  }
}

class When extends Node {
  When({
    this.expr,
    this.block,
    this.debug,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'When';
  dynamic expr;
  Node block;
  bool debug;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'expr': expr,
      'block': block?.toJSON(),
      'debug': debug,
    };
  }
}

class Conditional extends Node {
  Conditional({
    this.alternate,
    this.test,
    this.consequent,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Conditional';
  dynamic test;
  Node consequent;
  Node alternate;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'test': test,
      'consequent': consequent?.toJSON(),
      'alternate': alternate?.toJSON(),
    };
  }
}

class While extends Node {
  While({
    this.test,
    this.block,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'While';
  dynamic test;
  Node block;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'test': test,
      'block': block?.toJSON(),
    };
  }
}

class Comment extends Node {
  Comment({
    this.buffer,
    this.val,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Comment';
  dynamic val;
  bool buffer;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'val': val,
      'buffer': buffer,
    };
  }
}

class BlockComment extends Comment {
  BlockComment({
    this.block,
    bool buffer,
    dynamic val,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
          buffer: buffer,
          val: val,
        );

  @override
  final String type = 'BlockComment';
  Node block;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'block': block?.toJSON(),
    };
  }
}

class Doctype extends Node {
  Doctype({
    this.val,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Doctype';
  dynamic val;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'val': val,
    };
  }
}

class IncludeFilter extends Node {
  IncludeFilter({
    this.name,
    this.attrs,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'IncludeFilter';
  dynamic name;
  List attrs;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'name': name,
    };
  }
}

class Filter extends Node {
  Filter({
    this.name,
    this.block,
    this.attrs,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Filter';
  dynamic name;
  Node block;
  List attrs;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'name': name,
    };
  }
}

class Each extends Node {
  @override
  final String type = 'Each';
  String obj;
  dynamic val;
  String key;
  Node block;
  Node alternate;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'obj': obj,
      'val': val,
      'key': key,
      'block': block?.toJSON(),
      'alternate': alternate?.toJSON(),
    };
  }
}

class EachOf extends Node {
  EachOf({
    this.obj,
    this.val,
    this.block,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'EachOf';
  String obj;
  dynamic val;
  Node block;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'obj': obj,
      'val': val,
      'block': block?.toJSON(),
    };
  }
}

class Extends extends Node {
  Extends({
    this.file,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'Extends';
  FileReference file;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'file': file?.toJSON(),
    };
  }
}

class FileReference extends Node {
  FileReference({
    this.path,
    this.ast,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  final String type = 'FileReference';
  String path;
  Node ast;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'path': path,
    };
  }
}

class MixinBlock extends Node {
  @override
  final String type = 'MixinBlock';
}

class YieldBlock extends Node {
  @override
  final String type = 'YieldBlock';
}

class Include extends Node {
  Include({
    this.file,
    this.block,
    this.filters,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  String type = 'Include';
  FileReference file;
  Node block;
  List<Node> filters;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'file': file?.toJSON(),
      if (type == 'RawInclude')
        'filters': filters?.map((e) => e?.toJSON())?.toList(),
    };
  }
}

class Tag extends Node {
  Tag({
    this.name,
    this.expr,
    this.selfClosing,
    this.block,
    this.attrs,
    this.attributeBlocks,
    this.isInline,
    this.textOnly,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  @override
  String type = 'Tag';
  String name;
  dynamic expr;
  bool selfClosing;
  Node block;
  List<Node> attrs;
  List<Node> attributeBlocks;
  bool isInline;
  bool textOnly;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'expr': expr,
      'name': name,
      'selfClosing': selfClosing,
      'attrs': attrs?.map((e) => e?.toJSON())?.toList(),
      'attributeBlocks': attributeBlocks?.map((e) => e?.toJSON())?.toList(),
      'block': block?.toJSON(),
      'isInline': isInline,
    };
  }
}

class Mixin extends Tag {
  Mixin({
    this.args,
    this.call,
    this.code,
    String name,
    dynamic expr,
    bool selfClosing,
    Node block,
    List<Node> attrs,
    List<Node> attributeBlocks,
    bool isInline,
    bool textOnly,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
          name: name,
          expr: expr,
          selfClosing: selfClosing,
          block: block,
          attrs: attrs,
          attributeBlocks: attributeBlocks,
          isInline: isInline,
          textOnly: textOnly,
        );

  @override
  final String type = 'Mixin';
  String args;
  bool call;
  Node code;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'name': name,
      'args': args,
      'block': block?.toJSON(),
      'call': call,
      'code': code?.toJSON(),
    };
  }
}

class Attribute extends Node {
  Attribute({
    this.name,
    this.val,
    this.mustEscape,
    List<Node> nodes,
    int line,
    int column,
    String filename,
  }) : super(
          nodes: nodes,
          line: line,
          column: column,
          filename: filename,
        );

  String name;
  dynamic val;
  bool mustEscape;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'val': val,
      'name': name,
      'mustEscape': mustEscape,
    };
  }
}
