<?php
// Задаем правильный ключ
$correct_key = "SECRET123";

// Получаем ключ из запроса
$input_key = $_GET['key'] ?? $_POST['key'] ?? '';

// Проверяем, правильный ли ключ
if ($input_key === $correct_key) {
    echo "Success.";
} else {
    echo "Error.";
}
?>
