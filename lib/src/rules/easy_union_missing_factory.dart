import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../annotated_field.dart';

/// A class listed in an `@EasyUnion` mapping (or as its fallback) without a
/// `fromJson` constructor. The generated union `fromJson` calls
/// `Subclass.fromJson(json)`, so the generated code doesn't compile.
class EasyUnionMissingFactory extends AnalysisRule {
  static const LintCode code = LintCode(
    'easy_union_missing_factory',
    "'{0}' is used by the @EasyUnion of '{1}' but has no 'fromJson' "
        "constructor, so the generated code for '{1}' doesn't compile.",
    correctionMessage:
        "Add 'factory {0}.fromJson(Map<String, dynamic> json) => "
        "{2}FromJson(json);'.",
    severity: DiagnosticSeverity.WARNING,
  );

  EasyUnionMissingFactory()
    : super(
        name: 'easy_union_missing_factory',
        description:
            'A class used by an @EasyUnion has no fromJson constructor.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

/// The `@EasyUnion` classes that use [element] and need its `fromJson`.
Iterable<InterfaceElement> unionsNeedingFactory(InterfaceElement element) sync* {
  for (final supertype in element.allSupertypes) {
    final union = supertype.element;
    final ann = easyJsonAnnotationOf(union, 'EasyUnion');
    if (ann == null) continue;

    // Só o fromJson normal (não strict) chama `Subclasse.fromJson`.
    final json = easyJsonAnnotationOf(union, 'EasyJson');
    if (!annotationFlag(json, 'fromJson', true)) continue;
    if (annotationFlag(json, 'strict', false)) continue;

    final used = [
      ...?ann.getField('mapping')?.toMapValue()?.values,
      ann.getField('fallback'),
    ].map((v) => v?.toTypeValue()?.element);
    if (used.contains(element)) yield union;
  }
}

String lcFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || element.getNamedConstructor('fromJson') != null) {
      return;
    }
    final name = element.displayName;
    for (final union in unionsNeedingFactory(element)) {
      rule.reportAtToken(
        node.namePart.typeName,
        arguments: [name, union.displayName, lcFirst(name)],
      );
    }
  }
}
