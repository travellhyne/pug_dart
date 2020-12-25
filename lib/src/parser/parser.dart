import 'package:logger/logger.dart';

import '../../pug_dart.dart';
import './token_stream.dart';
import './node.dart';
import './inline-tags.dart';

Node parse(List<Token> tokens, [ParserOptions options]) {
  var parser = Parser(tokens, options);
  return parser.parse();
}

class Parser {
  Parser(List<Token> tokens, [ParserOptions options]) {
    options ??= ParserOptions();
    this.tokens = TokenStream.fromIterable(tokens);
    filename = options.filename;
    src = options.src;
    plugins = options.plugins ?? [];
  }

  TokenStream tokens;
  
  String filename;
  String src;
  int inMixin = 0;
  List plugins;

  final Logger _logger = Logger();

  void error(String code, String message, Token token) {
    throw makeError(
      code: code,
      message: message,
      options: {
        'line': token.loc.start.line,
        'column': token.loc.start.column,
        'filename': filename,
        'src': src,
      },
    );
  }

  Token advance() => tokens.advance();

  Token peek() => tokens.peek();

  Token lookAhead(int index) => tokens.lookAhead(index);

  Node parse() {
    var block = emptyBlock(0);

    while(peek().type != 'eos') {
      if (peek().type == 'newline') {
        advance();
      } else if (peek().type == 'text-html') {
        block.nodes += parseTextHtml();
      } else {
        var expr = parseExpr();

        if (expr != null) {
          if (expr.type == 'Block') {
            block.nodes += expr.nodes;
          } else {
            block.nodes.add(expr);
          }
        }
      }
    }

    return block;
  }

  Token expect(String type) {
    if (peek().type == type) {
      return advance();
    } else {
      error(
        'INVALID_TOKEN',
        'expected "$type", but got "${peek().type}"',
        peek(),
      );
      return null;
    }
  }

  Token accept(String type) {
    if (peek().type == type) {
      return advance();
    }

    return null;
  }

  Block initBlock(int line, List<Node> nodes) {
    return Block()
      ..nodes = nodes
      ..line = line
      ..filename = filename;
  }

  Block emptyBlock(int line) {
    return initBlock(line, []);
  }

  dynamic runPlugin(String context, Token tok, [List arguments]) {
    var rest = <dynamic>[this];
    if (arguments != null) {
      rest?.addAll(arguments);
    }

    var pluginContext;

    for (var plugin in plugins) {
      if (plugin[context] != null && plugin[context][tok.type] != null) {
        if (pluginContext) {
          throw Exception('Multiple plugin handlers found for context $context, token type ${tok.type}');
        }
        pluginContext = plugin[context];
      }
    }

    if (pluginContext != null) {
      return pluginContext[tok.type](rest);
    }

    return null;
  }

  Block block() {
    var tok = expect('indent');
    var block = emptyBlock(tok.loc.start.line);
    while ('outdent' != peek().type) {
      if ('newline' == peek().type) {
        advance();
      } else if ('text-html' == peek().type) {
        block.nodes += parseTextHtml();
      } else {
        var expr = parseExpr();
        if (expr.type == 'Block') {
          block.nodes += expr.nodes;
        } else {
          block.nodes.add(expr);
        }
      }
    }
    expect('outdent');
    return block;
  }

  Node parseExpr() {
    switch (peek().type) {
      case 'tag':
        return parseTag();
      case 'mixin':
        return parseMixin();
      case 'block':
        return parseBlock();
      case 'mixin-block':
        return parseMixinBlock();
      case 'case':
        return parseCase();
      case 'extends':
        return parseExtends();
      case 'include':
        return parseInclude();
      case 'doctype':
        return parseDoctype();
      case 'filter':
        return parseFilter();
      case 'comment':
        return parseComment();
      case 'text':
      case 'interpolated-code':
      case 'start-pug-interpolation':
        return parseText({'block': true});
      case 'text-html':
        return initBlock(peek().loc.start.line, parseTextHtml());
      case 'dot':
        return parseDot();
      case 'each':
        return parseEach();
      case 'eachOf':
        return parseEachOf();
      case 'code':
        return parseCode();
      case 'blockcode':
        return parseBlockCode();
      case 'if':
        return parseConditional();
      case 'while':
        return parseWhile();
      case 'call':
        return parseCall();
      case 'interpolation':
        return parseInterpolation();
      case 'yield':
        return parseYield();
      case 'id':
      case 'class':
        tokens.defer(Token(
          type: 'tag',
          val: 'div',
          loc: peek().loc,
          filename: filename,
        ));
        return parseExpr();
      default:
        var pluginResult = runPlugin('expressionTokens', peek());
        if (pluginResult != null) return pluginResult;
        error(
          'INVALID_TOKEN',
          'unexpected token "${peek().type}"',
          peek()
        );
        return null;
    }
  }

