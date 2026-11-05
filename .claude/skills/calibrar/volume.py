"""Volume da caixa (tronco de cone), com a mesma fórmula de volumeLitros() no firmware.

Uso:
  python volume.py --fundo 95 --topo 122 --parede 58 --cheia 52 [--fator 1.0]
      Mostra capacidade, litros por cm e a tabela altura x litros para o README.

  python volume.py ... --entre 40.2 31.5
      Mostra quantos litros a fórmula calcula entre duas alturas (sem o fator),
      para comparar com um volume conhecido e achar o FATOR_CORRECAO.
"""

import argparse
import math


def volume_litros(h, fundo, topo, parede, fator=1.0):
    if h <= 0:
        return 0.0
    r_fundo = fundo / 2
    r_topo = topo / 2
    r_agua = r_fundo + (r_topo - r_fundo) * h / parede
    cm3 = math.pi * h * (r_fundo**2 + r_fundo * r_agua + r_agua**2) / 3
    return cm3 / 1000 * fator


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--fundo", type=float, required=True, help="DIAMETRO_FUNDO_CM")
    p.add_argument("--topo", type=float, required=True, help="DIAMETRO_TOPO_CM")
    p.add_argument("--parede", type=float, required=True, help="ALTURA_CAIXA_CM")
    p.add_argument("--cheia", type=float, required=True, help="ALTURA_AGUA_CHEIA_CM")
    p.add_argument("--fator", type=float, default=1.0, help="FATOR_CORRECAO")
    p.add_argument("--entre", type=float, nargs=2, metavar=("H1", "H2"))
    a = p.parse_args()

    def v(h, fator=a.fator):
        return volume_litros(min(h, a.parede), a.fundo, a.topo, a.parede, fator)

    if a.entre:
        h1, h2 = a.entre
        print(f"Volume entre {h1} cm e {h2} cm (fator 1.0): {abs(v(h1, 1.0) - v(h2, 1.0)):.1f} L")
        return

    capacidade = v(a.cheia)
    meio = a.cheia / 2
    litros_por_cm = v(meio + 0.5) - v(meio - 0.5)
    print(f"Capacidade (agua cheia em {a.cheia:g} cm): {capacidade:.0f} L")
    print(f"Litros por cm na metade da altura: {litros_por_cm:.1f} L/cm")
    print()
    print("| Altura | Litros |")
    print("|---|---|")
    alturas = sorted({10, 20, 30, 40, a.cheia, a.parede})
    for h in alturas:
        nota = ""
        if h == a.cheia:
            nota = " (cheia)"
        if h == a.parede:
            nota = " (borda)"
        print(f"| {h:g} cm{nota} | ~{v(h):.0f} L |")


if __name__ == "__main__":
    main()
