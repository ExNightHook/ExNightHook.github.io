<?php
try {
    $pdo = new PDO('mysql:host=sql303.infinityfree.com;dbname=if0_37645935_aesthesia', 'if0_37645935', 'lprZY9p1uvYpH3R');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, 3); // Используем числовое значение
    
    $stmt = $pdo->query('SELECT 1');
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "PDO работает корректно! Результат: ";
    print_r($result);
    
} catch (PDOException $e) {
    die("Ошибка PDO: " . $e->getMessage());
}