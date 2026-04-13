from pybricks.hubs import CityHub
from pybricks.pupdevices import DCMotor
from pybricks.parameters import Port
from pybricks.tools import wait
# Import für die Bluetooth-Kommunikation
from pybricks.experimental import pupdevices

hub = CityHub()

# Setup der Bluetooth UART Verbindung (aktiviert NUS automatisch)
uart = pupdevices.UART(Port.A) # Port spielt für UART keine Rolle

# Motoren initialisieren (passe die Ports an dein Modell an)
motor_a = DCMotor(Port.A)
motor_b = DCMotor(Port.B)

def set_motor(port_letter, speed_pct):
    speed = int(speed_pct)
    # PyBricks nutzt Werte von -100 bis 100 für dc()
    if port_letter == "A":
        motor_a.dc(speed)
    elif port_letter == "B":
        motor_b.dc(speed)

print("Hub wartet auf App...")

while True:
    # Lese Daten aus der App (wartet auf das '\n' von unserer App)
    if uart.waiting() > 0:
        data = uart.readline().decode().strip()
        
        # Erwartetes Format: "M:A:100" oder "L:B:0"
        parts = data.split(":")
        
        if len(parts) == 3:
            cmd_type = parts[0]
            port = parts[1]
            val = parts[2]
            
            if cmd_type == "M":
                set_motor(port, val)
            elif cmd_type == "L":
                # Hier könntest du Lichter (ColorLightMatrix) steuern
                pass

    wait(10) # Kurze Pause, damit der Hub nicht überhitzt