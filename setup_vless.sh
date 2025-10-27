#!/bin/bash

# --- Настройки ---
# Вы можете изменить порт, если 443 недоступен
PORT=443
ADMIN_USERNAME="Aesthesia"
ADMIN_PASSWORD="aN5oL2rZ4vrJ"
ADMIN_EMAIL="admin@example.com"
PROJECT_NAME="vless_panel"
APP_NAME="panel"
PYTHON_VENV_PATH="/opt/vless_panel_venv"
XRAY_CONFIG_GENERATOR="/opt/generate_xray_config.py"
DJANGO_SERVICE_FILE="/etc/systemd/system/django_vless_panel.service"
NGINX_CONFIG_FILE="/etc/nginx/sites-available/vless_panel"
XRAY_UPDATE_SCRIPT="/opt/update_xray_from_db.sh"
PROJECT_DIR="$PYTHON_VENV_PATH/$PROJECT_NAME" # Полный путь к проекту Django
APP_DIR="$PROJECT_DIR/$APP_NAME"              # Полный путь к приложению Django
# --- Конец Настроек ---

# Получение внешнего IP-адреса сервера
SERVER_IP=$(curl -s https://api.ipify.org)

echo "Начинается установка Xray с VLESS + TCP и Django-панели управления..."

# 1. Обновление системы
apt update -y
apt upgrade -y

# 2. Установка curl, python3, pip, venv, git, postgresql, nginx
apt install -y curl python3 python3-pip python3-venv git postgresql postgresql-contrib nginx

# 3. Установка Xray через официальный скрипт
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

if [ $? -ne 0 ]; then
    echo "Ошибка при установке Xray. Выход."
    exit 1
fi

# 4. Создание виртуального окружения для Django
python3 -m venv "$PYTHON_VENV_PATH"
source "$PYTHON_VENV_PATH/bin/activate"

# 5. Установка Django и psycopg2 (для PostgreSQL) в виртуальное окружение
pip install django psycopg2-binary

# 6. Создание Django-проекта и приложения
django-admin startproject "$PROJECT_NAME" "$PYTHON_VENV_PATH"

# Проверка, успешно ли создан проект
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Ошибка при создании Django-проекта. Директория $PROJECT_DIR не существует."
    exit 1
fi

cd "$PROJECT_DIR"
python manage.py startapp "$APP_NAME"

# Проверка, успешно ли создано приложение
if [ ! -d "$APP_DIR" ]; then
    echo "Ошибка при создании Django-приложения. Директория $APP_DIR не существует."
    exit 1
fi

# 7. Настройка settings.py для Django
cat << EOF > "$PROJECT_DIR/settings.py"
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = '$(openssl rand -hex 32)'
DEBUG = False # Всегда False для продакшена
ALLOWED_HOSTS = ['*'] # Укажите конкретный IP или домен для безопасности

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    '$APP_NAME',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = '$PROJECT_NAME.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = '$PROJECT_NAME.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'vless_panel_db',
        'USER': 'vless_panel_user',
        'PASSWORD': '$(openssl rand -hex 16)', # Случайный пароль для БД
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOF

# 8. Создание модели VlessKey в models.py
cat << 'EOF' > "$APP_DIR/models.py"
from django.db import models
import uuid

class VlessKey(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    uuid = models.CharField(max_length=36, unique=True) # UUID для VLESS
    valid_until = models.DateTimeField() # Срок действия
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"VLESS Key {self.uuid[:8]}... (Expires: {self.valid_until})"
EOF

# 9. Создание admin.py для управления ключами в админке
cat << 'EOF' > "$APP_DIR/admin.py"
from django.contrib import admin
from .models import VlessKey

@admin.register(VlessKey)
class VlessKeyAdmin(admin.ModelAdmin):
    list_display = ('uuid', 'valid_until', 'created_at')
    readonly_fields = ('id', 'uuid') # ID и UUID не редактируются
    ordering = ('-valid_until',) # Сортировка по сроку действия
    list_filter = ('valid_until',)

    def has_add_permission(self, request):
        # Включаем кнопку "Добавить"
        return True

    def save_model(self, request, obj, form, change):
        # При сохранении вручную, если uuid пустой, генерируем
        if not obj.uuid:
            import uuid
            obj.uuid = str(uuid.uuid4())
        super().save_model(request, obj, form, change)
EOF

# 10. Создание скрипта для генерации конфига Xray на основе активных ключей
cat << 'EOF' > "$XRAY_CONFIG_GENERATOR"
#!/usr/bin/env python3
import os
import sys
import django
from datetime import datetime
from django.conf import settings

# Добавляем путь к проекту Django
sys.path.append('/opt/vless_panel_venv/vless_panel')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'vless_panel.settings')

django.setup()

from panel.models import VlessKey

# Получаем активные ключи (не истёкшие)
now = datetime.now().astimezone()
active_keys = VlessKey.objects.filter(valid_until__gt=now)

# Формируем список клиентов для Xray
clients = []
for key in active_keys:
    clients.append({
        "id": key.uuid,
        "level": 0,
        "email": f"vless-{key.id}"
    })

# Создаем конфигурацию Xray
xray_config = {
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443, # Порт из настроек скрипта
            "protocol": "vless",
            "settings": {
                "decryption": "none",
                "clients": clients
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}

import json
CONFIG_FILE_PATH = "/usr/local/etc/xray/config.json"

# Записываем конфигурацию в файл
with open(CONFIG_FILE_PATH, 'w') as f:
    json.dump(xray_config, f, indent=2)

print(f"Конфигурация Xray обновлена. Активные ключи: {len(clients)}")
EOF

# 11. Делаем скрипт исполняемым
chmod +x "$XRAY_CONFIG_GENERATOR"

# 12. Установка зависимостей Django (makemigrations, migrate, createsuperuser)
# Переходим в директорию проекта
cd "$PROJECT_DIR"

# makemigrations
python manage.py makemigrations

if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении makemigrations."
    exit 1
fi

# migrate
python manage.py migrate

if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении migrate."
    exit 1
fi

# Создание суперпользователя напрямую
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$ADMIN_USERNAME', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')" | python manage.py shell

if [ $? -ne 0 ]; then
    echo "Ошибка при создании суперпользователя."
    exit 1
fi

echo "Django успешно настроена и суперпользователь создан."

# 13. Настройка PostgreSQL
DB_USER="vless_panel_user"
DB_NAME="vless_panel_db"
# Извлекаем случайный пароль из settings.py
DB_PASSWORD=$(grep "PASSWORD" "$PROJECT_DIR/settings.py" | grep -o "'[^']*'" | sed -n 2p | sed "s/'//g")

# Переключаемся на пользователя postgres и создаем БД и пользователя
sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD'; END IF; END \$\$;"
sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME') THEN CREATE DATABASE $DB_NAME OWNER $DB_USER; END IF; END \$\$;"

# 14. Создание скрипта для запуска Django (для systemd)
cat << EOF > "$DJANGO_SERVICE_FILE"
[Unit]
Description=Django VLESS Panel
After=network.target

[Service]
Type=exec
User=root
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PYTHON_VENV_PATH/bin
ExecStart=$PYTHON_VENV_PATH/bin/python manage.py runserver 0.0.0.0:8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 15. Создание скрипта для обновления Xray (для cron)
cat << EOF > "$XRAY_UPDATE_SCRIPT"
#!/bin/bash
# Активируем виртуальное окружение
source $PYTHON_VENV_PATH/bin/activate
# Запускаем скрипт генерации конфига
python $XRAY_CONFIG_GENERATOR
# Перезапускаем Xray
systemctl restart xray
EOF
chmod +x "$XRAY_UPDATE_SCRIPT"

# 16. Добавление cron-задачи для обновления Xray каждую минуту
(crontab -l 2>/dev/null; echo "* * * * * $XRAY_UPDATE_SCRIPT >> /var/log/xray_update.log 2>&1") | crontab -

# 17. Запуск Django-сервиса
systemctl daemon-reload
systemctl enable django_vless_panel
systemctl start django_vless_panel

if [ $? -ne 0 ]; then
    echo "Ошибка при запуске Django-сервиса."
    exit 1
fi

# 18. Настройка Nginx
cat << EOF > "$NGINX_CONFIG_FILE"
server {
    listen 80;
    server_name $SERVER_IP; # Или ваш домен

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /static/ {
        alias $PROJECT_DIR/staticfiles/;
    }
}
EOF

ln -s "$NGINX_CONFIG_FILE" /etc/nginx/sites-enabled/
nginx -t # Проверка синтаксиса
systemctl reload nginx

# 19. Открытие портов в ufw, если он установлен
if command -v ufw &> /dev/null; then
    echo "Настраивается брандмауэр (ufw)..."
    ufw allow $PORT/tcp   # Порт VLESS
    ufw allow 80/tcp      # Порт для веб-панели (Nginx)
    ufw allow 22/tcp      # SSH, если заблокирован
    ufw --force enable
else
    echo "Брандмауэр ufw не найден. Убедитесь, что порты $PORT и 80 открыты вручную или провайдером VPS."
fi

# 20. Запуск и включение Xray
systemctl enable xray
systemctl restart xray

echo "Установка завершена!"

# 21. Вывод данных для подключения и доступа к панели
echo "=== Настройки подключения VLESS (изначально пусто, добавляйте ключи в панели) ==="
echo "Адрес сервера (IP): $SERVER_IP"
echo "Порт: $PORT"
echo "Поток (Network): tcp"
echo "Безопасность (Security): none"
echo "UUID: Будет указан при создании ключа в панели"
echo "=================================="
echo "=== Доступ к панели управления ==="
echo "Адрес панели: http://$SERVER_IP/admin/"
echo "Логин: $ADMIN_USERNAME"
echo "Пароль: $ADMIN_PASSWORD"
echo "=================================="
echo ""
echo "Советы:"
echo "- Зайдите в панель http://$SERVER_IP/admin/ под логином $ADMIN_USERNAME и создайте ключи."
echo "- Укажите срок действия для каждого ключа."
echo "- Клиенты могут использовать полученные UUID для подключения через Hiddify или другой клиент."
echo "- Ключи автоматически перестанут работать после истечения срока."
echo "Лог обновления Xray: cat /var/log/xray_update.log"
