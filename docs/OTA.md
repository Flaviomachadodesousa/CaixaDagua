# Gravação do firmware pela rede (OTA)

Com o OTA, dá para atualizar o firmware do ESP32 pelo Wi-Fi, sem tirar a placa da caixa d'água. A placa aparece na Arduino IDE como a porta de rede **caixadagua**, protegida pela senha `OTA_PASSWORD`.

## 1. Preparação (uma vez só, pelo cabo USB)

O OTA só funciona depois que a placa recebe, pelo USB, um firmware que já tem OTA.

1. No `Arduino/CaixaDagua/secrets.h`, acrescente uma senha inventada por você (não precisa ser a do Wi-Fi):

   ```
   #define OTA_PASSWORD "uma_senha_qualquer"
   ```

   Sem essa linha o sketch não compila.

2. Na Arduino IDE, em **Ferramentas**:

   | Opção | Valor |
   |---|---|
   | Placa | **ESP32 Dev Module** |
   | Partition Scheme | **Minimal SPIFFS (1.9MB APP with OTA/128KB SPIFFS)** |
   | Porta | a **COMx** do cabo USB |

3. Clique em **Carregar**.
4. Abra o Monitor Serial (115200 baud) e confira se aparece `Conectado: 192.168.x.x`. Anote esse IP. Ele também aparece na lista de dispositivos do roteador.

> **Por que Minimal SPIFFS?** No esquema padrão, o firmware ocupa 96% do espaço e qualquer acréscimo deixa de caber. O esquema de partições só muda pelo USB. Por isso, defina antes da primeira gravação e mantenha sempre o mesmo.

## 2. Gravar pela rede (toda vez)

1. O ESP32 tem que estar ligado e na **mesma rede Wi-Fi do computador**. Rede de convidados ou roteador com "isolamento de clientes" impedem a gravação.
2. Em **Ferramentas → Porta**, na parte de **portas de rede**, escolha **caixadagua at 192.168.x.x**.
3. Clique em **Carregar**. Quando a IDE pedir a senha, digite a `OTA_PASSWORD`.
4. Na primeira vez, o Windows pode perguntar se libera o **espota** no firewall. Marque **Redes privadas** e permita.
5. A IDE mostra `Uploading: [====] 100% Done` e a placa reinicia. Em até 1 minuto o app volta a mostrar leituras novas.

### Pela linha de comando

Também dá para gravar sem abrir a IDE, com o `arduino-cli` que vem junto com ela. Rode no Git Bash, na raiz do repositório, trocando o IP:

```
CLI="/c/Program Files/Arduino IDE/resources/app/lib/backend/resources/arduino-cli.exe"
"$CLI" compile --fqbn esp32:esp32:esp32:PartitionScheme=min_spiffs Arduino/CaixaDagua
"$CLI" upload -p 192.168.x.x --protocol network \
  --fqbn esp32:esp32:esp32:PartitionScheme=min_spiffs \
  --upload-field password="$(sed -n 's/^#define OTA_PASSWORD *"\(.*\)".*/\1/p' Arduino/CaixaDagua/secrets.h)" \
  Arduino/CaixaDagua
```

O `sed` lê a senha do `secrets.h`, então ela não fica no histórico do terminal.

No Claude Code, a skill `/firmware ota` (ou `/firmware ota 192.168.x.x`) faz o mesmo.

## 3. Se der problema

| Sintoma | O que fazer |
|---|---|
| A porta **caixadagua** não aparece na IDE | Espere 1 minuto ou reinicie a IDE. No Windows, a busca de dispositivos na rede (mDNS) às vezes falha. Nesse caso, grave pela linha de comando usando o IP direto. |
| `No response from device` | Quase sempre é o firewall bloqueando o `espota`. Confira também se a rede Wi-Fi do Windows está como **Privada**, e não Pública (Configurações → Rede e Internet). |
| `Authentication Failed` | A senha digitada não é a que está gravada na placa. |
| A placa não aparece de jeito nenhum | Ela pode estar sem Wi-Fi. Sem conexão, o ESP32 reinicia a cada 30 s e não aceita OTA. Só resolve pelo USB. |

## 4. Cuidados

- **Se a gravação falhar no meio, a placa continua com o firmware antigo.** O OTA grava na outra metade da memória e só troca no final, então uma queda de conexão não estraga a placa.
- **Só perde o OTA o firmware que não conectar no Wi-Fi.** Se você mudar o nome ou a senha da rede no `secrets.h` e errar, a placa não volta para a rede, e aí só pelo USB. Teste mudanças desse tipo na bancada antes de instalar.
- **Mudar a `OTA_PASSWORD` só vale depois que o firmware novo é gravado.** Na gravação que troca a senha, digite a senha antiga.
- **Pela rede não existe Monitor Serial.** Para ver a saída, só pelo cabo.
- **Mantenha sempre o Partition Scheme em Minimal SPIFFS**, inclusive nas gravações pela rede.
