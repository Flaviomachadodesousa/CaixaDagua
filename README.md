# Olho d'Água
 De olho na sua caixa d'água · Projeto Arduino + Flutter + Firebase

Mede o volume de água de uma caixa d'água Fortlev 500 L com um sensor ultrassônico e envia os dados para o Firebase Realtime Database, para serem mostrados em um app Flutter.

## Status atual

| Parte | Situação |
|---|---|
| Firmware ESP32 ([Arduino/CaixaDagua](Arduino/CaixaDagua)) | ✅ Pronto e compilando (esp32 3.3.12, ESP32 Dev Module). Ainda **não testado** com o sensor ligado. |
| Regras do Firebase ([firebase/database.rules.json](firebase/database.rules.json)) | ✅ Publicadas (`firebase deploy --only database`). |
| Login no Firebase | ⏳ Falta ativar **E-mail/senha** e criar os usuários no console. |
| Instalação física do sensor | ⏳ Pendente |
| Calibração | ⏳ Pendente |
| App Flutter ([app](app)) | ✅ Login, nível em tempo real e gráfico das últimas 24 h. Registrado no Firebase (Android e Web). |
| Alertas (nível baixo, sensor offline) | ⏳ Não iniciado |


## Como funciona

1. O sensor JSN-SR04T, preso acima da tampa, mede a distância até a superfície da água.
2. O ESP32 faz 15 leituras e usa a mediana, descartando leituras ruins.
3. A distância é convertida em **altura da água** e depois em **litros**. A caixa tem formato de tronco de cone, então o volume é:

   ```
   r(h) = r_fundo + (r_topo − r_fundo) × h / H
   L    = π × h × (r_fundo² + r_fundo·r(h) + r(h)²) / 3 / 1000
   ```

4. A cada 1 minuto grava a leitura atual no Firebase. A cada 15 minutos grava também um registro no histórico.

## Hardware

- ESP32 DevKit
- Sensor ultrassônico à prova d'água **JSN-SR04T**
- Resistores de 1 kΩ e 2 kΩ (divisor de tensão)
- Fonte USB 5 V (tomada)
- Caixa vedada (IP65) para o ESP32
- Cano PVC 100 mm (~15 cm) para elevar o sensor

### Ligações

| JSN-SR04T | ESP32 |
|---|---|
| 5V | VIN / 5V |
| GND | GND |
| TRIG | GPIO26 |
| ECHO | GPIO27 (via divisor de tensão) |

```
ECHO --[1k]--+--> GPIO27
             |
           [2k]
             |
            GND
```

O ECHO sai em 5 V e o ESP32 aceita só 3,3 V. **Não ligue o ECHO direto no ESP32.**

### Instalação do sensor

O JSN-SR04T **não mede nada a menos de ~22 cm**. Com a caixa cheia, um sensor preso direto na tampa fica perto demais da água. Por isso:

- Faça um furo no centro da tampa e prenda o sensor no alto de um cano PVC de 100 mm, de modo que ele fique **10 a 15 cm acima da tampa**.
- Aponte o sensor longe da entrada de água e da boia.

## Medidas da caixa

Fortlev 500 L, modelo 02010005 (medidas do fabricante; confira com uma trena):

| Medida | Valor |
|---|---|
| Diâmetro do fundo | 95 cm |
| Diâmetro do topo | 122 cm |
| Altura sem tampa | 58 cm |
| Altura com tampa | 72 cm |

Volume calculado por altura da água:

| Altura | Litros |
|---|---|
| 10 cm | ~74 L |
| 22 cm | ~173 L |
| 34 cm | ~283 L |
| 46 cm | ~405 L |
| 52 cm | ~470 L |
| 58 cm (borda) | ~539 L |

## Configuração

### 1. Arduino IDE

1. Em **Preferências → URLs adicionais**, adicione:
   `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
2. Em **Gerenciador de Placas**, instale **esp32** (Espressif Systems).
3. Em **Gerenciador de Bibliotecas**, instale **Firebase Arduino Client Library for ESP8266 and ESP32** (Mobizt).
4. Selecione a placa **ESP32 Dev Module**.

### 2. Firebase

Projeto: `caixadagua-b3d63`.

1. **Authentication → Método de login:** ative **E-mail/senha**.
2. **Authentication → Users:** crie dois usuários:
   - o do ESP: `esp@caixadagua.local`;
   - o seu, para entrar no app.
3. As regras do banco ficam em [firebase/database.rules.json](firebase/database.rules.json). Para publicar depois de alterar, rode na raiz do repositório:

   ```
   firebase deploy --only database
   ```

   Se o e-mail do ESP for diferente de `esp@caixadagua.local`, troque nas regras antes de publicar.

### 3. Credenciais

Copie `Arduino/CaixaDagua/secrets.example.h` para `Arduino/CaixaDagua/secrets.h` e preencha. O `secrets.h` está no `.gitignore` e não vai para o git.

A `API_KEY` é a **Chave de API da Web** (Configurações do projeto → Geral).

### 4. Calibração

Ajuste as constantes no topo de [CaixaDagua.ino](Arduino/CaixaDagua/CaixaDagua.ino):

| Constante | O que medir |
|---|---|
| `DIST_SENSOR_FUNDO_CM` | Distância da face do sensor até o fundo da caixa |
| `ALTURA_AGUA_CHEIA_CM` | Altura da água (a partir do fundo) quando a boia fecha |
| `DIAMETRO_FUNDO_CM`, `DIAMETRO_TOPO_CM`, `ALTURA_CAIXA_CM` | Medidas da caixa, se forem diferentes das de fábrica |
| `FATOR_CORRECAO` | Ajuste final, se os litros calculados não baterem com os reais |

Abra o Monitor Serial (115200 baud) e compare a altura mostrada com a medida feita com trena.

## Dados no Firebase

```
caixadagua/
├── atual/
│   ├── status: "ok" | "erro_sensor"
│   ├── distancia_cm: 42.3
│   ├── altura_cm: 37.7
│   ├── litros: 320
│   ├── percentual: 68
│   ├── capacidade_litros: 470
│   └── timestamp: 1760450000000
└── historico/
    └── <push-id>/
        ├── litros: 320
        ├── percentual: 68
        └── timestamp: 1760450000000
