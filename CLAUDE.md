# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão geral

Monitor de nível de uma caixa d'água Fortlev 500 L, em três partes que se falam pelo Firebase Realtime Database (projeto `caixadagua-b3d63`):

1. **Firmware ESP32** ([Arduino/CaixaDagua/CaixaDagua.ino](Arduino/CaixaDagua/CaixaDagua.ino)): lê o sensor JSN-SR04T, converte distância → altura → litros e grava no Firebase.
2. **Regras do banco** ([firebase/database.rules.json](firebase/database.rules.json)).
3. **App Flutter** ([app/](app)): só lê os dados. Todo cálculo de consumo e vazamento acontece no app, não no ESP32.

Código, identificadores, comentários e README estão em português. Mantenha assim.

## Comandos

App Flutter (rodar dentro de `app/`):

```
flutter pub get
flutter analyze
flutter test                                   # todos os testes
flutter test test/analise_test.dart            # um arquivo
flutter test --plain-name "queda contínua"     # um teste pelo nome
flutter run                                    # precisa de login no Firebase
flutter run --dart-define=DEMO=true            # dados simulados, sem Firebase e sem login
```

Regras do banco (rodar na **raiz** do repositório, onde está o `firebase.json` que aponta para as regras; o `app/firebase.json` é só configuração do FlutterFire):

```
firebase deploy --only database
```

Firmware: compilado pela Arduino IDE (placa **ESP32 Dev Module**, core esp32 3.3.12, biblioteca "Firebase Arduino Client Library for ESP8266 and ESP32" da Mobizt). O `arduino-cli` não está instalado nesta máquina. Para compilar é preciso `Arduino/CaixaDagua/secrets.h`, copiado de `secrets.example.h`; ele fica no `.gitignore`.

## Contrato de dados (Firebase)

O formato em `/caixadagua` é compartilhado. Ao mudar um campo, atualize **todos** estes lugares juntos:

- `enviarLeitura()` no firmware (quem escreve);
- `Leitura.fromMap` / `PontoHistorico.fromMap` em [app/lib/models/leitura.dart](app/lib/models/leitura.dart) (quem lê);
- `_DemoCaixaService` em [app/lib/services/caixa_service.dart](app/lib/services/caixa_service.dart) (dados simulados);
- o teste `Leitura.fromMap` em [app/test/widget_test.dart](app/test/widget_test.dart);
- a seção "Dados no Firebase" do [README.md](README.md);
- as regras, se o caminho mudar.

Pontos importantes:

- `/caixadagua/atual` é sobrescrito a cada 1 min. Com o sensor em erro, o firmware só atualiza `status: "erro_sensor"` e `timestamp` (via `updateNode`), e os litros antigos continuam lá. Por isso o app usa `sensorOk` antes de confiar nos números.
- `/caixadagua/historico` recebe um `push` a cada 15 min, só com `litros`, `percentual` e `timestamp`. O app consulta com `orderByChild('timestamp')`, que depende do `.indexOn` nas regras.
- `timestamp` é o horário do servidor (`{".sv": "timestamp"}`), em ms.
- Só o usuário `esp@caixadagua.com` pode escrever. Qualquer usuário autenticado pode ler.
- O app considera o sensor offline quando passam 5 min sem leitura (`Leitura.estaOnline`). Isso depende do intervalo de 1 min do firmware.

## Arquitetura do app

- [main.dart](app/lib/main.dart): com `modoDemo`, vai direto para a `HomePage` sem inicializar o Firebase. Sem ele, `authStateChanges` escolhe entre `LoginPage` e `BloqueioGate(HomePage)`. O `BloqueioGate` pede biometria se ela estiver ativada.
- `CaixaService` é uma interface com duas implementações escolhidas pela flag `DEMO` (`bool.fromEnvironment`): Firebase real ou simulação determinística de 7 dias (`Random(42)`, com vazamento nas duas últimas madrugadas). Use o modo demo para verificar mudanças de UI.
- [models/analise.dart](app/lib/models/analise.dart) tem funções puras (sem Flutter nem Firebase), cobertas por [test/analise_test.dart](app/test/analise_test.dart): mediana móvel de 3 pontos, consumo que ignora quedas abaixo de 10 L e subidas, e vazamento por regressão linear entre 2h e 5h (≥ 3 L/h). A explicação dos algoritmos e das limitações está no README.
- `CartaoClima` é a única parte do app que não usa o Firebase. Ele chama a Open-Meteo direto pelo pacote `http` (coordenadas do Grajaú, SP, em `ClimaService`), busca a cada 15 min e funciona também no modo demo. Nos testes, injete um `MockClient` (`package:http/testing.dart`) pelo construtor; não faça chamadas reais.
- `BiometriaService` guarda e-mail e senha no `flutter_secure_storage` e refaz o login com eles. Biometria só funciona no Android.

## Constantes acopladas à geometria da caixa

A calibração fica nos `#define` do topo do `.ino` (`DIST_SENSOR_FUNDO_CM`, `ALTURA_AGUA_CHEIA_CM`, diâmetros, `FATOR_CORRECAO`). Alguns valores do app dependem dessa mesma geometria e **não** são lidos do firmware:

- `limiarRuidoLitros = 10` e `limiarVazamentoLitrosPorHora = 3.0` em `analise.dart` foram escolhidos como ≈ 1 cm de água na Fortlev 500 L.
- O `_DemoCaixaService` usa capacidade fixa de 470 L e altura cheia de 52 cm.
- A tabela altura × litros do README sai da fórmula do tronco de cone em `volumeLitros()`.

Se a caixa ou a calibração mudarem, revise esses pontos.

## Skills do projeto

Ficam em `.claude/skills/`:

- `/calibrar`: calibração guiada. Usa `volume.py`, que tem a mesma fórmula de `volumeLitros()`; se mudar a fórmula no firmware, mude no script também.
- `/firmware`: compila, grava e lê o serial com `arduino-cli`.
- `/verificar-app`: `flutter analyze`, `flutter test` e app em modo demo.

## README

O README tem uma tabela "Status atual" com o andamento de cada parte (firmware ainda não testado com o sensor, instalação e calibração pendentes, alertas não iniciados). Atualize essa tabela quando uma etapa for concluída.
