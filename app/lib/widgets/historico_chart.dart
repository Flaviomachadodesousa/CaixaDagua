import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leitura.dart';
import '../theme.dart';

enum Periodo {
  dia('24 h', Duration(hours: 24)),
  semana('7 dias', Duration(days: 7));

  final String rotulo;
  final Duration duracao;

  const Periodo(this.rotulo, this.duracao);
}

/// Gráfico do nível (%) ao longo do tempo.
class HistoricoChart extends StatelessWidget {
  final List<PontoHistorico> pontos;
  final Periodo periodo;

  const HistoricoChart({super.key, required this.pontos, this.periodo = Periodo.dia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);
    final estiloEixo = tema.textTheme.labelSmall?.copyWith(color: paleta.textoSecundario);

    if (pontos.length < 2) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 40, color: paleta.textoSecundario),
              const SizedBox(height: 8),
              Text(
                'Ainda não há histórico suficiente.',
                style: tema.textTheme.bodyMedium?.copyWith(color: paleta.textoSecundario),
              ),
            ],
          ),
        ),
      );
    }

    final inicio = pontos.first.timestamp.millisecondsSinceEpoch.toDouble();
    final fim = pontos.last.timestamp.millisecondsSinceEpoch.toDouble();
    final formatoEixo = periodo == Periodo.dia ? DateFormat.Hm() : DateFormat('dd/MM');
    final formatoDica = DateFormat('dd/MM HH:mm');

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: inicio,
          maxX: fim,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: paleta.borda, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (valor, _) => Text('${valor.toInt()}%', style: estiloEixo),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: ((fim - inicio) / 4).clamp(1, double.infinity),
                getTitlesWidget: (valor, meta) {
                  // Esconde os rótulos das pontas para não cortarem
                  if (valor == meta.min || valor == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      formatoEixo.format(DateTime.fromMillisecondsSinceEpoch(valor.toInt())),
                      style: estiloEixo,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (barra, indices) => indices
                .map(
                  (_) => TouchedSpotIndicatorData(
                    FlLine(
                      color: corAgua.withValues(alpha: 0.5),
                      strokeWidth: 2,
                      dashArray: [4, 4],
                    ),
                    FlDotData(
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 6,
                        color: corAguaClara,
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                )
                .toList(),
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => tema.colorScheme.inverseSurface,
              getTooltipItems: (spots) => spots.map((spot) {
                final ponto = pontos[spot.spotIndex];
                return LineTooltipItem(
                  '${ponto.litros} L',
                  TextStyle(color: tema.colorScheme.onInverseSurface, fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(
                      text: '\n${formatoDica.format(ponto.timestamp)}',
                      style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final p in pontos)
                  FlSpot(p.timestamp.millisecondsSinceEpoch.toDouble(), p.percentual.toDouble()),
              ],
              gradient: const LinearGradient(colors: [corAguaClara, corAgua]),
              barWidth: 3,
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [corAgua.withValues(alpha: 0.35), corAgua.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
