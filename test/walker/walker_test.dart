import 'package:pug_dart/src/parser/node.dart';
import 'package:pug_dart/src/walker/walker.dart';
import 'package:test/test.dart';

import 'package:pug_dart/pug_dart.dart';

void main() {
  group('walker', () {
    test('simple', () {
      Node ast = walkAST(
        parse(lex('.my-class foo', LexerOptions(filename: 'my-file.pug'))),
        (node, replacer) {
          if (node.type == 'Text') {
            replacer.replace(Text(
              val: 'bar',
              line: node.line,
              column: node.column,
            ));
          }
          return null;
        },
        (node, replace) => null,
      );

      expect(
          ast.toJSON(),
          equals(
              parse(lex('.my-class bar', LexerOptions(filename: 'my-file.pug')))
                  .toJSON()));
    });

    group('replace([])', () {
      test('block flattening', () {
        var called = <String>[];

        var ast = walkAST(
          Block(
            nodes: [
              Block(
                nodes: [
                  Block(
                    nodes: [
                      Text(val: 'a'),
                      Text(val: 'b'),
                    ],
                  ),
                  Text(val: 'c'),
                ],
              ),
              Text(val: 'd'),
            ],
          ),
          (node, replacer) {
            if (node is Text) {
              called.add('before ${node.val}');
              if (node.val == 'a') {
                assert(replacer.isListAllowed,
                    'replacer.isListAllowed set wrongly');
                replacer.replace(<Node>[
                  Text(val: 'e'),
                  Text(val: 'f'),
                ]);
              }
            }

            return null;
          },
          (node, replacer) {
            if (node is Block && replacer.isListAllowed) {
              replacer.replace(node.nodes);
            } else if (node is Text) {
              called.add('after ${node.val}');
            }
            return null;
          },
        );
        expect(
            (ast as Node).toJSON(),
            equals(
              Block(
                nodes: [
                  Text(val: 'e'),
                  Text(val: 'f'),
                  Text(val: 'b'),
                  Text(val: 'c'),
                  Text(val: 'd'),
                ],
              ).toJSON(),
            ));
        expect(
            called,
            equals([
              'before a',
              'before e',
              'after e',
              'before f',
              'after f',
              'before b',
              'after b',
              'before c',
              'after c',
              'before d',
              'after d',
            ]));
      });
      test('adding include filters', () {
        var ast = walkAST(
          parse(lex('include:filter1:filter2 file',
              LexerOptions(filename: 'my-file.pug'))),
          (node, replacer) {
            if (node is IncludeFilter) {
              assert(replacer.isListAllowed);
              if (node.name == 'filter1') {
                var firstFilter = 'filter3';

                replacer.replace([
                  IncludeFilter(
                    name: firstFilter,
                    attrs: [],
                    line: node.line,
                    column: node.column,
                  ),
                  IncludeFilter(
                    name: 'filter4',
                    attrs: [],
                    line: node.line,
                    column: node.column + firstFilter.length + 1,
                  ),
                ]);
              } else if (node.name == 'filter2') {
                replacer.replace([]);
              }
            }

            return null;
          },
          null,
        );
        expect(
            (ast as Node).toJSON(),
            equals(
              parse(lex(
                'include:filter3:filter4 file',
                LexerOptions(filename: 'my-file.pug'),
              )).toJSON(),
            ));
      });
    });
  });
}
