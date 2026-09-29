// Os métodos precisam do prefixo test_ para o test_reflective_loader.
// ignore_for_file: non_constant_identifier_names

import 'package:dart_easy_json_lints/src/rules/easy_convert_wrong_signature.dart';
import 'package:dart_easy_json_lints/src/rules/easy_validate_wrong_type.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EasyValidateWrongTypeTest);
    defineReflectiveTests(EasyConvertWrongSignatureTest);
  });
}

@reflectiveTest
class EasyValidateWrongTypeTest extends EasyJsonRuleTest {
  @override
  void setUp() {
    rule = EasyValidateWrongType();
    // Precisa vir antes do super.setUp(), que grava o package_config.
    addEasyJson();
    super.setUp();
  }

  Future<void> test_minLength_onInt() async {
    const code = '''$easyImport
class A {
  @EasyValidate(minLength: 3)
  final int x;
  A(this.x);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, 'minLength: 3', message: "'minLength' doesn't apply to 'int'"),
    ]);
  }

  Future<void> test_validTypes_noDiagnostics() async {
    await assertNoDiagnostics('''$easyImport
class A {
  @EasyValidate(minLength: 3, maxLength: 9, regex: 'a', format: EasyFormat.email)
  final String s;
  @EasyValidate(minLength: 1)
  final List<int>? items;
  @EasyValidate(maxLength: 2)
  final Map<String, int> m;
  @EasyValidate(min: 0, max: 10)
  final double d;
  @EasyValidate(min: 0)
  final num n;
  @EasyValidate(past: true)
  final DateTime? born;
  A(this.s, this.items, this.m, this.d, this.n, this.born);
}
''');
  }

  Future<void> test_eachWrongRuleIsReported() async {
    const code = '''$easyImport
class A {
  @EasyValidate(min: 1, past: true)
  final String s;
  A(this.s);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, 'min: 1', message: "'min' doesn't apply to 'String'"),
      lintOn(code, 'past: true', message: "'past' doesn't apply to 'String'"),
    ]);
  }

  Future<void> test_formatOnInt() async {
    const code = '''$easyImport
class A {
  @EasyValidate(format: EasyFormat.uuid)
  final int id;
  A(this.id);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, 'format: EasyFormat.uuid'),
    ]);
  }

  Future<void> test_onConstructorParameter() async {
    const code = '''$easyImport
class A {
  final int x;
  A(@EasyValidate(maxLength: 3) this.x);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, 'maxLength: 3'),
    ]);
  }

  Future<void> test_sameNameFromAnotherPackage_ignored() async {
    await assertNoDiagnostics('''
class EasyValidate { final int? minLength; const EasyValidate({this.minLength}); }
class A {
  @EasyValidate(minLength: 3)
  final int x;
  A(this.x);
}
''');
  }
}

@reflectiveTest
class EasyConvertWrongSignatureTest extends EasyJsonRuleTest {
  @override
  void setUp() {
    rule = EasyConvertWrongSignature();
    // Precisa vir antes do super.setUp(), que grava o package_config.
    addEasyJson();
    super.setUp();
  }

  Future<void> test_validConverters_noDiagnostics() async {
    await assertNoDiagnostics('''$easyImport
class Ms {
  static DateTime fromJson(Object? v) => throw 'unused';
  static int toJson(DateTime v) => 0;
}
int parseInt(Object? v) => 0;
bool isPositive(int v) => v > 0;
class A {
  @EasyConvert(fromJson: Ms.fromJson, toJson: Ms.toJson)
  final DateTime at;
  @EasyConvert(fromJson: Ms.fromJson, toJson: Ms.toJson)
  final DateTime? maybe;
  @EasyConvert(valueFromJson: parseInt)
  final Map<String, int> scores;
  @EasyValidate(custom: isPositive)
  final int age;
  A(this.at, this.maybe, this.scores, this.age);
}
''');
  }

  Future<void> test_fromJson_wrongReturnType() async {
    const code = '''$easyImport
String asText(Object? v) => '';
class A {
  @EasyConvert(fromJson: asText)
  final DateTime at;
  A(this.at);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, '@EasyConvert(fromJson: asText)',
          message: "it returns 'String', but the value is 'DateTime'"),
    ]);
  }

  Future<void> test_fromJson_nullableResult_onNonNullableField() async {
    const code = '''$easyImport
DateTime? maybeDate(Object? v) => null;
class A {
  @EasyConvert(fromJson: maybeDate)
  final DateTime at;
  A(this.at);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, '@EasyConvert(fromJson: maybeDate)'),
    ]);
  }

  Future<void> test_toJson_wrongParameterType() async {
    const code = '''$easyImport
class Ms {
  static int toJson(int v) => v;
}
class A {
  @EasyConvert(toJson: Ms.toJson)
  final DateTime at;
  A(this.at);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, '@EasyConvert(toJson: Ms.toJson)',
          message: "'Ms.toJson' doesn't fit field 'at': it takes 'int'"),
    ]);
  }

  Future<void> test_wrongArity() async {
    const code = '''$easyImport
DateTime two(Object? a, Object? b) => throw 'unused';
class A {
  @EasyConvert(fromJson: two)
  final DateTime at;
  A(this.at);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, '@EasyConvert(fromJson: two)',
          message: 'must take exactly one argument'),
    ]);
  }

  Future<void> test_valueFromJson_wrongReturnType() async {
    const code = '''$easyImport
String asText(Object? v) => '';
class A {
  @EasyConvert(valueFromJson: asText)
  final Map<String, int> scores;
  A(this.scores);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, '@EasyConvert(valueFromJson: asText)'),
    ]);
  }

  Future<void> test_custom_mustReturnBool() async {
    const code = '''$easyImport
int check(int v) => v;
class A {
  @EasyValidate(custom: check)
  final int age;
  A(this.age);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, '@EasyValidate(custom: check)',
          message: "returns 'int' instead of 'bool'"),
    ]);
  }

  Future<void> test_custom_wrongParameterType() async {
    const code = '''$easyImport
bool isShort(String v) => v.length < 3;
class A {
  @EasyValidate(custom: isShort)
  final int age;
  A(this.age);
}
''';
    await assertDiagnostics(code, [
      lintOn(code, '@EasyValidate(custom: isShort)'),
    ]);
  }
}
