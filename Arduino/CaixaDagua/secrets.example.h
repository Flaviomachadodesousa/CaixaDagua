// Copie este arquivo para secrets.h e preencha com seus dados.
// O secrets.h está no .gitignore e não deve ser enviado ao git.

// --- Wi-Fi (rede 2.4 GHz) ---
#define WIFI_SSID     "nome_da_rede"
#define WIFI_PASSWORD "senha_da_rede"

// --- Firebase ---
// Configurações do projeto > Geral > Chave de API da Web
#define API_KEY      "sua_api_key"
#define DATABASE_URL "https://caixadagua-b3d63-default-rtdb.firebaseio.com/"

// Usuário criado em Authentication > Users (provedor E-mail/senha)
#define USER_EMAIL    "esp@caixadagua.com"
#define USER_PASSWORD "senha_do_usuario_esp"

// --- Atualização pela rede (OTA) ---
// Pedida pela Arduino IDE ao gravar pela rede. Invente uma; não precisa ser a do Wi-Fi.
#define OTA_PASSWORD "senha_para_gravar_pela_rede"
