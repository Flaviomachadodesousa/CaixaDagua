import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/clima.dart';
import '../services/clima_service.dart';
import '../theme.dart';

/// Temperatura atual e previsão de 3 dias no Grajaú. Busca ao abrir e a cada 15 minutos.
class CartaoClima extends StatefulWidget {
  /// Para testes; por padrão usa a Open-Meteo.
  final ClimaService? service;

  const CartaoClima({super.key, this.service});

  @override
  State<CartaoClima> createState() => CartaoClimaState();
}

/// Pública para a tela inicial poder chamar [atualizar] (puxar para atualizar).
class CartaoClimaState extends State<CartaoClima> {
  late final _service = widget.service ?? ClimaService();
  late final Timer _timer;

  Clima? _clima;
  bool _erro = false;

  /// Quando o app recebeu a última resposta. Não é o horário do dado: a
  /// Open-Meteo só publica o tempo atual a cada 15 min (ex.: 10:30, 10:45).
  DateTime? _buscadoEm;

  @override
  void initState() {
    super.initState();
    _buscar();
    _timer = Timer.periodic(ClimaService.intervaloAtualizacao, (_) => _buscar());
  }

  /// Busca o tempo de novo. Não lança erro: se falhar, mantém o último valor.
  Future<void> atualizar() => _buscar();

  Future<void> _buscar() async {
    try {
      final clima = await _service.atual();
      if (mounted) {
        setState(() {
          _clima = clima;
          _erro = false;
          _buscadoEm = DateTime.now();
        });
      }
    } catch (_) {
      // Mantém o último valor; só mostra erro se nunca carregou.
      if (mounted) setState(() => _erro = true);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _service.fechar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);
    final clima = _clima;
    final decimal = NumberFormat('0', 'pt_BR');
    const cor = corAlerta;

    final Widget conteudo;
    if (clima == null && !_erro) {
      conteudo = const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (clima == null) {
      conteudo = Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: paleta.textoSecundario),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Não foi possível obter o tempo agora.',
              style: tema.textTheme.bodyMedium?.copyWith(color: paleta.textoSecundario),
            ),
          ),
          TextButton(onPressed: _buscar, child: const Text('Tentar de novo')),
        ],
      );
    } else {
      final detalhes = [
        if (clima.sensacao != null) 'sensação ${decimal.format(clima.sensacao)}°',
        if (clima.umidade != null) 'umidade ${clima.umidade}%',
      ].join(' · ');

      conteudo = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(clima.icone, color: cor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clima.descricao,
                  style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (detalhes.isNotEmpty)
                  Text(
                    detalhes,
                    style: tema.textTheme.bodySmall?.copyWith(color: paleta.textoSecundario),
                  ),
              ],
            ),
          ),
          Text(
            '${decimal.format(clima.temperatura)}°C',
            style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      );
    }

    final horario = _buscadoEm;
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tempo agora',
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            [
              ClimaService.nomeLocal,
              if (horario != null) 'atualizado às ${DateFormat('HH:mm').format(horario)}',
            ].join(' · '),
            style: tema.textTheme.bodySmall?.copyWith(color: paleta.textoSecundario),
          ),
          const SizedBox(height: 16),
          conteudo,
          if (clima != null && clima.previsao.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: paleta.borda),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < clima.previsao.length; i++)
                  Expanded(child: _Dia(previsao: clima.previsao[i], indice: i)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma coluna da previsão: dia, condição, máxima/mínima e chuva.
class _Dia extends StatelessWidget {
  final PrevisaoDia previsao;

  /// 0 = hoje, 1 = amanhã.
  final int indice;

  const _Dia({required this.previsao, required this.indice});

  /// A partir de 60% a chuva ganha destaque.
  static const _chanceAlta = 60;

  String get _rotulo => switch (indice) {
    0 => 'Hoje',
    1 => 'Amanhã',
    _ => _semDia(previsao.data),
  };

  /// "sáb." → "Sáb"
  static String _semDia(DateTime data) {
    final curto = DateFormat('EEE', 'pt_BR').format(data).replaceAll('.', '');
    return curto.isEmpty ? curto : curto[0].toUpperCase() + curto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);
    final inteiro = NumberFormat('0', 'pt_BR');
    final decimal = NumberFormat('0.0', 'pt_BR');
    final chance = previsao.chanceChuva;
    final mm = previsao.chuvaMm;
    final chuvaAlta = chance != null && chance >= _chanceAlta;
    final corIcone = previsao.codigo >= 51 ? corAgua : corAlerta;

    return Tooltip(
      message: previsao.descricao,
      child: Column(
        children: [
          Text(_rotulo, style: tema.textTheme.labelMedium?.copyWith(color: paleta.textoSecundario)),
          const SizedBox(height: 6),
          Icon(previsao.icone, color: corIcone, size: 22),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${inteiro.format(previsao.maxima)}°',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: ' / ${inteiro.format(previsao.minima)}°',
                  style: TextStyle(color: paleta.textoSecundario),
                ),
              ],
            ),
            style: tema.textTheme.bodyMedium,
          ),
          if (chance != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop_rounded,
                  size: 12,
                  color: chuvaAlta ? corAgua : paleta.textoSecundario,
                ),
                const SizedBox(width: 2),
                Text(
                  '$chance%',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: chuvaAlta ? corAgua : paleta.textoSecundario,
                    fontWeight: chuvaAlta ? FontWeight.w800 : null,
                  ),
                ),
              ],
            ),
          ],
          if (mm != null && mm >= 0.1)
            Text(
              '${decimal.format(mm)} mm',
              style: tema.textTheme.labelSmall?.copyWith(color: paleta.textoSecundario),
            ),
        ],
      ),
    );
  }
}
