import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      theme: ThemeData(colorSchemeSeed: Colors.lightBlue),
      darkTheme: ThemeData(colorSchemeSeed: Colors.lightBlue, brightness: Brightness.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.hasData ? const HomePage() : const LoginPage();
        },
      ),
    );
  }
}
