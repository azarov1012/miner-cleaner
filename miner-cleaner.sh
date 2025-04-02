#!/bin/bash

### Точный сканер: удаляет только chrome.php и вирусы с рандомными именами ###

LOG="/var/log/miner-cleaner.log"
echo "[*] Запуск miner-cleaner: $(date)" >> $LOG

### Поиск и удаление процессов-майнеров ###
echo "[*] Поиск и удаление вредоносных процессов..."
PIDS=$(ps aux | grep -Ei 'chrome\.php|xmr|mine|ws://|kinsing|kdevtmpfsi' | grep -v grep | awk '{print $2}')

if [ -n "$PIDS" ]; then
    echo "[!] Найдены подозрительные процессы:" >> $LOG
    echo "$PIDS" >> $LOG
    for pid in $PIDS; do
        echo " -> Удаление процесса $pid" >> $LOG
        kill -9 $pid 2>/dev/null
    done
else
    echo "[+] Подозрительных процессов не найдено." >> $LOG
fi

### Удаление chrome.php ###
echo "[*] Удаление chrome.php..."
find / -type f -name "chrome.php" -mtime -5 2>/dev/null | while read f; do
    echo " -> Удаление файла: $f" >> $LOG
    rm -f "$f"
done

### Поиск и удаление подозрительных PHP-файлов с рандомным именем ###
echo "[*] Поиск и удаление подозрительных PHP-файлов (рандомные имена)..."
find /home/*/public_html/wp-content/ -type f -name "*.php" -mtime -5 2>/dev/null | while read f; do
    fname=$(basename "$f")
    if [[ "$fname" =~ ^[a-zA-Z0-9]{8,}\.php$ ]] && grep -Eiq 'eval\(|base64_decode\(|gzinflate\(|str_rot13\(|system\(|shell_exec\(' "$f"; then
        echo " -> Удаление вредоносного PHP-файла: $f" >> $LOG
        rm -f "$f"
    fi
done

echo "[✔] Завершено. Удалены только chrome.php и вредоносные файлы с подозрительными именами. См. лог: $LOG"

