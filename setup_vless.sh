#!/bin/bash

# --- Настройки ---
PORT=443
ADMIN_USERNAME="Aesthesia"
ADMIN_PASSWORD="aN5oL2rZ4vrJ"
ADMIN_EMAIL="admin@example.com"
PROJECT_NAME="vless_panel"
APP_NAME="panel"
PYTHON_VENV_PATH="/opt/vless_panel_venv"
# PROJECT_DIR указывает на директорию, где будет находиться manage.py и settings.py
PROJECT_DIR="$PYTHON_VENV_PATH/$PROJECT_NAME"
APP_DIR="$PROJECT_DIR/$APP_NAME" # /opt/vless_panel_venv/vless_panel/panel
XRAY_CONFIG_FILE="/usr/local/etc/xray/config.json"
XRAY_CONFIG_GENERATOR="/opt/generate_xray_config.py"
DJANGO_SERVICE_FILE="/etc/systemd/system/django_vless_panel.service"
NGINX_CONFIG_FILE="/etc/nginx/sites-available/vless_panel"
XRAY_UPDATE_SCRIPT="/opt/update_xray_from_db.sh"
# --- Конец Настроек ---

# Получение внешнего IP-адреса сервера
SERVER_IP=$(curl -s https://api.ipify.org)

echo "=== Начало установки VLESS + Django-панели ==="

# --- Предварительная очистка (если были предыдущие запуски) ---
echo "Проверка и очистка остатков от предыдущих установок..."
systemctl stop django_vless_panel 2>/dev/null
systemctl disable django_vless_panel 2>/dev/null
rm -f "$DJANGO_SERVICE_FILE"

# Удаление директории проекта и виртуального окружения
rm -rf "$PYTHON_VENV_PATH"

# Удаление БД и пользователя PostgreSQL (если существуют)
sudo -u postgres psql -c "DROP DATABASE IF EXISTS vless_panel_db;" 2>/dev/null
sudo -u postgres psql -c "DROP USER IF EXISTS vless_panel_user;" 2>/dev/null

# Удаление конфигурации Nginx
rm -f "$NGINX_CONFIG_FILE"
rm -f "/etc/nginx/sites-enabled/vless_panel" 2>/dev/null

# Удаление скриптов и cron-задачи
rm -f "$XRAY_CONFIG_GENERATOR"
rm -f "$XRAY_UPDATE_SCRIPT"
(crontab -l 2>/dev/null | grep -v 'update_xray_from_db') | crontab - 2>/dev/null

# Перезагрузка systemd и Nginx
systemctl daemon-reload
systemctl reload nginx 2>/dev/null || true

echo "Предварительная очистка завершена."

# 1. Обновление системы
echo "Обновление системы..."
apt update -y && apt upgrade -y
if [ $? -ne 0 ]; then
    echo "Ошибка при обновлении системы. Выход."
    exit 1
fi

# 2. Установка зависимостей
echo "Установка зависимостей..."
apt install -y curl python3 python3-pip python3-venv git postgresql postgresql-contrib nginx
if [ $? -ne 0 ]; then
    echo "Ошибка при установке зависимостей. Выход."
    exit 1
fi

# 3. Установка Xray
echo "Установка Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
if [ $? -ne 0 ]; then
    echo "Ошибка при установке Xray. Выход."
    exit 1
fi

# 4. Создание виртуального окружения и установка Python-пакетов
echo "Создание виртуального окружения и установка Django/psycopg2..."
python3 -m venv "$PYTHON_VENV_PATH"
if [ $? -ne 0 ]; then
    echo "Ошибка при создании виртуального окружения. Выход."
    exit 1
fi

source "$PYTHON_VENV_PATH/bin/activate"
pip install django psycopg2-binary
if [ $? -ne 0 ]; then
    echo "Ошибка при установке Python-пакетов. Выход."
    exit 1
fi

# 5. Создание Django-проекта и приложения
echo "Создание Django-проекта и приложения..."
# django-admin startproject PROJECT_NAME DESTINATION_DIR
# Создаст /opt/vless_panel_venv/vless_panel/
django-admin startproject "$PROJECT_NAME" "$PYTHON_VENV_PATH"
if [ $? -ne 0 ]; then
    echo "Ошибка при создании Django-проекта. Выход."
    exit 1
fi

# Перейдем в директорию, где находится внутренняя папка проекта и manage.py
cd "$PROJECT_DIR/$PROJECT_NAME" # /opt/vless_panel_venv/vless_panel/vless_panel
# Создадим приложение
python manage.py startapp "$APP_NAME"
if [ $? -ne 0 ]; then
    echo "Ошибка при создании Django-приложения. Выход."
    exit 1
fi

# Переместим приложение на уровень выше, в PROJECT_DIR
mv "$PROJECT_DIR/$PROJECT_NAME/$APP_NAME" "$PROJECT_DIR/"

# Теперь переместим manage.py и внутреннюю директорию проекта на уровень PROJECT_DIR
mv manage.py "$PROJECT_DIR/"
mv "$PROJECT_NAME"/* "$PROJECT_DIR/" # Переносим settings.py, urls.py, wsgi.py, asgi.py
rmdir "$PROJECT_NAME" # Удаляем теперь пустую внутреннюю директорию

# 6. Настройка settings.py (теперь путь к settings.py правильный)
echo "Настройка Django settings.py..."
cat << EOF > "$PROJECT_DIR/$PROJECT_NAME/settings.py"
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = '$(openssl rand -hex 32)'
DEBUG = False
ALLOWED_HOSTS = ['*']

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
        'PASSWORD': '$(openssl rand -hex 16)',
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
if [ $? -ne 0 ]; then
    echo "Ошибка при записи settings.py. Выход."
    exit 1
fi

# 7. Настройка models.py
echo "Настройка Django models.py..."
cat << 'EOF' > "$APP_DIR/models.py"
from django.db import models
import uuid

class VlessKey(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    uuid = models.CharField(max_length=36, unique=True)
    valid_until = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"VLESS Key {self.uuid[:8]}... (Expires: {self.valid_until})"
EOF
if [ $? -ne 0 ]; then
    echo "Ошибка при записи models.py. Выход."
    exit 1
fi

# 8. Настройка admin.py
echo "Настройка Django admin.py..."
cat << 'EOF' > "$APP_DIR/admin.py"
from django.contrib import admin
from .models import VlessKey

@admin.register(VlessKey)
class VlessKeyAdmin(admin.ModelAdmin):
    list_display = ('uuid', 'valid_until', 'created_at')
    readonly_fields = ('id', 'uuid')
    ordering = ('-valid_until',)
    list_filter = ('valid_until',)

    def has_add_permission(self, request):
        return True

    def save_model(self, request, obj, form, change):
        if not obj.uuid:
            import uuid
            obj.uuid = str(uuid.uuid4())
        super().save_model(request, obj, form, change)
EOF
if [ $? -ne 0 ]; then
    echo "Ошибка при записи admin.py. Выход."
    exit 1
fi

# 9. Создание скрипта генерации конфига Xray
echo "Создание скрипта генерации конфига Xray..."
cat << 'EOF' > "$XRAY_CONFIG_GENERATOR"
#!/usr/bin/env python3
import os
import sys
import django
from datetime import datetime
from django.conf import settings

sys.path.append('/opt/vless_panel_venv/vless_panel')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'vless_panel.settings')

django.setup()

from panel.models import VlessKey

now = datetime.now().astimezone()
active_keys = VlessKey.objects.filter(valid_until__gt=now)

clients = []
for key in active_keys:
    clients.append({
        "id": key.uuid,
        "level": 0,
        "email": f"vless-{key.id}"
    })

xray_config = {
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": 443,
        "protocol": "vless",
        "settings": {"decryption": "none", "clients": clients},
        "streamSettings": {"network": "tcp", "security": "none"}
    }],
    "outbounds": [{"protocol": "freedom", "settings": {}}]
}

import json
CONFIG_FILE_PATH = "/usr/local/etc/xray/config.json"

with open(CONFIG_FILE_PATH, 'w') as f:
    json.dump(xray_config, f, indent=2)

print(f"Конфигурация Xray обновлена. Активные ключи: {len(clients)}")
EOF
if [ $? -ne 0 ]; then
    echo "Ошибка при создании скрипта генерации конфига Xray. Выход."
    exit 1
fi
chmod +x "$XRAY_UPDATE_SCRIPT" "$XRAY_CONFIG_GENERATOR"

# 10. Выполнение миграций и создание суперпользователя
echo "Выполнение Django миграций и создание суперпользователя..."
cd "$PROJECT_DIR" # Убедимся, что мы в /opt/vless_panel_venv/vless_panel
python manage.py makemigrations
if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении makemigrations. Выход."
    exit 1
fi

python manage.py migrate
if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении migrate. Выход."
    exit 1
fi

echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$ADMIN_USERNAME', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')" | python manage.py shell
if [ $? -ne 0 ]; then
    echo "Ошибка при создании суперпользователя. Выход."
    exit 1
fi
echo "Django миграции и суперпользователь успешно созданы."

# 11. Настройка PostgreSQL
echo "Настройка PostgreSQL..."
DB_USER="vless_panel_user"
DB_NAME="vless_panel_db"
DB_PASSWORD=$(grep "PASSWORD" "$PROJECT_DIR/$PROJECT_NAME/settings.py" | grep -o "'[^']*'" | sed -n 2p | sed "s/'//g")

sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD'; END IF; END \$\$;"
sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME') THEN CREATE DATABASE $DB_NAME OWNER $DB_USER; END IF; END \$\$;"
if [ $? -ne 0 ]; then
    echo "Ошибка при настройке PostgreSQL. Выход."
    exit 1
fi

# 12. Создание сервиса Django
echo "Создание и настройка сервиса Django..."
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
if [ $? -ne 0 ]; then
    echo "Ошибка при создании файла сервиса Django. Выход."
    exit 1
fi

systemctl daemon-reload
systemctl enable django_vless_panel
if [ $? -ne 0 ]; then
    echo "Ошибка при включении сервиса Django. Выход."
    exit 1
fi

# 13. Создание скрипта обновления Xray и cron-задачи
echo "Создание скрипта обновления Xray и cron-задачи..."
cat << EOF > "$XRAY_UPDATE_SCRIPT"
#!/bin/bash
source $PYTHON_VENV_PATH/bin/activate
python $XRAY_CONFIG_GENERATOR
systemctl restart xray
EOF
if [ $? -ne 0 ]; then
    echo "Ошибка при создании скрипта обновления Xray. Выход."
    exit 1
fi
chmod +x "$XRAY_UPDATE_SCRIPT"

(crontab -l 2>/dev/null; echo "* * * * * $XRAY_UPDATE_SCRIPT >> /var/log/xray_update.log 2>&1") | crontab -
if [ $? -ne 0 ]; then
    echo "Ошибка при добавлении cron-задачи. Выход."
    exit 1
fi

# 14. Настройка Nginx
echo "Настройка Nginx..."
cat << EOF > "$NGINX_CONFIG_FILE"
server {
    listen 80;
    server_name $SERVER_IP;

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
if [ $? -ne 0 ]; then
    echo "Ошибка при создании конфига Nginx. Выход."
    exit 1
fi

ln -sf "$NGINX_CONFIG_FILE" /etc/nginx/sites-enabled/
nginx -t
if [ $? -ne 0 ]; then
    echo "Ошибка в синтаксисе конфига Nginx. Выход."
    exit 1
fi
systemctl reload nginx

# 15. Настройка брандмауэра
echo "Настройка UFW..."
if command -v ufw &> /dev/null; then
    ufw allow $PORT/tcp
    ufw allow 80/tcp
    ufw allow 22/tcp
    ufw --force enable
fi

# 16. Запуск Xray и Django
echo "Запуск Xray и Django сервиса..."
systemctl enable xray
systemctl restart xray
systemctl start django_vless_panel

if [ $? -ne 0 ]; then
    echo "Ошибка при запуске Xray или Django сервиса. Выход."
    exit 1
fi

echo "=== Установка завершена успешно! ==="
echo "=== Настройки подключения VLESS ==="
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
echo "Лог обновления Xray: cat /var/log/xray_update.log"
