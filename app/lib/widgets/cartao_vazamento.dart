import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analise.dart';
import '../theme.dart';

/// Resultado da análise de vazamento nas madrugadas.
class CartaoVazamento extends StatelessWidget {
  /// Da mais antiga para a mais recente.
  final List<AnaliseNoite> noites;

  const CartaoVazamento({super.key, required this.noites});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);
    final ultima = noites.isEmpty ? null : noites.last;
    final noitesComVazamento = noites.where((n) => n.resultado == ResultadoNoite.vazamento).length;

    final (IconData icone, Color cor, String titulo, String texto) = _resumo(ultima, paleta);

    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vazamento',
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'Queda de nível entre ${horaInicioMadrugada}h e ${horaFimMadrugada}h',
            style: tema.textTheme.bodySmall?.copyWith(color: paleta.textoSecundario),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icone, color: cor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: tema.textTheme.titleSmall?.copyWith(
                          color: cor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(texto, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (noites.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final noite in noites) _Noite(noite: noite)],
            ),
            if (noitesComVazamento > 1) ...[
              const SizedBox(height: 12),
              Text(
                'Queda de nível em $noitesComVazamento das últimas ${noites.length} madrugadas. '
                'Confira a boia, o ladrão e as torneiras.',
                style: tema.textTheme.bodySmall?.copyWith(color: corPerigo),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static (IconData, Color, String, String) _resumo(AnaliseNoite? noite, Paleta paleta) {
    if (noite == null) {
      return (
        Icons.hourglass_empty_rounded,
        paleta.textoSecundario,
        'Aguardando dados',
        'A análise começa depois da primeira madrugada com leituras.',
      );
    }

    final dia = DateFormat('dd/MM').format(noite.dia);
    final taxa = NumberFormat('0.0', 'pt_BR').format(noite.litrosPorHora.abs());

    return switch (noite.resultado) {
      ResultadoNoite.vazamento => (
        Icons.warning_rounded,
        corPerigo,
        'Possível vazamento',
        'Em $dia a caixa perdeu ~${noite.perdaLitros} L entre ${horaInicioMadrugada}h e '
            '${horaFimMadrugada}h ($taxa L/h), quando normalmente ninguém usa água.',
      ),
      ResultadoNoite.ok => (
        Icons.verified_rounded,
        corOnline,
        'Nenhum vazamento detectado',
        'Nível estável na madrugada de $dia ($taxa L/h).',
      ),
      ResultadoNoite.reabastecendo => (
        Icons.water_rounded,
        corAgua,
        'Inconclusivo',
        'Entrou água da rua na madrugada de $dia, então não dá para avaliar.',
      ),
      ResultadoNoite.semDados => (
        Icons.help_outline_rounded,
        paleta.textoSecundario,
        'Sem dados',
        'Poucas leituras na madrugada de $dia. Verifique se o ESP32 ficou ligado.',
      ),
    };
  }
}

/// Um ponto colorido por madrugada, com o dia embaixo.
class _Noite extends StatelessWidget {
  final AnaliseNoite noite;

  const _Noite({required this.noite});

  @override
  Widget build(BuildContext context) {
    final paleta = Paleta.of(context);
    final (Color cor, IconData? icone, String descricao) = switch (noite.resultado) {
      ResultadoNoite.ok => (corOnline, Icons.check_rounded, 'sem vazamento'),
      ResultadoNoite.vazamento => (corPerigo, Icons.priority_high_rounded, 'possível vazamento'),
      ResultadoNoite.reabastecendo => (corAgua, Icons.water_drop_rounded, 'reabastecendo'),
      ResultadoNoite.semDados => (paleta.textoSecundario, null, 'sem dados'),
    };

    return Tooltip(
      message: '${DateFormat('dd/MM').format(noite.dia)}: $descricao',
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor.withValues(alpha: 0.18),
              border: Border.all(color: cor.withValues(alpha: 0.6)),
            ),
            child: icone != null ? Icon(icone, size: 16, color: cor) : null,
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd').format(noite.dia),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: paleta.textoSecundario),
          ),
        ],
      ),
    );
  }
}
