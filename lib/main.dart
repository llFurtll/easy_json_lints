import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/easy_convert_wrong_signature.dart';
import 'src/rules/easy_validate_wrong_type.dart';

/// Entry point loaded by the Dart analysis server.
final plugin = EasyJsonLintsPlugin();

class EasyJsonLintsPlugin extends Plugin {
  @override
  String get name => 'dart_easy_json_lints';

  @override
  void register(PluginRegistry registry) {
    // Warning rules are on by default: adding the plugin is enough.
    registry.registerWarningRule(EasyValidateWrongType());
    registry.registerWarningRule(EasyConvertWrongSignature());
  }
}
