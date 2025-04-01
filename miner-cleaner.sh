#!/bin/bash

echo "[*] Проверка на наличие майнера..."

# Найдём процессы по ключевым словам
PIDS=$(ps aux | grep -Ei 'chrome\.php|xmr|mine|ws://|kinsing' | grep -v grep | awk '{print $2}')

if [ -n "$PIDS" ]; then
    echo "[!] Найдены подозрительные процессы:"
    echo "$PIDS"
    for pid in $PIDS; do
        echo " -> Удаление процесса $pid"
        kill -9 $pid 2>/dev/null
    done
else
    echo "[+] Подозрительных процессов не найдено."
fi

echo "[*] Поиск и удаление chrome.php..."
find / -name "chrome.php" 2>/dev/null | while read f; do
    echo " -> Удаление $f"
    rm -f "$f"
done

echo "[*] Проверка crontab пользователей..."
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -l -u "$user" 2>/dev/null | grep -Ei 'curl|wget|mine|php|chrome\.php|xmr' >/dev/null
    if [ $? -eq 0 ]; then
        echo " -> Удаление подозрительного crontab у пользователя $user"
        crontab -r -u "$user"
    fi
done

echo "[*] Проверка пользователя activ5..."
id activ5 &>/dev/null
if [ $? -eq 0 ]; then
    echo " -> Удаление пользователя activ5"
    userdel -r activ5 2>/dev/null
else
    echo "[+] Пользователь activ5 не найден."
fi

echo "[✔] Очистка завершена."
