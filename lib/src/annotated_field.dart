import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Whether [value] is an instance of the `dart_easy_json` annotation class
/// named [className] (a class with the same name from another package
/// doesn't count).
bool isEasyJsonAnnotation(DartObject? value, String className) {
  final type = value?.type;
  if (type is! InterfaceType || type.element.name != className) return false;
  final lib = type.element.library.uri;
  return lib.scheme == 'package' && lib.pathSegments.first == 'dart_easy_json';
}

/// The value of the `@<className>` annotation of [element], if any.
DartObject? easyJsonAnnotationOf(Element element, String className) {
  for (final a in element.metadata.annotations) {
    final value = a.computeConstantValue();
    if (isEasyJsonAnnotation(value, className)) return value;
  }
  return null;
}

/// Reads a `bool` parameter of an annotation, with the annotation's default.
bool annotationFlag(DartObject? annotation, String name, bool defaultValue) =>
    annotation?.getField(name)?.toBoolValue() ?? defaultValue;

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
    if (value == null || !isEasyJsonAnnotation(value, className)) return null;

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
