---
name: calibrar
description: Calibração guiada da caixa d'água. Coleta medidas de trena e leituras do sensor, calcula DIST_SENSOR_FUNDO_CM, ALTURA_AGUA_CHEIA_CM e FATOR_CORRECAO, atualiza os #define do firmware e recalcula a tabela de volume do README. Use quando o usuário quiser calibrar o sensor, ajustar as medidas da caixa ou corrigir litros que não batem com o real.
argument-hint: "[medidas ou leituras já feitas]"
---

# Calibração da caixa

Objetivo: fazer a altura e os litros calculados pelo firmware baterem com a caixa real. Converse em português, uma etapa por vez, e não peça tudo de uma vez. Se o usuário já trouxe dados em `$ARGUMENTS`, aproveite e pule as perguntas já respondidas.

Leia antes os `#define` do topo de [Arduino/CaixaDagua/CaixaDagua.ino](../../../Arduino/CaixaDagua/CaixaDagua.ino) para saber os valores atuais.

## Como ler o sensor

Cada leitura precisa da **distância medida pelo sensor** (`distancia_cm`). Há duas fontes:

- **Monitor Serial** (115200 baud): linhas `Distancia: 42.3 cm | Altura: 37.7 cm | 320 L | 68%`. O usuário cola o texto. Use a mediana de várias linhas, não uma só.
- **Firebase** (somente leitura): `firebase database:get /caixadagua/atual --project caixadagua-b3d63`. Precisa de `firebase login`. O `/atual` muda a cada 1 min, então leia algumas vezes. Ignore leituras com `status: "erro_sensor"`.

Com a skill `/firmware` é possível capturar o serial direto.

## Etapa 1: medidas da caixa (trena)

Pergunte, em cm:

- diâmetro **interno** do fundo e do topo da parede (`DIAMETRO_FUNDO_CM`, `DIAMETRO_TOPO_CM`). Os valores de fábrica (95 e 122) são externos; a medida interna é mais certa;
- altura da parede, sem a tampa (`ALTURA_CAIXA_CM`).

Se o usuário não medir, mantenha os valores de fábrica e diga isso no resumo.

## Etapa 2: distância do sensor ao fundo (`DIST_SENSOR_FUNDO_CM`)

Medir com a trena da face do sensor até o fundo é difícil com a caixa instalada. Prefira este método:

1. O usuário mede a **altura da água** com uma régua ou cabo de vassoura encostado no fundo (perto do centro, longe da boia).
2. No mesmo momento, pega a `distancia_cm` do sensor.
3. `DIST_SENSOR_FUNDO_CM = distancia_cm + altura_agua_real`.

Peça pelo menos 2 pares em níveis diferentes (ex.: antes e depois de gastar água). Se os resultados variarem mais de ~1 cm, avise: pode ser sensor torto, eco na parede ou na boia, ou onda na superfície. Não tire a média sem comentar.

Se o usuário medir a distância diretamente com a trena, aceite, mas sugira conferir com um par.

## Etapa 3: altura da água cheia (`ALTURA_AGUA_CHEIA_CM`)

Com a boia fechada (caixa cheia, água da rua parada), meça a altura da água a partir do fundo. Também dá para calcular com uma leitura do sensor: `DIST_SENSOR_FUNDO_CM - distancia_cm`.

**Verifique a zona cega:** `DIST_SENSOR_FUNDO_CM - ALTURA_AGUA_CHEIA_CM` precisa ser ≥ 25 cm. O sensor não mede abaixo de 22 cm (`DIST_MIN_CM`), e com a caixa cheia ele vai dar `erro_sensor`. Se não der, avise que o sensor precisa subir mais no cano (veja "Instalação do sensor" no README). Não tente resolver baixando `DIST_MIN_CM`.

## Etapa 4: fator de correção (`FATOR_CORRECAO`)

Só ajuste com um volume conhecido de pelo menos ~50 L. Uma caixa de 500 L tem ~9 L por cm e o sensor oscila ~0,5 cm, então volumes pequenos dão um fator sem sentido. Métodos:

- **Hidrômetro da rua:** sem ninguém usar água, anote o hidrômetro e a altura, deixe a caixa encher bastante e anote de novo. Volume real = diferença do hidrômetro × 1000 (m³ → L).
- **Baldes:** tire N baldes de volume conhecido e anote a altura antes e depois.

Calcule o volume da fórmula entre as duas alturas, sem fator:

```
python -I .claude/skills/calibrar/volume.py --fundo <D_FUNDO> --topo <D_TOPO> --parede <PAREDE> --cheia <CHEIA> --entre <H1> <H2>
```

`FATOR_CORRECAO = volume_real / volume_calculado`, arredondado para 2 casas. Fora de 0,90–1,10, desconfie das medidas (diâmetros, altura) antes de aceitar o fator e diga isso. Sem volume de referência, deixe `1.0`.

## Etapa 5: aplicar

1. Mostre uma tabela com o valor antigo e o novo de cada `#define` e peça confirmação.
2. Edite só os `#define` que mudaram em `CaixaDagua.ino`. Mantenha o comentário de cada linha.
3. Gere a tabela do README:

   ```
   python -I .claude/skills/calibrar/volume.py --fundo ... --topo ... --parede ... --cheia ... --fator ...
   ```

   Substitua a tabela "Volume calculado por altura da água" do [README.md](../../../README.md). Se os diâmetros ou a altura mudaram, atualize também a tabela "Medidas da caixa".
4. Se a capacidade mudou de 470 L ou a altura cheia mudou de 52 cm, atualize também:
   - `_capacidade` e o `52` em `_DemoCaixaService` ([app/lib/services/caixa_service.dart](../../../app/lib/services/caixa_service.dart));
   - o exemplo `capacidade_litros: 470` na seção "Dados no Firebase" do README;
   - a menção a 470 L / 52 cm no [CLAUDE.md](../../../CLAUDE.md).
5. Compare os "litros por cm" que o script mostra com o pressuposto do app (≈ 10 L por cm, usado em `limiarRuidoLitros` e `limiarVazamentoLitrosPorHora` de [analise.dart](../../../app/lib/models/analise.dart)). Se a diferença passar de ~30%, **avise** e não mude esses limiares sozinho.
6. Se a calibração estiver concluída, marque "Calibração" como ✅ na tabela "Status atual" do README.
7. Lembre que o firmware precisa ser compilado e gravado de novo (`/firmware`) para valer.

## Resumo final

Liste os valores aplicados, de onde veio cada um (medido, calculado ou fábrica) e o que ficou pendente (ex.: fator sem referência).
