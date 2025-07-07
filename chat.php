<?php
require_once 'includes/config.php';
checkAuth();

$chatId = $_GET['id'] ?? 0;
$user_id = $_SESSION['user_id'];

// Проверка участия в чате
$member = fetch_single("SELECT * FROM chat_members WHERE chat_id = ? AND user_id = ?", 
    [$chatId, $user_id]);
    
if (!$member) {
    redirect('chats.php', 'Вы не состоите в этом чате');
}

// Получение информации о чате
$chat = fetch_single("SELECT name, chat_code FROM chats WHERE id = ?", [$chatId]);

// Отправка сообщения
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['send_message'])) {
    $message = trim($_POST['message']);
    
    if (!empty($message)) {
        // Шифрование сообщения
        $encrypted = encryptMessage($message);
        
        execute_query("
            INSERT INTO messages (chat_id, user_id, encrypted_message, iv)
            VALUES (?, ?, ?, ?)
        ", [$chatId, $user_id, $encrypted['encrypted'], $encrypted['iv']]);
        
        // Перенаправление для предотвращения повторной отправки
        redirect("chat.php?id=$chatId");
    }
}

// Получение сообщений
$messages = fetch_all("
    SELECT m.*, u.username 
    FROM messages m
    JOIN users u ON m.user_id = u.id
    WHERE m.chat_id = ?
    ORDER BY m.created_at ASC
", [$chatId]);

// Дешифровка сообщений
foreach ($messages as &$msg) {
    $msg['message'] = decryptMessage($msg['encrypted_message'], $msg['iv']);
}
?>
<!DOCTYPE html>
<html lang="ru" data-theme="onyx">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Чат - <?= htmlspecialchars($chat['name']) ?></title>
    <link rel="stylesheet" href="/assets/css/styles.css">
</head>
<body>
    <div class="container">
        <header>
            <h1><?= htmlspecialchars($chat['name']) ?></h1>
            <nav>
                <a href="chats.php">Чаты</a>
                <a href="profile.php">Профиль</a>
                <a href="logout.php">Выйти</a>
            </nav>
        </header>
        
        <main class="chat-container">
            <div class="chat-info">
                <p>Код чата: <?= htmlspecialchars($chat['chat_code']) ?></p>
            </div>
            
            <div class="messages-container">
                <?php foreach ($messages as $msg): ?>
                    <div class="message <?= $msg['user_id'] == $user_id ? 'own' : '' ?>">
                        <div class="message-header">
                            <strong><?= htmlspecialchars($msg['username']) ?></strong>
                            <span><?= date('H:i', strtotime($msg['created_at'])) ?></span>
                        </div>
                        <div class="message-content"><?= htmlspecialchars($msg['message']) ?></div>
                    </div>
                <?php endforeach; ?>
            </div>
            
            <div class="message-input-area">
                <form method="POST">
                    <input type="text" name="message" placeholder="Введите сообщение..." required>
                    <button type="submit" name="send_message">Отправить</button>
                </form>
            </div>
        </main>
    </div>
</body>
</html>