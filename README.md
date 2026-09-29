# dart_easy_json_lints

Analyzer plugin for [`dart_easy_json`](https://pub.dev/packages/dart_easy_json). It flags annotations that are used in a way the generator can't honor — right in your editor and in `dart analyze`, before you even run `build_runner`.

```dart
@EasyJson()
class User {
  @EasyValidate(minLength: 3)   // ⚠ 'minLength' doesn't apply to 'int' fields, so it is ignored.
  final int age;

  @EasyConvert(fromJson: asText) // ⚠ The fromJson function 'asText' doesn't fit field 'createdAt':
  final DateTime createdAt;      //   it returns 'String', but the value is 'DateTime'.
  // ...
}
```

## Setup

Requires Dart 3.10+ (Flutter 3.38+). Add the plugin to the `analysis_options.yaml` at the root of your package:

```yaml
plugins:
  dart_easy_json_lints: ^0.1.0
```

Then restart the Dart analysis server (in VS Code: *Dart: Restart Analysis Server*). There is nothing to add to `pubspec.yaml` — the analysis server fetches the plugin itself.

> Run `dart analyze` from the package root (or on specific files). When given a sub-directory (`dart analyze lib/models`), `dart analyze` doesn't load the plugins configured at the root.

## Rules

Both rules are warnings, enabled by default.

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

## Suppressing

Like any analyzer diagnostic:

```dart
// ignore: easy_validate_wrong_type
@EasyValidate(minLength: 3)
final int age;
```

## Compatibility

Analyzer plugins run inside the Dart analysis server, pinned to the analyzer version of your Dart SDK. This package is released for the current stable SDK; if the plugin doesn't load after a Dart upgrade, update it to the latest version.
