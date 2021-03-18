/*
https://randomnerdtutorials.com/esp8266-weather-forecaster/
 */

// ================================================================================
// --- Inclusão da biblioteca ---
#include <ArduinoJson.h>
#include <ESP8266WiFi.h>
#include <WiFiClient.h>
#include <FirebaseESP8266.h>
// ================================================================================
// --- Configuração Firebase ---
#define FIREBASE_HOST "https://caixadagua-b3d63-default-rtdb.firebaseio.com/"
#define FIREBASE_AUTH "rwOrOdLxje0CuK5y3vRxCG0Z1wFdf9kxZCXSmOXu"
// ================================================================================
// --- Dados de Acesso do seu roteador ---
#define WIFI_SSID "Flavio_2.4"
#define PASS "1qaz2wSX"

WiFiClient client;

// Open Weather Map API server name
const char server[] = "api.openweathermap.org";

// Replace the next line to match your city and 2 letter country code
String nameOfCity = "Diadema,3464739";

// Replace the next line with your API Key
String apiKey = "188b3f564389580a8ebbe6f9367003a4"; 

FirebaseData firebaseData;
bool iterar = true;
float leitura;

void setup() {
 
  Serial.begin(9600);
  
  // Iniciar ligação à rede
  Serial.print("A ligar à rede ");
  Serial.println(WIFI_SSID);
 
  WiFi.begin(WIFI_SSID, PASS);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    }
    Serial.println();
    Serial.print("Conectando: ");
    Serial.println(WiFi.localIP());

    Serial.println("Leitura do potenciometro");
    Serial.println("Valor        Volts");
    
    Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
    Firebase.reconnectWiFi(true);
 
  }

void loop() {
  
      while(iterar){
        Firebase.setFloat(firebaseData, "caixadagua", leitura);
        leitura = (analogRead(A0));
        Serial.println(leitura);
        delay(2000); // 2 segundo
      }

}