```

`timestamp` é o horário do servidor do Firebase, em milissegundos.

## App Flutter

O app fica em [app/](app). Ele tem:

- **Login** com e-mail e senha (Firebase Authentication).
- **Tela principal** com a caixa animada (água em ondas) até o nível atual, o percentual, os litros e o status do sensor: online, erro no sensor ou offline (sem atualização há mais de 5 min).
- **Cartões** com volume, altura da água, consumo estimado (últimas 24 h e média diária de até 7 dias) e horário da última leitura.
- **Vazamento**: analisa a queda de nível entre 2h e 5h nas últimas 7 madrugadas e avisa quando a caixa perde água num horário em que ninguém costuma usar.
- **Gráfico** do nível nas últimas 24 horas ou 7 dias.
- **Login por biometria** (Android): depois do primeiro login com senha, o app oferece ativar a biometria. Com ela ativa, o app pede a digital ao abrir, e a tela de login ganha o botão "Entrar com biometria". Para ligar ou desligar, use o menu ⋮ → "Entrar com biometria". O e-mail e a senha ficam guardados no armazenamento seguro do aparelho (Android Keystore). O celular precisa ter bloqueio de tela e uma digital cadastrada.
- Tema claro e escuro, seguindo a configuração do celular. A fonte Plus Jakarta Sans vem incluída no app (licença em `assets/fonts/OFL.txt`).

### Configurar e rodar

O app já está registrado no Firebase (Android e Web), e a configuração fica em `lib/firebase_options.dart`. Para rodar:

```
cd app
flutter run
```

Entre com o seu usuário (criado no passo 2 da configuração do Firebase).

Para ver o app com dados simulados, sem ESP32 e sem login:

```
flutter run --dart-define=DEMO=true
```

Para adicionar outra plataforma (ex.: iOS), rode na pasta `app`:

```
dart pub global activate flutterfire_cli
flutterfire configure --project=caixadagua-b3d63
```

### Como o consumo e o vazamento são calculados

Tudo sai do histórico (um ponto a cada 15 min), em [lib/models/analise.dart](app/lib/models/analise.dart).

**Consumo**
1. Uma mediana móvel de 3 pontos remove leituras isoladas fora da curva (eco ruim, onda na superfície).
2. Só conta quedas de pelo menos **10 L** (≈ 1 cm na Fortlev 500 L) em relação à última referência. Oscilações menores são ruído do sensor.
3. Subidas são reabastecimento e não entram na conta.

**Vazamento**
- Para cada madrugada (2h–5h), calcula a tendência do volume por mínimos quadrados.
- Perda de **3 L/h ou mais** (≈ 1 cm em 3 h) = possível vazamento.
- Se entrou água da rua nesse horário, a noite fica "inconclusiva". Com menos de 8 leituras, fica "sem dados".

**Limitações (medindo só o nível)**
- Se a água da rua estiver entrando enquanto se consome, a boia repõe o volume e esse consumo **não aparece**.
- Com a caixa cheia e água da rua disponível de madrugada, a boia também repõe o que vaza.
- Para medir o consumo real, é preciso um sensor de vazão na saída da caixa.

### Estrutura

| Arquivo | Conteúdo |
|---|---|
| `lib/main.dart` | Inicialização do Firebase e troca entre login e tela principal |
| `lib/models/leitura.dart` | Conversão dos dados do Firebase |
| `lib/models/analise.dart` | Cálculo do consumo e detecção de vazamento |
| `lib/services/caixa_service.dart` | Leitura em tempo real de `atual` e `historico`, e os dados simulados do modo demonstração |
| `lib/theme.dart` | Cores, tema claro/escuro, fundo e cartões |
| `lib/services/biometria_service.dart` | Biometria (`local_auth`) e credenciais guardadas (`flutter_secure_storage`) |
| `lib/pages/` | Telas de login, bloqueio por biometria e principal |
| `lib/widgets/` | Caixa animada, gráfico, cartões de informação e status |