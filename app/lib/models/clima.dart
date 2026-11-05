import 'package:flutter/material.dart';

/// Tempo atual e previsão de um lugar, vindos da API Open-Meteo.
class Clima {
  final double temperatura;
  final double? sensacao;
  final int? umidade;

  /// Código WMO da condição do tempo (0 = céu limpo, 61 = chuva fraca...).
  final int codigo;
  final bool dia;

  /// Horário da medição, no fuso do lugar.
  final DateTime? horario;

  /// Previsão diária, começando por hoje.
  final List<PrevisaoDia> previsao;

  const Clima({
    required this.temperatura,
    required this.codigo,
    this.sensacao,
    this.umidade,
    this.dia = true,
    this.horario,
    this.previsao = const [],
  });

  /// Lê os blocos `current` e `daily` da resposta da Open-Meteo.
  /// Retorna null se faltar a temperatura atual.
  static Clima? fromOpenMeteo(Map<String, dynamic> json) {
    final atual = json['current'];
    if (atual is! Map) return null;
    final temperatura = atual['temperature_2m'];
    if (temperatura is! num) return null;

    final horario = atual['time'];
    return Clima(
      temperatura: temperatura.toDouble(),
      sensacao: (atual['apparent_temperature'] as num?)?.toDouble(),
      umidade: (atual['relative_humidity_2m'] as num?)?.round(),
      codigo: (atual['weather_code'] as num?)?.toInt() ?? 0,
      dia: atual['is_day'] != 0,
      horario: horario is String ? DateTime.tryParse(horario) : null,
      previsao: PrevisaoDia.listaDeOpenMeteo(json['daily']),
    );
  }

  String get descricao => descricaoTempo(codigo);

  IconData get icone => iconeTempo(codigo, dia: dia);
}

/// Previsão de um dia: máxima, mínima e chuva.
class PrevisaoDia {
  final DateTime data;
  final double maxima;
  final double minima;

  /// Maior probabilidade de chuva do dia, em %.
  final int? chanceChuva;

  /// Chuva prevista no dia, em mm.
  final double? chuvaMm;

  final int codigo;

  const PrevisaoDia({
    required this.data,
    required this.maxima,
    required this.minima,
    required this.codigo,
    this.chanceChuva,
    this.chuvaMm,
  });

  /// O bloco `daily` traz uma lista por campo, todas do mesmo tamanho de `time`.
  /// Dias sem máxima ou mínima são ignorados; os outros campos podem vir null.
  static List<PrevisaoDia> listaDeOpenMeteo(Object? diario) {
    if (diario is! Map) return const [];
    final datas = diario['time'];
    if (datas is! List) return const [];

    T? valor<T>(String campo, int i) {
      final lista = diario[campo];
      if (lista is! List || i >= lista.length) return null;
      final v = lista[i];
      return v is T ? v : null;
    }

    final dias = <PrevisaoDia>[];
    for (var i = 0; i < datas.length; i++) {
      final data = datas[i] is String ? DateTime.tryParse(datas[i] as String) : null;
      final maxima = valor<num>('temperature_2m_max', i);
      final minima = valor<num>('temperature_2m_min', i);
      if (data == null || maxima == null || minima == null) continue;

      dias.add(
        PrevisaoDia(
          data: data,
          maxima: maxima.toDouble(),
          minima: minima.toDouble(),
          codigo: valor<num>('weather_code', i)?.toInt() ?? 0,
          chanceChuva: valor<num>('precipitation_probability_max', i)?.round(),
          chuvaMm: valor<num>('precipitation_sum', i)?.toDouble(),
        ),
      );
    }
    return dias;
  }

  String get descricao => descricaoTempo(codigo);

  IconData get icone => iconeTempo(codigo);
}

String descricaoTempo(int codigo) => switch (codigo) {
  0 => 'Céu limpo',
  1 => 'Poucas nuvens',
  2 => 'Parcialmente nublado',
  3 => 'Nublado',
  45 || 48 => 'Neblina',
  51 || 53 || 55 || 56 || 57 => 'Garoa',
  61 || 66 || 80 => 'Chuva fraca',
  63 || 81 => 'Chuva',
  65 || 67 || 82 => 'Chuva forte',
  71 || 73 || 75 || 77 || 85 || 86 => 'Neve',
  95 => 'Trovoada',
  96 || 99 => 'Trovoada com granizo',
  _ => 'Tempo indefinido',
};

IconData iconeTempo(int codigo, {bool dia = true}) => switch (codigo) {
  0 || 1 => dia ? Icons.wb_sunny_rounded : Icons.nightlight_round,
  2 => dia ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded,
  3 => Icons.cloud_rounded,
  45 || 48 => Icons.foggy,
  >= 51 && <= 67 || >= 80 && <= 82 => Icons.water_drop_rounded,
  >= 71 && <= 77 || 85 || 86 => Icons.ac_unit_rounded,
  >= 95 => Icons.thunderstorm_rounded,
  _ => Icons.cloud_rounded,
};
