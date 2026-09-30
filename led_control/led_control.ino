#include <string.h>

// AMB82-MINI: HIGH = on, LOW = off.
bool blueOn = false;
bool greenOn = false;
char lineBuffer[96];
size_t lineLength = 0;
bool discardLine = false;

void reply(const char *id, const char *result) {
  Serial.print("ACK ");
  Serial.print(id);
  Serial.print(' ');
  Serial.print(result);
  Serial.print(" BLUE=");
  Serial.print(blueOn ? 1 : 0);
  Serial.print(" GREEN=");
  Serial.println(greenOn ? 1 : 0);
}

void processLine() {
  // Exactly eight hexadecimal characters identify each request.
  if (lineLength < 10 || lineBuffer[8] != ' ') {
    reply("00000000", "ERR_FORMAT");
    return;
  }
  for (size_t i = 0; i < 8; ++i) {
    const char c = lineBuffer[i];
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
      reply("00000000", "ERR_FORMAT");
      return;
    }
  }
  lineBuffer[8] = '\0';
  const char *command = lineBuffer + 9;
  if (strcmp(command, "BLUE_ON") == 0) {
    blueOn = true;
  } else if (strcmp(command, "GREEN_ON") == 0) {
    greenOn = true;
  } else if (strcmp(command, "ALL_OFF") == 0) {
    blueOn = false;
    greenOn = false;
  } else if (strcmp(command, "STATUS") != 0) {
    reply(lineBuffer, "ERR_COMMAND");
    return;
  }
  digitalWrite(LED_B, blueOn ? HIGH : LOW);
  digitalWrite(LED_G, greenOn ? HIGH : LOW);
  reply(lineBuffer, "OK");
}

void setup() {
  pinMode(LED_B, OUTPUT);
  pinMode(LED_G, OUTPUT);
  digitalWrite(LED_B, LOW);
  digitalWrite(LED_G, LOW);
  Serial.begin(115200);
  Serial.println("READY AMB82_LED_CONTROL_V1");
}

void loop() {
  while (Serial.available() > 0) {
    const char c = (char)Serial.read();
    if (c == '\n') {
      if (discardLine) {
        reply("00000000", "ERR_FRAME");
      } else {
        if (lineLength > 0 && lineBuffer[lineLength - 1] == '\r') {
          --lineLength;
        }
        lineBuffer[lineLength] = '\0';
        if (lineLength > 0) processLine();
      }
      lineLength = 0;
      discardLine = false;
    } else if (!discardLine) {
      // Reject the entire frame, never execute a truncated command.
      if (lineLength >= sizeof(lineBuffer) - 1 || c == '\0') {
        discardLine = true;
      } else {
        lineBuffer[lineLength++] = c;
      }
    }
  }
  delay(1);
}
