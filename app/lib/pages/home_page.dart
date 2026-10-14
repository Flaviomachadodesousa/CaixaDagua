import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leitura.dart';
import '../services/caixa_service.dart';
import '../widgets/caixa_widget.dart';
import '../widgets/historico_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = CaixaService();
  late final Stream<Leitura?> _atual;
  late final Stream<List<PontoHistorico>> _historico;

  // Redesenha periodicamente para detectar quando o sensor fica offline.
  late final Timer _relogio;

  @override
  void initState() {
    super.initState();
    _atual = _service.atual();
    _historico = _service.historico(DateTime.now().subtract(const Duration(hours: 24)));
    _relogio = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _relogio.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Caixa d'Água"),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StreamBuilder<Leitura?>(
              stream: _atual,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Mensagem(
                    icone: Icons.error_outline,
                    texto: 'Erro ao ler os dados:\n${snapshot.error}',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final leitura = snapshot.data;
                if (leitura == null) {
                  return const _Mensagem(
                    icone: Icons.sensors_off,
                    texto: 'Nenhuma leitura recebida ainda.\nVerifique se o ESP32 está ligado.',
                  );
                }
                return _PainelAtual(leitura: leitura);
              },
            ),
            const SizedBox(height: 24),
            Text('Últimas 24 horas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            StreamBuilder<List<PontoHistorico>>(
              stream: _historico,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Erro ao ler o histórico: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return HistoricoChart(pontos: snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PainelAtual extends StatelessWidget {
  final Leitura leitura;

  const _PainelAtual({required this.leitura});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final online = leitura.estaOnline(DateTime.now());
    final percentual = leitura.percentual ?? 0;

    final (IconData icone, String status, Color cor) = switch ((online, leitura.sensorOk)) {
      (false, _) => (Icons.cloud_off, 'Sem atualização', tema.colorScheme.error),
      (true, false) => (Icons.warning_amber, 'Erro no sensor', Colors.orange),
      (true, true) => (Icons.check_circle, 'Online', Colors.green),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: CaixaWidget(percentual: percentual, ativo: online && leitura.sensorOk),
        ),
        const SizedBox(height: 24),
        Text(
          leitura.litros != null ? '${leitura.litros} L' : '—',
          style: tema.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          leitura.capacidadeLitros != null
              ? '$percentual% de ${leitura.capacidadeLitros} L'
              : '$percentual%',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Chip(
          avatar: Icon(icone, color: cor, size: 18),
          label: Text(status),
        ),
        if (leitura.timestamp != null)
          Text(
            'Atualizado em ${DateFormat('dd/MM HH:mm').format(leitura.timestamp!)}',
            style: tema.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _Mensagem extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Mensagem({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(icone, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
