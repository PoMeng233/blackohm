import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/game_repository.dart';
import 'package:blackohm/features/scanner/directory_scanner.dart';
import 'package:blackohm/features/scanner/ingestion_service.dart';
import 'package:blackohm/features/scanner/library_scanner.dart';
import 'package:blackohm/ui/theme.dart';
import 'package:blackohm/ui/widgets/library_import_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 说明：测试体运行在 fake-async 中，不能 await 真实文件 IO 或数据库流，
/// 否则 future 永不推进导致挂起。这里直接构造布局数据，只验证预览渲染；
/// 真实导入行为由 test/library_import_test.dart 覆盖。
void main() {
  testWidgets('预览列出每款游戏及其自动选中的主程序', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final service = IngestionService(GameRepository(db));
    addTearDown(db.close);

    final layout = LibraryLayout(
      isLibrary: true,
      truncated: false,
      games: [
        LibraryGameEntry(
          dirPath: r'G:\games\GameA',
          candidates: [
            _candidate(r'G:\games\GameA\GameA.exe'),
            _candidate(r'G:\games\GameA\tool.exe', size: 8 * 1024 * 1024),
          ],
        ),
        LibraryGameEntry(
          dirPath: r'G:\games\GameB',
          candidates: [_candidate(r'G:\games\GameB\GameB.exe')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(
          body: LibraryImportDialog(layout: layout, service: service),
        ),
      ),
    );

    expect(find.text('批量添加游戏库'), findsOneWidget);
    expect(find.textContaining('检测到 2 款游戏'), findsOneWidget);
    expect(find.text('GameA'), findsOneWidget);
    expect(find.text('GameB'), findsOneWidget);
    // 多候选游戏自动采用评分最高的主程序，并标记待复核。
    expect(find.text('GameA.exe'), findsOneWidget);
    expect(find.text('多候选'), findsOneWidget);
    expect(find.text('开始添加'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}

ExeCandidate _candidate(String path, {int size = 1024}) {
  final dirPath = path.substring(0, path.lastIndexOf(RegExp(r'[\\/]')));
  return ExeCandidate(
    path: path,
    dirPath: dirPath,
    sizeBytes: size,
    modified: DateTime(2026, 1, 1),
  );
}
