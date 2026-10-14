import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analise.dart';
import '../models/leitura.dart';
import '../services/biometria_service.dart';
import '../services/caixa_service.dart';
import '../theme.dart';
import '../widgets/caixa_widget.dart';
import '../widgets/cartao_vazamento.dart';
import '../widgets/historico_chart.dart';
import '../widgets/info_card.dart';
import '../widgets/status_pill.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = CaixaService();

  StreamSubscription<Leitura?>? _assinaturaAtual;
  StreamSubscription<List<PontoHistorico>>? _assinaturaHistorico;

  Leitura? _leitura;
  bool _carregando = true;
  Object? _erro;

  Periodo _periodo = Periodo.dia;
  List<PontoHistorico>? _pontos;

  // Redesenha periodicamente para detectar quando o sensor fica offline.
  late final Timer _relogio;

  @override
  void initState() {
    super.initState();
    _assinaturaAtual = _service.atual().listen(
      (leitura) => setState(() {
        _leitura = leitura;
        _carregando = false;
        _erro = null;
      }),
      onError: (Object e) => setState(() {
        _erro = e;
        _carregando = false;
      }),
    );
    _ouvirHistorico();
    _relogio = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _oferecerBiometria());
  }

  /// Logo depois do primeiro login com senha, pergunta uma vez se a pessoa
  /// quer entrar com biometria.
  Future<void> _oferecerBiometria() async {
    final biometria = BiometriaService.instance;
    final credenciais = biometria.credenciaisRecentes;
    if (modoDemo || credenciais == null) return;
    if (!await biometria.disponivel() ||
        await biometria.ativada() ||
        await biometria.jaOferecida()) {
      return;
    }
    if (!mounted) return;

    await biometria.marcarOferecida();
    if (!mounted) return;
    final aceitou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.fingerprint_rounded, size: 40, color: corAgua),
        title: const Text('Entrar com biometria?'),
        content: const Text(
          'Use a digital para abrir o app sem digitar a senha. '
          'Dá para mudar depois no menu ⋮.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    if (aceitou == true && mounted) await _ativarBiometria(context, credenciais);
  }

  /// Busca sempre 7 dias: o gráfico de 24 h, o consumo e a análise das
  /// madrugadas saem da mesma lista.
  void _ouvirHistorico() {
    _assinaturaHistorico = _service
        .historico(DateTime.now().subtract(Periodo.semana.duracao))
        .listen((pontos) => setState(() => _pontos = pontos));
  }

  List<PontoHistorico>? _pontosDoPeriodo() {
    final desde = DateTime.now().subtract(_periodo.duracao);
    return _pontos?.where((p) => p.timestamp.isAfter(desde)).toList();
  }

  @override
  void dispose() {
    _relogio.cancel();
    _assinaturaAtual?.cancel();
    _assinaturaHistorico?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leitura = _leitura;

    return Scaffold(
      body: FundoGradiente(
        child: SafeArea(
          child: LayoutBuilder(
            // Em paisagem ou tablet, centraliza o conteúdo numa coluna de até 560 px.
            builder: (context, restricoes) => ListView(
              padding: EdgeInsets.fromLTRB(
                math.max(20, (restricoes.maxWidth - _larguraMaxima) / 2),
                12,
                math.max(20, (restricoes.maxWidth - _larguraMaxima) / 2),
                32,
              ),
              children: [
                _Cabecalho(leitura: leitura, carregando: _carregando),
                const SizedBox(height: 20),
                if (_carregando)
                  const Cartao(
                    child: SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
                  )
                else if (_erro != null)
                  _Mensagem(
                    icone: Icons.error_outline_rounded,
                    titulo: 'Erro ao ler os dados',
                    texto: '$_erro',
                  )
                else if (leitura == null)
                  const _Mensagem(
                    icone: Icons.sensors_off_rounded,
                    titulo: 'Nenhuma leitura recebida',
                    texto: 'Verifique se o ESP32 está ligado e conectado ao Wi-Fi.',
                  )
                else ...[
                  _PainelNivel(leitura: leitura),
                  const SizedBox(height: 16),
                  _GradeInfo(leitura: leitura, pontos: _pontos),
                ],
                const SizedBox(height: 16),
                _CartaoHistorico(
                  periodo: _periodo,
                  pontos: _pontosDoPeriodo(),
                  aoMudarPeriodo: (periodo) => setState(() => _periodo = periodo),
                ),
                if (_pontos != null) ...[
                  const SizedBox(height: 16),
                  CartaoVazamento(noites: analisarMadrugadas(_pontos!, DateTime.now())),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _larguraMaxima = 560.0;
}

// ================================================================================
// --- Cabeçalho ---

class _Cabecalho extends StatelessWidget {
  final Leitura? leitura;
  final bool carregando;

  const _Cabecalho({required this.leitura, required this.carregando});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);

    final (String texto, Color cor, bool pulsar) = switch (leitura) {
      _ when carregando => ('Conectando', paleta.textoSecundario, false),
      null => ('Aguardando', paleta.textoSecundario, false),
      final l when !l.estaOnline(DateTime.now()) => ('Offline', corPerigo, false),
      final l when !l.sensorOk => ('Erro no sensor', corAlerta, true),
      _ => ('Online', corOnline, true),
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Caixa d'Água",
                style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              StatusPill(texto: texto, cor: cor, pulsar: pulsar),
            ],
          ),
        ),
        if (!modoDemo) const _MenuConta(),
      ],
    );
  }
}

/// Confirma a digital e guarda as credenciais para o login por biometria.
Future<void> _ativarBiometria(
  BuildContext context,
  ({String email, String senha}) credenciais,
) async {
  final mensageiro = ScaffoldMessenger.of(context);
  final biometria = BiometriaService.instance;

  final resultado = await biometria.autenticar('Confirme a biometria para ativar o login');
  if (resultado.ok) {
    await biometria.ativar(credenciais.email, credenciais.senha);
    mensageiro.showSnackBar(const SnackBar(content: Text('Login por biometria ativado.')));
  } else if (resultado.mensagem != null) {
    mensageiro.showSnackBar(SnackBar(content: Text(resultado.mensagem!)));
  }
}

class _MenuConta extends StatefulWidget {
  const _MenuConta();

  @override
  State<_MenuConta> createState() => _MenuContaState();
}

class _MenuContaState extends State<_MenuConta> {
  final _biometria = BiometriaService.instance;
  bool _suportada = false;
  bool _disponivel = false;
  bool _ativada = false;

  Future<void> _atualizar() async {
    final suportada = await _biometria.suportada();
    final disponivel = await _biometria.disponivel();
    final ativada = await _biometria.ativada();
    if (mounted) {
      setState(() {
        _suportada = suportada;
        _disponivel = disponivel;
        _ativada = ativada;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _alternarBiometria() async {
    if (!_disponivel && !_ativada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma digital cadastrada. Cadastre em Configurações → Segurança → Impressão digital.',
          ),
        ),
      );
      return;
    }
    if (_ativada) {
      await _biometria.desativar();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Login por biometria desativado.')));
      }
    } else {
      final credenciais = _biometria.credenciaisRecentes ?? await _confirmarSenha();
      if (credenciais != null && mounted) await _ativarBiometria(context, credenciais);
    }
    await _atualizar();
  }

  /// Pede a senha atual (necessária para guardar no aparelho) e confere no Firebase.
  Future<({String email, String senha})?> _confirmarSenha() async {
    final usuario = FirebaseAuth.instance.currentUser;
    final email = usuario?.email;
    if (usuario == null || email == null) return null;

    final controle = TextEditingController();
    final senha = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirme sua senha'),
        content: TextField(
          controller: controle,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Senha',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
          onSubmitted: (valor) => Navigator.pop(context, valor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, controle.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controle.dispose();
    if (senha == null || senha.isEmpty) return null;

    try {
      await usuario.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: senha),
      );
      return (email: email, senha: senha);
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Senha incorreta.')));
      }
      return null;
    }
  }

  void _sair() {
    _biometria
      ..desbloqueado = false
      ..pedirAutomaticamente = false
      ..credenciaisRecentes = null;
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: const Icon(Icons.more_vert_rounded),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onOpened: _atualizar,
      onSelected: (opcao) => switch (opcao) {
        'biometria' => _alternarBiometria(),
        _ => _sair(),
      },
      itemBuilder: (context) => [
        if (_suportada)
          CheckedPopupMenuItem(
            value: 'biometria',
            checked: _ativada,
            child: const Text('Entrar com biometria'),
          ),
        const PopupMenuItem(
          value: 'sair',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Sair'),
          ),
        ),
      ],
    );
  }
}

