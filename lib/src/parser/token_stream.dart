import '../../pug_dart.dart';

class TokenStream {
  TokenStream.fromIterable(this._tokens);

  final List<Token> _tokens;

  Token lookAhead(int index) => _tokens[index];

  Token peek() => _tokens.first;

  Token advance() => _tokens.removeAt(0);

  void defer(Token token) {
    _tokens.insert(0, token);
  }
}
