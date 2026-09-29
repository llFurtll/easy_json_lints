import 'package:analysis_server_plugin/edit/assist/assist.dart';
import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../fixes/add_serializer_mixin.dart';
import '../rules/easy_json_missing_mixin.dart';
import '../rules/easy_union_missing_factory.dart';

const _easyJsonUri = 'package:dart_easy_json/easy_json.dart';

/// Assist on a class name: turns a plain class into an `@EasyJson` model —
/// the imports (package and `.easy.dart`), the annotation, the serializer
/// mixin, a named-parameter constructor (only if the class has none) and a
/// `fromJson` factory.
class ConvertToEasyJsonModel extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dart_easy_json_lints.assist.convertToEasyJsonModel',
    30,
    'Convert to @EasyJson model',
  );

  ConvertToEasyJsonModel({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final decl = node is ClassDeclaration
        ? node as ClassDeclaration
        : node.parent is ClassDeclaration
        ? node.parent as ClassDeclaration
        : null;
    final body = decl?.body;
    if (decl == null || body is! BlockClassBody) return;

    // Só no nome da classe, para não poluir o menu no corpo inteiro.
    final nameToken = decl.namePart.typeName;
    if (selectionOffset < nameToken.offset || selectionOffset > nameToken.end) {
      return;
    }
    // ponytail: classes genéricas, abstratas e sealed (unions) ficam de fora;
    // elas pedem conversores ou @EasyUnion. Incluir quando alguém pedir.
    if (decl.namePart.typeParameters != null ||
        decl.abstractKeyword != null ||
        decl.sealedKeyword != null ||
        decl.metadata.any((a) => a.name.name == 'EasyJson')) {
      return;
    }

    final name = nameToken.lexeme;
    final members = body.members;
    final fields = [
      for (final m in members)
        if (m is FieldDeclaration && !m.isStatic) ...m.fields.variables,
    ];

    // Construtor com parâmetros nomeados (é o que o código gerado chama),
    // só se não houver nenhum construtor.
    final hasCtor = members.any((m) => m is ConstructorDeclaration);
    final params = [
      for (final f in fields)
        if (f.initializer == null)
          _isNullable(f)
              ? 'this.${f.name.lexeme}'
              : 'required this.${f.name.lexeme}',
    ];
    final ctor = params.isEmpty ? '$name();' : '$name({${params.join(', ')}});';
    final hasFromJson = members.any(
      (m) => m is ConstructorDeclaration && m.name?.lexeme == 'fromJson',
    );
    final factory =
        'factory $name.fromJson(Map<String, dynamic> json) => '
        '${lcFirst(name)}FromJson(json);';
    final additions = [if (!hasCtor) ctor, if (!hasFromJson) factory];

    final imports = _missingImports();
    final unit = unitResult.unit;
    final content = unitResult.content;
    // Mantém o fim de linha do arquivo (CRLF no Windows).
    final nl = content.contains('\r\n') ? '\r\n' : '\n';

    await builder.addDartFileEdit(file, (builder) {
      if (imports.isNotEmpty) {
        final lines = imports.map((u) => "import '$u';").join(nl);
        final last = unit.directives.whereType<ImportDirective>().lastOrNull;
        if (last != null) {
          builder.addSimpleInsertion(last.end, '$nl$lines');
        } else {
          final first = unit.directives.firstOrNull;
          // Depois de `library`, se houver; senão, no topo do arquivo.
          builder.addSimpleInsertion(
            first is LibraryDirective ? first.end : 0,
            first is LibraryDirective ? '$nl$nl$lines' : '$lines$nl$nl',
          );
        }
      }

      builder.addSimpleInsertion(
        decl.firstTokenAfterCommentAndMetadata.offset,
        '@EasyJson()$nl',
      );

      final (offset, text) = mixinInsertion(decl, serializerName(name));
      builder.addSimpleInsertion(offset, text);

      if (additions.isNotEmpty) {
        // `}` sozinho na linha: insere acima dele; senão (`{}`), quebra antes.
        final close = body.rightBracket.offset;
        final lineStart = content.lastIndexOf('\n', close - 1) + 1;
        final onOwnLine = content.substring(lineStart, close).trim().isEmpty;
        final text = additions.map((a) => '  $a$nl').join();
        builder.addSimpleInsertion(close, onOwnLine ? text : '$nl$text');
      }
    });
  }

  /// `package:dart_easy_json/easy_json.dart` e `<arquivo>.easy.dart`, se
  /// ainda não importados.
  List<String> _missingImports() {
    final uris = {
      for (final d in unitResult.unit.directives.whereType<ImportDirective>())
        d.uri.stringValue,
    };
    final base = file.replaceAll(r'\', '/').split('/').last;
    final generated =
        '${base.substring(0, base.length - '.dart'.length)}.easy.dart';
    return [
      if (!uris.contains(_easyJsonUri)) _easyJsonUri,
      if (!uris.any((u) => u != null && u.endsWith(generated))) generated,
    ];
  }

  static bool _isNullable(VariableDeclaration v) {
    final type = (v.parent as VariableDeclarationList).type;
    return type == null || type.question != null;
  }
}
