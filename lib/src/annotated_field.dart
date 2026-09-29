import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';

/// Uma anotação do `dart_easy_json` num campo, já resolvida: o valor
/// constante da anotação e o tipo do campo anotado.
class AnnotatedField {
  AnnotatedField(this.value, this.fieldType, this.fieldName);

  final DartObject value;
  final DartType fieldType;
  final String fieldName;

  /// Resolve [node] se ele for `@<className>(...)` do pacote
  /// `dart_easy_json` aplicado a um campo (ou a um parâmetro `this.x`).
  static AnnotatedField? of(Annotation node, String className) {
    final value = node.elementAnnotation?.computeConstantValue();
    final type = value?.type;
    if (value == null || type is! InterfaceType) return null;
    if (type.element.name != className) return null;
    final lib = type.element.library.uri;
    if (lib.scheme != 'package' || lib.pathSegments.first != 'dart_easy_json') {
      return null;
    }

    final parent = node.parent;
    final variable = switch (parent) {
      FieldDeclaration() => parent.fields.variables.first.declaredFragment?.element,
      FormalParameter() => parent.declaredFragment?.element,
      _ => null,
    };
    if (variable == null) return null;
    return AnnotatedField(value, variable.type, variable.displayName);
  }

  /// Nome do tipo sem `?` (ex.: `int`, `List`, `DateTime`).
  String get baseTypeName => switch (fieldType) {
    InterfaceType(:final element) => element.name ?? '',
    _ => fieldType.getDisplayString().replaceAll('?', ''),
  };
}
