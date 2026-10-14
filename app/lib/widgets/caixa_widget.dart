import 'package:flutter/material.dart';

/// Desenho da caixa d'água (tronco de cone) com o nível da água.
class CaixaWidget extends StatelessWidget {
  /// Nível de 0 a 100.
  final int percentual;
  final bool ativo;

  const CaixaWidget({super.key, required this.percentual, this.ativo = true});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 1.6,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: percentual.clamp(0, 100) / 100),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, nivel, _) => CustomPaint(
          painter: _CaixaPainter(
            nivel: nivel,
            corAgua: ativo ? Colors.lightBlue : cores.outline,
            corParede: cores.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CaixaPainter extends CustomPainter {
  final double nivel;
  final Color corAgua;
  final Color corParede;

  _CaixaPainter({required this.nivel, required this.corAgua, required this.corParede});

  // Proporção fundo/topo da Fortlev 500 L (95 cm / 122 cm)
  static const _proporcaoFundo = 95 / 122;

  @override
  void paint(Canvas canvas, Size size) {
    final topo = size.width;
    final fundo = size.width * _proporcaoFundo;
    final recuo = (topo - fundo) / 2;
    final altura = size.height;

    // Largura da caixa numa altura y (0 = topo, altura = fundo)
    double xEsquerda(double y) => recuo * y / altura;

    final contorno = Path()
      ..moveTo(0, 0)
      ..lineTo(recuo, altura)
      ..lineTo(topo - recuo, altura)
      ..lineTo(topo, 0);

    final yAgua = altura * (1 - nivel);
    final agua = Path()
      ..moveTo(xEsquerda(yAgua), yAgua)
      ..lineTo(recuo, altura)
      ..lineTo(topo - recuo, altura)
      ..lineTo(topo - xEsquerda(yAgua), yAgua)
      ..close();

    canvas.drawPath(
      agua,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [corAgua.withValues(alpha: 0.6), corAgua],
        ).createShader(Rect.fromLTWH(0, yAgua, topo, altura - yAgua)),
    );

    canvas.drawPath(
      contorno,
      Paint()
        ..color = corParede
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CaixaPainter old) =>
      old.nivel != nivel || old.corAgua != corAgua || old.corParede != corParede;
}
