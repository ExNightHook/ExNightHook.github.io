<?php
// Включить отображение всех ошибок
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

session_start();

// Параметры подключения к БД
$db_host = 'sql303.infinityfree.com';
$db_user = 'if0_37645935';
$db_pass = 'lprZY9p1uvYpH3R';
$db_name = 'if0_37645935_aesthesia';
$db_port = 3306;

// Подключение к базе данных
$db = mysqli_connect($db_host, $db_user, $db_pass, $db_name, $db_port);

if (!$db) {
    die("Ошибка подключения к базе данных: " . mysqli_connect_error());
}

// Установка кодировки
mysqli_set_charset($db, 'utf8mb4');

// Ключ шифрования (ЗАМЕНИТЕ НА СВОЙ!)
define('ENCRYPTION_KEY', 'd08b2e9240c7a3aa5c1b8c6d7f9a1b2e3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9');

// Подключаем вспомогательные функции
require_once 'functions.php';
?>