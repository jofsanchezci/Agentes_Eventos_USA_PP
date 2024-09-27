import tkinter as tk

def click_button(value):
    current = display.get()
    display.delete(0, tk.END)
    display.insert(0, current + value)

def clear():
    display.delete(0, tk.END)

def calculate():
    try:
        result = eval(display.get())
        display.delete(0, tk.END)
        display.insert(0, str(result))
    except Exception as e:
        display.delete(0, tk.END)
        display.insert(0, "Error")

# Crear la ventana principal
root = tk.Tk()
root.title("Calculadora UNO")

# Entrada de la calculadora
display = tk.Entry(root, width=40, borderwidth=5)
display.grid(row=0, column=0, columnspan=4, padx=10, pady=10)

# Botones de la calculadora
buttons = [
    ('1', 1), ('2', 1), ('3', 1), ('+', 1),
    ('4', 2), ('5', 2), ('6', 2), ('-', 2),
    ('7', 3), ('8', 3), ('9', 3), ('*', 3),
    ('C', 4), ('0', 4), ('=', 4), ('/', 4),
]

for button_text, row in buttons:
    action = lambda x=button_text: click_button(x)
    tk.Button(root, text=button_text, width=10, command=action).grid(row=row, column=buttons.index((button_text, row)) % 4)

# Botón de limpiar 'C'
tk.Button(root, text='C', width=10, command=clear).grid(row=4, column=0)
# Botón de igual '='
tk.Button(root, text='=', width=10, command=calculate).grid(row=4, column=2)

root.mainloop()
