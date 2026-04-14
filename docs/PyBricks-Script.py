from pybricks.hubs import CityHub # (Oder TechnicHub, falls ihr den nutzt)
from pybricks.pupdevices import DCMotor
from pybricks.parameters import Port
from pybricks.tools import wait
import sys
import uselect

hub = CityHub()

# Motoren initialisieren (passe die Ports an dein Modell an)
motor_a = DCMotor(Port.A)
motor_b = DCMotor(Port.B)

def set_motor(port_letter, speed_pct):
    speed = int(speed_pct)
    if port_letter == "A":
        motor_a.dc(speed)
    elif port_letter == "B":
        motor_b.dc(speed)

# --- DIE MAGIE FÜR BLUETOOTH ---
# Wir registrieren die Standard-Eingabe (Bluetooth UART) zum Mitlesen
keyboard = uselect.poll()
keyboard.register(sys.stdin)

print("Hub wartet auf App-Befehle...")

while True:
    # Prüfen, ob Daten über Bluetooth angekommen sind (poll > 0)
    if keyboard.poll(0):
        # Die gesendete Textzeile der App auslesen und Leerzeichen/Umbruch entfernen
        data = sys.stdin.readline().strip()
        
        # Erwartetes Format unserer App: "M:A:100"
        parts = data.split(":")
        
        if len(parts) == 3:
            cmd_type = parts[0]
            port = parts[1]
            val = parts[2]
            
            if cmd_type == "M":
                set_motor(port, val)
                
    # Kurze Pause, damit der Hub nicht überhitzt
    wait(10)
