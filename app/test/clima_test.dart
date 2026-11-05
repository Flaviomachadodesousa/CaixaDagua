import 'dart:convert';

import 'package:caixadagua/models/clima.dart';
import 'package:caixadagua/services/clima_service.dart';
import 'package:caixadagua/theme.dart';
import 'package:caixadagua/widgets/cartao_clima.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Resposta real da Open-Meteo, resumida.
const respostaOpenMeteo = {
  'latitude': -23.796133,
  'longitude': -46.712494,
  'current': {
    'time': '2026-11-05T10:15',
    'interval': 900,
    'temperature_2m': 21.4,
    'apparent_temperature': 23.5,
    'relative_humidity_2m': 95,
    'weather_code': 3,
    'is_day': 1,
  },
  'daily': {
    'time': ['2026-11-05', '2026-11-06', '2026-11-07'],
    'temperature_2m_max': [26.2, 22.1, 28.8],
    'temperature_2m_min': [18.4, 16.0, 17.6],
    'precipitation_probability_max': [96, 65, 78],
    'precipitation_sum': [9.8, 1.2, 0.0],
    'weather_code': [63, 61, 2],
  },
};

void main() {
  group('Clima.fromOpenMeteo', () {
    test('lê o bloco current', () {
      final clima = Clima.fromOpenMeteo(respostaOpenMeteo)!;

      expect(clima.temperatura, 21.4);
      expect(clima.sensacao, 23.5);
      expect(clima.umidade, 95);
      expect(clima.codigo, 3);
      expect(clima.dia, isTrue);
      expect(clima.horario, DateTime(2026, 11, 5, 10, 15));
      expect(clima.descricao, 'Nublado');
    });

    test('lê a previsão diária', () {
      final previsao = Clima.fromOpenMeteo(respostaOpenMeteo)!.previsao;

      expect(previsao, hasLength(3));
      expect(previsao.first.data, DateTime(2026, 11, 5));
      expect(previsao.first.maxima, 26.2);
      expect(previsao.first.minima, 18.4);
      expect(previsao.first.chanceChuva, 96);
      expect(previsao.first.chuvaMm, 9.8);
      expect(previsao.first.descricao, 'Chuva');
      expect(previsao.last.chuvaMm, 0.0);
    });

    test('ignora dia sem máxima e aceita chuva nula', () {
      final previsao = PrevisaoDia.listaDeOpenMeteo({
        'time': ['2026-11-05', '2026-11-06'],
        'temperature_2m_max': [null, 22.1],
        'temperature_2m_min': [18.4, 16.0],
        'precipitation_probability_max': [96, null],
      });

      expect(previsao, hasLength(1));
      expect(previsao.single.data, DateTime(2026, 11, 6));
      expect(previsao.single.chanceChuva, isNull);
      expect(previsao.single.chuvaMm, isNull);
    });

    test('sem bloco daily a previsão fica vazia', () {
      final json = Map<String, dynamic>.of(respostaOpenMeteo)..remove('daily');
      expect(Clima.fromOpenMeteo(json)!.previsao, isEmpty);
    });

    test('sem temperatura retorna null', () {
      expect(Clima.fromOpenMeteo({'current': {'weather_code': 0}}), isNull);
      expect(Clima.fromOpenMeteo({}), isNull);
    });

    test('noite de céu limpo usa ícone de lua', () {
      const clima = Clima(temperatura: 18, codigo: 0, dia: false);
      expect(clima.icone, Icons.nightlight_round);
    });
  });

  group('ClimaService', () {
    test('consulta as coordenadas do Grajaú', () async {
      late Uri chamada;
      final service = ClimaService(
        cliente: MockClient((requisicao) async {
          chamada = requisicao.url;
          return http.Response(jsonEncode(respostaOpenMeteo), 200);
        }),
      );

      final clima = await service.atual();

      expect(clima.temperatura, 21.4);
      expect(chamada.host, 'api.open-meteo.com');
      expect(chamada.queryParameters['latitude'], '-23.76979');
      expect(chamada.queryParameters['longitude'], '-46.67112');
      expect(chamada.queryParameters['daily'], contains('precipitation_probability_max'));
      expect(chamada.queryParameters['forecast_days'], '3');
      expect(clima.previsao, hasLength(3));
    });

    test('erro HTTP vira exceção', () async {
      final service = ClimaService(cliente: MockClient((_) async => http.Response('', 500)));
      expect(service.atual(), throwsException);
    });
  });

  group('CartaoClima', () {
    Future<void> montar(WidgetTester tester, http.Client cliente) async {
      await initializeDateFormatting('pt_BR');
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: construirTema(Brightness.light),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: CartaoClima(service: ClimaService(cliente: cliente)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('mostra a temperatura e cabe numa tela de 360 px', (tester) async {
      final resposta = jsonDecode(jsonEncode(respostaOpenMeteo)) as Map<String, dynamic>;
      (resposta['current'] as Map)['weather_code'] = 99; // descrição mais longa
      await montar(tester, MockClient((_) async => http.Response(jsonEncode(resposta), 200)));

      expect(find.text('21°C'), findsOneWidget);
      expect(find.text('Trovoada com granizo'), findsOneWidget);
      expect(find.text('sensação 24° · umidade 95%'), findsOneWidget);
      // Hora da busca, não a do dado (10:15 na resposta)
      expect(find.textContaining('Grajaú, São Paulo · atualizado às'), findsOneWidget);
      expect(find.textContaining('10:15'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mostra a previsão de 3 dias com chuva', (tester) async {
      await montar(
        tester,
        MockClient((_) async => http.Response(jsonEncode(respostaOpenMeteo), 200)),
      );

      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Amanhã'), findsOneWidget);
      expect(find.text('Sáb'), findsOneWidget); // 07/11/2026
      expect(find.text('26° / 18°', findRichText: true), findsOneWidget);
      expect(find.text('96%'), findsOneWidget);
      expect(find.text('9,8 mm'), findsOneWidget);
      // Dia sem chuva não mostra "0,0 mm"
      expect(find.text('0,0 mm'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mostra aviso quando a API falha', (tester) async {
      await montar(tester, MockClient((_) async => http.Response('', 503)));

      expect(find.text('Não foi possível obter o tempo agora.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
