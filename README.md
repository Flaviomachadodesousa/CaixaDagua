# CaixaDagua
 Projeto Arduino + Flutter + Firebase

Mede o volume de água de uma caixa d'água Fortlev 500 L com um sensor ultrassônico e envia os dados para o Firebase Realtime Database, para serem mostrados em um app Flutter.

## Status atual

| Parte | Situação |
|---|---|
| Firmware ESP32 ([Arduino/CaixaDagua](Arduino/CaixaDagua)) | ✅ Pronto e compilando (esp32 3.3.12, ESP32 Dev Module). Ainda **não testado** com o sensor ligado. |
| Regras do Firebase ([firebase/database.rules.json](firebase/database.rules.json)) | ✅ Escritas. Falta publicar no console. |
| Instalação física do sensor | ⏳ Pendente |
| Calibração | ⏳ Pendente |
| App Flutter ([app](app)) | 🚧 Iniciado: login, nível em tempo real e gráfico das últimas 24 h. Falta rodar `flutterfire configure`. |
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
| TRIG | GPIO18 |
| ECHO | GPIO19 (via divisor de tensão) |

```
ECHO --[1k]--+--> GPIO19
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

1. **Authentication → Método de login:** ative **E-mail/senha**.
2. **Authentication → Users:** crie o usuário do ESP (ex.: `esp@caixadagua.local`).
3. **Configurações do projeto → Geral:** copie a **Chave de API da Web**.
4. **Realtime Database → Regras:** cole o conteúdo de [firebase/database.rules.json](firebase/database.rules.json). Se o e-mail do ESP for diferente, troque nas regras.

### 3. Credenciais

Copie `Arduino/CaixaDagua/secrets.example.h` para `Arduino/CaixaDagua/secrets.h` e preencha. O `secrets.h` está no `.gitignore` e não vai para o git.

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
- **Tela principal** com o desenho da caixa preenchido até o nível atual, os litros, o percentual e o status do sensor (online, erro no sensor ou sem atualização há mais de 5 min).
- **Gráfico** do nível nas últimas 24 horas.

### Configurar e rodar

1. No console do Firebase, em **Authentication → Users**, crie um usuário para você (diferente do usuário do ESP).
2. Gere a configuração do Firebase para o app. O comando registra os apps no projeto e sobrescreve o arquivo provisório `lib/firebase_options.dart`:

   ```
   dart pub global activate flutterfire_cli
   cd app
   flutterfire configure --project=caixadagua-b3d63
   ```

3. Rode o app:

   ```
   flutter run
   ```

### Estrutura

| Arquivo | Conteúdo |
|---|---|
| `lib/main.dart` | Inicialização do Firebase e troca entre login e tela principal |
| `lib/models/leitura.dart` | Conversão dos dados do Firebase |
| `lib/services/caixa_service.dart` | Leitura em tempo real de `atual` e `historico` |
| `lib/pages/` | Telas de login e principal |
| `lib/widgets/` | Desenho da caixa e gráfico do histórico |