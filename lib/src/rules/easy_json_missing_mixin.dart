import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../annotated_field.dart';

/// An `@EasyJson` class that doesn't mix in its generated `XSerializer`.
/// Without it the class has no `toJson()` method, and the generated `toJson`
/// of any model containing it (which calls `field.toJson()`) doesn't compile.
class EasyJsonMissingMixin extends AnalysisRule {
  static const LintCode code = LintCode(
    'easy_json_missing_mixin',
    "'{0}' doesn't mix in '{1}', so it has no toJson() method.",
    correctionMessage: "Add 'with {1}' to the class declaration.",
    severity: DiagnosticSeverity.WARNING,
  );

  EasyJsonMissingMixin()
    : super(
        name: 'easy_json_missing_mixin',
        description:
            "An @EasyJson class doesn't mix in its generated Serializer mixin.",
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

/// Name of the generated mixin for [className].
String serializerName(String className) => '${className}Serializer';

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || element.isAbstract) return;

    final json = easyJsonAnnotationOf(element, 'EasyJson');
    if (json == null || !annotationFlag(json, 'toJson', true)) return;
    if (easyJsonAnnotationOf(element, 'EasyUnion') != null) return;

    final name = element.displayName;
    final mixin = serializerName(name);

    // Pelo texto: antes do primeiro build_runner o mixin ainda não existe
    // como tipo, e quem já escreveu `with XSerializer` não deve ser avisado.
    final mixins = node.withClause?.mixinTypes ?? const <NamedType>[];
    if (mixins.any((t) => t.name.lexeme == mixin)) return;

    // toJson escrito à mão (na classe ou herdado) também resolve.
    if (element.lookUpConcreteMethod('toJson', element.library) != null) {
      return;
    }

    rule.reportAtToken(node.namePart.typeName, arguments: [name, mixin]);
  }
}
