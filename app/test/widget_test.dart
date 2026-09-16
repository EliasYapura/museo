// Prueba de humo: verifica que la app arranca y arma la pantalla principal
// sin lanzar excepciones. No valida contenido todavia; la app es una maqueta
// visual y las pruebas funcionales llegan con las historias del visitante.

import 'package:flutter_test/flutter_test.dart';

import 'package:exploradores_museo/main.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla principal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExploradoresApp());

    expect(find.byType(PantallaPrincipal), findsOneWidget);
  });
}
