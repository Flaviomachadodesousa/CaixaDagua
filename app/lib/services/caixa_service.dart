import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';

import '../models/leitura.dart';

/// Modo demonstração: `flutter run --dart-define=DEMO=true`.
/// Usa dados simulados e pula o login.
const modoDemo = bool.fromEnvironment('DEMO');

abstract class CaixaService {
  factory CaixaService() => modoDemo ? _DemoCaixaService() : _FirebaseCaixaService();

  /// Leitura atual, atualizada em tempo real.
  Stream<Leitura?> atual();

  /// Histórico a partir de [desde], em ordem cronológica.
  Stream<List<PontoHistorico>> historico(DateTime desde);
}

class _FirebaseCaixaService implements CaixaService {
  final DatabaseReference _raiz = FirebaseDatabase.instance.ref('caixadagua');

  @override
  Stream<Leitura?> atual() {
    return _raiz.child('atual').onValue.map((event) {
      final valor = event.snapshot.value;
      return valor is Map ? Leitura.fromMap(valor) : null;
    });
  }

  @override
  Stream<List<PontoHistorico>> historico(DateTime desde) {
    return _raiz
        .child('historico')
        .orderByChild('timestamp')
        .startAt(desde.millisecondsSinceEpoch)
        .onValue
        .map((event) {
          final pontos = <PontoHistorico>[];
          for (final filho in event.snapshot.children) {
            final valor = filho.value;
            if (valor is! Map) continue;
            final ponto = PontoHistorico.fromMap(valor);
            if (ponto != null) pontos.add(ponto);
          }
          pontos.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return pontos;
        });
  }
}

/// Simula 7 dias de uso: consumo durante o dia, água da rua no fim da manhã,
/// ruído do sensor e um vazamento nas duas últimas madrugadas.
class _DemoCaixaService implements CaixaService {
  static const _capacidade = 470;
  late final List<PontoHistorico> _pontos = _simular();

  List<PontoHistorico> _simular() {
    final agora = DateTime.now();
    final inicioVazamento = agora.subtract(const Duration(days: 2));
    final aleatorio = math.Random(42);
    var instante = agora.subtract(const Duration(days: 7));
    var litros = 440.0;
    final pontos = <PontoHistorico>[];

    while (instante.isBefore(agora)) {
      final hora = instante.hour;
      var consumo = switch (hora) {
        >= 6 && < 9 => 10.0,
        >= 18 && < 22 => 7.0,
        >= 9 && < 18 => 5.0,
        _ => 0.0,
      };
      if (instante.isAfter(inicioVazamento)) consumo += 1.5; // 6 L/h
      final reabastecimento = (hora >= 10 && hora < 13) ? 50.0 : 0.0;
      litros = (litros - consumo + reabastecimento).clamp(40, _capacidade.toDouble());

      final medido = (litros + (aleatorio.nextDouble() - 0.5) * 8).round();
      pontos.add(
        PontoHistorico(
          timestamp: instante,
          litros: medido,
          percentual: (medido / _capacidade * 100).round(),
        ),
      );
      instante = instante.add(const Duration(minutes: 15));
    }
    return pontos;
  }

  @override
  Stream<Leitura?> atual() {
    final ultimo = _pontos.last;
    return Stream.value(
      Leitura(
        sensorOk: true,
        alturaCm: ultimo.percentual / 100 * 52,
        litros: ultimo.litros,
        percentual: ultimo.percentual,
        capacidadeLitros: _capacidade,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
  }

  @override
  Stream<List<PontoHistorico>> historico(DateTime desde) {
    return Stream.value(_pontos.where((p) => p.timestamp.isAfter(desde)).toList());
  }
}
