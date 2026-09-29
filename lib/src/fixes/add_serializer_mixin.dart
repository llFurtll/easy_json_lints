import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analysis_server_plugin/edit/fix/fix.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../rules/easy_json_missing_mixin.dart';

/// Fix for `easy_json_missing_mixin`: adds `with XSerializer` (or appends it
/// to an existing `with` clause), with the class's type parameters if any.
class AddSerializerMixin extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'dart_easy_json_lints.fix.addSerializerMixin',
    DartFixKindPriority.standard,
    "Add 'with {0}'",
  );

  AddSerializerMixin({required super.context});

  String _mixin = '';

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_mixin];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final decl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (decl == null) return;

    final name = decl.namePart.typeName.lexeme;
    final typeParams = decl.namePart.typeParameters?.typeParameters;
    final args = typeParams == null || typeParams.isEmpty
        ? ''
        : '<${typeParams.map((p) => p.name.lexeme).join(', ')}>';
    _mixin = serializerName(name);
    final mixin = '$_mixin$args';

    await builder.addDartFileEdit(file, (builder) {
      final (offset, text) = mixinInsertion(decl, mixin);
      builder.addSimpleInsertion(offset, text);
    });
  }
}

/// Onde e o que inserir para [decl] ganhar `with [mixin]`: no fim de um
/// `with` existente, ou depois do `extends` (e antes do `implements`).
(int, String) mixinInsertion(ClassDeclaration decl, String mixin) {
  final withClause = decl.withClause;
  if (withClause != null) return (withClause.end, ', $mixin');
  return (decl.extendsClause?.end ?? decl.namePart.end, ' with $mixin');
}
