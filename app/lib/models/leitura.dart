/// Leitura atual da caixa, gravada pelo ESP32 em /caixadagua/atual.
class Leitura {
  final bool sensorOk;
  final double? alturaCm;
  final int? litros;
  final int? percentual;
  final int? capacidadeLitros;
  final DateTime? timestamp;

  const Leitura({
    required this.sensorOk,
    this.alturaCm,
    this.litros,
    this.percentual,
    this.capacidadeLitros,
    this.timestamp,
  });

  factory Leitura.fromMap(Map<dynamic, dynamic> map) {
    final ts = map['timestamp'];
    return Leitura(
      sensorOk: map['status'] == 'ok',
      alturaCm: (map['altura_cm'] as num?)?.toDouble(),
      litros: (map['litros'] as num?)?.toInt(),
      percentual: (map['percentual'] as num?)?.toInt(),
      capacidadeLitros: (map['capacidade_litros'] as num?)?.toInt(),
      timestamp: ts is num ? DateTime.fromMillisecondsSinceEpoch(ts.toInt()) : null,
    );
  }

  /// O ESP32 envia a cada 1 minuto; sem notícias por mais de 5 min = offline.
  bool estaOnline(DateTime agora) =>
      timestamp != null && agora.difference(timestamp!) < const Duration(minutes: 5);
}

/// Ponto do histórico, gravado em /caixadagua/historico a cada 15 minutos.
class PontoHistorico {
  final DateTime timestamp;
  final int litros;
  final int percentual;

  const PontoHistorico({
    required this.timestamp,
    required this.litros,
    required this.percentual,
  });

  static PontoHistorico? fromMap(Map<dynamic, dynamic> map) {
    final ts = map['timestamp'];
    final litros = map['litros'];
    final percentual = map['percentual'];
    if (ts is! num || litros is! num || percentual is! num) return null;

    return PontoHistorico(
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts.toInt()),
      litros: litros.toInt(),
      percentual: percentual.toInt(),
    );
  }
}
