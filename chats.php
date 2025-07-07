<?php
require_once 'includes/config.php';
checkAuth();

// Получение списка чатов пользователя
$user_id = $_SESSION['user_id'];
$chats = fetch_all("
    SELECT c.id, c.name, c.chat_code 
    FROM chats c
    JOIN chat_members cm ON c.id = cm.chat_id
    WHERE cm.user_id = ?
", [$user_id]);

// Создание чата
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_chat'])) {
    $name = trim($_POST['name']);
    
    if (empty($name)) {
        $error = "Введите название чата";
    } else {
        $chatCode = generateChatCode();
        
        execute_query("INSERT INTO chats (chat_code, name, owner_id) VALUES (?, ?, ?)", 
            [$chatCode, $name, $user_id]);
        
        $chatId = mysqli_insert_id($db);
        
        // Добавление создателя в чат
        execute_query("INSERT INTO chat_members (chat_id, user_id) VALUES (?, ?)", 
            [$chatId, $user_id]);
        
        redirect("chat.php?id=$chatId", "Чат успешно создан! Код: $chatCode");
    }
}

// Присоединение к чату
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['join_chat'])) {
    $chatCode = trim($_POST['chat_code']);
    
    if (empty($chatCode)) {
        $error = "Введите код чата";
    } else {
        $chat = fetch_single("SELECT id FROM chats WHERE chat_code = ?", [$chatCode]);
        
        if (!$chat) {
            $error = "Чат не найден";
        } else {
            $chatId = $chat['id'];
            
            // Проверка, не состоит ли уже в чате
            $member = fetch_single("SELECT * FROM chat_members WHERE chat_id = ? AND user_id = ?", 
                [$chatId, $user_id]);
            
            if (!$member) {
                execute_query("INSERT INTO chat_members (chat_id, user_id) VALUES (?, ?)", 
                    [$chatId, $user_id]);
                redirect("chat.php?id=$chatId", "Вы присоединились к чату!");
            } else {
                $error = "Вы уже состоите в этом чате";
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="ru" data-theme="onyx">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Чаты - Aesthesia</title>
    <link rel="stylesheet" href="/assets/css/styles.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>Aesthesia Messenger</h1>
            <nav>
                <a href="chats.php" class="active">Чаты</a>
                <a href="profile.php">Профиль</a>
                <a href="logout.php">Выйти</a>
            </nav>
        </header>
        
        <main>
            <?php displayFlash(); ?>
            
            <?php if (!empty($error)): ?>
                <div class="error"><?= $error ?></div>
            <?php endif; ?>
            
            <div class="actions">
                <h2>Создать новый чат</h2>
                <form method="POST">
                    <input type="text" name="name" placeholder="Название чата" required>
                    <button type="submit" name="create_chat">Создать</button>
                </form>
                
                <h2>Присоединиться к чату</h2>
                <form method="POST">
                    <input type="text" name="chat_code" placeholder="Код чата (AE-XXXXX-XXXXX)" required>
                    <button type="submit" name="join_chat">Присоединиться</button>
                </form>
            </div>
            
            <div class="chat-list">
                <h2>Ваши чаты</h2>
                <?php if (count($chats) > 0): ?>
                    <?php foreach ($chats as $chat): ?>
                        <a href="chat.php?id=<?= $chat['id'] ?>" class="chat-item">
                            <h3><?= htmlspecialchars($chat['name']) ?></h3>
                            <p>Код: <?= htmlspecialchars($chat['chat_code']) ?></p>
                        </a>
                    <?php endforeach; ?>
                <?php else: ?>
                    <p>Вы еще не состоите ни в одном чате</p>
                <?php endif; ?>
            </div>
        </main>
    </div>
</body>
</html>