# dart_easy_json_lints

Analyzer plugin for [`dart_easy_json`](https://pub.dev/packages/dart_easy_json). It flags annotations that are used in a way the generator can't honor — right in your editor and in `dart analyze`, before you even run `build_runner`.

```dart
@EasyJson()
class User with UserSerializer {
  @EasyValidate(minLength: 3)   // ⚠ 'minLength' doesn't apply to 'int' fields, so it is ignored.
  final int age;

  @EasyConvert(fromJson: asText) // ⚠ The fromJson function 'asText' doesn't fit field 'createdAt':
  final DateTime createdAt;      //   it returns 'String', but the value is 'DateTime'.
  // ...
}
```

Most warnings come with a quick fix (the 💡 in your editor), and an [assist](#assist-convert-to-easyjson-model) turns a plain class into a model.

## Setup

Requires Dart 3.10+ (Flutter 3.38+). Add the plugin to the `analysis_options.yaml` at the root of your package:

```yaml
plugins:
  dart_easy_json_lints: ^0.3.0
```

Then restart the Dart analysis server (in VS Code: *Dart: Restart Analysis Server*). There is nothing to add to `pubspec.yaml` — the analysis server fetches the plugin itself.

> Run `dart analyze` from the package root (or on specific files). When given a sub-directory (`dart analyze lib/models`), `dart analyze` doesn't load the plugins configured at the root.

## Assist: Convert to @EasyJson model

With the cursor on the name of a plain class, the 💡 menu offers **Convert to @EasyJson model**:

```dart
class User {
  final String name;
  final int? age;
}
```

becomes

```dart
import 'package:dart_easy_json/easy_json.dart';
import 'user.easy.dart';

@EasyJson()
class User with UserSerializer {
  final String name;
  final int? age;
  User({required this.name, this.age});
  factory User.fromJson(Map<String, dynamic> json) => userFromJson(json);
}
```

Then run `dart run build_runner build`. It only adds what's missing: an existing constructor, `fromJson` factory or import is kept (the constructor is only created when the class has none, with a named parameter per field). The `.easy.dart` import assumes the default location, next to the model. Generic, abstract and sealed classes aren't offered the assist, since they need converters or `@EasyUnion`.

## Rules

All rules are warnings, enabled by default.

| Rule | Catches | Quick fix |
|---|---|---|
| [`easy_validate_wrong_type`](#easy_validate_wrong_type) | `@EasyValidate` rules on a field type they don't apply to | Remove the rule |
| [`easy_convert_wrong_signature`](#easy_convert_wrong_signature) | `@EasyConvert` / `custom:` functions that don't fit the field | — |
| [`easy_json_missing_mixin`](#easy_json_missing_mixin) | `@EasyJson` class without `with XSerializer` | Add the mixin |
| [`easy_union_missing_factory`](#easy_union_missing_factory) | `@EasyUnion` subclass without `factory X.fromJson` | Add the factory |
| [`easy_union_mapping_not_subtype`](#easy_union_mapping_not_subtype) | `@EasyUnion` mapping to a class that isn't a subtype | — |

### `easy_validate_wrong_type`

An `@EasyValidate` rule on a field type it doesn't apply to. The generator silently skips these, so the validation you wrote never runs.

| Rule | Applies to |
|---|---|
| `minLength`, `maxLength` | `String`, `List`, `Set`, `Map` |
| `regex`, `format` | `String` |
| `min`, `max` | `int`, `double`, `num` |
| `past`, `future` | `DateTime` |

### `easy_convert_wrong_signature`

A function passed to `@EasyConvert` or `@EasyValidate(custom:)` that doesn't fit the field. `@EasyConvert` accepts untyped functions, so without this rule a mismatch only shows up as a compile error in the generated code — or at runtime.

*   `fromJson` / `valueFromJson`: must take one argument, and return something assignable to the field (or `Map` value) type.
*   `toJson` / `valueToJson`: must take one argument that accepts the field (or `Map` value) type.
*   `custom`: must take one argument that accepts the field type, and return `bool`.

### `easy_json_missing_mixin`

An `@EasyJson` class that doesn't mix in its generated `XSerializer`. Without it the class has no `toJson()` method, and the generated `toJson` of any model that contains it (which calls `field.toJson()`) doesn't compile. Not reported when the class defines its own `toJson()`, is abstract, is an `@EasyUnion` base, or uses `@EasyJson(toJson: false)`. Writing `with XSerializer` before running `build_runner` is fine — the check is done on the source.

### `easy_union_missing_factory`

A class listed in an `@EasyUnion` `mapping` (or as its `fallback`) without a `fromJson` constructor. The generated union `fromJson` calls `Subclass.fromJson(json)`, so the generated code doesn't compile. Not reported for `@EasyJson(strict: true)` unions, which don't use these constructors.

### `easy_union_mapping_not_subtype`

A class in an `@EasyUnion` `mapping` (or its `fallback`) that doesn't extend or implement the union class.

## Suppressing

Like any analyzer diagnostic:

```dart
// ignore: easy_validate_wrong_type
@EasyValidate(minLength: 3)
final int age;
```

## Compatibility

Analyzer plugins run inside the Dart analysis server, pinned to the analyzer version of your Dart SDK. This package is released for the current stable SDK; if the plugin doesn't load after a Dart upgrade, update it to the latest version.