  Node parseDot() {
    advance();
    return parseTextBlock();
  }

  Node parseText([Map<String, dynamic> options]) {
    var tags = <Node>[];
    var lineno = peek().loc.start.line;
    var nextTok = peek();

    loop: while (true) {
      switch (nextTok.type) {
        case 'text':
          var tok = advance();
          tags.add(Text()
            ..type = 'Text'
            ..val = tok.val
            ..line = tok.loc.start.line
            ..column = tok.loc.start.column
            ..filename = filename
          );
          break;
        case 'interpolated-code':
          var tok = advance();
          tags.add(Code()
            ..val = tok.val
            ..buffer = tok.buffer
            ..mustEscape = tok.mustEscape != false
            ..isInline = true
            ..line = tok.loc.start.line
            ..column = tok.loc.start.column
            ..filename = filename
          );
          break;
        case 'newline':
          if (options == null || options['block'] == null) break loop;
          var tok = advance();
          var nextType = peek().type;
          if (nextType == 'text' || nextType == 'interpolated-code') {
            tags.add(Text()
              ..val = '\n'
              ..line = tok.loc.start.line
              ..column = tok.loc.start.column
              ..filename = filename
            );
          }
          break;
        case 'start-pug-interpolation':
          advance();
          tags.add(parseExpr());
          expect('end-pug-interpolation');
          break;
        default:
          var pluginResult = runPlugin('textTokens', nextTok, tags);
          if (pluginResult != null) break;
          break loop;
      }
      nextTok = peek();
    }

    if (tags.length == 1) {
      return tags.first;
    }
    else {
      return initBlock(lineno, tags);
    }
  }

  List<Node> parseTextHtml() {
    var nodes = <Node>[];
    Node currentNode;
    loop: while (true) {
      switch (peek().type) {
        case 'text-html':
          var text = advance();
          if (currentNode == null) {
            currentNode = Text()
              ..val = text.val
              ..filename = filename
              ..line = text.loc.start.line
              ..column = text.loc.start.column
              ..isHtml = true;
            nodes.add(currentNode);
          } else if (currentNode is Text) {
            (currentNode as Text).val += '\n${text.val}';
          }
          break;
        case 'indent':
          var block = this.block();
          block.nodes.forEach((node) {
            if (node is Text && node.isHtml) {
              if (currentNode != null) {
                currentNode = node;
                nodes.add(currentNode);
              } else if (currentNode is Text) {
                (currentNode as Text).val += '\n${node.val}';
              }
            } else {
              currentNode = null;
              nodes.add(node);
            }
          });
          break;
        case 'code':
          currentNode = null;
          nodes.add(parseCode(true));
          break;
        case 'newline':
          advance();
          break;
        default:
          break loop;
      }
    }
    return nodes;
  }

  Node parseBlockExpansion() {
    var tok = accept(':');

    if (tok != null) {
      var expr = parseExpr();
      return expr.type == 'Block'
        ? expr
        : initBlock(tok.loc.start.line, [expr]);
    } else {
      return block();
    }
  }

