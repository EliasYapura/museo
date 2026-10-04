// Prueba de humo: verifica que la app arranca y arma la pantalla de misiones
// sin lanzar excepciones.
//
// No se usa pumpAndSettle: la pantalla arranca con un indicador de carga que
// gira para siempre, asi que esperar a que todo se quede quieto no terminaria
// nunca. Con un pump alcanza para que se arme el primer cuadro.

import 'package:flutter_test/flutter_test.dart';

import 'package:exploradores_museo/main.dart';
import 'package:exploradores_museo/pantallas/misiones.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla de misiones',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExploradoresApp());
    await tester.pump();

    expect(find.byType(PantallaMisiones), findsOneWidget);
    expect(find.text('Exploradores del Museo'), findsOneWidget);
  });
}
