import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analysis_server_plugin/edit/fix/fix.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../annotated_field.dart';
import '../rules/easy_union_missing_factory.dart';

/// Fix for `easy_union_missing_factory`: adds
/// `factory X.fromJson(Map<String, dynamic> json) => xFromJson(json);`.
class AddFromJsonFactory extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'dart_easy_json_lints.fix.addFromJsonFactory',
    DartFixKindPriority.standard,
    "Add the 'fromJson' factory",
  );

  AddFromJsonFactory({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final decl = node.thisOrAncestorOfType<ClassDeclaration>();
    final body = decl?.body;
    final element = decl?.declaredFragment?.element;
    if (decl == null || body is! BlockClassBody || element == null) return;

    // A função `xFromJson` só existe se a classe for @EasyJson com fromJson.
    final json = easyJsonAnnotationOf(element, 'EasyJson');
    if (json == null || !annotationFlag(json, 'fromJson', true)) return;

    final name = element.displayName;
    final factory =
        'factory $name.fromJson(Map<String, dynamic> json) => '
        '${lcFirst(name)}FromJson(json);';

    // `}` sozinho na linha: insere uma linha nova acima dele; senão (`{}` na
    // mesma linha), quebra a linha antes.
    final content = unitResult.content;
    final close = body.rightBracket.offset;
    final lineStart = content.lastIndexOf('\n', close - 1) + 1;
    final onOwnLine = content.substring(lineStart, close).trim().isEmpty;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        close,
        onOwnLine ? '  $factory\n' : '\n  $factory\n',
      );
    });
  }
}
