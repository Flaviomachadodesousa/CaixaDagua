---
name: firmware
description: Compila o firmware do ESP32 (Arduino/CaixaDagua) com arduino-cli, grava na placa pela porta COM ou pela rede (OTA) e lê o Monitor Serial a 115200. Use quando o usuário quiser compilar, gravar, fazer upload do firmware, atualizar o ESP32 já instalado ou ver a saída serial.
argument-hint: "[compilar | gravar | ota | serial] [COMx | IP]"
---

# Firmware do ESP32

Sketch: `Arduino/CaixaDagua`. Placa: ESP32 Dev Module com o esquema de partições Minimal SPIFFS. FQBN: `esp32:esp32:esp32:PartitionScheme=min_spiffs`. Rode tudo no **Git Bash**, a partir da raiz do repositório.

Use **sempre** esse FQBN. No esquema padrão o sketch ocupa ~96% da partição de app. Além disso, o esquema de partições só muda pelo USB: gravar com outro esquema pode deixar uma placa já instalada sem espaço para OTA.

`$ARGUMENTS` pode restringir a tarefa:

- `compilar`: só compila;
- `gravar`: compila e grava pelo USB (padrão);
- `ota`: compila e grava pela rede;
- `serial`: só lê a saída serial.

Uma porta `COMx` ou um IP em `$ARGUMENTS` dispensa a detecção.

## 1. Pré-requisitos

1. **arduino-cli**: `command -v arduino-cli`. Se não estiver no PATH, use o que vem embutido na Arduino IDE: `/c/Program Files/Arduino IDE/resources/app/lib/backend/resources/arduino-cli.exe`. Ele usa as mesmas pastas de core e bibliotecas da IDE. O shell não guarda variáveis entre comandos, então comece cada comando com `CLI="<caminho>";` e chame `"$CLI"`. Só se nenhum dos dois existir, diga ao usuário que a skill precisa dele e **pergunte** antes de instalar com `winget install ArduinoSA.CLI`.
2. **Core e biblioteca**: rode `core list` e `lib list`. Se faltar algo, instale (é demorado na primeira vez, use timeout longo ou rode em segundo plano). O `--additional-urls` evita mexer na configuração da IDE:

   ```
   URL=https://espressif.github.io/arduino-esp32/package_esp32_index.json
   "$CLI" core update-index --additional-urls $URL
   "$CLI" core install esp32:esp32@3.3.12 --additional-urls $URL
   "$CLI" lib install "Firebase Arduino Client Library for ESP8266 and ESP32"
   ```

   O projeto foi validado com o core **3.3.12**. Se houver outra versão instalada, avise e não troque sem perguntar.
3. **secrets.h**: confira se `Arduino/CaixaDagua/secrets.h` existe e se tem `OTA_PASSWORD` (`grep -q '^#define OTA_PASSWORD' Arduino/CaixaDagua/secrets.h`). Se faltar o arquivo ou a senha, **pare** e explique: copiar `secrets.example.h` para `secrets.h` (ou acrescentar a linha que falta) e preencher Wi-Fi (rede 2,4 GHz), `API_KEY`, a senha do usuário `esp@caixadagua.com` e uma `OTA_PASSWORD` inventada. Não crie nem complete o arquivo com valores inventados e nunca mostre o conteúdo dele na resposta (tem senhas).

## 2. Compilar

```
"$CLI" compile --fqbn esp32:esp32:esp32:PartitionScheme=min_spiffs Arduino/CaixaDagua
```

Em caso de sucesso, informe o uso de flash e RAM que o comando mostra. Em caso de erro, mostre a primeira mensagem de erro real e corrija se for do código. Erros de biblioteca ou core voltam para a etapa 1.

## 3a. Gravar pelo USB

Obrigatório na primeira gravação e sempre que for preciso ver o serial.

1. `"$CLI" board list` para achar a porta. Se houver mais de uma porta serial, ou nenhuma, pergunte ao usuário. Sem porta, sugira conferir o cabo USB (precisa ser de dados) e o driver CP210x/CH340.
2. A porta não pode estar aberta em outro programa (Monitor Serial da Arduino IDE, outro `monitor`).
3. Grave:

   ```
   "$CLI" upload -p COMx --fqbn esp32:esp32:esp32:PartitionScheme=min_spiffs Arduino/CaixaDagua
   ```

   Se travar em `Connecting...`, peça para segurar o botão **BOOT** da placa até começar a gravação.

## 3b. Gravar pela rede (OTA)

Para a placa já instalada na caixa. Ela precisa ter recebido pelo USB um firmware com OTA, e o computador tem que estar na mesma rede.

1. Ache o IP: `"$CLI" board list` mostra a porta de rede `caixadagua` (protocolo `network`). Se não aparecer, pergunte o IP ao usuário (ele aparece no roteador ou no serial como `Conectado: <IP>`).
2. Grave, lendo a senha do `secrets.h` sem mostrá-la:

   ```
   "$CLI" upload -p <IP> --protocol network --fqbn esp32:esp32:esp32:PartitionScheme=min_spiffs \
     --upload-field password="$(sed -n 's/^#define OTA_PASSWORD *"\(.*\)".*/\1/p' Arduino/CaixaDagua/secrets.h)" \
     Arduino/CaixaDagua
   ```

3. Falhas comuns: `No response from device` costuma ser o firewall do Windows bloqueando o `espota.exe` (liberar para redes privadas) ou a placa em outra rede. `Authentication Failed` é a senha diferente da que está gravada na placa.

Depois de gravar, a placa reinicia. Confirme pelo app ou pelo Firebase (`/caixadagua/atual` com `timestamp` novo em até 1 min).

## 4. Monitor Serial

Só pelo USB. O `monitor` não termina sozinho. Capture por um tempo limitado:

```
timeout 90 "$CLI" monitor -p COMx -c baudrate=115200 --quiet
```

Saída esperada depois do reset:

- `Conectando a rede <SSID>` seguido de pontos, e depois `Conectado: <IP>`. Se em 30 s não conectar, aparece `Sem Wi-Fi. Reiniciando...` e tudo recomeça. Isso em loop indica SSID ou senha errados, ou rede de 5 GHz;
- a primeira leitura sai assim que o Firebase fica pronto, e depois uma a cada 1 min: `Distancia: X cm | Altura: Y cm | Z L | P%`;
- `Erro ao enviar leitura: ...` indica problema de credencial ou de regra. Confira `API_KEY`, o usuário do ESP no Authentication e o e-mail em [firebase/database.rules.json](../../../firebase/database.rules.json). Depois de 15 min sem nenhum envio aceito, a placa reinicia (`Nenhum envio aceito pelo Firebase em 15 min. Reiniciando...`);
- nenhuma linha de `Distancia` depois de conectar significa `erro_sensor` (status gravado sem print). Confira as ligações TRIG/ECHO, o divisor de tensão e se a água não está a menos de 22 cm do sensor;
- `task_wdt` / `Task watchdog got triggered` seguido de reinício: o loop ficou mais de 2 min parado. Mostre o trecho ao usuário.

Resuma o que aconteceu (conectou? leituras plausíveis?). Para calibrar com essas leituras, use `/calibrar`.
