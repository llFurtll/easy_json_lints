// Os métodos precisam do prefixo test_ para o test_reflective_loader.
// ignore_for_file: non_constant_identifier_names

import 'package:dart_easy_json_lints/src/assists/convert_to_easy_json_model.dart';
import 'package:dart_easy_json_lints/src/rules/easy_json_missing_mixin.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ConvertToEasyJsonModelTest);
  });
}

@reflectiveTest
class ConvertToEasyJsonModelTest extends EasyJsonRuleTest {
  @override
  void setUp() {
    // O assist não depende de regra; a regra só serve para analisar o arquivo.
    rule = EasyJsonMissingMixin();
    addEasyJson();
    super.setUp();
  }

  /// Só resolve o arquivo: o código de partida pode ter erros (ex.: campo
  /// final sem construtor), que é justamente o que o assist resolve.
  Future<void> _resolve(String code) async {
    testFile.writeAsStringSync(code);
    result = await resolveFile(testFile.path);
  }

  Future<String> _convert(String code, String at) async {
    await _resolve(code);
    return applyAssist(ConvertToEasyJsonModel.new, at);
  }

  Future<void> test_plainClass() async {
    final out = await _convert('''
/// A user.
class User {
  final String name;
  final int? age;
  final List<String> tags = const [];
}
''', 'User {');
    expect(out, '''
import 'package:dart_easy_json/easy_json.dart';
import 'test.easy.dart';

/// A user.
@EasyJson()
class User with UserSerializer {
  final String name;
  final int? age;
  final List<String> tags = const [];
  User({required this.name, this.age});
  factory User.fromJson(Map<String, dynamic> json) => userFromJson(json);
}
''');
  }

  Future<void> test_keepsExistingConstructorImportsAndClauses() async {
    final out = await _convert('''
import 'dart:math';
import 'package:dart_easy_json/easy_json.dart';

class Base {}

class Point extends Base implements Comparable<Point> {
  final int x;
  Point(this.x);
  @override
  int compareTo(Point other) => x - other.x;
}
''', 'Point extends');
    expect(out, '''
import 'dart:math';
import 'package:dart_easy_json/easy_json.dart';
import 'test.easy.dart';

class Base {}

@EasyJson()
class Point extends Base with PointSerializer implements Comparable<Point> {
  final int x;
  Point(this.x);
  @override
  int compareTo(Point other) => x - other.x;
  factory Point.fromJson(Map<String, dynamic> json) => pointFromJson(json);
}
''');
  }

  Future<void> test_emptyBodyOnOneLine() async {
    final out = await _convert('class Empty {}\n', 'Empty');
    expect(out, '''
import 'package:dart_easy_json/easy_json.dart';
import 'test.easy.dart';

@EasyJson()
class Empty with EmptySerializer {
  Empty();
  factory Empty.fromJson(Map<String, dynamic> json) => emptyFromJson(json);
}
''');
  }

  Future<void> _expectNotOffered(String code, String at) async =>
      expect(await _convert(code, at), code);

  Future<void> test_notOffered_insideTheBody() => _expectNotOffered('''
class A {
  final int x = 1;
}
''', 'final');

  Future<void> test_notOffered_genericClass() =>
      _expectNotOffered('class B<T> {}', 'B<');

  Future<void> test_notOffered_abstractClass() =>
      _expectNotOffered('abstract class C {}', 'C ');

  Future<void> test_notOffered_alreadyAnnotated() => _expectNotOffered('''
$easyImport@EasyJson()
class D with DSerializer {}
''', 'D ');
}
