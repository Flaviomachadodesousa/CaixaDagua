import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/clima.dart';

/// Tempo atual e previsão no Grajaú (São Paulo, SP) pela API Open-Meteo (gratuita, sem chave).
class ClimaService {
  static const nomeLocal = 'Grajaú, São Paulo';
  static const _latitude = -23.76979;
  static const _longitude = -46.67112;

  /// A Open-Meteo atualiza os dados de `current` a cada 15 minutos.
  static const intervaloAtualizacao = Duration(minutes: 15);

  /// Hoje e os dois dias seguintes.
  static const diasPrevisao = 3;

  final http.Client _cliente;

  ClimaService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  Future<Clima> atual() async {
    final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$_latitude',
      'longitude': '$_longitude',
      'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day',
      'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,'
          'precipitation_sum,weather_code',
      'forecast_days': '$diasPrevisao',
      'timezone': 'America/Sao_Paulo',
    });

    final resposta = await _cliente.get(url).timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) {
      throw Exception('Open-Meteo respondeu ${resposta.statusCode}');
    }

    final clima = Clima.fromOpenMeteo(jsonDecode(resposta.body) as Map<String, dynamic>);
    if (clima == null) throw const FormatException('Resposta da Open-Meteo sem temperatura');
    return clima;
  }

  void fechar() => _cliente.close();
}
