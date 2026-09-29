## 0.2.0

*   **New rule** `easy_json_missing_mixin`: an `@EasyJson` class without `with XSerializer` (it has no `toJson()`, so models containing it don't compile). Quick fix: add the mixin, with the class's type parameters.
*   **New rule** `easy_union_missing_factory`: an `@EasyUnion` mapped class without `factory X.fromJson`, which the generated union code calls. Quick fix: add the factory.
*   **New rule** `easy_union_mapping_not_subtype`: an `@EasyUnion` mapping to a class that doesn't extend or implement the union.
*   **Quick fix** for `easy_validate_wrong_type`: remove the rule (or the whole annotation when it's the only one). The warning is now reported on the offending argument (`minLength: 3`) instead of the whole annotation.

## 0.1.0

*   Initial release, for Dart 3.10+ analyzer plugins.
*   `easy_validate_wrong_type`: flags `@EasyValidate` rules used on a field type they don't apply to (they were silently ignored by the generator).
*   `easy_convert_wrong_signature`: flags `@EasyConvert` (`fromJson`, `toJson`, `valueFromJson`, `valueToJson`) and `@EasyValidate(custom:)` functions whose signature doesn't fit the annotated field.
