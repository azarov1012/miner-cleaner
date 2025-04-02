#!/bin/bash

### Расширенный и безопасный сканер для очистки майнеров ###

echo "[*] Поиск и удаление вредоносных процессов..."

PIDS=$(ps aux | grep -Ei 'chrome\.php|xmr|mine|ws://|kinsing|kdevtmpfsi|watchdog|dbused|udevd|irqbalance|curl.*http|wget.*http' | grep -v grep | awk '{print $2}')

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

### Удаление файлов по известным именам ###
echo "[*] Удаление известных вредоносных файлов..."
for name in chrome.php 1.php shell.php mail.php post.php wp-ajax.php kdevtmpfsi config99.php system32.php; do
    find / -type f -name "$name" 2>/dev/null | while read f; do
        echo " -> Удаление файла: $f"
        rm -f "$f"
    done
done

### Удаление только подозрительных файлов за последние 7 дней в безопасных директориях ###
echo "[*] Проверка /uploads, /tmp, /cache на свежие вредоносные .php..."
find /home/*/public_html/wp-content/uploads \
     /home/*/public_html/wp-content/cache \
     /home/*/public_html/wp-content/tmp \
     -type f -name "*.php" -mtime -7 2>/dev/null | while read f; do
    echo "[!] Подозрительный свежий файл: $f"
    rm -f "$f"
done

### Поиск вредоносного содержимого в .php ###
echo "[*] Поиск вредоносного кода в файлах..."
find /home/*/public_html -type f -name "*.php" 2>/dev/null | while read file; do
    if grep -Eiq 'eval\(|base64_decode\(|shell_exec\(|system\(|passthru\(|exec\(|gzinflate\(|str_rot13\(|curl_exec\(' "$file"; then
        echo "[!] Вредоносный код найден в: $file"
        rm -f "$file"
    fi
done

### Очистка временных директорий ###
echo "[*] Очистка /tmp, /dev/shm, /run, /var/tmp..."
find /tmp /dev/shm /run /var/tmp -type f \( -name '*.php' -o -name '*.sh' -o -name '*.bin' -o -name '*.out' -o -name '*' \) -exec rm -f {} + 2>/dev/null

### Очистка crontab ###
echo "[*] Проверка crontab..."
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -l -u "$user" 2>/dev/null | grep -Ei 'curl|wget|mine|php|chrome\.php|xmr|eval' >/dev/null
    if [ $? -eq 0 ]; then
        echo " -> Удаление crontab у пользователя $user"
        crontab -r -u "$user"
    fi
    rm -f /var/spool/cron/$user 2>/dev/null
done

### Очистка .bashrc и .profile ###
echo "[*] Очистка .bashrc и .profile..."
for file in /root/.bashrc /root/.profile /home/*/.bashrc /home/*/.profile; do
    [ -f "$file" ] && sed -i '/curl\|wget\|php\|base64\|eval/d' "$file"
done

### Проверка пользователя activ5 ###
echo "[*] Проверка пользователя activ5..."
id activ5 &>/dev/null && userdel -r activ5 && echo " -> Удален пользователь activ5" || echo "[+] Пользователь activ5 не найден."

### Очистка rc.local ###
if [ -f /etc/rc.local ]; then
    echo "[*] Очистка rc.local..."
    sed -i '/curl\|wget\|php\|base64\|eval/d' /etc/rc.local
fi

### Проверка systemd юнитов ###
echo "[*] Проверка systemd юнитов..."
find /etc/systemd/system -type f -name '*.service' 2>/dev/null | while read svc; do
    grep -Eiq 'wget|curl|php|mine|xmr|kdev|chrome' "$svc" && echo "[!] Удаление systemd: $svc" && rm -f "$svc"
done

systemctl daemon-reload

echo "[✔] Очистка завершена. Сайт должен работать. Рекомендую сделать бэкап!"
