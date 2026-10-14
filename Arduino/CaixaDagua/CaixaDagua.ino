/*
  CaixaDagua - medição do volume da caixa d'água

  Hardware:
    - ESP32 DevKit
    - Sensor ultrassônico à prova d'água JSN-SR04T
    - Caixa d'água Fortlev 500 L (tronco de cone)

  Ligações:
    JSN-SR04T 5V   -> VIN / 5V (5V do USB)
    JSN-SR04T GND  -> GND
    JSN-SR04T TRIG -> GPIO18
    JSN-SR04T ECHO -> divisor de tensão -> GPIO19
                      ECHO --[1k]--+--> GPIO19
                                   |
                                 [2k]
                                   |
                                  GND

  Bibliotecas (Gerenciador de Bibliotecas do Arduino IDE):
    - "Firebase Arduino Client Library for ESP8266 and ESP32" (Mobizt)

  Credenciais: copie secrets.example.h para secrets.h e preencha.
 */

// ================================================================================
// --- Inclusão das bibliotecas ---
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "secrets.h"

// ================================================================================
// --- Pinos do sensor ---
#define PINO_TRIG 18
#define PINO_ECHO 19

// ================================================================================
// --- Medidas da caixa (cm) ---
// Fortlev 500 L (modelo 02010005). Confira com uma trena e ajuste se preciso.
#define DIAMETRO_FUNDO_CM   95.0
#define DIAMETRO_TOPO_CM   122.0
#define ALTURA_CAIXA_CM     58.0   // altura da parede, sem a tampa

// --- Medidas da instalação (cm) ---
// Distância da face do sensor até o fundo da caixa (meça com trena).
#define DIST_SENSOR_FUNDO_CM 80.0
// Altura da água quando a boia fecha (caixa cheia), medida a partir do fundo.
#define ALTURA_AGUA_CHEIA_CM 52.0

// --- Calibração ---
// Multiplica o volume calculado. Ajuste comparando com o volume real.
#define FATOR_CORRECAO 1.0

// ================================================================================
// --- Leitura do sensor ---
#define NUM_AMOSTRAS       15     // leituras por medição (usa a mediana)
#define MIN_AMOSTRAS_VALIDAS 5
#define DIST_MIN_CM        22.0   // zona cega do JSN-SR04T
#define DIST_MAX_CM       450.0
#define INTERVALO_PING_MS  70     // o JSN-SR04T precisa de ~60 ms entre pings

// --- Envio ao Firebase ---
#define INTERVALO_LEITURA_MS    (60UL * 1000)        // atualiza /atual a cada 1 min
#define INTERVALO_HISTORICO_MS  (15UL * 60 * 1000)   // grava histórico a cada 15 min

#define CAMINHO_ATUAL     "/caixadagua/atual"
#define CAMINHO_HISTORICO "/caixadagua/historico"

// ================================================================================
// --- Variáveis globais ---
FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long ultimaLeitura = 0;
unsigned long ultimoHistorico = 0;
bool primeiroHistorico = true;

// ================================================================================
// --- Sensor ---

// Uma leitura de distância em cm. Retorna -1 se não houve eco.
float lerDistanciaCm() {
  digitalWrite(PINO_TRIG, LOW);
  delayMicroseconds(5);
  digitalWrite(PINO_TRIG, HIGH);
  delayMicroseconds(20);
  digitalWrite(PINO_TRIG, LOW);

  unsigned long duracao = pulseIn(PINO_ECHO, HIGH, 30000UL); // timeout ~5 m
  if (duracao == 0) return -1;

  return duracao * 0.0343 / 2.0;
}

// Faz várias leituras e retorna a mediana das válidas. Retorna -1 em caso de falha.
float medirDistanciaCm() {
  float amostras[NUM_AMOSTRAS];
  int validas = 0;

  for (int i = 0; i < NUM_AMOSTRAS; i++) {
    float d = lerDistanciaCm();
    if (d >= DIST_MIN_CM && d <= DIST_MAX_CM) {
      amostras[validas++] = d;
    }
    delay(INTERVALO_PING_MS);
  }

  if (validas < MIN_AMOSTRAS_VALIDAS) return -1;

  // Ordenação por inserção (poucos elementos)
  for (int i = 1; i < validas; i++) {
    float v = amostras[i];
    int j = i - 1;
    while (j >= 0 && amostras[j] > v) {
      amostras[j + 1] = amostras[j];
      j--;
    }
    amostras[j + 1] = v;
  }

  return amostras[validas / 2];
}

