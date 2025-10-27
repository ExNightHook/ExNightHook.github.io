#!/bin/bash

# --- Настройки ---
PORT=443
ADMIN_USERNAME="Aesthesia"
ADMIN_PASSWORD="aN5oL2rZ4vrJ"
ADMIN_EMAIL="admin@example.com"
PROJECT_NAME="vless_panel"
APP_NAME="panel"
PYTHON_VENV_PATH="/opt/vless_panel_venv"
PROJECT_DIR="$PYTHON_VENV_PATH/$PROJECT_NAME"
APP_DIR="$PROJECT_DIR/$APP_NAME"
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

# 5. Создание Django-проекта и приложения с правильной структурой
echo "Создание Django-проекта и приложения..."

# Создаем основную директорию проекта
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Создаем Django проект в текущей директории
"$PYTHON_VENV_PATH/bin/django-admin" startproject "$PROJECT_NAME" .
if [ $? -ne 0 ]; then
    echo "Ошибка при создании Django-проекта. Выход."
    exit 1
fi

# Создаем приложение
"$PYTHON_VENV_PATH/bin/python" manage.py startapp "$APP_NAME"
if [ $? -ne 0 ]; then
    echo "Ошибка при создании Django-приложения. Выход."
    exit 1
fi

# 6. Настройка settings.py
echo "Настройка Django settings.py..."
DB_PASSWORD=$(openssl rand -hex 16)

cat << EOF > "$PROJECT_DIR/$PROJECT_NAME/settings.py"
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = '$(openssl rand -hex 32)'
DEBUG = False
ALLOWED_HOSTS = ['$SERVER_IP', 'localhost', '127.0.0.1']

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
        'DIRS': [os.path.join(BASE_DIR, 'templates')],
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
        'PASSWORD': '$DB_PASSWORD',
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

# 9. Настройка URLs
echo "Настройка URLs..."
cat << EOF > "$PROJECT_DIR/$PROJECT_NAME/urls.py"
from django.contrib import admin
from django.urls import path

urlpatterns = [
    path('admin/', admin.site.urls),
]
EOF

# 10. Настройка PostgreSQL
echo "Настройка PostgreSQL..."
sudo -u postgres psql -c "CREATE USER vless_panel_user WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE vless_panel_db OWNER vless_panel_user;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE vless_panel_db TO vless_panel_user;" 2>/dev/null || true

# 11. Выполнение миграций и создание суперпользователя
echo "Выполнение Django миграций и создание суперпользователя..."
cd "$PROJECT_DIR"

# Собираем статические файлы
"$PYTHON_VENV_PATH/bin/python" manage.py collectstatic --noinput

"$PYTHON_VENV_PATH/bin/python" manage.py makemigrations
if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении makemigrations. Выход."
    exit 1
fi

"$PYTHON_VENV_PATH/bin/python" manage.py migrate
if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении migrate. Выход."
    exit 1
fi

echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$ADMIN_USERNAME', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')" | "$PYTHON_VENV_PATH/bin/python" manage.py shell
if [ $? -ne 0 ]; then
    echo "Ошибка при создании суперпользователя. Выход."
    exit 1
fi
echo "Django миграции и суперпользователь успешно созданы."

# 12. Создание скрипта генерации конфига Xray
echo "Создание скрипта генерации конфига Xray..."
cat << 'EOF' > "$XRAY_CONFIG_GENERATOR"
#!/usr/bin/env python3
import os
import sys
import django
from datetime import datetime

# Добавляем путь к проекту Django
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
        "settings": {
            "clients": clients,
            "decryption": "none"
        },
        "streamSettings": {
            "network": "tcp",
            "security": "none"
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {}
    }]
}

import json
CONFIG_FILE_PATH = "/usr/local/etc/xray/config.json"

# Создаем директорию если не существует
os.makedirs(os.path.dirname(CONFIG_FILE_PATH), exist_ok=True)

with open(CONFIG_FILE_PATH, 'w') as f:
    json.dump(xray_config, f, indent=2)

print(f"Конфигурация Xray обновлена. Активные ключи: {len(clients)}")
EOF

chmod +x "$XRAY_CONFIG_GENERATOR"

# 13. Создание скрипта обновления Xray и cron-задачи
echo "Создание скрипта обновления Xray и cron-задачи..."
cat << EOF > "$XRAY_UPDATE_SCRIPT"
#!/bin/bash
source $PYTHON_VENV_PATH/bin/activate
cd $PROJECT_DIR
python $XRAY_CONFIG_GENERATOR
systemctl restart xray
EOF

chmod +x "$XRAY_UPDATE_SCRIPT"

# Создаем лог-файл и добавляем cron задачу
touch /var/log/xray_update.log
chmod 644 /var/log/xray_update.log
(crontab -l 2>/dev/null | grep -v 'update_xray_from_db'; echo "* * * * * $XRAY_UPDATE_SCRIPT >> /var/log/xray_update.log 2>&1") | crontab -

# 14. Создание сервиса Django
echo "Создание и настройка сервиса Django..."
cat << EOF > "$DJANGO_SERVICE_FILE"
[Unit]
Description=Django VLESS Panel
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PYTHON_VENV_PATH/bin
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PYTHON_VENV_PATH/bin/gunicorn --bind 0.0.0.0:8000 --workers 3 vless_panel.wsgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable django_vless_panel

# 15. Установка Gunicorn
echo "Установка Gunicorn..."
source "$PYTHON_VENV_PATH/bin/activate"
pip install gunicorn

# 16. Настройка Nginx
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
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        alias $PROJECT_DIR/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

ln -sf "$NGINX_CONFIG_FILE" /etc/nginx/sites-enabled/
nginx -t
if [ $? -ne 0 ]; then
    echo "Ошибка в синтаксисе конфига Nginx. Выход."
    exit 1
fi

# 17. Настройка брандмауэра
echo "Настройка UFW..."
if command -v ufw &> /dev/null; then
    ufw allow $PORT/tcp
    ufw allow 80/tcp
    ufw allow 22/tcp
    ufw --force enable
fi

# 18. Генерация начального конфига Xray и запуск сервисов
echo "Генерация начального конфига Xray..."
$XRAY_UPDATE_SCRIPT

echo "Запуск сервисов..."
systemctl enable xray
systemctl restart xray
systemctl restart nginx
systemctl start django_vless_panel

# Даем сервисам время на запуск
sleep 5

# Проверяем статусы сервисов
echo "=== Статусы сервисов ==="
echo "Xray: $(systemctl is-active xray)"
echo "Nginx: $(systemctl is-active nginx)"
echo "Django: $(systemctl is-active django_vless_panel)"

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
echo "Полезные команды:"
echo "Просмотр логов Xray: journalctl -u xray -f"
echo "Просмотр логов Django: journalctl -u django_vless_panel -f"
echo "Просмотр логов обновления: tail -f /var/log/xray_update.log"
echo "Перезапуск панели: systemctl restart django_vless_panel"
