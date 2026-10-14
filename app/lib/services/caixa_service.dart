import 'package:firebase_database/firebase_database.dart';

import '../models/leitura.dart';

class CaixaService {
  final DatabaseReference _raiz = FirebaseDatabase.instance.ref('caixadagua');

  /// Leitura atual, atualizada em tempo real.
  Stream<Leitura?> atual() {
    return _raiz.child('atual').onValue.map((event) {
      final valor = event.snapshot.value;
      return valor is Map ? Leitura.fromMap(valor) : null;
    });
  }

  /// Histórico a partir de [desde], em ordem cronológica.
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