// ================================================================================
// --- Geometria da caixa ---

// Volume (litros) de um tronco de cone com a água na altura h (cm).
// O raio cresce linearmente do fundo até o topo da parede.
float volumeLitros(float h) {
  if (h <= 0) return 0;

  float rFundo = DIAMETRO_FUNDO_CM / 2.0;
  float rTopo = DIAMETRO_TOPO_CM / 2.0;
  float rAgua = rFundo + (rTopo - rFundo) * h / ALTURA_CAIXA_CM;

  float cm3 = PI * h * (rFundo * rFundo + rFundo * rAgua + rAgua * rAgua) / 3.0;
  return cm3 / 1000.0 * FATOR_CORRECAO;
}

// ================================================================================
// --- Firebase ---

void enviarLeitura(float distancia, bool gravarHistorico) {
  FirebaseJson json;

  if (distancia < 0) {
    json.set("status", "erro_sensor");
    json.set("timestamp/.sv", "timestamp");
    if (!Firebase.RTDB.updateNode(&firebaseData, CAMINHO_ATUAL, &json)) {
      Serial.printf("Erro ao enviar status: %s\n", firebaseData.errorReason().c_str());
    }
    return;
  }

  float altura = constrain(DIST_SENSOR_FUNDO_CM - distancia, 0, ALTURA_CAIXA_CM);
  float litros = volumeLitros(altura);
  float capacidade = volumeLitros(ALTURA_AGUA_CHEIA_CM);
  float percentual = constrain(litros / capacidade * 100.0, 0, 100);

  Serial.printf("Distancia: %.1f cm | Altura: %.1f cm | %.0f L | %.0f%%\n",
                distancia, altura, litros, percentual);

  json.set("status", "ok");
  json.set("distancia_cm", round(distancia * 10) / 10.0);
  json.set("altura_cm", round(altura * 10) / 10.0);
  json.set("litros", (int)round(litros));
  json.set("percentual", (int)round(percentual));
  json.set("capacidade_litros", (int)round(capacidade));
  json.set("timestamp/.sv", "timestamp");

  if (!Firebase.RTDB.setJSON(&firebaseData, CAMINHO_ATUAL, &json)) {
    Serial.printf("Erro ao enviar leitura: %s\n", firebaseData.errorReason().c_str());
  }

  if (gravarHistorico) {
    FirebaseJson historico;
    historico.set("litros", (int)round(litros));
    historico.set("percentual", (int)round(percentual));
    historico.set("timestamp/.sv", "timestamp");

    if (!Firebase.RTDB.pushJSON(&firebaseData, CAMINHO_HISTORICO, &historico)) {
      Serial.printf("Erro ao gravar historico: %s\n", firebaseData.errorReason().c_str());
    }
  }
}

// ================================================================================
// --- Setup ---

void setup() {
  Serial.begin(115200);
  Serial.println();

  pinMode(PINO_TRIG, OUTPUT);
  pinMode(PINO_ECHO, INPUT);
  digitalWrite(PINO_TRIG, LOW);

  // Iniciar conexão à rede
  Serial.print("Conectando a rede ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Conectado: ");
  Serial.println(WiFi.localIP());

  // Firebase com usuário/senha (Authentication > E-mail/senha)
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.reconnectWiFi(true);
  Firebase.begin(&config, &auth);
}

// ================================================================================
// --- Loop ---

void loop() {
  unsigned long agora = millis();

  if (!Firebase.ready()) return;
  if (agora - ultimaLeitura < INTERVALO_LEITURA_MS && ultimaLeitura != 0) return;
  ultimaLeitura = agora;

  bool gravarHistorico = primeiroHistorico || agora - ultimoHistorico >= INTERVALO_HISTORICO_MS;
  if (gravarHistorico) {
    ultimoHistorico = agora;
    primeiroHistorico = false;
  }

  enviarLeitura(medirDistanciaCm(), gravarHistorico);
}
