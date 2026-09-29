// Os métodos precisam do prefixo test_ para o test_reflective_loader.
// ignore_for_file: non_constant_identifier_names

import 'package:dart_easy_json_lints/src/fixes/add_from_json_factory.dart';
import 'package:dart_easy_json_lints/src/fixes/add_serializer_mixin.dart';
import 'package:dart_easy_json_lints/src/fixes/remove_inapplicable_rule.dart';
import 'package:dart_easy_json_lints/src/rules/easy_json_missing_mixin.dart';
import 'package:dart_easy_json_lints/src/rules/easy_union_mapping_not_subtype.dart';
import 'package:dart_easy_json_lints/src/rules/easy_union_missing_factory.dart';
import 'package:dart_easy_json_lints/src/rules/easy_validate_wrong_type.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EasyUnionMissingFactoryTest);
    defineReflectiveTests(EasyJsonMissingMixinTest);
    defineReflectiveTests(EasyUnionMappingNotSubtypeTest);
    defineReflectiveTests(RemoveInapplicableRuleTest);
  });
}

/// Uma union com duas subclasses; `{TEXT}` e `{JSON}` variam por teste.
String _union({String text = '', String json = '@EasyJson()'}) =>
    '''$easyImport
$json
@EasyUnion(discriminator: 'type', mapping: {'text': TextPost, 'video': VideoPost})
sealed class Post {
  Map<String, dynamic> toJson();
}

@EasyJson()
class TextPost extends Post {
  final String content;
  TextPost(this.content);$text
  Map<String, dynamic> toJson() => {};
}

@EasyJson()
class VideoPost extends Post {
  VideoPost();
  factory VideoPost.fromJson(Map<String, dynamic> json) => VideoPost();
  Map<String, dynamic> toJson() => {};
}
''';

@reflectiveTest
class EasyUnionMissingFactoryTest extends EasyJsonRuleTest {
  @override
  void setUp() {
    rule = EasyUnionMissingFactory();
    addEasyJson();
    super.setUp();
  }

  Future<void> test_mappedClassWithoutFactory() async {
    final code = _union();
    // Só TextPost: VideoPost já tem a factory.
    await assertDiagnostics(code, [_lintOnName(code, 'TextPost')]);
  }

  Future<void> test_withFactory_noDiagnostics() async {
    await assertNoDiagnostics(
      _union(text: '\n  factory TextPost.fromJson(Map<String, dynamic> json) => TextPost("");'),
    );
  }

  Future<void> test_strictUnion_doesNotNeedFactory() async {
    await assertNoDiagnostics(_union(json: '@EasyJson(strict: true)'));
  }

  Future<void> test_fix_addsFactory() async {
    final code = _union();
    await assertDiagnostics(code, [_lintOnName(code, 'TextPost')]);
    final fixed = await applyFix(EasyUnionMissingFactory.code, AddFromJsonFactory.new);
    expect(
      fixed,
      contains(
        '  Map<String, dynamic> toJson() => {};\n'
        '  factory TextPost.fromJson(Map<String, dynamic> json) => textPostFromJson(json);\n'
        '}',
      ),
    );
  }

  dynamic _lintOnName(String code, String name) {
    final offset = code.indexOf('class $name') + 'class '.length;
    return lint(offset, name.length);
  }
}

@reflectiveTest
class EasyJsonMissingMixinTest extends EasyJsonRuleTest {
  @override
  void setUp() {
    rule = EasyJsonMissingMixin();
    addEasyJson();
    super.setUp();
  }

  dynamic _onName(String code, String name) =>
      lint(code.indexOf('class $name') + 'class '.length, name.length);

  Future<void> test_missingMixin() async {
    const code = '''$easyImport
@EasyJson()
class User {
  final String name;
  User(this.name);
}
''';
    await assertDiagnostics(code, [_onName(code, 'User')]);
  }

  Future<void> test_mixinPresent_noDiagnostics() async {
    await assertNoDiagnostics('''$easyImport
mixin UserSerializer {}
@EasyJson()
class User with UserSerializer {
  final String name;
  User(this.name);
}
''');
  }

  Future<void> test_notReported_whenNotNeeded() async {
    await assertNoDiagnostics('''$easyImport
@EasyJson(toJson: false)
class ReadOnly { ReadOnly(); }

@EasyJson()
class OwnToJson {
  OwnToJson();
  Map<String, dynamic> toJson() => {};
}

@EasyJson()
abstract class Base { }

class Plain { Plain(); }
''');
  }

  Future<void> test_fix_addsWith() async {
    const code = '''$easyImport
class Base {}
@EasyJson()
class User extends Base implements Comparable<User> {
  User();
  int compareTo(User other) => 0;
}
''';
    await assertDiagnostics(code, [_onName(code, 'User')]);
    final fixed = await applyFix(EasyJsonMissingMixin.code, AddSerializerMixin.new);
    expect(fixed, contains('class User extends Base with UserSerializer implements Comparable<User> {'));
  }

  Future<void> test_fix_genericAndExistingWith() async {
    const code = '''$easyImport
mixin Other {}
@EasyJson()
class Page<T> with Other {
  Page();
}
''';
    await assertDiagnostics(code, [_onName(code, 'Page')]);
    final fixed = await applyFix(EasyJsonMissingMixin.code, AddSerializerMixin.new);
    expect(fixed, contains('class Page<T> with Other, PageSerializer<T> {'));
  }
}

@reflectiveTest
class EasyUnionMappingNotSubtypeTest extends EasyJsonRuleTest {
  @override
  void setUp() {
    rule = EasyUnionMappingNotSubtype();
    addEasyJson();
    super.setUp();
  }

  Future<void> test_mappedClassNotASubtype() async {
    const ann = "@EasyUnion(discriminator: 'type', mapping: {'a': A, 'b': B}, fallback: C)";
    const code = '''$easyImport
@EasyJson()
$ann
sealed class Shape {}

class A extends Shape {}
class B {}
class C implements Shape {}
''';
    await assertDiagnostics(code, [
      lintOn(code, ann, message: "'B' is in the @EasyUnion of 'Shape'"),
    ]);
  }
}

@reflectiveTest
class RemoveInapplicableRuleTest extends EasyJsonRuleTest {
  @override
  void setUp() {
    rule = EasyValidateWrongType();
    addEasyJson();
    super.setUp();
  }

  Future<void> test_removesOnlyTheRule() async {
    const code = '''$easyImport
class A {
  @EasyValidate(minLength: 3, min: 0)
  final int x;
  A(this.x);
}
''';
    await assertDiagnostics(code, [lintOn(code, 'minLength: 3')]);
    final fixed = await applyFix(EasyValidateWrongType.code, RemoveInapplicableRule.new);
    expect(fixed, contains('  @EasyValidate(min: 0)\n  final int x;'));
  }

  Future<void> test_removesWholeAnnotationWhenOnlyRule() async {
    const code = '''$easyImport
class A {
  @EasyValidate(minLength: 3)
  final int x;
  A(this.x);
}
''';
    await assertDiagnostics(code, [lintOn(code, 'minLength: 3')]);
    final fixed = await applyFix(EasyValidateWrongType.code, RemoveInapplicableRule.new);
    expect(fixed, contains('class A {\n  final int x;\n'));
  }
}
