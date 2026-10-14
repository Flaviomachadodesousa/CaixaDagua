import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Desenho da caixa d'água (tronco de cone) com a água em ondas.
class CaixaWidget extends StatefulWidget {
  /// Nível de 0 a 100.
  final int percentual;
  final bool ativo;

  /// Conteúdo mostrado no meio da caixa (ex.: o percentual).
  final Widget? centro;

  const CaixaWidget({super.key, required this.percentual, this.ativo = true, this.centro});

  @override
  State<CaixaWidget> createState() => _CaixaWidgetState();
}

class _CaixaWidgetState extends State<CaixaWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _onda = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _onda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paleta = Paleta.of(context);

    return AspectRatio(
      aspectRatio: 1.3,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.percentual.clamp(0, 100) / 100),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, nivel, centro) => Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _CaixaPainter(
                    nivel: nivel,
                    fase: _onda,
                    ativo: widget.ativo,
                    paleta: paleta,
                  ),
                ),
              ),
            ),
            if (centro != null) Align(alignment: const Alignment(0, 0.2), child: centro),
          ],
        ),
        child: widget.centro,
      ),
    );
  }
}

class _CaixaPainter extends CustomPainter {
  final double nivel;
  final Animation<double> fase;
  final bool ativo;
  final Paleta paleta;

  _CaixaPainter({
    required this.nivel,
    required this.fase,
    required this.ativo,
    required this.paleta,
  }) : super(repaint: fase);

  // Proporção fundo/topo da Fortlev 500 L (95 cm / 122 cm)
  static const _proporcaoFundo = 95 / 122;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Corpo da caixa
    final larguraTopo = w * 0.86;
    final larguraFundo = larguraTopo * _proporcaoFundo;
    final yTopo = h * 0.12;
    final yFundo = h * 0.98;
    final lt = Offset((w - larguraTopo) / 2, yTopo);
    final rt = Offset((w + larguraTopo) / 2, yTopo);
    final lb = Offset((w - larguraFundo) / 2, yFundo);
    final rb = Offset((w + larguraFundo) / 2, yFundo);

    const raio = 22.0;
    Offset rumo(Offset de, Offset para, double distancia) =>
        de + (para - de) / (para - de).distance * distancia;

    final corpo = Path()
      ..moveTo(lt.dx, lt.dy)
      ..lineTo(rumo(lb, lt, raio).dx, rumo(lb, lt, raio).dy)
      ..quadraticBezierTo(lb.dx, lb.dy, lb.dx + raio, lb.dy)
      ..lineTo(rb.dx - raio, rb.dy)
      ..quadraticBezierTo(rb.dx, rb.dy, rumo(rb, rt, raio).dx, rumo(rb, rt, raio).dy)
      ..lineTo(rt.dx, rt.dy)
      ..close();

    canvas.drawPath(corpo, Paint()..color = paleta.vidro);

    // Água
    canvas.save();
    canvas.clipPath(corpo);

    final yAgua = yFundo - nivel * (yFundo - yTopo);
    // Ondas menores perto de vazia/cheia para não "vazar" do desenho
    final amplitude = 7 * math.min(1, math.min(nivel, 1 - nivel) * 8).toDouble();
    final t = fase.value * 2 * math.pi;

    final corClara = ativo ? corAguaClara : const Color(0xFF94A3B8);
    final corEscura = ativo ? corAguaEscura : const Color(0xFF475569);

    canvas.drawPath(
      _onda(size, yAgua, amplitude * 0.8, t + math.pi, 1.4),
      Paint()..color = corClara.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      _onda(size, yAgua, amplitude, t, 1.1),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [corClara, corEscura],
        ).createShader(Rect.fromLTRB(0, yAgua - amplitude, w, yFundo)),
    );

    // Bolhas subindo
    if (ativo && nivel > 0.05) {
      final bolha = Paint()..color = Colors.white.withValues(alpha: 0.25);
      for (var i = 0; i < 6; i++) {
        final progresso = (fase.value + i / 6) % 1;
        final y = yFundo - progresso * (yFundo - yAgua);
        final x = w * (0.3 + 0.4 * ((i * 37) % 10) / 10) + math.sin(t + i) * 6;
        canvas.drawCircle(Offset(x, y), 2 + (i % 3).toDouble(), bolha);
      }
    }

    // Reflexo do vidro
    canvas.drawRect(
      Rect.fromLTWH(lt.dx + w * 0.06, yTopo, w * 0.035, yFundo - yTopo),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, yTopo, w, yFundo - yTopo)),
    );

    canvas.restore();

    // Marcas de 25%, 50% e 75%
    final marca = Paint()
      ..color = paleta.textoSecundario.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final p in [0.25, 0.5, 0.75]) {
      final y = yFundo - p * (yFundo - yTopo);
      final x = rb.dx + (rt.dx - rb.dx) * p - 10;
      canvas.drawLine(Offset(x - 12, y), Offset(x, y), marca);
    }

    // Contorno
    canvas.drawPath(
      corpo,
      Paint()
        ..color = paleta.textoSecundario.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Tampa
    final tampa = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, yTopo - h * 0.035), width: w * 0.92, height: h * 0.07),
      const Radius.circular(12),
    );
    final puxador = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, yTopo - h * 0.085), width: w * 0.18, height: h * 0.04),
      const Radius.circular(8),
    );
    final corTampa = Paint()..color = paleta.tampa;
    canvas.drawRRect(puxador, corTampa);
    canvas.drawRRect(tampa, corTampa);
  }

  Path _onda(Size size, double y, double amplitude, double t, double frequencia) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 4) {
      path.lineTo(x, y + amplitude * math.sin(x / size.width * 2 * math.pi * frequencia + t));
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(_CaixaPainter old) =>
      old.nivel != nivel || old.ativo != ativo || old.paleta != paleta;
}
