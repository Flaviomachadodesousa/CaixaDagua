// Arquivo provisório. Gere o definitivo com:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=caixadagua-b3d63
//
// O comando sobrescreve este arquivo com as chaves do projeto.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase não configurado. Rode "flutterfire configure --project=caixadagua-b3d63" '
      'na pasta app/.',
    );
  }
}