  Node parseCase() {
    var tok = expect('case');
    var node = Case()
      ..expr = tok.val
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;

    var block = emptyBlock(tok.loc.start.line + 1);
    expect('indent');
    while ('outdent' != peek().type) {
      switch (peek().type) {
        case 'comment':
        case 'newline':
          advance();
          break;
        case 'when':
          block.nodes.add(parseWhen());
          break;
        case 'default':
          block.nodes.add(parseDefault());
          break;
        default:
          var pluginResult = runPlugin('caseTokens', peek(), [block]);
          if (pluginResult != null) break;
          error(
            'INVALID_TOKEN',
            'Unexpected token "' +
              peek().type +
              '", expected "when", "default" or "newline"',
            peek()
          );
      }
    }
    expect('outdent');

    node.block = block;

    return node;
  }

  Node parseWhen() {
    var tok = expect('when');
    if (peek().type != 'newline') {
      return When()
        ..expr = tok.val
        ..block = parseBlockExpansion()
        ..debug = false
        ..line = tok.loc.start.line
        ..column = tok.loc.start.column
        ..filename = filename;
    } else {
      return When()
        ..type = 'When'
        ..expr = tok.val
        ..debug = false
        ..line = tok.loc.start.line
        ..column = tok.loc.start.column
        ..filename = filename;
    }
  }

