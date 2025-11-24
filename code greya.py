def decimal_to_binary(n):

    if n == 0:
        return "0"

    binary = ""
    while n > 0:
        binary = str(n % 2) + binary
        n = n // 2
    return binary


def decimal_to_gray(n):

    if n < 0:
        raise ValueError("Число должно быть неотрицательным")

    # Преобразуем число в двоичное представление (ручной метод)
    binary = decimal_to_binary(n)

    # Если число 0, возвращаем 0
    if binary == "0":
        return 0

    # Первый бит кода Грея совпадает с первым битом двоичного числа
    gray = binary[0]

    # Вычисляем остальные биты кода Грея
    for i in range(1, len(binary)):
        # Каждый бит кода Грея = XOR текущего и предыдущего битов двоичного числа
        current_bit = int(binary[i])
        prev_bit = int(binary[i - 1])
        gray_bit = str(current_bit ^ prev_bit)
        gray += gray_bit

    # Преобразуем двоичную строку обратно в десятичное число
    gray_decimal = 0
    for i, bit in enumerate(gray[::-1]):
        if bit == '1':
            gray_decimal += 2 ** i

    return gray_decimal

def binary_to_decimal(binary_str):

    decimal = 0
    for i, bit in enumerate(binary_str[::-1]):
        if bit == '1':
            decimal += 2 ** i
    return decimal


# Бесконечный цикл для ввода чисел
print("Программа для преобразования чисел в код Грея")
print("Введите 'exit' для выхода из программы")
print("-" * 50)

while True:
    user_input = input("\nВведите десятичное число: ")

    try:
        # Преобразуем ввод в число
        number = int(user_input)

        if number < 0:
            print("Ошибка: число должно быть неотрицательным!")
            continue

        # Получаем двоичное представление (ручной метод)
        binary_manual = decimal_to_binary(number)

        # Преобразуем в код Грея
        gray_manual = decimal_to_gray(number)

        # Получаем двоичное представление кода Грея
        gray_binary = decimal_to_binary(gray_manual)

        # Выводим результаты
        print(f"\nРезультаты для числа {number}:")
        print(f"Двоичное представление: {binary_manual}")
        print(f"Код Грея: {gray_manual} (двоичное: {gray_binary})")

    except ValueError:
        print("Ошибка: введите корректное целое число!")
    except Exception as e:
        print(f"Произошла ошибка: {e}")