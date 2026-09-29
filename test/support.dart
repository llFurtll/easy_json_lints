import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

/// Cópia mínima das anotações do dart_easy_json, no pacote falso de teste.
const easyJsonStub = r'''
enum EasyFormat { email, url, uuid }

class EasyJson {
  final bool fromJson;
  final bool toJson;
  final bool strict;
  const EasyJson({this.fromJson = true, this.toJson = true, this.strict = false});
}

class EasyUnion {
  final String discriminator;
  final Map<String, Type> mapping;
  final Type? fallback;
  const EasyUnion({required this.discriminator, required this.mapping, this.fallback});
}

class EasyValidate {
  final int? minLength;
  final int? maxLength;
  final String? regex;
  final num? min;
  final num? max;
  final EasyFormat? format;
  final bool? past;
  final bool? future;
  final Function? custom;
  const EasyValidate({this.minLength, this.maxLength, this.regex, this.min,
      this.max, this.format, this.past, this.future, this.custom});
}

class EasyConvert {
  final Function? fromJson;
  final Function? toJson;
  final Function? valueFromJson;
  final Function? valueToJson;
  const EasyConvert({this.fromJson, this.toJson, this.valueFromJson,
      this.valueToJson});
}
''';

const easyImport = "import 'package:dart_easy_json/easy_json.dart';\n";

typedef FixGenerator =
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    });

abstract class EasyJsonRuleTest extends AnalysisRuleTest {
  /// Registra o pacote falso `dart_easy_json`. Tem de ser chamado antes de
  /// `super.setUp()`, que grava o package_config.
  void addEasyJson() =>
      newPackage('dart_easy_json').addFile('lib/easy_json.dart', easyJsonStub);

  /// Espera um aviso exatamente sobre [snippet] dentro de [code].
  // O tipo (ExpectedDiagnostic) não é exportado publicamente pelo
  // analyzer_testing, então fica implícito.
  dynamic lintOn(String code, String snippet, {String? message}) {
    final offset = code.indexOf(snippet);
    assert(offset >= 0, 'snippet not found: $snippet');
    return lint(offset, snippet.length, messageContainsAll: [?message]);
  }

  /// Aplica a correção [fix] ao primeiro aviso com [code] do último arquivo
  /// analisado (via assertDiagnostics) e devolve o código resultante.
  ///
  /// O analysis_server_plugin não tem kit de teste de fixes; isto repete o
  /// que o servidor faz (fix_processor): contexto a partir do resultado
  /// resolvido, `compute` num ChangeBuilder e aplicação das edições.
  Future<String> applyFix(DiagnosticCode code, FixGenerator fix) async {
    final diagnostic = result.diagnostics.firstWhere(
      (d) => d.diagnosticCode == code,
    );
    final library =
        await result.session.getResolvedLibrary(result.path)
            as ResolvedLibraryResult;
    final producer = fix(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: result,
        diagnostic: diagnostic,
        selectionOffset: diagnostic.offset,
        selectionLength: diagnostic.length,
      ),
    );
    return _apply(producer);
  }

  /// Aplica o assist [assist] com o cursor no início de [at] (no último
  /// arquivo analisado) e devolve o código resultante — igual ao código
  /// original se o assist não se aplica ali.
  Future<String> applyAssist(FixGenerator assist, String at) async {
    final offset = result.content.indexOf(at);
    assert(offset >= 0, 'snippet not found: $at');
    final library =
        await result.session.getResolvedLibrary(result.path)
            as ResolvedLibraryResult;
    return _apply(
      assist(
        context: CorrectionProducerContext.createResolved(
          libraryResult: library,
          unitResult: result,
          selectionOffset: offset,
        ),
      ),
    );
  }

  Future<String> _apply(ResolvedCorrectionProducer producer) async {
    final builder = ChangeBuilder(session: result.session);
    await producer.compute(builder);

    final edits = [for (final file in builder.sourceChange.edits) ...file.edits]
      ..sort((a, b) => b.offset.compareTo(a.offset));
    var out = result.content;
    for (final e in edits) {
      out = out.replaceRange(e.offset, e.offset + e.length, e.replacement);
    }
    return out;
  }
}