  Node parseDefault() {
    var tok = expect('default');
    return When()
      ..expr = 'default'
      ..block = parseBlockExpansion()
      ..debug = false
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseCode([bool noBlock]) {
    noBlock ??= false;
    var tok = expect('code');

    var node = Code()
      ..val = tok.val
      ..buffer = tok.buffer
      ..mustEscape = tok.mustEscape != false
      ..isInline = noBlock
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;

    if (noBlock) return node;

    var block;

    // handle block
    block = 'indent' == peek().type;
    if (block) {
      if (tok.buffer) {
        error(
          'BLOCK_IN_BUFFERED_CODE',
          'Buffered code cannot have a block attached to it',
          peek()
        );
      }
      node.block = this.block();
    }

    return node;
  }

  Node parseConditional() {
    var tok = expect('if');
    var node = Conditional()
      ..test = tok.val
      ..consequent = emptyBlock(tok.loc.start.line)
      ..alternate = null
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;

    // handle block
    if ('indent' == peek().type) {
      node.consequent = block();
    }

    var currentNode = node;
    while (true) {
      if (peek().type == 'newline') {
        expect('newline');
      } else if (peek().type == 'else-if') {
        tok = expect('else-if');
        currentNode = currentNode.alternate = Conditional()
          ..test = tok.val
          ..consequent = emptyBlock(tok.loc.start.line)
          ..alternate = null
          ..line = tok.loc.start.line
          ..column = tok.loc.start.column
          ..filename = filename;
        if ('indent' == peek().type) {
          currentNode.consequent = block();
        }
      } else if (peek().type == 'else') {
        expect('else');
        if (peek().type == 'indent') {
          currentNode.alternate = block();
        }
        break;
      } else {
        break;
      }
    }

    return node;
  }

  Node parseWhile() {
    var tok = expect('while');
    var node = While()
      ..test = tok.val
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;

    // handle block
    if ('indent' == peek().type) {
      node.block = block();
    } else {
      node.block = emptyBlock(tok.loc.start.line);
    }

    return node;
  }

  Node parseBlockCode() {
    var tok = expect('blockcode');
    var line = tok.loc.start.line;
    var column = tok.loc.start.column;
    var body = peek();
    var text = '';
    if (body.type == 'start-pipeless-text') {
      advance();
      while (peek().type != 'end-pipeless-text') {
        tok = advance();
        switch (tok.type) {
          case 'text':
            text += tok.val;
            break;
          case 'newline':
            text += '\n';
            break;
          default:
            var pluginResult = runPlugin('blockCodeTokens', tok, [tok]);
            if (pluginResult) {
              text += pluginResult;
              break;
            }
            error(
              'INVALID_TOKEN',
              'Unexpected token type: ' + tok.type,
              tok
            );
        }
      }
      advance();
    }
    return Code()
      ..type = 'Code'
      ..val = text
      ..buffer = false
      ..mustEscape = false
      ..isInline = false
      ..line = line
      ..column = column
      ..filename = filename;
  }

  Node parseComment() {
    var tok = expect('comment');
    var block = parseTextBlock();
    if (block != null) {
      return BlockComment()
        ..type = 'BlockComment'
        ..val = tok.val
        ..block = block
        ..buffer = tok.buffer
        ..line = tok.loc.start.line
        ..column = tok.loc.start.column
        ..filename = filename;
    } else {
      return Comment()
        ..type = 'Comment'
        ..val = tok.val
        ..buffer = tok.buffer
        ..line = tok.loc.start.line
        ..column = tok.loc.start.column
        ..filename = filename;
    }
  }

  Node parseDoctype() {
    var tok = expect('doctype');
    return Doctype()
      ..val = tok.val
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseIncludeFilter() {
    var tok = expect('filter');
    var attrs = [];

    if (peek().type == 'start-attributes') {
      attrs = this.attrs();
    }

    return IncludeFilter()
      ..name = tok.val
      ..attrs = attrs
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseFilter() {
    var tok = expect('filter');
    Node block;
    var attrs = [];

    if (peek().type == 'start-attributes') {
      attrs = this.attrs();
    }

    if (peek().type == 'text') {
      var textToken = advance();
      block = initBlock(textToken.loc.start.line, [
        Text()
          ..val = textToken.val
          ..line = textToken.loc.start.line
          ..column = textToken.loc.start.column
          ..filename = filename
      ]);
    } else if (peek().type == 'filter') {
      block = initBlock(tok.loc.start.line, [parseFilter()]);
    } else {
      block = parseTextBlock() ?? emptyBlock(tok.loc.start.line);
    }

    return Filter()
      ..name = tok.val
      ..block = block
      ..attrs = attrs
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseEach() {
    var tok = expect('each');
    var node = Each()
      ..obj = tok.code
      ..val = tok.val
      ..key = tok.key
      ..block = block()
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
    if (peek().type == 'else') {
      advance();
      node.alternate = block();
    }
    return node;
  }

  Node parseEachOf() {
    var tok = expect('eachOf');
    return EachOf()
      ..obj = tok.code
      ..val = tok.val
      ..block = block()
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseExtends() {
    var tok = expect('extends');
    var path = expect('path');
    var file = FileReference()
      ..path = path.val.trim()
      ..line = path.loc.start.line
      ..column = path.loc.start.column
      ..filename = filename;
    return Extends()
      ..file = file
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseBlock() {
    var tok = expect('block');

    var node =
      ('indent' == peek().type
        ? block()
        : emptyBlock(tok.loc.start.line))
      ..type = 'NamedBlock'
      ..name = tok.val.trim()
      ..mode = tok.mode
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column;

    return node;
  }

  Node parseMixinBlock() {
    var tok = expect('mixin-block');
    if (inMixin == 0) {
      error(
        'BLOCK_OUTISDE_MIXIN',
        'Anonymous blocks are not allowed unless they are part of a mixin.',
        tok
      );
    }
    return MixinBlock()
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseYield() {
    var tok = expect('yield');
    return YieldBlock()
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
  }

  Node parseInclude() {
    var tok = expect('include');
    var node = Include()
      ..file = (FileReference()..filename = filename)
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;
    var filters = <Node>[];
    while (peek().type == 'filter') {
      filters.add(parseIncludeFilter());
    }
    var path = expect('path');

    node.file.path = path.val.trim();
    node.file.line = path.loc.start.line;
    node.file.column = path.loc.start.column;

    if (
      (
        RegExp(r'\.jade$').hasMatch(node.file.path) ||
        RegExp(r'\.pug$').hasMatch(node.file.path)
      ) &&
      filters.isEmpty
    ) {
      node.block =
        'indent' == peek().type
          ? block()
          : emptyBlock(tok.loc.start.line);
      if (RegExp(r'\.jade$').hasMatch(node.file.path)) {
        _logger.w(
          '$filename, line ${tok.loc.start.line}:\nThe .jade extension is deprecated, use .pug for "${node.file.path}".'
        );
      }
    } else {
      node.type = 'RawInclude';
      node.filters = filters;
      if (peek().type == 'indent') {
        error(
          'RAW_INCLUDE_BLOCK',
          'Raw inclusion cannot contain a block',
          peek()
        );
      }
    }
    return node;
  }

  Node parseCall() {
    var tok = expect('call');
    var name = tok.val;
    var args = tok.args;
    var mixinNode = Mixin()
      ..type = 'Mixin'
      ..name = name
      ..args = args
      ..block = emptyBlock(tok.loc.start.line)
      ..call = true
      ..attrs = []
      ..attributeBlocks = []
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;

    tag(mixinNode);
    if (mixinNode.code != null) {
      mixinNode.block.nodes.add(mixinNode.code);
      mixinNode.code = null;
    }
    if (mixinNode.block.nodes.isEmpty) mixinNode.block = null;
    return mixinNode;
  }

  Node parseMixin() {
    var tok = expect('mixin');
    var name = tok.val;
    var args = tok.args;

    if ('indent' == peek().type) {
      inMixin++;
      var mixinNode = Mixin()
        ..type = 'Mixin'
        ..name = name
        ..args = args
        ..block = block()
        ..call = false
        ..line = tok.loc.start.line
        ..column = tok.loc.start.column
        ..filename = filename;
      inMixin--;
      return mixinNode;
    } else {
      error(
        'MIXIN_WITHOUT_BODY',
        'Mixin ' + name + ' declared without body',
        tok
      );
      return null;
    }
  }

  Node parseTextBlock() {
    var tok = accept('start-pipeless-text');
    if (tok == null) return null;
    var block = emptyBlock(tok.loc.start.line);
    while (peek().type != 'end-pipeless-text') {
      var tok = advance();
      switch (tok.type) {
        case 'text':
          block.nodes.add(Text()
            ..val = tok.val
            ..line = tok.loc.start.line
            ..column = tok.loc.start.column
            ..filename = filename
          );
          break;
        case 'newline':
          block.nodes.add(Text()
            ..val = '\n'
            ..line = tok.loc.start.line
            ..column = tok.loc.start.column
            ..filename = filename
          );
          break;
        case 'start-pug-interpolation':
          block.nodes.add(parseExpr());
          expect('end-pug-interpolation');
          break;
        case 'interpolated-code':
          block.nodes.add(Code()
            ..val = tok.val
            ..buffer = tok.buffer
            ..mustEscape = tok.mustEscape != false
            ..isInline = true
            ..line = tok.loc.start.line
            ..column = tok.loc.start.column
            ..filename = filename
          );
          break;
        default:
          var pluginResult = runPlugin('textBlockTokens', tok, [block, tok]);
          if (pluginResult != null) break;
          error(
            'INVALID_TOKEN',
            'Unexpected token type: ' + tok.type,
            tok
          );
      }
    }
    advance();
    return block;
  }

  Node parseInterpolation() {
    var tok = advance();
    var tagNode = Tag()
      ..type = 'InterpolatedTag'
      ..expr = tok.val
      ..selfClosing = false
      ..block = emptyBlock(tok.loc.start.line)
      ..attrs = []
      ..attributeBlocks = []
      ..isInline = false
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;

    return tag(tagNode, TagOptions(selfClosingAllowed: true));
  }

  Node parseTag() {
    var tok = advance();
    var tagNode = Tag()
      ..name = tok.val
      ..selfClosing = false
      ..block = emptyBlock(tok.loc.start.line)
      ..attrs = []
      ..attributeBlocks = []
      ..isInline = inlineTags.contains(tok.val)
      ..line = tok.loc.start.line
      ..column = tok.loc.start.column
      ..filename = filename;

    return tag(tagNode, TagOptions(selfClosingAllowed: true));
  }

  Node tag(Tag tagNode, [TagOptions options]) {
    var seenAttrs = false;
    var attributeNames = <String>[];
    var selfClosingAllowed = options?.selfClosingAllowed;
    // (attrs | class | id)*
    out: while (true) {
      switch (peek().type) {
        case 'id':
        case 'class':
          var tok = advance();
          if (tok.type == 'id') {
            if (attributeNames.contains('id')) {
              error(
                'DUPLICATE_ID',
                'Duplicate attribute "id" is not allowed.',
                tok
              );
            }
            attributeNames.add('id');
          }
          tagNode.attrs.add(Attribute()
            ..name = tok.type
            ..val = "'" + tok.val + "'"
            ..line = tok.loc.start.line
            ..column = tok.loc.start.column
            ..filename = filename
            ..mustEscape = false
          );
          continue;
        case 'start-attributes':
          if (seenAttrs) {
            _logger.w(
              '$filename, line ${peek().loc.start.line}:\nYou should not have pug tags with multiple attributes.'
            );
          }
          seenAttrs = true;
          tagNode.attrs += attrs(attributeNames);
          continue;
        case '&attributes':
          var tok = advance();
          tagNode.attributeBlocks.add(Attribute()
            ..type = 'AttributeBlock'
            ..val = tok.val
            ..line = tok.loc.start.line
            ..column = tok.loc.start.column
            ..filename = filename
          );
          break;
        default:
          var pluginResult = runPlugin(
            'tagAttributeTokens',
            peek(),
            [tagNode, attributeNames]
          );
          if (pluginResult != null) break;
          break out;
      }
    }

    // check immediate '.'
    if ('dot' == peek().type) {
      tagNode.textOnly = true;
      advance();
    }

    // (text | code | ':')?
    switch (peek().type) {
      case 'text':
      case 'interpolated-code':
        var text = parseText();
        if (text.type == 'Block') {
          tagNode.block.nodes.addAll(text.nodes);
        } else {
          tagNode.block.nodes.add(text);
        }
        break;
      case 'code':
        tagNode.block.nodes.add(parseCode(true));
        break;
      case ':':
        advance();
        var expr = parseExpr();
        tagNode.block =
          expr.type == 'Block' ? expr : initBlock(tagNode.line, [expr]);
        break;
      case 'newline':
      case 'indent':
      case 'outdent':
      case 'eos':
      case 'start-pipeless-text':
      case 'end-pug-interpolation':
        break;
      default:
        if (peek().type == 'slash') {
          if (selfClosingAllowed) {
            advance();
            tagNode.selfClosing = true;
            break;
          }
        }
        var pluginResult = runPlugin(
          'tagTokens',
          peek(),
          [tagNode, options]
        );
        if (pluginResult) break;
        error(
          'INVALID_TOKEN',
          'Unexpected token `' +
            peek().type +
            '` expected `text`, `interpolated-code`, `code`, `:`' +
            (selfClosingAllowed ? ', `slash`' : '') +
            ', `newline` or `eos`',
          peek()
        );
    }

    // newline*
    while ('newline' == peek().type) {
      advance();
    }

    // block?
    if (tagNode?.textOnly ?? false) {
      tagNode.block = parseTextBlock() ?? emptyBlock(tagNode.line);
    } else if ('indent' == peek().type) {
      var blockNode = block();
      tagNode.block.nodes += blockNode.nodes;
    }

    return tagNode;
  }

  List<Node> attrs([List<String> attributeNames]) {
    expect('start-attributes');

    var attributes = <Node>[];
    var tok = advance();
    while (tok.type == 'attribute') {
      if (tok.name != 'class' && attributeNames != null) {
        if (attributeNames.contains(tok.name)) {
          error(
            'DUPLICATE_ATTRIBUTE',
            'Duplicate attribute "' + tok.name + '" is not allowed.',
            tok
          );
        }
        attributeNames.add(tok.name);
      }
      attributes.add(Attribute()
        ..name = tok.name
        ..val = tok.val
        ..line = tok.loc.start.line
        ..column = tok.loc.start.column
        ..filename = filename
        ..mustEscape = tok.mustEscape != false
      );
      tok = advance();
    }
    tokens.defer(tok);
    expect('end-attributes');
    return attributes;
  }
}

class ParserOptions {
  ParserOptions({
    this.filename,
    this.src,
    this.plugins,
  });

  String filename;
  String src;
  List plugins;
}

class TagOptions {
  TagOptions({
    this.selfClosingAllowed,
  });

  bool selfClosingAllowed;
}
