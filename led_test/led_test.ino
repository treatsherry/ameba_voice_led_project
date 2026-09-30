// AMB82-MINI hardware check: blue, off, green, off.
// LED_B = D23 (PF9); LED_G = D24 (PE6).
void setup() {
  Serial.begin(115200);
  pinMode(LED_B, OUTPUT);
  pinMode(LED_G, OUTPUT);
  digitalWrite(LED_B, LOW);
  digitalWrite(LED_G, LOW);
  Serial.println("AMB82_MINI_LED_TEST_READY");
}

void loop() {
  digitalWrite(LED_B, HIGH);
  Serial.println("LED_TEST BLUE=ON GREEN=OFF");
  delay(1000);
  digitalWrite(LED_B, LOW);
  Serial.println("LED_TEST BLUE=OFF GREEN=OFF");
  delay(1000);
  digitalWrite(LED_G, HIGH);
  Serial.println("LED_TEST BLUE=OFF GREEN=ON");
  delay(1000);
  digitalWrite(LED_G, LOW);
  Serial.println("LED_TEST BLUE=OFF GREEN=OFF");
  delay(1000);
}
