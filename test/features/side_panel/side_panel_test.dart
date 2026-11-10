import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  forBothModes('the icon bar switches panes and closes', (tester, mode) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sidePanelProvider('c1').notifier).openPane(PanelPane.plan);
    tester.view
      ..physicalSize = desktop
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: kSidePanelWidth,
                child: SidePanel(chatKey: 'c1'),
              ),
            ),
          ),
        ),
      ),
    );

    // The active tab shows its name; the others are icons with a tooltip.
    expect(find.text('Plan'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Map'));
    await tester.pump();
    expect(container.read(sidePanelProvider('c1')).pane, PanelPane.map);

    await tester.tap(find.byTooltip('Close panel'));
    await tester.pump();
    expect(container.read(sidePanelProvider('c1')).open, isFalse);
  });

  testWidgets('the phone sheet shows the same panel and Close pops it', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(onPressed: () => showSidePanelSheet(context, 'c1'), child: const Text('Open')),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(SidePanel), findsOneWidget);
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    expect(find.byType(SidePanel), findsNothing);
  });
}
