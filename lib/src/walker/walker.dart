import '../parser/node.dart';

typedef NodeReplacer = bool Function(Node node, Replacer replacer);

dynamic walkAST(dynamic ast, NodeReplacer before, NodeReplacer after,
    [WalkerOptions options]) {
  options ??= WalkerOptions(includeDependencies: true);
  var parents = options.parents ??= [];

  List<Node> walkAndMergeNodes(List nodes) {
    return nodes.fold([], (value, element) {
      var res = walkAST(element, before, after, options);
      if (res is List) {
        return [...value, ...res];
      } else {
        return [...value, res];
      }
    });
  }

  var replacer = Replacer()
    ..isListAllowed = parents.isNotEmpty &&
        parents[0] != null &&
        (RegExp(r'^(Named)?Block$').hasMatch(parents[0].type) ||
            parents[0].type == 'RawInclude' && ast.type == 'IncludeFilter');
  replacer.replace = (replacement) {
    if (replacement is List && !replacer.isListAllowed) {
      throw Exception(
          'replacer.replace() can only be called with an array if the last parent is a Block or NamedBlock');
    }
    ast = replacement;
  };

  if (before != null) {
    var result = before(ast, replacer);

    if (result != null && !result) {
      return ast;
    } else if (ast is List) {
      return walkAndMergeNodes(ast);
    }
  }

  parents.insert(0, ast);

  switch (ast.type) {
    case 'NamedBlock':
    case 'Block':
      ast.nodes = walkAndMergeNodes(ast.nodes);
      break;
    case 'Case':
    case 'Filter':
    case 'Mixin':
    case 'Tag':
    case 'InterpolatedTag':
    case 'When':
    case 'Code':
    case 'While':
      if (ast.block != null) {
        ast.block = walkAST(ast.block, before, after, options);
      }
      break;
    case 'Each':
      if (ast.block != null) {
        ast.block = walkAST(ast.block, before, after, options);
      }
      if (ast.alternate != null) {
        ast.alternate = walkAST(ast.alternate, before, after, options);
      }
      break;
    case 'EachOf':
      if (ast.block != null) {
        ast.block = walkAST(ast.block, before, after, options);
      }
      break;
    case 'Conditional':
      if (ast.consequent != null) {
        ast.consequent = walkAST(ast.consequent, before, after, options);
      }
      if (ast.alternate != null) {
        ast.alternate = walkAST(ast.alternate, before, after, options);
      }
      break;
    case 'Include':
      walkAST(ast.block, before, after, options);
      walkAST(ast.file, before, after, options);
      break;
    case 'Extends':
      walkAST(ast.file, before, after, options);
      break;
    case 'RawInclude':
      ast.filters = walkAndMergeNodes(ast.filters);
      walkAST(ast.file, before, after, options);
      break;
    case 'Attrs':
    case 'BlockComment':
    case 'Comment':
    case 'Doctype':
    case 'IncludeFilter':
    case 'MixinBlock':
    case 'YieldBlock':
    case 'Text':
      break;
    case 'FileReference':
      if (options.includeDependencies && ast.ast != null) {
        walkAST(ast.ast, before, after, options);
      }
      break;
    default:
      throw Exception('Unexpected node type ' + ast.type);
      break;
  }

  parents.removeAt(0);

  if (after != null) {
    after(ast, replacer);
  }

  return ast;
}

class WalkerOptions {
  WalkerOptions({
    this.includeDependencies,
  });

  bool includeDependencies;
  List<Node> parents;
}

class Replacer {
  Replacer({
    this.isListAllowed,
    this.replace,
  });

  bool isListAllowed;
  void Function(dynamic replacement) replace;
}
