import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';
import 'pages/bloqueio_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/caixa_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!modoDemo) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  runApp(const CaixaDaguaApp());
}

class CaixaDaguaApp extends StatelessWidget {
  const CaixaDaguaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Caixa d'Água",
      debugShowCheckedModeBanner: false,
      theme: construirTema(Brightness.light),
      darkTheme: construirTema(Brightness.dark),
      home: modoDemo
          ? const HomePage()
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return snapshot.hasData ? const BloqueioGate(child: HomePage()) : const LoginPage();
              },
            ),
    );
  }
}
