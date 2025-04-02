#!/bin/bash

### Расширенный сканер и удалитель майнеров и вредоносных PHP-скриптов ###

echo "[*] Поиск и удаление вредоносных процессов..."

PIDS=$(ps aux | grep -Ei 'chrome\\.php|xmr|mine|ws://|kinsing|kdevtmpfsi|watchdog|dbused|udevd|irqbalance|curl.*http|wget.*http' | grep -v grep | awk '{print $2}')

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

### Удаление подозрительных файлов по имени ###
echo "[*] Поиск и удаление известных вредоносных файлов по имени..."
for name in chrome.php 1.php shell.php mail.php post.php wp-ajax.php kdevtmpfsi config99.php system32.php; do
    find / -type f -name "$name" 2>/dev/null | while read f; do
        echo " -> Удаление файла: $f"
        rm -f "$f"
    done
done

### Удаление новых .php/.sh/.bin файлов за последнюю неделю ###
echo "[*] Поиск всех потенциально вредоносных файлов, созданных за 7 дней..."
find /home/*/public_html -type f \( -name "*.php" -o -name "*.sh" -o -name "*.bin" \) -mtime -7 2>/dev/null | while read f; do
    echo "[!] Новый подозрительный файл (7 дней): $f"
    rm -f "$f"
done

### Поиск файлов с вредоносным содержимым ###
echo "[*] Поиск файлов с потенциально вредоносным PHP-кодом..."
find /var/www /home /usr/share/nginx/html /opt -type f -name "*.php" 2>/dev/null | while read file; do
    if grep -Eiq 'eval\(|base64_decode\(|shell_exec\(|system\(|passthru\(|exec\(|gzinflate\(|str_rot13\(|curl_exec\(' "$file"; then
        echo "[!] Вредоносный код найден в: $file"
        echo " -> Удаление $file"
        rm -f "$file"
    fi
    [ -f "$file" ] && [ ! -s "$file" ] && rm -f "$file"
done

### Очистка временных директорий от подозрительных файлов ###
echo "[*] Очистка /tmp, /dev/shm, /run, /var/tmp от вредоносных скриптов..."
find /tmp /dev/shm /run /var/tmp -type f \( -name '*.php' -o -name '*.sh' -o -name '*.bin' -o -name '*.out' -o -name '*' \) -exec rm -f {} + 2>/dev/null

### Проверка и очистка crontab для всех пользователей ###
echo "[*] Очистка crontab..."
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -l -u "$user" 2>/dev/null | grep -Ei 'curl|wget|mine|php|chrome\.php|xmr|eval' >/dev/null
    if [ $? -eq 0 ]; then
        echo " -> Удаление crontab у пользователя $user"
        crontab -r -u "$user"
    fi
    rm -f /var/spool/cron/$user 2>/dev/null
done

### Очистка .bashrc и .profile от майнеров ###
echo "[*] Очистка .bashrc и .profile..."
for file in /root/.bashrc /root/.profile /home/*/.bashrc /home/*/.profile; do
    [ -f "$file" ] && sed -i '/curl\|wget\|php\|base64\|eval/d' "$file"
done

### Проверка и удаление пользователя activ5 ###
echo "[*] Проверка пользователя activ5..."
id activ5 &>/dev/null && userdel -r activ5 && echo " -> Удален пользователь activ5" || echo "[+] Пользователь activ5 не найден."

### Проверка /etc/rc.local и удаление вредоносных команд ###
if [ -f /etc/rc.local ]; then
    echo "[*] Проверка rc.local..."
    sed -i '/curl\|wget\|php\|base64\|eval/d' /etc/rc.local
fi

### Проверка systemd юнитов на наличие майнеров ###
echo "[*] Проверка systemd юнитов..."
find /etc/systemd/system -type f -name '*.service' 2>/dev/null | while read svc; do
    grep -Eiq 'wget|curl|php|mine|xmr|kdev|chrome' "$svc" && echo "[!] Подозрительный systemd: $svc" && rm -f "$svc"
done

systemctl daemon-reload

echo "[✔] Очистка завершена. Проверьте сайт на работоспособность и сделайте бэкап."
