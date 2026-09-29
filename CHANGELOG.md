## 0.1.0

*   Initial release, for Dart 3.10+ analyzer plugins.
*   `easy_validate_wrong_type`: flags `@EasyValidate` rules used on a field type they don't apply to (they were silently ignored by the generator).
*   `easy_convert_wrong_signature`: flags `@EasyConvert` (`fromJson`, `toJson`, `valueFromJson`, `valueToJson`) and `@EasyValidate(custom:)` functions whose signature doesn't fit the annotated field.
