import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/biometria_service.dart';
import '../theme.dart';

/// Mostra [child] direto, ou a tela de bloqueio quando a biometria está ativa
/// e o app acabou de ser aberto com uma sessão já salva.
class BloqueioGate extends StatefulWidget {
  final Widget child;

  const BloqueioGate({super.key, required this.child});

  @override
  State<BloqueioGate> createState() => _BloqueioGateState();
}

class _BloqueioGateState extends State<BloqueioGate> {
  final _biometria = BiometriaService.instance;
  late bool _bloqueado = !_biometria.desbloqueado;
  bool _verificando = true;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    if (_bloqueado) {
      _bloqueado = await _biometria.disponivel() && await _biometria.ativada();
    }
    if (mounted) setState(() => _verificando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) {
      return const Scaffold(body: FundoGradiente(child: SizedBox.expand()));
    }
    if (!_bloqueado) return widget.child;

    return _BloqueioPage(
      aoDesbloquear: () {
        _biometria.desbloqueado = true;
        setState(() => _bloqueado = false);
      },
    );
  }
}

class _BloqueioPage extends StatefulWidget {
  final VoidCallback aoDesbloquear;

  const _BloqueioPage({required this.aoDesbloquear});

  @override
  State<_BloqueioPage> createState() => _BloqueioPageState();
}

class _BloqueioPageState extends State<_BloqueioPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  bool _autenticando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _desbloquear());
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  Future<void> _desbloquear() async {
    if (_autenticando) return;
    setState(() {
      _autenticando = true;
      _erro = null;
    });

    final resultado = await BiometriaService.instance.autenticar("Desbloqueie o Caixa d'Água");
    if (!mounted) return;

    if (resultado.ok) {
      widget.aoDesbloquear();
    } else {
      setState(() {
        _autenticando = false;
        _erro = resultado.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);

    return Scaffold(
      body: FundoGradiente(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  "Caixa d'Água",
                  style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use a biometria para desbloquear',
                  style: tema.textTheme.bodyLarge?.copyWith(color: paleta.textoSecundario),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _desbloquear,
                  child: SizedBox.square(
                    dimension: 180,
                    child: AnimatedBuilder(
                      animation: _pulso,
                      builder: (context, child) => Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final atraso in [0.0, 0.5])
                            _Onda(progresso: (_pulso.value + atraso) % 1),
                          child!,
                        ],
                      ),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [corAguaClara, corAguaEscura],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: corAgua.withValues(alpha: 0.45),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.fingerprint_rounded, size: 64, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _erro ?? 'Toque para desbloquear',
                    key: ValueKey(_erro),
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: _erro != null ? corPerigo : paleta.textoSecundario,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                TextButton(
                  onPressed: () {
                    BiometriaService.instance
                      ..desbloqueado = false
                      ..pedirAutomaticamente = false;
                    FirebaseAuth.instance.signOut();
                  },
                  child: const Text('Entrar com e-mail e senha'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Onda extends StatelessWidget {
  final double progresso;

  const _Onda({required this.progresso});

  @override
  Widget build(BuildContext context) {
    final tamanho = 110 + 70 * progresso;
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: corAgua.withValues(alpha: 0.5 * (1 - progresso)), width: 2),
      ),
    );
  }
}
