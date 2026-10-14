import 'package:flutter/material.dart';

import '../theme.dart';

/// Cartão pequeno com ícone, rótulo, valor e uma linha de detalhe.
class InfoCard extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String rotulo;
  final String valor;
  final String? detalhe;

  const InfoCard({
    super.key,
    required this.icone,
    required this.cor,
    required this.rotulo,
    required this.valor,
    this.detalhe,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final paleta = Paleta.of(context);

    return Cartao(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: cor, size: 20),
          ),
          const SizedBox(height: 14),
          Text(rotulo, style: tema.textTheme.labelMedium?.copyWith(color: paleta.textoSecundario)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (detalhe != null)
            Text(
              detalhe!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodySmall?.copyWith(color: paleta.textoSecundario),
            ),
        ],
      ),
    );
  }
}
