#!/bin/bash

# Файл для хранения информации о процессах
PROCESS_FILE="process.txt"

# Функция для отображения меню
show_menu() {
    echo "Выберите опцию:"
    echo "1. Скачать и сжать фильм"
    echo "2. Возобновить процесс"
    echo "3. Выйти"
    echo -n "Введите номер опции: "
}

# Функция для скачивания и сжатия фильма в реальном времени с использованием wget или curl
download_and_compress_realtime() {
    local url="$1"
    local output="$2"

    # Сначала пытаемся использовать wget
    echo "Пытаемся скачать и сжать файл в реальном времени с помощью wget..."
    if wget --user-agent="Mozilla/5.0" --header="Accept: */*" -O - "$url" | ffmpeg -i pipe:0 -c:v libvpx-vp9 -b:v 1M -c:a libopus "${output}.webm"; then
        echo "Файл успешно скачан и сжат в реальном времени с использованием wget как ${output}.webm."
    else
        echo "Ошибка при скачивании с использованием wget. Переход на curl..."

        # Если wget не удался, используем curl
        if curl -L -A "Mozilla/5.0" -o - "$url" | ffmpeg -i pipe:0 -c:v libvpx-vp9 -b:v 1M -c:a libopus "${output}.webm"; then
            echo "Файл успешно скачан и сжат в реальном времени с использованием curl как ${output}.webm."
        else
            echo "Ошибка при скачивании и сжатии файла с использованием curl."
            return 1
        fi
    fi

    # Добавление информации о процессе в файл
    echo "$$ $url $output" >> $PROCESS_FILE
}

# Функция для приостановки процесса
pause_process() {
    if [[ ! -z "$PID" ]]; then
        kill -STOP $PID
        echo "Процесс $PID приостановлен."
        echo "$PID $url $output" >> $PROCESS_FILE  # Сохраняем информацию о процессе в файл
    else
        echo "Процесс не найден."
    fi
}

# Функция для отображения списка незаконченных фильмов
list_unfinished_processes() {
    if [[ -s $PROCESS_FILE ]]; then
        echo "Незаконченные фильмы:"
        cat $PROCESS_FILE | while read line; do
            pid=$(echo $line | awk '{print $1}')
            url=$(echo $line | awk '{print $2}')
            file=$(echo $line | awk '{print $3}')
            echo "PID: $pid, URL: $url, Файл: $file"
        done
    else
        echo "Нет незаконченных фильмов."
    fi
}

# Функция для возобновления процесса
resume_process() {
    list_unfinished_processes
    read -p "Введите PID процесса, который хотите возобновить: " resume_pid

    # Поиск информации о процессе по PID
    if grep -q "^$resume_pid " $PROCESS_FILE; then
        url=$(grep "^$resume_pid " $PROCESS_FILE | awk '{print $2}')
        output=$(grep "^$resume_pid " $PROCESS_FILE | awk '{print $3}')
        
        # Возобновляем процесс
        if kill -CONT $resume_pid; then
            echo "Процесс $resume_pid возобновлен."
        else
            echo "Не удалось возобновить процесс. Перезапуск..."
            download_and_compress_realtime "$url" "$output" &
            new_pid=$!
            echo "Процесс перезапущен с новым PID: $new_pid"
            sed -i "/^$resume_pid /d" $PROCESS_FILE  # Удаляем старую запись
            echo "$new_pid $url $output" >> $PROCESS_FILE  # Сохраняем новую запись
        fi
    else
        echo "Неверный PID или процесс не найден."
    fi
}

# Основной цикл
while true; do
    show_menu
    read choice

    case $choice in
        1)
            # Запрос URL и названия выходного файла
            read -p "Введите URL для скачивания: " url
            read -p "Введите название выходного файла (без расширения): " output

            # Запуск скачивания и сжатия в реальном времени в фоновом режиме
            download_and_compress_realtime "$url" "$output" &
            PID=$!
            echo "Процесс скачивания и сжатия начат с PID: $PID (Файл: ${output}.webm)"
            
            # Наблюдение за вводом команды stop в основном процессе
            while true; do
                read -r input
                if [[ "$input" == "stop" ]]; then
                    pause_process
                    break
                fi
            done
            ;;
        2) resume_process ;;
        3) echo "Выход из программы."; exit 0 ;;
        *) echo "Неверный выбор. Попробуйте снова." ;;
    esac
done
