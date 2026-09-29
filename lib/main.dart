import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/assists/convert_to_easy_json_model.dart';
import 'src/fixes/add_from_json_factory.dart';
import 'src/fixes/add_serializer_mixin.dart';
import 'src/fixes/remove_inapplicable_rule.dart';
import 'src/rules/easy_convert_wrong_signature.dart';
import 'src/rules/easy_json_missing_mixin.dart';
import 'src/rules/easy_union_mapping_not_subtype.dart';
import 'src/rules/easy_union_missing_factory.dart';
import 'src/rules/easy_validate_wrong_type.dart';

/// Entry point loaded by the Dart analysis server.
final plugin = EasyJsonLintsPlugin();

class EasyJsonLintsPlugin extends Plugin {
  @override
  String get name => 'dart_easy_json_lints';

  @override
  void register(PluginRegistry registry) {
    // Warning rules are on by default: adding the plugin is enough.
    registry
      ..registerWarningRule(EasyValidateWrongType())
      ..registerWarningRule(EasyConvertWrongSignature())
      ..registerWarningRule(EasyUnionMissingFactory())
      ..registerWarningRule(EasyJsonMissingMixin())
      ..registerWarningRule(EasyUnionMappingNotSubtype())
      ..registerFixForRule(
        EasyValidateWrongType.code,
        RemoveInapplicableRule.new,
      )
      ..registerFixForRule(EasyUnionMissingFactory.code, AddFromJsonFactory.new)
      ..registerFixForRule(EasyJsonMissingMixin.code, AddSerializerMixin.new)
      ..registerAssist(ConvertToEasyJsonModel.new);
  }
}
