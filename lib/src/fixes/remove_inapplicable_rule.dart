import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analysis_server_plugin/edit/fix/fix.dart';
import 'package:analysis_server_plugin/edit/range_factory.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Fix for `easy_validate_wrong_type`: removes the rule that doesn't apply
/// (or the whole `@EasyValidate` when it was the only one).
class RemoveInapplicableRule extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'dart_easy_json_lints.fix.removeInapplicableRule',
    DartFixKindPriority.standard,
    "Remove the '{0}' rule",
  );

  RemoveInapplicableRule({required super.context});

  String _param = '';

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_param];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final arg = node.thisOrAncestorOfType<NamedArgument>();
    final list = arg?.parent;
    final annotation = list?.parent;
    if (arg == null || list is! ArgumentList || annotation is! Annotation) {
      return;
    }
    _param = arg.name.lexeme;

    await builder.addDartFileEdit(file, (builder) {
      if (list.arguments.length == 1) {
        // Único argumento: remove a anotação inteira e o espaço até o
        // próximo token (a quebra de linha e a indentação).
        builder.addDeletion(
          range.startStart(annotation, annotation.endToken.next!),
        );
      } else {
        builder.addDeletion(range.nodeInList(list.arguments, arg));
      }
    });
  }
}
