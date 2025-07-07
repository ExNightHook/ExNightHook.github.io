<?php
require_once 'includes/config.php';
checkAuth();

$user_id = $_SESSION['user_id'];

// Получение данных пользователя
$user = fetch_single("SELECT username, avatar FROM users WHERE id = ?", [$user_id]);

// Обновление аватара
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['avatar'])) {
    $file = $_FILES['avatar'];
    
    if ($file['error'] === UPLOAD_ERR_OK) {
        // Проверка типа файла
        $allowed = ['image/jpeg', 'image/png'];
        if (in_array($file['type'], $allowed)) {
            // Чтение файла и преобразование в base64
            $avatarData = base64_encode(file_get_contents($file['tmp_name']));
            $avatar = 'data:' . $file['type'] . ';base64,' . $avatarData;
            
            execute_query("UPDATE users SET avatar = ? WHERE id = ?", [$avatar, $user_id]);
            $success = "Аватар успешно обновлен!";
        } else {
            $error = "Только JPG/PNG изображения разрешены";
        }
    } else {
        $error = "Ошибка загрузки файла";
    }
}

// Изменение пароля
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['change_password'])) {
    $currentPassword = $_POST['current_password'];
    $newPassword = $_POST['new_password'];
    $confirmPassword = $_POST['confirm_password'];
    
    if ($newPassword === $confirmPassword) {
        // Проверка текущего пароля
        $userData = fetch_single("SELECT password FROM users WHERE id = ?", [$user_id]);
        
        if ($userData && password_verify($currentPassword, $userData['password'])) {
            $newHashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
            execute_query("UPDATE users SET password = ? WHERE id = ?", [$newHashedPassword, $user_id]);
            $success = "Пароль успешно изменен!";
        } else {
            $error = "Текущий пароль неверен";
        }
    } else {
        $error = "Пароли не совпадают";
    }
}
?>
<!DOCTYPE html>
<html lang="ru" data-theme="onyx">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Профиль - Aesthesia</title>
    <link rel="stylesheet" href="/assets/css/styles.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>Aesthesia Messenger</h1>
            <nav>
                <a href="chats.php">Чаты</a>
                <a href="profile.php" class="active">Профиль</a>
                <a href="logout.php">Выйти</a>
            </nav>
        </header>
        
        <main class="profile-container">
            <?php displayFlash(); ?>
            
            <?php if (!empty($error)): ?>
                <div class="error"><?= $error ?></div>
            <?php endif; ?>
            
            <?php if (!empty($success)): ?>
                <div class="success"><?= $success ?></div>
            <?php endif; ?>
            
            <div class="avatar-section">
                <h2>Аватар профиля</h2>
                <?php if (!empty($user['avatar'])): ?>
                    <img src="<?= htmlspecialchars($user['avatar']) ?>" alt="Ваш аватар" class="avatar-preview">
                <?php else: ?>
                    <div class="avatar-placeholder">Нет аватара</div>
                <?php endif; ?>
                
                <form method="POST" enctype="multipart/form-data">
                    <input type="file" name="avatar" accept="image/png, image/jpeg" required>
                    <button type="submit">Изменить аватар</button>
                </form>
            </div>
            
            <div class="password-form">
                <h2>Изменение пароля</h2>
                <form method="POST">
                    <div class="form-group">
                        <label for="current-password">Текущий пароль:</label>
                        <input type="password" id="current-password" name="current_password" required>
                    </div>
                    <div class="form-group">
                        <label for="new-password">Новый пароль:</label>
                        <input type="password" id="new-password" name="new_password" required>
                    </div>
                    <div class="form-group">
                        <label for="confirm-password">Подтвердите пароль:</label>
                        <input type="password" id="confirm-password" name="confirm_password" required>
                    </div>
                    <button type="submit" name="change_password">Изменить пароль</button>
                </form>
            </div>
        </main>
    </div>
</body>
</html>