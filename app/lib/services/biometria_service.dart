import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum StatusBiometria { sucesso, cancelado, erro }

class ResultadoBiometria {
  final StatusBiometria status;
  final String? mensagem;

  const ResultadoBiometria(this.status, [this.mensagem]);

  bool get ok => status == StatusBiometria.sucesso;
}

/// Login por biometria.
///
/// O e-mail e a senha ficam no armazenamento seguro do aparelho (Keystore no
/// Android) e só são lidos depois que a digital/rosto é confirmada.
class BiometriaService {
  BiometriaService._();
  static final instance = BiometriaService._();

  static const _chaveEmail = 'biometria_email';
  static const _chaveSenha = 'biometria_senha';
  static const _chaveOferecida = 'biometria_oferecida';

  final _auth = LocalAuthentication();
  final _armazenamento = const FlutterSecureStorage();

  /// Já passou pelo login ou pelo desbloqueio nesta execução do app.
  bool desbloqueado = false;

  /// Pede a biometria assim que a tela de login abre. Só na primeira vez em
  /// cada execução; depois de sair, a pessoa escolhe como entrar.
  bool pedirAutomaticamente = true;

  /// Credenciais do último login com senha, para oferecer ativar a biometria
  /// na tela principal. Ficam só na memória.
  ({String email, String senha})? credenciaisRecentes;

  Future<bool> disponivel() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// O aparelho suporta biometria, mesmo que ainda não tenha digital cadastrada.
  Future<bool> suportada() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> ativada() async {
    try {
      return await _armazenamento.containsKey(key: _chaveSenha);
    } catch (_) {
      return false;
    }
  }

  Future<void> ativar(String email, String senha) async {
    await _armazenamento.write(key: _chaveEmail, value: email);
    await _armazenamento.write(key: _chaveSenha, value: senha);
  }

  Future<void> desativar() async {
    await _armazenamento.delete(key: _chaveEmail);
    await _armazenamento.delete(key: _chaveSenha);
  }

  /// Se já perguntamos uma vez se a pessoa quer usar biometria.
  Future<bool> jaOferecida() async {
    try {
      return await _armazenamento.containsKey(key: _chaveOferecida);
    } catch (_) {
      return true;
    }
  }

  Future<void> marcarOferecida() => _armazenamento.write(key: _chaveOferecida, value: '1');

  Future<({String email, String senha})?> credenciais() async {
    final email = await _armazenamento.read(key: _chaveEmail);
    final senha = await _armazenamento.read(key: _chaveSenha);
    if (email == null || senha == null) return null;
    return (email: email, senha: senha);
  }

  Future<ResultadoBiometria> autenticar(String motivo) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: motivo,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok
          ? const ResultadoBiometria(StatusBiometria.sucesso)
          : const ResultadoBiometria(StatusBiometria.erro, 'Biometria não reconhecida.');
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.timeout => const ResultadoBiometria(StatusBiometria.cancelado),
        LocalAuthExceptionCode.noBiometricsEnrolled => const ResultadoBiometria(
          StatusBiometria.erro,
          'Nenhuma digital cadastrada. Cadastre nas configurações do celular.',
        ),
        LocalAuthExceptionCode.noBiometricHardware => const ResultadoBiometria(
          StatusBiometria.erro,
          'Este celular não tem leitor biométrico.',
        ),
        LocalAuthExceptionCode.temporaryLockout => const ResultadoBiometria(
          StatusBiometria.erro,
          'Muitas tentativas. Aguarde 30 segundos e tente de novo.',
        ),
        LocalAuthExceptionCode.biometricLockout => const ResultadoBiometria(
          StatusBiometria.erro,
          'Biometria bloqueada. Desbloqueie o celular com o PIN e tente de novo.',
        ),
        _ => ResultadoBiometria(
          StatusBiometria.erro,
          'Não foi possível usar a biometria (${e.code.name}).',
        ),
      };
    }
  }
}
