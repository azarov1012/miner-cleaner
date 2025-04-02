#!/bin/bash

### Расширенный и безопасный сканер для очистки майнеров ###

LOG="/var/log/miner-cleaner.log"
echo "[*] Запуск miner-cleaner: $(date)" >> $LOG

### Поиск и удаление вредоносных процессов ###
echo "[*] Поиск и удаление вредоносных процессов..."
PIDS=$(ps aux | grep -Ei 'chrome\.php|xmr|mine|ws://|kinsing|kdevtmpfsi|watchdog|dbused|udevd|irqbalance|curl.*http|wget.*http' | grep -v grep | awk '{print $2}')

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

### Удаление файлов по известным именам ###
echo "[*] Удаление известных вредоносных файлов..."
for name in chrome.php 1.php shell.php mail.php post.php wp-ajax.php kdevtmpfsi config99.php system32.php; do
    find / -type f -name "$name" 2>/dev/null | while read f; do
        echo " -> Удаление файла: $f" >> $LOG
        rm -f "$f"
    done
done

### Удаление новых файлов за 2 дня с анализом содержимого ###
echo "[*] Анализ новых файлов в /uploads, /cache, /tmp..."
find /home/*/public_html/wp-content/uploads \
     /home/*/public_html/wp-content/cache \
     /home/*/public_html/wp-content/tmp \
     -type f \( -name "*.php" -o -name "*.sh" -o -name "*.bin" \) -mtime -2 2>/dev/null | while read f; do

    # Пропустить важные системные файлы
    if [[ "$f" =~ index.php|wp-config.php|functions.php ]]; then
        echo "[+] Пропущен системный файл: $f" >> $LOG
        continue
    fi

    # Проверка содержимого на вирусы
    if grep -Eiq 'eval\(|base64_decode\(|shell_exec\(|system\(|passthru\(|exec\(|gzinflate\(|str_rot13\(|curl_exec\(' "$f"; then
        echo "[!] Вредоносный файл: $f" >> $LOG
        rm -f "$f"
    else
        echo "[+] Безопасный файл (оставлен): $f" >> $LOG
    fi

done

### Очистка временных директорий ###
echo "[*] Очистка /tmp и аналогов..."
find /tmp /dev/shm /run /var/tmp -type f \( -name '*.php' -o -name '*.sh' -o -name '*.bin' -o -name '*.out' \) -exec rm -f {} + 2>/dev/null

### Очистка crontab ###
echo "[*] Очистка crontab..."
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -l -u "$user" 2>/dev/null | grep -Ei 'curl|wget|mine|php|chrome\.php|xmr|eval' >/dev/null
    if [ $? -eq 0 ]; then
        echo " -> Удаление crontab у $user" >> $LOG
        crontab -r -u "$user"
    fi
    rm -f /var/spool/cron/$user 2>/dev/null
done

### Очистка .bashrc и .profile ###
echo "[*] Очистка bashrc/profile..."
for file in /root/.bashrc /root/.profile /home/*/.bashrc /home/*/.profile; do
    [ -f "$file" ] && sed -i '/curl\|wget\|php\|base64\|eval/d' "$file"
done

### Проверка пользователя activ5 ###
id activ5 &>/dev/null && userdel -r activ5 && echo " -> Удален пользователь activ5" >> $LOG || echo "[+] Пользователь activ5 не найден." >> $LOG

### Очистка rc.local ###
[ -f /etc/rc.local ] && sed -i '/curl\|wget\|php\|base64\|eval/d' /etc/rc.local

### Проверка systemd юнитов ###
echo "[*] Проверка systemd..."
find /etc/systemd/system -type f -name '*.service' 2>/dev/null | while read svc; do
    grep -Eiq 'wget|curl|php|mine|xmr|kdev|chrome' "$svc" && echo "[!] Удаление systemd: $svc" >> $LOG && rm -f "$svc"
done

systemctl daemon-reload

echo "[✔] Очистка завершена." >> $LOG
echo "[*] См. лог: $LOG"
