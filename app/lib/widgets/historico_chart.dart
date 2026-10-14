import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leitura.dart';

/// Gráfico do nível (%) ao longo do tempo.
class HistoricoChart extends StatelessWidget {
  final List<PontoHistorico> pontos;

  const HistoricoChart({super.key, required this.pontos});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final estiloEixo = Theme.of(context).textTheme.labelSmall;

    if (pontos.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Ainda não há histórico suficiente.')),
      );
    }

    final inicio = pontos.first.timestamp.millisecondsSinceEpoch.toDouble();
    final fim = pontos.last.timestamp.millisecondsSinceEpoch.toDouble();
    final formatoHora = DateFormat.Hm();

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
                FlLine(color: cores.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 25,
                getTitlesWidget: (valor, _) => Text('${valor.toInt()}%', style: estiloEixo),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: ((fim - inicio) / 4).clamp(1, double.infinity),
                getTitlesWidget: (valor, _) => Text(
                  formatoHora.format(DateTime.fromMillisecondsSinceEpoch(valor.toInt())),
                  style: estiloEixo,
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final ponto = pontos[spot.spotIndex];
                return LineTooltipItem(
                  '${ponto.litros} L\n${formatoHora.format(ponto.timestamp)}',
                  TextStyle(color: cores.onInverseSurface),
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
              color: Colors.lightBlue,
              barWidth: 3,
              isCurved: true,
              preventCurveOverShooting: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.lightBlue.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
