import 'package:flutter_test/flutter_test.dart';
import 'package:app/app.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/chat_provider.dart';

void main() {
  testWidgets('SecureChatApp renders splash screen', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
        ],
        child: const SecureChatApp(),
      ),
    );

    expect(find.text('SecureChat'), findsOneWidget);
    expect(find.text('End-to-End Encrypted'), findsOneWidget);
  });
}
