#include <SPI.h>
#include <Ethernet.h>
#include <EthernetDHCP.h>
#include <EthernetDNS.h>
#include <EthernetBonjour.h>
#include <avr/sleep.h>

const char* bonjour_hostname = "arduino";
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };

const char* ip_to_str(const uint8_t*);
void printlnBoth(String text);
void printBoth(String text);

//freenode...replace with nslookup
byte server[] = {208,71,169,36};
//byte server[] = {10,10,7,47};

String channel="#stockpile";
String nick="robaduino_bot";
String client_join = "";//"NICK ? \nUSER ? 8 * : ?\n";
String channel_join = "";//"JOIN ? ";

Client client(server, 6667);
char c = '\n';
unsigned long lastmillis = 0;
bool must_disconnect = false;
bool stay_dead = false;

void setup(){
  Serial.begin(9600);
  Serial.println("HELLO.");
  EthernetDHCP.begin(mac, 1);
}

void loop(){
  check_dhcp();

  check_server_connection();

  read_from_server();

  read_from_terminal();

  check_server_disconnection();
}

void check_dhcp(){
  if (EthernetDHCP.poll() < DhcpStateLeased){
    Serial.println("Seeking DHCP.");

    while(EthernetDHCP.poll() < DhcpStateLeased){
      if (millis() - lastmillis > 100){
        lastmillis = millis();
        Serial.print(".");
      }
    }

    Serial.println("DHCP Leased.");
  }
}

void check_server_connection(){
  int dot_count = 0;
  if (! client.connected() ) {
    Serial.println("Connecting.");
    while (! client.connected() ){
      client.connect();
      if (millis() - lastmillis > 50){
        lastmillis = millis();
        Serial.print('.');
        dot_count ++;

        if (dot_count > 50){
          Serial.println();
          dot_count = 0;
        }
      }
    }

    Serial.println("Connected to chat server (W00T).");
    client_join = "NICK " + nick + " \nUSER " + nick + " 8 * : itsaduinobot";
    channel_join = "JOIN " + channel;
    printlnBoth(client_join);
    printlnBoth(channel_join);
  }
}

void check_server_disconnection(){
  if (must_disconnect && client.connected()){
    printlnBoth("QUIT");
    must_disconnect = false;
    client.stop();
  }

  if (! client.connected() ){
    client.stop();
    Serial.println("DISCONNECTED.");
  }

  /*
  if (stay_dead && ! client.connected() ){
    set_sleep_mode(SLEEP_MODE_PWR_DOWN);
    sleep_enable();
    for (;;)
      sleep_mode();
  }
  */
}

void read_from_server(){
  String a_sentence;
  String response;
  String after_space;

  while (client.available()){

    c = client.read();

    a_sentence = "";
    //pull out characters from the client serial and assemble a string
    while (client.available() && c != '\n'){
      a_sentence = a_sentence + c;
      c = client.read();
    }

    response = command_response(a_sentence);
    //todo, stuff to detect if the message was sent from/to a pm or a channel
    //  and direct the response back to that channel

    Serial.println(a_sentence);

    if (response != ""){
      printlnBoth(response);
    }

  }

}

String command_response(String a_sentence){
    String response = "";
    int space_index = a_sentence.indexOf(' ') + 1;
    int nick_index = a_sentence.indexOf(nick, space_index);

    if (a_sentence.startsWith("PING")){
      //hehe...P(I|O)NG
      response = a_sentence;
      response.setCharAt(1,'O');
    } else if ( a_sentence.startsWith("PRIVMSG", space_index) ) {   //I suppose this is the most common
      response = message_response(a_sentence);
    } else if ( a_sentence.startsWith("NOTICE", space_index) ) {
    } else if ( a_sentence.startsWith("JOIN", space_index) ) {
    } else if ( a_sentence.startsWith("PART", space_index) ) {
    } else if ( a_sentence.startsWith("MODE", space_index) ) {
    } else if ( a_sentence.startsWith(0, space_index) ) { //2xx = Network Info
    } else if ( a_sentence.startsWith(2, space_index) ) { //2xx = User Stats
    } else if ( a_sentence.startsWith(3, space_index) ) { //3xx = MOTD / nicklist
    } else if ( a_sentence.startsWith(421, space_index) ) { //421 = unknown command
    } else if ( a_sentence.startsWith(451, space_index) ) { //451 = nickname in use
      //throw on a _ to the end of the nick, and force reconnect
      nick += '_';
      must_disconnect = true;
    } else if ( nick_index > -1 ) {
      response = a_sentence.substring(nick_index);
    }

    return response;
}

String message_response(String a_sentence){
  String response = "";
  int space_index = a_sentence.indexOf(' ') + 1;
  int colon_index = a_sentence.indexOf(':', space_index) + 1;
  int nick_index = a_sentence.indexOf(nick, colon_index) + 1;

  // is the message actually for me? No PM yet :(
  if ( nick_index > colon_index){
    if ( a_sentence.indexOf('ECHO') > -1 ) {
      response = a_sentence;
    } else if ( a_sentence.indexOf('EXEC') > -1) {
      response = execute_command( a_sentence );
    } else if ( a_sentence.indexOf('DIE') > -1) {
      stay_dead = 1;
      must_disconnect = 1;
      response = "PRIVMSG #stockpile ::-(";
      Serial.println("Perhaps today _is_ a good day to die.");
    } else {
      Serial.println("YAY ITS FOR ME!\n\nwait.\n\nwat do.\n\n:(");
    }
  } else {
    Serial.print("not for me :(\nindex:");
    Serial.println(nick_index);
    Serial.println(colon_index);
  }

  return response;
}

String execute_command(String a_sentence){
  Serial.println("execute function or something");
  return "";
}

void read_from_terminal(){
  if (Serial.available()){
    char c = Serial.read();
    //send tilde for linebreak
    if (c == '~'){
      client.println();
      Serial.println();
    } else {
      client.print(c);
      Serial.print(c);
    }
  }
}

void printBoth(String text){ Serial.print(text); client.print(text); }
void printlnBoth(String text){ Serial.println(text); client.println(text); }
