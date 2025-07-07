<?php
// Редирект с сообщением
function redirect($url, $message = null) {
    if ($message) {
        $_SESSION['flash_message'] = $message;
    }
    header("Location: $url");
    exit;
}

// Отображение flash-сообщения
function displayFlash() {
    if (!empty($_SESSION['flash_message'])) {
        echo '<div class="flash-message">' . htmlspecialchars($_SESSION['flash_message']) . '</div>';
        unset($_SESSION['flash_message']);
    }
}

// Генерация кода чата
function generateChatCode() {
    $prefix = 'AE-';
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    $part1 = substr(str_shuffle($chars), 0, 5);
    $part2 = substr(str_shuffle($chars), 0, 5);
    return $prefix . $part1 . '-' . $part2;
}

// Шифрование сообщения
function encryptMessage($message) {
    $iv = openssl_random_pseudo_bytes(16);
    $encrypted = openssl_encrypt($message, 'aes-256-cbc', ENCRYPTION_KEY, 0, $iv);
    return [
        'encrypted' => base64_encode($encrypted),
        'iv' => bin2hex($iv)
    ];
}

// Дешифровка сообщения
function decryptMessage($encrypted, $iv) {
    return openssl_decrypt(base64_decode($encrypted), 'aes-256-cbc', ENCRYPTION_KEY, 0, hex2bin($iv));
}

// Безопасное выполнение запроса
function safe_query($query, $params = []) {
    global $db;
    
    $stmt = mysqli_prepare($db, $query);
    if (!$stmt) {
        die("Ошибка подготовки запроса: " . mysqli_error($db));
    }
    
    if (!empty($params)) {
        $types = '';
        $values = [];
        
        foreach ($params as $param) {
            if (is_int($param)) {
                $types .= 'i';
            } elseif (is_float($param)) {
                $types .= 'd';
            } else {
                $types .= 's';
            }
            $values[] = $param;
        }
        
        mysqli_stmt_bind_param($stmt, $types, ...$values);
    }
    
    if (!mysqli_stmt_execute($stmt)) {
        die("Ошибка выполнения запроса: " . mysqli_error($db));
    }
    
    return $stmt;
}

// Получение одной строки
function fetch_single($query, $params = []) {
    $stmt = safe_query($query, $params);
    $result = mysqli_stmt_get_result($stmt);
    return mysqli_fetch_assoc($result);
}

// Получение всех строк
function fetch_all($query, $params = []) {
    $stmt = safe_query($query, $params);
    $result = mysqli_stmt_get_result($stmt);
    $rows = [];
    
    while ($row = mysqli_fetch_assoc($result)) {
        $rows[] = $row;
    }
    
    return $rows;
}

// Выполнение запроса без возврата данных
function execute_query($query, $params = []) {
    $stmt = safe_query($query, $params);
    return mysqli_stmt_affected_rows($stmt);
}

// Проверка авторизации
function checkAuth() {
    if (empty($_SESSION['user_id'])) {
        redirect('index.php', 'Пожалуйста, войдите в систему');
    }
}
?>