import 'leitura.dart';

/// Variação mínima considerada real. Na Fortlev 500 L, 1 cm de altura ≈ 9 L,
/// e o JSN-SR04T oscila cerca de ±0,5–1 cm entre leituras.
const limiarRuidoLitros = 10;

/// Mediana móvel de 3 pontos: remove leituras isoladas fora da curva
/// (eco ruim, onda na superfície) sem atrasar as mudanças reais.
List<PontoHistorico> suavizar(List<PontoHistorico> pontos) {
  if (pontos.length < 3) return pontos;

  return [
    pontos.first,
    for (var i = 1; i < pontos.length - 1; i++)
      PontoHistorico(
        timestamp: pontos[i].timestamp,
        litros: _mediana(pontos[i - 1].litros, pontos[i].litros, pontos[i + 1].litros),
        percentual: _mediana(
          pontos[i - 1].percentual,
          pontos[i].percentual,
          pontos[i + 1].percentual,
        ),
      ),
    pontos.last,
  ];
}

int _mediana(int a, int b, int c) => ([a, b, c]..sort())[1];

/// Litros gastos na série.
///
/// Usa uma "zona morta": só conta uma queda quando o volume fica pelo menos
/// [limiar] litros abaixo da última referência. Oscilações menores são
/// ruído do sensor. Subidas são reabastecimento e não entram na conta.
///
/// Limitação: se a água da rua estiver entrando enquanto se consome, a boia
/// repõe o volume e esse consumo não aparece no nível.
int consumoLitros(List<PontoHistorico> pontos, {int limiar = limiarRuidoLitros}) {
  final serie = suavizar(pontos);
  if (serie.length < 2) return 0;

  var referencia = serie.first.litros;
  var total = 0;
  for (final ponto in serie.skip(1)) {
    final queda = referencia - ponto.litros;
    if (queda >= limiar) {
      total += queda;
      referencia = ponto.litros;
    } else if (-queda >= limiar) {
      referencia = ponto.litros;
    }
  }
  return total;
}

// ================================================================================
// --- Vazamento na madrugada ---

enum ResultadoNoite {
  /// Nível estável: sem sinal de vazamento.
  ok,

  /// O nível caiu num horário em que ninguém costuma usar água.
  vazamento,

  /// Entrou água da rua: não dá para avaliar.
  reabastecendo,

  /// Poucos pontos no histórico nessa madrugada.
  semDados,
}

class AnaliseNoite {
  /// Dia da madrugada analisada (00:00).
  final DateTime dia;
  final ResultadoNoite resultado;

  /// Tendência do volume em L/h (negativo = perdendo água).
  final double litrosPorHora;

  /// Litros perdidos na janela, pela tendência.
  final int perdaLitros;

  const AnaliseNoite({
    required this.dia,
    required this.resultado,
    this.litrosPorHora = 0,
    this.perdaLitros = 0,
  });
}

const horaInicioMadrugada = 2;
const horaFimMadrugada = 5;

/// Perda mínima (L/h) para considerar vazamento. 3 L/h ≈ 1 cm em 3 horas.
const limiarVazamentoLitrosPorHora = 3.0;

/// Analisa as madrugadas completas (2h–5h) das últimas [noites] noites, da mais
/// antiga para a mais recente.
///
/// Limitação: com a caixa cheia e água da rua disponível, a boia repõe o que
/// vaza e o nível não cai, então o vazamento não aparece.
List<AnaliseNoite> analisarMadrugadas(
  List<PontoHistorico> pontos,
  DateTime agora, {
  int noites = 7,
}) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final resultados = <AnaliseNoite>[];

  for (var n = noites; n >= 0; n--) {
    final dia = DateTime(hoje.year, hoje.month, hoje.day - n);
    final inicio = dia.add(const Duration(hours: horaInicioMadrugada));
    final fim = dia.add(const Duration(hours: horaFimMadrugada));
    if (fim.isAfter(agora)) continue;

    final janela = pontos
        .where((p) => !p.timestamp.isBefore(inicio) && !p.timestamp.isAfter(fim))
        .toList();
    resultados.add(_analisarJanela(dia, suavizar(janela)));
  }

  return resultados.length > noites ? resultados.sublist(resultados.length - noites) : resultados;
}

AnaliseNoite _analisarJanela(DateTime dia, List<PontoHistorico> janela) {
  // Com um ponto a cada 15 min, 3 h têm 13 pontos; exige pelo menos 2/3.
  if (janela.length < 8) return AnaliseNoite(dia: dia, resultado: ResultadoNoite.semDados);

  var minimo = janela.first.litros;
  for (final p in janela) {
    if (p.litros - minimo >= limiarRuidoLitros) {
      return AnaliseNoite(dia: dia, resultado: ResultadoNoite.reabastecendo);
    }
    if (p.litros < minimo) minimo = p.litros;
  }

  // Tendência por mínimos quadrados (litros × horas): resiste ao ruído melhor
  // do que comparar só o primeiro e o último ponto.
  final t0 = janela.first.timestamp;
  final xs = [for (final p in janela) p.timestamp.difference(t0).inMinutes / 60];
  final ys = [for (final p in janela) p.litros.toDouble()];
  final mediaX = xs.reduce((a, b) => a + b) / xs.length;
  final mediaY = ys.reduce((a, b) => a + b) / ys.length;
  var numerador = 0.0;
  var denominador = 0.0;
  for (var i = 0; i < xs.length; i++) {
    numerador += (xs[i] - mediaX) * (ys[i] - mediaY);
    denominador += (xs[i] - mediaX) * (xs[i] - mediaX);
  }
  final inclinacao = denominador == 0 ? 0.0 : numerador / denominador;
  final perda = (-inclinacao * xs.last).round();

  return AnaliseNoite(
    dia: dia,
    resultado: inclinacao <= -limiarVazamentoLitrosPorHora
        ? ResultadoNoite.vazamento
        : ResultadoNoite.ok,
    litrosPorHora: inclinacao,
    perdaLitros: perda > 0 ? perda : 0,
  );
}