// ================================================================================
// --- Nível atual ---

class _PainelNivel extends StatelessWidget {
  final Leitura leitura;

  const _PainelNivel({required this.leitura});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);
    final percentual = leitura.percentual ?? 0;
    final ativo = leitura.sensorOk && leitura.estaOnline(DateTime.now());

    final textoCentro = Colors.white;
    const sombra = [Shadow(color: Color(0x66000000), blurRadius: 12)];
    final corTextoVazio = tema.colorScheme.onSurface;
    // Abaixo de ~45% o texto fica sobre o vidro vazio, não sobre a água
    final corTexto = percentual >= 45 ? textoCentro : corTextoVazio;

    return Cartao(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Nível atual',
                style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (percentual < 25)
                const _Etiqueta(texto: 'Nível baixo', cor: corPerigo, icone: Icons.warning_rounded)
              else if (percentual >= 95)
                const _Etiqueta(texto: 'Cheia', cor: corOnline, icone: Icons.check_rounded),
            ],
          ),
          const SizedBox(height: 16),
          // Em paisagem a caixa não pode ficar mais alta que a tela
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: CaixaWidget(
              percentual: percentual,
              ativo: ativo,
              centro: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: percentual.toDouble()),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (context, valor, _) => Text(
                      '${valor.round()}%',
                      style: tema.textTheme.displayMedium?.copyWith(
                        color: corTexto,
                        fontWeight: FontWeight.w800,
                        shadows: percentual >= 45 ? sombra : null,
                      ),
                    ),
                  ),
                  Text(
                    leitura.litros != null ? '${leitura.litros} litros' : '—',
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: percentual >= 45
                          ? textoCentro.withValues(alpha: 0.9)
                          : paleta.textoSecundario,
                      fontWeight: FontWeight.w600,
                      shadows: percentual >= 45 ? sombra : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData icone;

  const _Etiqueta({required this.texto, required this.cor, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(
            texto,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: cor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ================================================================================
// --- Cartões de informação ---

class _GradeInfo extends StatelessWidget {
  final Leitura leitura;
  final List<PontoHistorico>? pontos;

  const _GradeInfo({required this.leitura, required this.pontos});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final ultimas24h = pontos
        ?.where((p) => p.timestamp.isAfter(agora.subtract(const Duration(hours: 24))))
        .toList();
    final consumo = ultimas24h != null && ultimas24h.length >= 2 ? consumoLitros(ultimas24h) : null;
    final decimal = NumberFormat('0.0', 'pt_BR');

    // Média diária com o histórico todo (até 7 dias), se cobrir pelo menos 2 dias.
    String? mediaDiaria;
    final todos = pontos;
    if (todos != null && todos.length >= 2) {
      final dias = todos.last.timestamp.difference(todos.first.timestamp).inHours / 24;
      if (dias >= 2) mediaDiaria = 'média ${(consumoLitros(todos) / dias).round()} L/dia';
    }

    final cartoes = [
      InfoCard(
        icone: Icons.water_drop_rounded,
        cor: corAgua,
        rotulo: 'Volume',
        valor: leitura.litros != null ? '${leitura.litros} L' : '—',
        detalhe: leitura.capacidadeLitros != null ? 'de ${leitura.capacidadeLitros} L' : null,
      ),
      InfoCard(
        icone: Icons.straighten_rounded,
        cor: const Color(0xFF8B5CF6),
        rotulo: 'Altura da água',
        valor: leitura.alturaCm != null ? '${decimal.format(leitura.alturaCm)} cm' : '—',
        detalhe: 'medida do fundo',
      ),
      InfoCard(
        icone: Icons.trending_down_rounded,
        cor: corAlerta,
        rotulo: 'Consumo 24 h',
        valor: consumo != null ? '$consumo L' : '—',
        detalhe: consumo == null ? 'sem histórico' : mediaDiaria ?? 'estimado',
      ),
      InfoCard(
        icone: Icons.schedule_rounded,
        cor: corOnline,
        rotulo: 'Atualizado',
        valor: leitura.timestamp != null ? _tempoRelativo(leitura.timestamp!, agora) : '—',
        detalhe: leitura.timestamp != null
            ? DateFormat('dd/MM HH:mm').format(leitura.timestamp!)
            : null,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < cartoes.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cartoes[i]),
                const SizedBox(width: 12),
                Expanded(child: cartoes[i + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _tempoRelativo(DateTime quando, DateTime agora) {
    final diferenca = agora.difference(quando);
    if (diferenca.inMinutes < 1) return 'agora';
    if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
    if (diferenca.inHours < 24) return 'há ${diferenca.inHours} h';
    return 'há ${diferenca.inDays} d';
  }
}

// ================================================================================
// --- Histórico ---

class _CartaoHistorico extends StatelessWidget {
  final Periodo periodo;
  final List<PontoHistorico>? pontos;
  final ValueChanged<Periodo> aoMudarPeriodo;

  const _CartaoHistorico({
    required this.periodo,
    required this.pontos,
    required this.aoMudarPeriodo,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Cartao(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              Text(
                'Histórico',
                style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _SeletorPeriodo(selecionado: periodo, aoMudar: aoMudarPeriodo),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: pontos == null
                ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                : HistoricoChart(key: ValueKey(periodo), pontos: pontos!, periodo: periodo),
          ),
        ],
      ),
    );
  }
}

class _SeletorPeriodo extends StatelessWidget {
  final Periodo selecionado;
  final ValueChanged<Periodo> aoMudar;

  const _SeletorPeriodo({required this.selecionado, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: paleta.vidro,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: paleta.borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in Periodo.values)
            GestureDetector(
              onTap: () => aoMudar(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: p == selecionado ? corAgua : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  p.rotulo,
                  style: tema.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p == selecionado ? Colors.white : paleta.textoSecundario,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================================
// --- Mensagens ---

class _Mensagem extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;

  const _Mensagem({required this.icone, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);

    return Cartao(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: corAgua.withValues(alpha: 0.12),
            ),
            child: Icon(icone, size: 36, color: corAgua),
          ),
          const SizedBox(height: 20),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(color: paleta.textoSecundario),
          ),
        ],
      ),
    );
  }
}
