import 'package:caixadagua/models/analise.dart';
import 'package:caixadagua/models/leitura.dart';
import 'package:caixadagua/widgets/cartao_vazamento.dart';
import 'package:caixadagua/widgets/caixa_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Leitura.fromMap', () {
    test('lê os campos gravados pelo ESP32', () {
      final leitura = Leitura.fromMap({
        'status': 'ok',
        'altura_cm': 37.7,
        'litros': 320,
        'percentual': 68,
        'capacidade_litros': 470,
        'timestamp': 1760450000000,
      });

      expect(leitura.sensorOk, isTrue);
      expect(leitura.alturaCm, 37.7);
      expect(leitura.litros, 320);
      expect(leitura.percentual, 68);
      expect(leitura.capacidadeLitros, 470);
      expect(leitura.timestamp, DateTime.fromMillisecondsSinceEpoch(1760450000000));
    });

    test('status de erro do sensor não tem litros', () {
      final leitura = Leitura.fromMap({'status': 'erro_sensor', 'timestamp': 1760450000000});

      expect(leitura.sensorOk, isFalse);
      expect(leitura.litros, isNull);
    });

    test('fica offline após 5 minutos sem atualização', () {
      final ts = DateTime(2026, 10, 14, 12, 0);
      final leitura = Leitura(sensorOk: true, timestamp: ts);

      expect(leitura.estaOnline(ts.add(const Duration(minutes: 4))), isTrue);
      expect(leitura.estaOnline(ts.add(const Duration(minutes: 6))), isFalse);
    });
  });

  test('PontoHistorico.fromMap ignora registros incompletos', () {
    expect(PontoHistorico.fromMap({'litros': 100}), isNull);
    expect(
      PontoHistorico.fromMap({'litros': 100, 'percentual': 21, 'timestamp': 1760450000000})?.litros,
      100,
    );
  });

  testWidgets('CaixaWidget desenha sem erros', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaixaWidget(percentual: 68, centro: Text('68%'))),
      ),
    );
    // A onda anima sem parar, então avança o tempo em vez de pumpAndSettle.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(CaixaWidget), findsOneWidget);
    expect(find.text('68%'), findsOneWidget);
  });

  testWidgets('CartaoVazamento cabe numa tela de 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final noites = [
      for (var i = 0; i < 7; i++)
        AnaliseNoite(
          dia: DateTime(2026, 10, 8 + i),
          resultado: ResultadoNoite.values[i % ResultadoNoite.values.length],
          litrosPorHora: -6,
          perdaLitros: 18,
        ),
    ]..add(
      AnaliseNoite(
        dia: DateTime(2026, 10, 15),
        resultado: ResultadoNoite.vazamento,
        litrosPorHora: -6,
        perdaLitros: 18,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: CartaoVazamento(noites: noites.sublist(1)),
          ),
        ),
      ),
    );

    expect(find.text('Possível vazamento'), findsOneWidget);
    expect(find.textContaining('madrugadas'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
