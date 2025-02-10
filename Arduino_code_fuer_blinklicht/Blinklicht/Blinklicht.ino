#include <SPI.h>
#include <Ethernet.h>

const int relayPins[] = { 7, 8, 9, 10 };    // Relay control pins for 4 relays

// Relay state to track if a relay is active or not
bool relayState[] = { false, false, false, false };

// Enter a MAC address and IP address for your controller below.
// The IP address will be dependent on your local network:
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
IPAddress ip(10, 152, 102, 9);         // Update this with an available IP address on your network
IPAddress myDns(10, 152, 50, 1);       // Update this with your network's DNS server (usually your router's IP)
IPAddress gateway(10, 152, 102, 254);  // Update this with your network's gateway (usually your router's IP)
IPAddress subnet(255, 255, 255, 0);    // Subnet mask

EthernetServer server(80);

void setup() {
  // Initialize relay pins as outputs and ensure they are off at startup
  for (int i = 0; i < 4; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], HIGH);  // Assuming active LOW relay module (HIGH means off)
  }

  // Start the Ethernet connection and the server:
  Ethernet.begin(mac, ip, myDns, gateway, subnet);
  server.begin();
  Serial.begin(9600);
  Serial.print("Server is at ");
  Serial.println(Ethernet.localIP());
}

void loop() {
  // Listen for incoming clients
  EthernetClient client = server.available();
  if (client) {
    String request = "";
    boolean currentLineIsBlank = true;

    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        request += c;

        if (c == '\n' && currentLineIsBlank) {
          // Handle HTTP PUT request
          if (request.startsWith("PUT /relay")) {
            handleRelayRequest(request, client);
          } else if (request.startsWith("OPTIONS")) {
            handleOptionsRequest(client);
          } else {
            handleNotFoundRequest(client);
          }
          break;
        }

        if (c == '\n') {
          currentLineIsBlank = true;
        } else if (c != '\r') {
          currentLineIsBlank = false;
        }
      }
    }
    delay(1);
    client.stop();
  }
}

// Handle relay activation or deactivation
void handleRelayRequest(String &request, EthernetClient &client) {
  int relayIndex = extractRelayIndex(request);
  bool release = request.indexOf("action=release") > 0;  // Check if this is a release request

  if (relayIndex >= 0 && relayIndex < 4) {
    String responseMessage;

    if (release) {
      if (relayState[relayIndex]) {  // Only release if the relay is currently active
        digitalWrite(relayPins[relayIndex], HIGH);  // Deactivate relay (assuming active LOW)
        relayState[relayIndex] = false;  // Mark the relay as inactive
        responseMessage = "Relay released.";
      } else {
        responseMessage = "Relay is already inactive.";
      }
    } else {
      if (!relayState[relayIndex]) {  // Only activate if the relay is currently inactive
        digitalWrite(relayPins[relayIndex], LOW);  // Activate relay (assuming active LOW)
        relayState[relayIndex] = true;  // Mark the relay as active
        responseMessage = "Relay activated.";
      } else {
        responseMessage = "Relay is already active.";
      }
    }

    sendResponse(client, "200 OK", responseMessage);
  } else {
    sendResponse(client, "400 Bad Request", "Invalid relay index");
  }
}

void handleOptionsRequest(EthernetClient &client) {
  sendResponse(client, "204 No Content", "");
}

void handleNotFoundRequest(EthernetClient &client) {
  sendResponse(client, "404 Not Found", "Endpoint not found");
}

// Extract relay index from the request
int extractRelayIndex(String &request) {
  int start = request.indexOf("relay=") + 6;
  int end = request.indexOf(" ", start);
  if (end == -1) end = request.length();
  return request.substring(start, end).toInt() - 1;
}

// Send HTTP response
void sendResponse(EthernetClient &client, String status, String message) {
  client.println("HTTP/1.1 " + status);
  client.println("Content-Type: text/plain");
  client.println("Access-Control-Allow-Origin: *");
  client.println("Access-Control-Allow-Methods: PUT, GET, OPTIONS");
  client.println("Access-Control-Allow-Headers: Content-Type");
  client.println();
  client.println(message);
}
