# Example

`analysis_options.yaml` at the root of your package:

```yaml
plugins:
  dart_easy_json_lints: ^0.1.0
```

A model with mistakes the plugin reports (`dart analyze` output shown below it):

```dart
import 'package:dart_easy_json/easy_json.dart';

class Conv {
  static String fromJson(Object? v) => '$v';
  static int toJson(int v) => v;
}

bool isShort(String v) => v.length < 3;

@EasyJson()
class LintDemo {
  @EasyValidate(minLength: 3)
  final int age;

  @EasyValidate(past: true)
  final String name;

  @EasyConvert(fromJson: Conv.fromJson, toJson: Conv.toJson)
  final DateTime createdAt;

  @EasyValidate(custom: isShort)
  final int code;

  LintDemo(this.age, this.name, this.createdAt, this.code);
}
```

```text
warning - 'minLength' doesn't apply to 'int' fields, so it is ignored. - easy_validate_wrong_type
warning - 'past' doesn't apply to 'String' fields, so it is ignored. - easy_validate_wrong_type
warning - The fromJson function 'Conv.fromJson' doesn't fit field 'createdAt': it returns 'String', but the value is 'DateTime'. - easy_convert_wrong_signature
warning - The toJson function 'Conv.toJson' doesn't fit field 'createdAt': it takes 'int', but the value is 'DateTime'. - easy_convert_wrong_signature
warning - The custom function 'isShort' doesn't fit field 'code': it takes 'String', but the value is 'int'. - easy_convert_wrong_signature
```
