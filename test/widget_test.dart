import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travesias_conecta/widgets/travesias_app.dart';
import 'package:travesias_conecta/services/app_state.dart';

void main() {
  testWidgets('Abre Travesías Conecta sin inicio de sesión externo', (tester) async {
    final state = AppState(autoLoad: false);
    await tester.pumpWidget(TravesiasApp(state: state));
    await tester.pump();
    expect(find.text('Oficios y trabajadores'), findsOneWidget);
    expect(find.textContaining('iniciar sesión'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
