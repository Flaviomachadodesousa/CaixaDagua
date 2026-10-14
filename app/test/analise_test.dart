import 'package:caixadagua/models/analise.dart';
import 'package:caixadagua/models/leitura.dart';
import 'package:flutter_test/flutter_test.dart';

/// Série com um ponto a cada 15 min a partir de [inicio].
List<PontoHistorico> serie(DateTime inicio, List<int> litros) => [
  for (var i = 0; i < litros.length; i++)
    PontoHistorico(
      timestamp: inicio.add(Duration(minutes: 15 * i)),
      litros: litros[i],
      percentual: litros[i] * 100 ~/ 470,
    ),
];

void main() {
  final inicio = DateTime(2026, 10, 14, 12);

  group('consumoLitros', () {
    test('ignora o ruído do sensor', () {
      expect(consumoLitros(serie(inicio, [400, 404, 397, 402, 396, 401, 399])), 0);
    });

    test('conta o consumo contínuo', () {
      expect(consumoLitros(serie(inicio, [400, 380, 360, 340, 320, 300])), 100);
    });

    test('não conta o reabastecimento', () {
      // gasta 50, enche 100, gasta 50
      expect(consumoLitros(serie(inicio, [400, 350, 350, 450, 450, 400, 400])), 100);
    });

    test('acumula consumo lento menor que o limiar por ponto', () {
      final litros = [for (var i = 0; i <= 10; i++) 400 - 3 * i]; // −30 L em 2,5 h
      expect(consumoLitros(serie(inicio, litros)), inInclusiveRange(20, 30));
    });

    test('remove pico isolado', () {
      // Um eco ruim de −60 L não é consumo
      expect(consumoLitros(serie(inicio, [400, 400, 340, 400, 400])), 0);
    });
  });

  group('analisarMadrugadas', () {
    final madrugada = DateTime(2026, 10, 14, horaInicioMadrugada);
    final agora = DateTime(2026, 10, 14, 12);
    // 2h às 5h = 13 pontos
    List<int> pontosMadrugada(int Function(int i) litros) => [
      for (var i = 0; i < 13; i++) litros(i),
    ];

    test('nível estável não é vazamento', () {
      final pontos = serie(madrugada, pontosMadrugada((i) => 400 + (i.isEven ? 3 : -3)));
      final noite = analisarMadrugadas(pontos, agora).last;

      expect(noite.dia, DateTime(2026, 10, 14));
      expect(noite.resultado, ResultadoNoite.ok);
    });

    test('queda contínua de 6 L/h é vazamento', () {
      // 1,5 L a cada 15 min = 6 L/h
      final pontos = serie(madrugada, pontosMadrugada((i) => (400 - 1.5 * i).round()));
      final noite = analisarMadrugadas(pontos, agora).last;

      expect(noite.resultado, ResultadoNoite.vazamento);
      expect(noite.litrosPorHora, closeTo(-6, 0.5));
      expect(noite.perdaLitros, closeTo(18, 2));
    });

    test('entrada de água torna a noite inconclusiva', () {
      final pontos = serie(madrugada, pontosMadrugada((i) => 300 + 15 * i));
      expect(analisarMadrugadas(pontos, agora).last.resultado, ResultadoNoite.reabastecendo);
    });

    test('poucos pontos = sem dados', () {
      final pontos = serie(madrugada, [400, 400, 400]);
      expect(analisarMadrugadas(pontos, agora).last.resultado, ResultadoNoite.semDados);
    });

    test('não analisa a madrugada que ainda não terminou', () {
      final noites = analisarMadrugadas([], DateTime(2026, 10, 14, 3));
      expect(noites.last.dia, DateTime(2026, 10, 13));
      expect(noites, hasLength(7));
    });
  });
}
