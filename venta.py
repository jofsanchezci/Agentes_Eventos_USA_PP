import tkinter as tk

# Crear la ventana principal
ventana = tk.Tk()
ventana.title("Ejemplo de programación basada en eventos")

# Crear un manejador de evento para el botón
def al_hacer_clic():
    print("¡Botón clickeado!")

# Crear un botón y asociarlo al manejador de evento
boton = tk.Button(ventana, text="Haz clic aquí", command=al_hacer_clic)
boton.pack()

# Iniciar el bucle de eventos
ventana.mainloop()
