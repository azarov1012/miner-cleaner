#!/bin/bash

### Miner Cleaner with plugin exception ###

LOG="/var/log/miner-cleaner.log"
echo "[*] Запуск miner-cleaner: $(date)" | tee -a $LOG

# Подозрительные процессы по ключевым словам
PIDS=$(ps aux | grep -Ei 'chrome\.php|xmr|mine|ws://|kinsing' | grep -v grep | awk '{print $2}')
if [ -n "$PIDS" ]; then
  echo "[!] Найдены подозрительные процессы:" | tee -a $LOG
  echo "$PIDS" | tee -a $LOG
  for pid in $PIDS; do
    echo " -> Удаление процесса $pid" | tee -a $LOG
    kill -9 $pid 2>/dev/null
  done
else
  echo "[*] Подозрительных процессов не найдено." | tee -a $LOG
fi

# Удаление chrome.php в /home/*/public_html/
echo "[*] Поиск и удаление chrome.php..." | tee -a $LOG
find /home/*/public_html/ -type f -name "chrome.php" 2>/dev/null | while read f; do
  echo " -> Удаление файла: $f" | tee -a $LOG
  rm -f "$f"
done

# Проверка подозрительных PHP-файлов с короткими/рандомными именами (исключая rss-feed-post-generator-echo)
echo "[*] Поиск и удаление подозрительных PHP-файлов (рандомные имена)..." | tee -a $LOG
find /home/*/public_html/ -type f -name "*.php" -mtime -7 ! -path "*/rss-feed-post-generator-echo/*" 2>/dev/null | while read f; do
  filename=$(basename "$f")
  if [[ $filename =~ ^[a-zA-Z0-9_-]{1,10}\.php$ && $filename != "index.php" ]]; then
    echo " -> Удаление подозрительного PHP: $f" | tee -a $LOG
    rm -f "$f"
  fi
done

# Очистка .bashrc/.profile от вредных строк
for user in $(cut -f1 -d: /etc/passwd); do
  for file in "/home/$user/.bashrc" "/home/$user/.profile"; do
    if [ -f "$file" ]; then
      grep -Eiv 'curl|wget|php|chrome|xmr' "$file" > "${file}.clean"
      mv "${file}.clean" "$file"
    fi
  done
done

# Очистка временных директорий
rm -rf /tmp/* /var/tmp/* /dev/shm/* 2>/dev/null

# Проверка и очистка crontab от подозрительных заданий
for user in $(cut -f1 -d: /etc/passwd); do
  crontab -l -u $user 2>/dev/null | grep -Eiq 'curl|wget|php|mine|xmr|chrome' && {
    echo " -> Очистка crontab пользователя $user" | tee -a $LOG
    crontab -r -u $user
  }
done

# Проверка systemd юнитов
systemctl list-units --type=service | grep -Ei 'php|mine|xmr|chrome' | while read line; do
  service=$(echo $line | awk '{print $1}')
  echo " -> Найден вредоносный сервис: $service" | tee -a $LOG
  systemctl stop "$service"
  systemctl disable "$service"
  systemctl mask "$service"
done

# Завершение
echo "[✔] Завершено. Удалены только chrome.php и вредоносные файлы с подозрительными именами. См. лог: $LOG"
