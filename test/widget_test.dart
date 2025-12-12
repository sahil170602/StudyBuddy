import 'package:flutter_test/flutter_test.dart';
import 'package:studybuddy/main.dart';

void main() {
  testWidgets('StudyBuddyApp builds', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const StudyBuddyApp());

    // Basic sanity check: app title text is present somewhere.
    expect(find.text('StudyBuddy'), findsWidgets);
  });
}
