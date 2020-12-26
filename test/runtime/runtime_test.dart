import 'package:test/test.dart';
import 'package:pug_dart/pug_dart.dart';

class JSONString {
  JSONString(this._string);

  final String _string;

  String toJSON() => _string;
}

class JSONMap {
  JSONMap(this._map);

  final Map<String, dynamic> _map;

  Map<String, dynamic> toJSON() => _map;
}

void main() {
  group('Runtime', () {
    test('attr', () {
      // Boolean Attributes
      expect(pugAttr('key', true, true, true), equals(' key'));
      expect(pugAttr('key', true, false, true), equals(' key'));
      expect(pugAttr('key', true, true, false), equals(' key="key"'));
      expect(pugAttr('key', true, false, false), equals(' key="key"'));
      expect(pugAttr('key', false, true, true), equals(''));
      expect(pugAttr('key', false, false, true), equals(''));
      expect(pugAttr('key', false, true, false), equals(''));
      expect(pugAttr('key', false, false, false), equals(''));
      expect(pugAttr('key', null, true, true), equals(''));
      expect(pugAttr('key', null, false, true), equals(''));
      expect(pugAttr('key', null, true, false), equals(''));
      expect(pugAttr('key', null, false, false), equals(''));

      // Date Attributes
      expect(
        pugAttr('key', DateTime.parse('2014-12-28T16:46:06.962Z'), true, true),
        equals(' key="2014-12-28 16:46:06.962Z"'),
      );
      expect(
        pugAttr('key', DateTime.parse('2014-12-28T16:46:06.962Z'), false, true),
        equals(' key="2014-12-28 16:46:06.962Z"'),
      );
      expect(
        pugAttr('key', DateTime.parse('2014-12-28T16:46:06.962Z'), true, false),
        equals(' key="2014-12-28 16:46:06.962Z"'),
      );
      expect(
        pugAttr(
            'key', DateTime.parse('2014-12-28T16:46:06.962Z'), false, false),
        equals(' key="2014-12-28 16:46:06.962Z"'),
      );

      // Custom JSON Attributes
      expect(
          pugAttr('key', JSONString('bar'), true, false), equals(' key="bar"'));
      expect(pugAttr('key', JSONMap({'foo': 'bar'}), true, false),
          equals(' key="{&quot;foo&quot;:&quot;bar&quot;}"'));

      // JSON Attributes
      expect(pugAttr('key', {'foo': 'bar'}, true, true),
          equals(' key="{&quot;foo&quot;:&quot;bar&quot;}"'));
      expect(pugAttr('key', {'foo': 'bar'}, false, true),
          equals(' key=\'{"foo":"bar"}\''));
      expect(pugAttr('key', {'foo': "don't"}, true, true),
          equals(' key="{&quot;foo&quot;:&quot;don\'t&quot;}"'));
      expect(pugAttr('key', {'foo': "don't"}, false, true),
          equals(' key=\'{"foo":"don&#39;t"}\''));

      // Number attributes
      expect(pugAttr('key', 500, true, true), equals(' key="500"'));
      expect(pugAttr('key', 500, false, true), equals(' key="500"'));
      expect(pugAttr('key', 500, true, false), equals(' key="500"'));
      expect(pugAttr('key', 500, false, false), equals(' key="500"'));

      // String attributes
      expect(pugAttr('key', 'foo', true, true), equals(' key="foo"'));
      expect(pugAttr('key', 'foo', false, true), equals(' key="foo"'));
      expect(pugAttr('key', 'foo', true, false), equals(' key="foo"'));
      expect(pugAttr('key', 'foo', false, false), equals(' key="foo"'));
      expect(
          pugAttr('key', 'foo>bar', true, true), equals(' key="foo&gt;bar"'));
      expect(pugAttr('key', 'foo>bar', false, true), equals(' key="foo>bar"'));
      expect(
          pugAttr('key', 'foo>bar', true, false), equals(' key="foo&gt;bar"'));
      expect(pugAttr('key', 'foo>bar', false, false), equals(' key="foo>bar"'));
    });

    test('attrs', () {
      // (obj, terse)
      expect(pugAttrs({'foo': 'bar'}, true), equals(' foo="bar"'));
      expect(pugAttrs({'foo': 'bar'}, false), equals(' foo="bar"'));
      expect(pugAttrs({'foo': 'bar', 'hoo': 'boo'}, true),
          equals(' foo="bar" hoo="boo"'));
      expect(pugAttrs({'foo': 'bar', 'hoo': 'boo'}, false),
          equals(' foo="bar" hoo="boo"'));
      expect(pugAttrs({'foo': ''}, true), equals(' foo=""'));
      expect(pugAttrs({'foo': ''}, false), equals(' foo=""'));
      expect(pugAttrs({'class': ''}, true), equals(''));
      expect(pugAttrs({'class': ''}, false), equals(''));
      expect(
          pugAttrs({
            'class': [
              'foo',
              {'bar': true}
            ]
          }, true),
          equals(' class="foo bar"'));
      expect(
          pugAttrs({
            'class': [
              'foo',
              {'bar': true}
            ]
          }, false),
          equals(' class="foo bar"'));
      expect(
          pugAttrs({
            'class': [
              'foo',
              {'bar': true}
            ],
            'foo': 'bar'
          }, true),
          equals(' class="foo bar" foo="bar"'));
      expect(
          pugAttrs({
            'foo': 'bar',
            'class': [
              'foo',
              {'bar': true}
            ]
          }, false),
          equals(' class="foo bar" foo="bar"'));
      expect(
          pugAttrs({'style': 'foo: bar;'}, true), equals(' style="foo: bar;"'));
      expect(pugAttrs({'style': 'foo: bar;'}, false),
          equals(' style="foo: bar;"'));
      expect(
          pugAttrs({
            'style': {'foo': 'bar'}
          }, true),
          equals(' style="foo:bar;"'));
      expect(
          pugAttrs({
            'style': {'foo': 'bar'}
          }, false),
          equals(' style="foo:bar;"'));
    });

    test('classes', () {
      expect(pugClasses(['foo', 'bar']), equals('foo bar'));
      expect(
        pugClasses([
          ['foo', 'bar'],
          ['baz', 'bash'],
        ]),
        equals('foo bar baz bash'),
      );
      expect(
        pugClasses([
          ['foo', 'bar'],
          {'baz': true, 'bash': false}
        ]),
        equals('foo bar baz'),
      );
      expect(
        pugClasses([
          ['fo<o', 'bar'],
          {'ba>z': true, 'bash': false}
        ], [
          true,
          false
        ]),
        equals('fo&lt;o bar ba>z'),
      );
    });

    test('escape', () {
      expect(pugEscape('foo'), equals('foo'));
      expect(pugEscape(10), equals(10));
      expect(pugEscape('foo<bar'), equals('foo&lt;bar'));
      expect(pugEscape('foo&<bar'), equals('foo&amp;&lt;bar'));
      expect(pugEscape('foo&<>bar'), equals('foo&amp;&lt;&gt;bar'));
      expect(pugEscape('foo&<>"bar'), equals('foo&amp;&lt;&gt;&quot;bar'));
      expect(
          pugEscape('foo&<>"bar"'), equals('foo&amp;&lt;&gt;&quot;bar&quot;'));
    });

    test('merge', () {
      // expect(pugMerge({'foo': 'bar'}, {'baz': 'bash'}), equals({'foo': 'bar', 'baz': 'bash'}));
      // expect(pugMerge([{'foo': 'bar'}, {'baz': 'bash'}, {'bing': 'bong'}]), equals({
      //   'foo': 'bar',
      //   'baz': 'bash',
      //   'bing': 'bong',
      // }));
      expect(
          pugMerge(<String, dynamic>{'class': 'bar'},
              <String, dynamic>{'class': 'bash'}),
          equals({
            'class': ['bar', 'bash'],
          }));
      expect(
          pugMerge(<String, dynamic>{
            'class': ['bar']
          }, <String, dynamic>{
            'class': 'bash'
          }),
          equals({
            'class': ['bar', 'bash'],
          }));
      expect(
          pugMerge(<String, dynamic>{
            'class': 'bar'
          }, <String, dynamic>{
            'class': ['bash']
          }),
          equals({
            'class': ['bar', 'bash'],
          }));
      expect(
          pugMerge(<String, dynamic>{'class': 'bar'},
              <String, dynamic>{'class': null}),
          equals({
            'class': ['bar']
          }));
      expect(
          pugMerge(<String, dynamic>{
            'class': null
          }, <String, dynamic>{
            'class': ['bar']
          }),
          equals({
            'class': ['bar']
          }));
      expect(
          pugMerge(<String, dynamic>{}, <String, dynamic>{
            'class': ['bar']
          }),
          equals({
            'class': ['bar']
          }));
      expect(
          pugMerge(<String, dynamic>{
            'class': ['bar']
          }, <String, dynamic>{}),
          equals({
            'class': ['bar']
          }));

      expect(
          pugMerge(<String, dynamic>{'style': 'foo:bar'},
              <String, dynamic>{'style': 'baz:bash'}),
          equals({
            'style': 'foo:bar;baz:bash;',
          }));
      expect(
          pugMerge(<String, dynamic>{'style': 'foo:bar;'},
              <String, dynamic>{'style': 'baz:bash'}),
          equals({
            'style': 'foo:bar;baz:bash;',
          }));
      expect(
          pugMerge(<String, dynamic>{
            'style': {'foo': 'bar'}
          }, <String, dynamic>{
            'style': 'baz:bash'
          }),
          equals({
            'style': 'foo:bar;baz:bash;',
          }));
      expect(
          pugMerge(<String, dynamic>{
            'style': {'foo': 'bar'}
          }, <String, dynamic>{
            'style': {'baz': 'bash'}
          }),
          equals({
            'style': 'foo:bar;baz:bash;',
          }));
      expect(
          pugMerge(<String, dynamic>{'style': 'foo:bar'},
              <String, dynamic>{'style': null}),
          equals({'style': 'foo:bar;'}));
      expect(
          pugMerge(<String, dynamic>{'style': 'foo:bar;'},
              <String, dynamic>{'style': null}),
          equals({
            'style': 'foo:bar;',
          }));
      expect(
          pugMerge(<String, dynamic>{
            'style': {'foo': 'bar'}
          }, <String, dynamic>{
            'style': null
          }),
          equals({
            'style': 'foo:bar;',
          }));
      expect(
          pugMerge(<String, dynamic>{'style': null},
              <String, dynamic>{'style': 'baz:bash'}),
          equals({
            'style': 'baz:bash;',
          }));
      expect(
          pugMerge(<String, dynamic>{'style': null},
              <String, dynamic>{'style': 'baz:bash'}),
          equals({
            'style': 'baz:bash;',
          }));
      expect(
          pugMerge(<String, dynamic>{'style': null},
              <String, dynamic>{'style': 'baz:bash'}),
          equals({
            'style': 'baz:bash;',
          }));
      expect(
          pugMerge(<String, dynamic>{}, <String, dynamic>{'style': 'baz:bash'}),
          equals({'style': 'baz:bash;'}));
      expect(
          pugMerge(<String, dynamic>{}, <String, dynamic>{'style': 'baz:bash'}),
          equals({'style': 'baz:bash;'}));
      expect(
          pugMerge(<String, dynamic>{}, <String, dynamic>{'style': 'baz:bash'}),
          equals({'style': 'baz:bash;'}));
    });

    test('style', () {
      expect(pugStyle(null), equals(''));
      expect(pugStyle(''), equals(''));
      expect(pugStyle('foo: bar'), equals('foo: bar'));
      expect(pugStyle('foo: bar;'), equals('foo: bar;'));
      expect(pugStyle({'foo': 'bar'}), equals('foo:bar;'));
      expect(
          pugStyle({'foo': 'bar', 'baz': 'bash'}), equals('foo:bar;baz:bash;'));
    });
  });
}
