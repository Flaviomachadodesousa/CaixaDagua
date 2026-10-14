import 'package:flutter/material.dart';

/// Etiqueta de status com um ponto colorido que pulsa.
class StatusPill extends StatefulWidget {
  final String texto;
  final Color cor;
  final bool pulsar;

  const StatusPill({super.key, required this.texto, required this.cor, this.pulsar = true});

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsar) _pulso.repeat();
  }

  @override
  void didUpdateWidget(StatusPill old) {
    super.didUpdateWidget(old);
    if (widget.pulsar && !_pulso.isAnimating) {
      _pulso.repeat();
    } else if (!widget.pulsar) {
      _pulso.reset();
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: widget.cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: widget.cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 14,
            child: AnimatedBuilder(
              animation: _pulso,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.pulsar)
                    Container(
                      width: 6 + 8 * _pulso.value,
                      height: 6 + 8 * _pulso.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.cor.withValues(alpha: 0.5 * (1 - _pulso.value)),
                      ),
                    ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.cor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.texto,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: widget.cor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
