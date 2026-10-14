import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/biometria_service.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _biometria = BiometriaService.instance;
  bool _entrando = false;
  bool _senhaVisivel = false;
  bool _biometriaAtiva = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _verificarBiometria();
  }

  Future<void> _verificarBiometria() async {
    final ativa = await _biometria.disponivel() && await _biometria.ativada();
    if (!mounted || !ativa) return;
    setState(() => _biometriaAtiva = true);
    if (_biometria.pedirAutomaticamente) {
      _biometria.pedirAutomaticamente = false;
      _entrarComBiometria();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final email = _email.text.trim();
    final senha = _senha.text;

    final erro = await _fazerLogin(email, senha);
    if (erro != null) return;

    // Mantém a senha guardada atualizada, caso tenha sido trocada.
    if (await _biometria.ativada()) await _biometria.ativar(email, senha);
  }

  Future<void> _entrarComBiometria() async {
    setState(() => _erro = null);

    final resultado = await _biometria.autenticar("Entre no Caixa d'Água");
    if (!mounted) return;
    if (!resultado.ok) {
      setState(() => _erro = resultado.mensagem);
      return;
    }

    final credenciais = await _biometria.credenciais();
    if (credenciais == null) {
      setState(() {
        _biometriaAtiva = false;
        _erro = 'Entre com e-mail e senha para reativar a biometria.';
      });
      return;
    }

    final erro = await _fazerLogin(credenciais.email, credenciais.senha, porBiometria: true);
    if (erro == 'invalid-credential' && mounted) {
      // A senha mudou desde que a biometria foi ativada.
      await _biometria.desativar();
      setState(() {
        _biometriaAtiva = false;
        _erro = 'A senha mudou. Entre com e-mail e senha para reativar a biometria.';
      });
    }
  }

  /// Retorna o código de erro do Firebase, ou null se entrou.
  Future<String?> _fazerLogin(String email, String senha, {bool porBiometria = false}) async {
    setState(() {
      _entrando = true;
      _erro = null;
    });

    // Marcado antes do login porque a troca de tela acontece durante o await.
    _biometria.desbloqueado = true;
    if (!porBiometria) _biometria.credenciaisRecentes = (email: email, senha: senha);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: senha);
      return null;
    } on FirebaseAuthException catch (e) {
      _biometria.desbloqueado = false;
      _biometria.credenciaisRecentes = null;
      if (mounted) {
        setState(
          () => _erro = switch (e.code) {
            'invalid-credential' ||
            'wrong-password' ||
            'user-not-found' => 'E-mail ou senha incorretos.',
            'invalid-email' => 'E-mail inválido.',
            'network-request-failed' => 'Sem conexão com a internet.',
            'too-many-requests' => 'Muitas tentativas. Aguarde um pouco.',
            _ => 'Não foi possível entrar (${e.code}).',
          },
        );
      }
      return e.code;
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);

    return Scaffold(
      body: FundoGradiente(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: _Logo()),
                      const SizedBox(height: 28),
                      Text(
                        "Caixa d'Água",
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Acompanhe o nível da sua caixa\nem tempo real',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyLarge?.copyWith(color: paleta.textoSecundario),
                      ),
                      const SizedBox(height: 36),
                      Cartao(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _email,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _senha,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                                  icon: Icon(
                                    _senhaVisivel
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                                ),
                              ),
                              obscureText: !_senhaVisivel,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _entrar(),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: _erro == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: _Erro(texto: _erro!),
                                    ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _entrando ? null : _entrar,
                              child: _entrando
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                            if (_biometriaAtiva) ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: paleta.borda)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'ou',
                                      style: tema.textTheme.bodySmall?.copyWith(
                                        color: paleta.textoSecundario,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: paleta.borda)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: _entrando ? null : _entrarComBiometria,
                                icon: const Icon(Icons.fingerprint_rounded, size: 26),
                                label: const Text('Entrar com biometria'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  foregroundColor: corAguaClara,
                                  side: BorderSide(color: corAgua.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [corAguaClara, corAguaEscura],
        ),
        boxShadow: [
          BoxShadow(color: corAgua.withValues(alpha: 0.45), blurRadius: 40, spreadRadius: 4),
        ],
      ),
      child: const Icon(Icons.water_drop_rounded, size: 48, color: Colors.white),
    );
  }
}

class _Erro extends StatelessWidget {
  final String texto;

  const _Erro({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: corPerigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: corPerigo, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: const TextStyle(color: corPerigo)),
          ),
        ],
      ),
    );
  }
}
