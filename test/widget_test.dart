import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_trimmer/src/app.dart';
import 'package:video_trimmer/src/start_end_row.dart';
import 'package:video_trimmer/src/video_session.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('app shows the open prompt when nothing is open', (tester) async {
    final session = VideoSession(initOnConstruct: false);
    addTearDown(session.dispose);

    await tester.pumpWidget(VideoTrimmerApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('Video Trimmer'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.text('Trim'), findsNothing);
  });

  testWidgets('trim button is disabled until a valid selection exists',
      (tester) async {
    final session = VideoSession(initOnConstruct: false);
    addTearDown(session.dispose);

    session.setStartText('not a time');
    session.setEndText('0:00:05');

    await tester.pumpWidget(
      _wrap(StartEndRow(session: session, onRequestTrim: () {})),
    );
    await tester.pumpAndSettle();

    var trimButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Trim'));
    expect(trimButton.onPressed, isNull);

    session.setStartText('0:00:01');
    await tester.pump();

    trimButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Trim'));
    expect(trimButton.onPressed, isNotNull);
  });
}
