import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/splash_screen.dart';
import 'package:nine_fuse/main.dart';

void main() {
  testWidgets('abre em SplashScreen, não direto em LevelSelectScreen',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NineFuseApp()),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LevelSelectScreen), findsNothing);
  });
}
