---
name: verificar-app
description: Verifica o app Flutter da caixa d'água. Roda flutter analyze e flutter test e abre o app em modo demonstração (dados simulados, sem Firebase). Use depois de mudar código em app/ ou quando o usuário pedir para checar, testar ou rodar o app.
argument-hint: "[sem-rodar] [dispositivo]"
---

# Verificar o app Flutter

Todos os comandos rodam dentro de `app/`.

1. **Dependências**: se `pubspec.yaml` mudou ou não existe `.dart_tool/`, rode `flutter pub get`.
2. **Análise**: `flutter analyze`. Corrija erros e avisos que vierem do código alterado nesta sessão. Problemas que já existiam: apenas informe.
3. **Testes**: `flutter test`. Se algum falhar, mostre o nome do teste e a mensagem. Corrija se a falha vier de uma mudança desta sessão. Se a mudança alterou de propósito o comportamento testado (ex.: limiares em `analise.dart`), **pergunte** antes de mudar o teste.
4. **Rodar em modo demonstração**: pule esta etapa se `$ARGUMENTS` contiver `sem-rodar` ou se as etapas 2 e 3 falharam.
   - Dispositivo: use o de `$ARGUMENTS`, se houver. Senão, `flutter devices` e prefira `chrome` (ou `edge`). Um celular Android só se o usuário pedir; ele precisa estar autorizado para depuração USB.
   - Rode em segundo plano (`run_in_background`), porque o comando não termina:

     ```
     flutter run -d chrome --dart-define=DEMO=true
     ```

   - Espere a saída mostrar que o app subiu (`is being served at` / `Flutter run key commands`) ou um erro de compilação, e informe.
   - O modo demo abre direto na tela principal, com 7 dias simulados e vazamento nas duas últimas madrugadas. Assim dá para conferir o cartão de vazamento, o gráfico e os cartões de consumo sem ESP32.
   - Diga ao usuário que o app continua aberto e encerre o processo quando ele pedir ou quando a verificação acabar.

## Resultado

Responda em poucas linhas: analyze (ok / N problemas), testes (X passaram / Y falharam) e se o app abriu no modo demo.
