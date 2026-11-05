---
name: firmware
description: Compila o firmware do ESP32 (Arduino/CaixaDagua) com arduino-cli, grava na placa pela porta COM e lê o Monitor Serial a 115200. Use quando o usuário quiser compilar, gravar, fazer upload do firmware ou ver a saída serial do ESP32.
argument-hint: "[compilar | gravar | serial] [COMx]"
---

# Firmware do ESP32

Sketch: `Arduino/CaixaDagua`. Placa: ESP32 Dev Module (`esp32:esp32:esp32`). Rode tudo no **Git Bash**, a partir da raiz do repositório.

`$ARGUMENTS` pode restringir a tarefa:

- `compilar`: só compila;
- `gravar`: compila e grava (padrão);
- `serial`: só lê a saída serial.

Uma porta `COMx` em `$ARGUMENTS` dispensa a detecção.

## 1. Pré-requisitos

1. **arduino-cli**: `command -v arduino-cli`. Se não existir, diga ao usuário que a skill precisa dele e **pergunte** antes de instalar com `winget install ArduinoSA.CLI`. Depois da instalação, o terminal atual pode não enxergar o PATH novo. Procure o executável em `/c/Program\ Files/Arduino\ CLI/` ou peça ao usuário para reabrir o VS Code.
2. **Core e biblioteca**: rode `arduino-cli core list` e `arduino-cli lib list`. Se faltar algo, instale (é demorado na primeira vez, use timeout longo):

   ```
   arduino-cli config init --overwrite   # só se não houver config
   arduino-cli config add board_manager.additional_urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
   arduino-cli core update-index
   arduino-cli core install esp32:esp32@3.3.12
   arduino-cli lib install "Firebase Arduino Client Library for ESP8266 and ESP32"
   ```

   O projeto foi validado com o core **3.3.12**. Se houver outra versão instalada, avise e não troque sem perguntar.
3. **secrets.h**: confira se `Arduino/CaixaDagua/secrets.h` existe. Se não existir, **pare** e explique: copiar `secrets.example.h` para `secrets.h` e preencher Wi-Fi (rede 2,4 GHz), `API_KEY` e a senha do usuário `esp@caixadagua.local`. Não crie o arquivo com valores inventados e nunca mostre o conteúdo dele na resposta (tem senhas).

## 2. Compilar

```
arduino-cli compile --fqbn esp32:esp32:esp32 Arduino/CaixaDagua
```

Em caso de sucesso, informe o uso de flash e RAM que o comando mostra. Em caso de erro, mostre a primeira mensagem de erro real e corrija se for do código. Erros de biblioteca ou core voltam para a etapa 1.

## 3. Gravar

1. `arduino-cli board list` para achar a porta. Se houver mais de uma porta serial, ou nenhuma, pergunte ao usuário. Sem porta, sugira conferir o cabo USB (precisa ser de dados) e o driver CP210x/CH340.
2. A porta não pode estar aberta em outro programa (Monitor Serial da Arduino IDE, outro `arduino-cli monitor`).
3. Grave:

   ```
   arduino-cli upload -p COMx --fqbn esp32:esp32:esp32 Arduino/CaixaDagua
   ```

   Se travar em `Connecting...`, peça para segurar o botão **BOOT** da placa até começar a gravação.

## 4. Monitor Serial

O `arduino-cli monitor` não termina sozinho. Capture por um tempo limitado:

```
timeout 90 arduino-cli monitor -p COMx -c baudrate=115200 --quiet
```

Saída esperada depois do reset:

- `Conectando a rede <SSID>` seguido de pontos, e depois `Conectado: <IP>`. Pontos sem fim indicam SSID ou senha errados, ou rede de 5 GHz;
- a primeira leitura sai assim que o Firebase fica pronto, e depois uma a cada 1 min: `Distancia: X cm | Altura: Y cm | Z L | P%`;
- `Erro ao enviar leitura: ...` indica problema de credencial ou de regra. Confira `API_KEY`, o usuário do ESP no Authentication e o e-mail em [firebase/database.rules.json](../../../firebase/database.rules.json);
- nenhuma linha de `Distancia` depois de conectar significa `erro_sensor` (status gravado sem print). Confira as ligações TRIG/ECHO, o divisor de tensão e se a água não está a menos de 22 cm do sensor.

Resuma o que aconteceu (conectou? leituras plausíveis?). Para calibrar com essas leituras, use `/calibrar`.
