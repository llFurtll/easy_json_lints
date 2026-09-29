import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../annotated_field.dart';

/// `@EasyValidate` rules the generator silently ignores because they don't
/// apply to the field's type (e.g. `minLength` on an `int`).
class EasyValidateWrongType extends AnalysisRule {
  static const LintCode code = LintCode(
    'easy_validate_wrong_type',
    "'{0}' doesn't apply to '{1}' fields, so it is ignored.",
    correctionMessage: 'Remove it, or use it on a {2} field.',
    severity: DiagnosticSeverity.WARNING,
  );

  EasyValidateWrongType()
    : super(
        name: 'easy_validate_wrong_type',
        description:
            'An @EasyValidate rule is used on a field type it does not apply to.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addAnnotation(this, _Visitor(this));
  }
}

/// Regra do @EasyValidate -> (tipos aos quais se aplica, texto para a dica).
/// Espelha `_generateValidationChecks` do gerador do dart_easy_json.
const _appliesTo = <String, (Set<String>, String)>{
  'minLength': ({'String', 'List', 'Set', 'Map'}, 'String, List, Set or Map'),
  'maxLength': ({'String', 'List', 'Set', 'Map'}, 'String, List, Set or Map'),
  'regex': ({'String'}, 'String'),
  'format': ({'String'}, 'String'),
  'min': ({'int', 'double', 'num'}, 'int, double or num'),
  'max': ({'int', 'double', 'num'}, 'int, double or num'),
  'past': ({'DateTime'}, 'DateTime'),
  'future': ({'DateTime'}, 'DateTime'),
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitAnnotation(Annotation node) {
    final field = AnnotatedField.of(node, 'EasyValidate');
    if (field == null) return;

    for (final arg in node.arguments?.arguments ?? const <Argument>[]) {
      if (arg is! NamedArgument) continue;
      final param = arg.name.lexeme;
      final rule = _appliesTo[param];
      if (rule == null) continue;
      final (types, hint) = rule;
      if (types.contains(field.baseTypeName)) continue;
      // Reporta no argumento (`minLength: 3`), não na anotação inteira: fica
      // mais preciso no editor e é o que o quick fix remove.
      this.rule.reportAtNode(arg, arguments: [param, field.baseTypeName, hint]);
    }
  }
}
