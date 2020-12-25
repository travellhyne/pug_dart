class Node {
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
  @override String type = 'Block';
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
  @override final String type = 'Text';
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
  @override final String type = 'Code';
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
  @override final String type = 'Case';
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
  @override final String type = 'When';
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
  @override final String type = 'Conditional';
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
  @override final String type = 'While';
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
  @override final String type = 'Comment';
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
  @override final String type = 'BlockComment';
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
  @override final String type = 'Doctype';
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
  @override final String type = 'IncludeFilter';
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
  @override final String type = 'Filter';
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
  @override final String type = 'Each';
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
  @override final String type = 'EachOf';
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
  @override final String type = 'Extends';
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
  @override final String type = 'FileReference';
  String path;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'path': path,
    };
  }
}

class MixinBlock extends Node {
  @override final String type = 'MixinBlock';
}

class YieldBlock extends Node {
  @override final String type = 'YieldBlock';
}

class Include extends Node {
  @override String type = 'Include';
  FileReference file;
  Node block;
  List<Node> filters;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'file': file?.toJSON(),
      if (type == 'RawInclude') 'filters': filters?.map((e) => e?.toJSON())?.toList(),
    };
  }
}

class Tag extends Node {
  @override String type = 'Tag';
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
  @override final String type = 'Mixin';
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
