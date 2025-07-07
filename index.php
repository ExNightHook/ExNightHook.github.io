<?php
require_once 'includes/config.php';

// Обработка формы регистрации
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['register'])) {
    $username = trim($_POST['username']);
    $password = trim($_POST['password']);
    
    // Валидация
    if (empty($username) || empty($password)) {
        $error = "Заполните все поля";
    } else {
        // Проверка существования пользователя
        $user = fetch_single("SELECT id FROM users WHERE username = ?", [$username]);
        
        if ($user) {
            $error = "Имя пользователя занято";
        } else {
            // Создание пользователя
            $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
            execute_query("INSERT INTO users (username, password) VALUES (?, ?)", [$username, $hashedPassword]);
            
            // Автоматический вход
            $_SESSION['user_id'] = mysqli_insert_id($db);
            redirect('chats.php', 'Регистрация прошла успешно!');
        }
    }
}

// Обработка формы входа
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login'])) {
    $username = trim($_POST['username']);
    $password = trim($_POST['password']);
    
    $user = fetch_single("SELECT id, password FROM users WHERE username = ?", [$username]);
    
    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['user_id'] = $user['id'];
        redirect('chats.php');
    } else {
        $error = "Неверные учетные данные";
    }
}
?>
<!DOCTYPE html>
<html lang="ru" data-theme="onyx">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Aesthesia Messenger</title>
    <link rel="stylesheet" href="/assets/css/styles.css">
</head>
<body>
    <div id="auth-container">
        <h1>Aesthesia Messenger</h1>
        
        <?php if (isset($error)): ?>
            <div class="error"><?= $error ?></div>
        <?php endif; ?>
        
        <div class="tabs">
            <button class="tab active" data-tab="login">Вход</button>
            <button class="tab" data-tab="register">Регистрация</button>
        </div>
        
        <div id="login-form" class="form active">
            <form method="POST">
                <input type="text" name="username" placeholder="Никнейм" required>
                <input type="password" name="password" placeholder="Пароль" required>
                <button type="submit" name="login">Войти</button>
            </form>
        </div>
        
        <div id="register-form" class="form">
            <form method="POST">
                <input type="text" name="username" placeholder="Никнейм" required>
                <input type="password" name="password" placeholder="Пароль" required>
                <button type="submit" name="register">Создать аккаунт</button>
            </form>
        </div>
    </div>
    
    <script>
        // Переключение вкладок
        document.querySelectorAll('.tab').forEach(tab => {
            tab.addEventListener('click', () => {
                const target = tab.dataset.tab;
                document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
                document.querySelectorAll('.form').forEach(f => f.classList.remove('active'));
                
                tab.classList.add('active');
                document.getElementById(`${target}-form`).classList.add('active');
            });
        });
    </script>
</body>
</html>