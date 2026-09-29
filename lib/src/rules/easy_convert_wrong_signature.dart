import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../annotated_field.dart';

/// Functions passed to `@EasyConvert` / `@EasyValidate(custom:)` whose
/// signature doesn't fit the field. `@EasyConvert` takes untyped `Function`s,
/// so without this the mismatch only shows up in the generated code or at
/// runtime.
class EasyConvertWrongSignature extends AnalysisRule {
  static const LintCode code = LintCode(
    'easy_convert_wrong_signature',
    "The {0} function '{1}' doesn't fit field '{2}': {3}.",
    correctionMessage: 'Change the function, or the field type, so they match.',
    severity: DiagnosticSeverity.WARNING,
  );

  EasyConvertWrongSignature()
    : super(
        name: 'easy_convert_wrong_signature',
        description:
            'A function passed to @EasyConvert or @EasyValidate(custom:) '
            "doesn't match the annotated field's type.",
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
    final convert = AnnotatedField.of(node, 'EasyConvert');
    if (convert != null) {
      final field = convert.fieldType;
      _checkFromJson(node, convert, 'fromJson', field);
      _checkToJson(node, convert, 'toJson', field);

      // valueFromJson / valueToJson convertem cada valor de um Map.
      final mapValue = _mapValueType(field);
      if (mapValue != null) {
        _checkFromJson(node, convert, 'valueFromJson', mapValue);
        _checkToJson(node, convert, 'valueToJson', mapValue);
      }
      return;
    }

    final validate = AnnotatedField.of(node, 'EasyValidate');
    if (validate != null) _checkCustom(node, validate);
  }

  /// fromJson recebe o valor cru do JSON (qualquer tipo) e o resultado é
  /// atribuído ao campo.
  void _checkFromJson(
    Annotation node,
    AnnotatedField f,
    String param,
    DartType target,
  ) {
    final fn = _function(f, param);
    if (fn == null) return;
    if (_singleArg(fn.type) == null) {
      _report(node, param, fn, f, 'it must take exactly one argument');
    } else if (!types.isAssignableTo(fn.returnType, target)) {
      _report(node, param, fn, f,
          "it returns '${_show(fn.returnType)}', but the value is '${_show(target)}'");
    }
  }

  /// toJson recebe o valor (não-nulo) do campo.
  void _checkToJson(
    Annotation node,
    AnnotatedField f,
    String param,
    DartType source,
  ) {
    final fn = _function(f, param);
    if (fn == null) return;
    final arg = _singleArg(fn.type);
    final value = types.promoteToNonNull(source);
    if (arg == null) {
      _report(node, param, fn, f, 'it must take exactly one argument');
    } else if (!types.isAssignableTo(value, arg)) {
      _report(node, param, fn, f,
          "it takes '${_show(arg)}', but the value is '${_show(value)}'");
    }
  }

  /// custom recebe o valor (não-nulo) do campo e devolve bool.
  void _checkCustom(Annotation node, AnnotatedField f) {
    final fn = _function(f, 'custom');
    if (fn == null) return;
    final arg = _singleArg(fn.type);
    final value = types.promoteToNonNull(f.fieldType);
    if (arg == null) {
      _report(node, 'custom', fn, f, 'it must take exactly one argument');
    } else if (!types.isAssignableTo(value, arg)) {
      _report(node, 'custom', fn, f,
          "it takes '${_show(arg)}', but the value is '${_show(value)}'");
    } else if (!fn.returnType.isDartCoreBool) {
      _report(node, 'custom', fn, f,
          "it returns '${_show(fn.returnType)}' instead of 'bool'");
    }
  }

  ExecutableElement? _function(AnnotatedField f, String param) {
    final v = f.value.getField(param);
    return (v == null || v.isNull) ? null : v.toFunctionValue();
  }

  /// Tipo do único argumento posicional com que a função pode ser chamada,
  /// ou null se ela não puder ser chamada com exatamente um argumento.
  DartType? _singleArg(FunctionType t) {
    final required = t.normalParameterTypes;
    final optional = t.optionalParameterTypes;
    if (required.length == 1) return required.single;
    if (required.isEmpty && optional.isNotEmpty) return optional.first;
    return null;
  }

  DartType? _mapValueType(DartType t) =>
      t is InterfaceType && t.isDartCoreMap ? t.typeArguments.last : null;

  void _report(
    Annotation node,
    String param,
    ExecutableElement fn,
    AnnotatedField f,
    String why,
  ) {
    final owner = fn.enclosingElement;
    final name = owner is InterfaceElement
        ? '${owner.displayName}.${fn.displayName}'
        : fn.displayName;
    rule.reportAtNode(node, arguments: [param, name, f.fieldName, why]);
  }

  String _show(DartType t) => t.getDisplayString();
}
