<?php
// Подключение к базе данных
$servername = "sql303.infinityfree.com";
$username = "if0_37645935";
$password = "lprZY9p1uvYpH3R";
$dbname = "if0_37645935_api";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Функция генерации ключа
function generateKey() {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    $key = 'ENH-SC-';
    
    for($i = 0; $i < 3; $i++) {
        $part = '';
        for($j = 0; $j < 5; $j++) {
            $part .= $chars[rand(0, strlen($chars)-1)];
        }
        $key .= $part . ($i < 2 ? '-' : '');
    }
    
    return $key;
}

// Генерация 10 уникальных ключей
$generatedKeys = [];
for($i = 0; $i < 10; $i++) {
    do {
        $newKey = generateKey();
        // Проверка уникальности
        $check = $conn->query("SELECT `key` FROM api_keys WHERE `key` = '$newKey'");
    } while($check->num_rows > 0);
    
    $generatedKeys[] = $newKey;
}

// Добавление в базу данных
foreach($generatedKeys as $key) {
    $sql = "INSERT INTO api_keys (`key`, `long`) VALUES (?, 30)"; // 30 дней по умолчанию
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $key);
    $stmt->execute();
}

echo "Сгенерировано 10 ключей:\n";
foreach($generatedKeys as $key) {
    echo $key . "\n";
}

$conn->close();
?>