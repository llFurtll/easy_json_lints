import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../annotated_field.dart';

/// A class in an `@EasyUnion` mapping (or its fallback) that isn't a subtype
/// of the union. The generated union `fromJson` returns it as the union type,
/// so the generated code doesn't compile.
class EasyUnionMappingNotSubtype extends AnalysisRule {
  static const LintCode code = LintCode(
    'easy_union_mapping_not_subtype',
    "'{0}' is in the @EasyUnion of '{1}' but doesn't extend or implement it.",
    correctionMessage: "Make '{0}' extend '{1}', or remove it from the union.",
    severity: DiagnosticSeverity.WARNING,
  );

  EasyUnionMappingNotSubtype()
    : super(
        name: 'easy_union_mapping_not_subtype',
        description:
            "A class in an @EasyUnion mapping isn't a subtype of the union.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addAnnotation(this, _Visitor(this, context.typeSystem));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.types);

  final AnalysisRule rule;
  final TypeSystem types;

  @override
  void visitAnnotation(Annotation node) {
    final value = node.elementAnnotation?.computeConstantValue();
    if (!isEasyJsonAnnotation(value, 'EasyUnion')) return;
    final union = switch (node.parent) {
      ClassDeclaration(:final declaredFragment) => declaredFragment?.element,
      _ => null,
    };
    if (union == null) return;

    final used = [
      ...?value!.getField('mapping')?.toMapValue()?.values,
      value.getField('fallback'),
    ].map((v) => v?.toTypeValue()).whereType<InterfaceType>().toSet();

    for (final type in used) {
      if (types.isSubtypeOf(type, union.thisType)) continue;
      rule.reportAtNode(
        node,
        arguments: [type.element.displayName, union.displayName],
      );
    }
  }
}
