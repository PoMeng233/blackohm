import 'package:blackohm/features/scanner/ingestion_service.dart';
import 'package:blackohm/ui/widgets/exe_decision_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('已入库的 exe 在主程序选择窗口中显示状态', (tester) async {
    final modified = DateTime(2026, 1, 2, 3, 4);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExeDecisionDialog(
            candidates: [
              EnrichedCandidate(
                path: r'G:\Games\Shamrock\Shamrock.exe',
                sizeBytes: 1024,
                modified: modified,
                alreadyAdded: true,
              ),
              EnrichedCandidate(
                path: r'G:\Games\Shamrock\inst.exe',
                sizeBytes: 1024,
                modified: modified,
              ),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Shamrock.exe'), findsOneWidget);
    expect(find.text('inst.exe'), findsOneWidget);
    expect(find.text('已在库中'), findsOneWidget);
  });
}
