import 'package:flutter/material.dart';

const corAgua = Color(0xFF0EA5E9);
const corAguaClara = Color(0xFF38BDF8);
const corAguaEscura = Color(0xFF0369A1);

const corOnline = Color(0xFF22C55E);
const corAlerta = Color(0xFFF59E0B);
const corPerigo = Color(0xFFEF4444);

/// Cores de superfície que dependem do tema claro/escuro.
class Paleta {
  final Color fundoTopo;
  final Color fundoBase;
  final Color cartao;
  final Color borda;
  final Color textoSecundario;
  final Color vidro;
  final Color tampa;

  const Paleta._({
    required this.fundoTopo,
    required this.fundoBase,
    required this.cartao,
    required this.borda,
    required this.textoSecundario,
    required this.vidro,
    required this.tampa,
  });

  static const escura = Paleta._(
    fundoTopo: Color(0xFF0F2445),
    fundoBase: Color(0xFF070D18),
    cartao: Color(0xCC111C2E),
    borda: Color(0x14FFFFFF),
    textoSecundario: Color(0xFF94A3B8),
    vidro: Color(0x0DFFFFFF),
    tampa: Color(0xFF1E2D45),
  );

  static const clara = Paleta._(
    fundoTopo: Color(0xFFD6E9FB),
    fundoBase: Color(0xFFF5F8FC),
    cartao: Color(0xE6FFFFFF),
    borda: Color(0xFFE2E8F0),
    textoSecundario: Color(0xFF64748B),
    vidro: Color(0x0D0EA5E9),
    tampa: Color(0xFFCBD5E1),
  );

  static Paleta of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? escura : clara;
}

ThemeData construirTema(Brightness brilho) {
  final paleta = brilho == Brightness.dark ? Paleta.escura : Paleta.clara;
  final cores = ColorScheme.fromSeed(seedColor: corAgua, brightness: brilho);
  final base = ThemeData(colorScheme: cores, brightness: brilho, fontFamily: 'PlusJakartaSans');
  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: paleta.borda),
  );

  return base.copyWith(
    scaffoldBackgroundColor: paleta.fundoBase,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paleta.vidro,
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(borderSide: const BorderSide(color: corAgua, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: corAgua,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// Fundo com degradê e um brilho azul no canto superior.
class FundoGradiente extends StatelessWidget {
  final Widget child;

  const FundoGradiente({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final paleta = Paleta.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [paleta.fundoTopo, paleta.fundoBase],
          stops: const [0, 0.55],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, -1),
            radius: 1.1,
            colors: [corAgua.withValues(alpha: 0.18), corAgua.withValues(alpha: 0)],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Cartão com cantos arredondados e borda suave.
class Cartao extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Cartao({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    final paleta = Paleta.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: paleta.cartao,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: paleta.borda),
      ),
      child: child,
    );
  }
}
