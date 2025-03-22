<?php
header('Content-Type: text/html; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

$config = [
    'db' => [
        'host' => "sql303.infinityfree.com",
        'user' => "if0_37645935",
        'pass' => "lprZY9p1uvYpH3R",
        'name' => "if0_37645935_api"
    ],
    'file' => [
        'url' => 'https://exnighthook.github.io/521FE5C9ECE1AA1F8B66228171598263574AEFC6FA4BA06A61747EC81EE9F5A3/Stalcraft/sc_loader.exe',
        'name_length' => 8
    ]
];

// Обработка API запроса
if (isset($_GET['key'])) {
    header('Content-Type: application/json');
    
    try {
        $key = substr($_GET['key'], 0, 20);
        $conn = new mysqli(
            $config['db']['host'],
            $config['db']['user'],
            $config['db']['pass'],
            $config['db']['name']
        );

        if ($conn->connect_error) throw new Exception("DB connection error", 500);

        $stmt = $conn->prepare("SELECT * FROM api_keys WHERE `key` = ?");
        $stmt->bind_param("s", $key);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 0) throw new Exception("Key not found", 404);

        $row = $result->fetch_assoc();
        $ip = $_SERVER['REMOTE_ADDR'];

        if (empty($row['ip'])) {
            $updateStmt = $conn->prepare("UPDATE api_keys 
                SET ip = ?, expiry = DATE_ADD(NOW(), INTERVAL `long` DAY) 
                WHERE `key` = ?");
            $updateStmt->bind_param("ss", $ip, $key);
            if (!$updateStmt->execute()) throw new Exception("Activation failed", 500);
            $row = $result->fetch_assoc();
        }

        if ($row['ip'] !== $ip) throw new Exception("IP mismatch", 403);
        if (new DateTime($row['expiry']) < new DateTime()) throw new Exception("Subscription expired", 403);

        // Отправка файла
    if (isset($_GET['download'])) {
        // Генерация случайного имени
        $chars = '0123456789AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz!@#$%&*<>';
        $randomName = substr(str_shuffle(str_repeat($chars, 5)), 0, $config['file']['name_length']) . '.exe';

        $randomPadding = bin2hex(random_bytes(64));

        // Настройка cURL для потоковой передачи
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $config['file']['url'],
            CURLOPT_RETURNTRANSFER => false,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_HEADER => false,
            CURLOPT_BUFFERSIZE => 131072, // 128KB буфер
            CURLOPT_NOPROGRESS => false,
            CURLOPT_PROGRESSFUNCTION => function($resource, $downloadSize, $downloaded, $uploadSize, $uploaded) {
                return ($downloaded > 100 * 1024 * 1024) ? 1 : 0; // Лимит 100MB
            },
            CURLOPT_WRITEFUNCTION => function($ch, $data) {
                echo $data;
                ob_flush();
                flush();
                return strlen($data);
            }
        ]);

        // Заголовки для скачивания
        header('Content-Description: File Transfer');
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="'.$randomName.'"');
        header('Expires: 0');
        header('Cache-Control: must-revalidate');
        header('Pragma: public');

        // Убрать лимиты
        ignore_user_abort(true);
        set_time_limit(0);
        ob_implicit_flush(1);
        ob_end_flush();

        // Запуск загрузки
        $result = curl_exec($ch);
        
        if(curl_errno($ch)) {
            $error = curl_error($ch);
            curl_close($ch);
            throw new Exception("Download failed: $error", 500);
        }

        echo $randomPadding;
        ob_flush();
        flush();

        curl_close($ch);
        exit;
    }

        echo json_encode([
            'id' => $row['id'],
            'expiry' => $row['expiry'],
            'days_left' => (new DateTime())->diff(new DateTime($row['expiry']))->days
        ]);

    } catch (Exception $e) {
        http_response_code($e->getCode() ?: 500);
        echo json_encode(['error' => $e->getMessage()]);
    }
    exit;
}
?>

<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ExNightHook | Next-level gaming software</title>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #0f1014;
            --primary: #A38EEB;
            --accent: #C6B4FF;
            --text: #E8E3FF;
            --border: #2D283F;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Space Grotesk', sans-serif;
        }

        body {
            background: var(--bg);
            color: var(--text);
            line-height: 1.7;
            overflow-x: hidden;
        }

        ::selection {
            background: var(--primary);
            color: var(--bg);
        }

        .gradient-text {
            background: linear-gradient(45deg, var(--primary), var(--accent));
            -webkit-background-clip: text;
            background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .staggered-reveal {
            opacity: 0;
            transform: translateY(30px);
            transition: all 0.8s cubic-bezier(0.23, 1, 0.32, 1);
        }

        .nav-wrapper {
            position: fixed;
            top: 0;
            width: 100%;
            z-index: 1000;
            background: rgba(15, 16, 20, 0.92);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid var(--border);
        }

        nav {
            max-width: 1200px;
            margin: 0 auto;
            padding: 1.5rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-size: 1.8rem;
            font-weight: 600;
            letter-spacing: -0.03em;
            position: relative;
        }

        .logo::after {
            content: '';
            position: absolute;
            right: -8px;
            bottom: 4px;
            width: 8px;
            height: 8px;
            background: var(--accent);
            border-radius: 50%;
            opacity: 0.6;
        }

        .nav-links {
            display: flex;
            gap: 2.5rem;
        }

        .nav-links a {
            color: var(--text);
            text-decoration: none;
            position: relative;
            padding: 0.5rem 0;
        }

        .nav-links a::after {
            content: '';
            position: absolute;
            bottom: 0;
            left: 0;
            width: 0;
            height: 2px;
            background: var(--primary);
            transition: width 0.3s ease;
        }

        .nav-links a:hover::after {
            width: 100%;
        }

        .hero {
            min-height: 100vh;
            display: flex;
            align-items: center;
            padding: 8rem 2rem 4rem;
            position: relative;
            overflow: hidden;
        }

        .hero-content {
            max-width: 1200px;
            margin: 0 auto;
            position: relative;
            z-index: 1;
        }

        .hero h1 {
            font-size: 4rem;
            margin-bottom: 2rem;
            line-height: 1.1;
            max-width: 800px;
        }

        .hero p {
            font-size: 1.2rem;
            color: var(--primary);
            margin-bottom: 3rem;
            max-width: 600px;
        }

        .cta-button {
            display: inline-flex;
            align-items: center;
            padding: 1rem 2.5rem;
            background: linear-gradient(45deg, var(--primary), var(--accent));
            color: var(--bg);
            text-decoration: none;
            border-radius: 0.5rem;
            font-weight: 600;
            transition: transform 0.3s, box-shadow 0.3s;
            position: relative;
            overflow: hidden;
        }

        .cta-button::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(
                120deg,
                transparent,
                rgba(255, 255, 255, 0.1),
                transparent
            );
            transition: 0.5s;
        }

        .cta-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 30px rgba(163, 142, 235, 0.3);
        }

        .cta-button:hover::before {
            left: 100%;
        }

        .features {
            padding: 6rem 2rem;
            position: relative;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            max-width: 1200px;
            margin: 0 auto;
        }

        .feature-card {
            background: rgba(40, 42, 54, 0.4);
            border: 1px solid var(--border);
            border-radius: 1rem;
            padding: 2.5rem;
            transition: transform 0.3s, background 0.3s;
        }

        .feature-card:hover {
            transform: translateY(-10px);
            background: rgba(50, 52, 66, 0.6);
        }

        .feature-icon {
            width: 50px;
            height: 50px;
            background: rgba(163, 142, 235, 0.1);
            border-radius: 0.75rem;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .feature-card h3 {
            font-size: 1.5rem;
            margin-bottom: 1rem;
        }

        .feature-card p {
            color: #A098C7;
        }

        @media (max-width: 768px) {
            .hero h1 {
                font-size: 3rem;
            }

            .nav-links {
                display: none;
            }
        }

        @keyframes float {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-20px); }
        }

        .scroll-reveal {
            opacity: 0;
            transform: translateY(30px);
            transition: 1s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .scroll-reveal.active {
            opacity: 1;
            transform: translateY(0);
        }

        .cosmic-bg {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: -1;
        }

        .nebula {
            position: absolute;
            width: 150%;
            height: 150%;
            background: radial-gradient(circle at 50% 50%, 
                rgba(163, 142, 235, 0.05) 0%, 
                rgba(15, 16, 20, 0.9) 70%);
            animation: nebulaFlow 40s infinite linear;
        }

        @keyframes nebulaFlow {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .particle {
            position: absolute;
            background: rgba(163, 142, 235, 0.1);
            border-radius: 50%;
            filter: blur(1px);
        }

        .planet-system {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
        }

        .planet {
            position: absolute;
            border-radius: 50%;
            background: radial-gradient(circle at 30% 30%, 
                #6A5B8E, 
                #2D283F);
            box-shadow: 0 0 50px rgba(163, 142, 235, 0.1);
        }

        .ring {
            position: absolute;
            border-radius: 50%;
            border: 1px solid rgba(163, 142, 235, 0.2);
            transform-style: preserve-3d;
        }

        .floating-dots {
            position: fixed;
            width: 100%;
            height: 100%;
            pointer-events: none;
        }

        .hologram-effect {
            position: relative;
            overflow: hidden;
        }

        .hologram-effect::before {
            content: '';
            position: absolute;
            top: -50%;
            left: -50%;
            width: 200%;
            height: 200%;
            background: linear-gradient(45deg, 
                transparent 25%,
                rgba(163, 142, 235, 0.1) 50%,
                transparent 75%);
            animation: hologramScan 4s infinite linear;
            mix-blend-mode: overlay;
        }

        @keyframes hologramScan {
            0% { transform: rotate(45deg) translateY(-100%); }
            100% { transform: rotate(45deg) translateY(100%); }
        }

        .auth-section {
            padding: 2rem;
            background: rgba(40, 42, 54, 0.4);
            border-radius: 1rem;
            margin-top: 2rem;
        }
        
        .download-section {
            display: none;
            text-align: center;
            padding: 3rem;
        }

.success-message {
    color: #4CAF50;
    font-size: 2.5rem;
    margin-bottom: 2rem;
    text-shadow: 0 0 15px rgba(76, 175, 80, 0.3);
}

.license-info {
    background: rgba(40, 42, 54, 0.6);
    padding: 2rem;
    border-radius: 1rem;
    border: 1px solid var(--border);
    max-width: 600px;
    margin: 0 auto;
}

.license-info p {
    font-size: 1.2rem;
    margin: 1rem 0;
}

.download-progress {
    height: 4px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    margin-top: 2rem;
    overflow: hidden;
}

.progress-bar {
    width: 0%;
    height: 100%;
    background: linear-gradient(90deg, var(--primary), var(--accent));
    transition: width 0.3s ease;
}


/* Добавить в CSS */
.auth-container {
    position: relative;
    max-width: 500px;
    margin: 2rem auto;
    perspective: 1000px;
}

.auth-glass {
    background: rgba(40, 42, 54, 0.25);
    backdrop-filter: blur(12px);
    border-radius: 1.5rem;
    padding: 2.5rem 2rem;
    border: 1px solid rgba(163, 142, 235, 0.15);
    box-shadow: 0 8px 32px rgba(11, 12, 16, 0.3);
    transform-style: preserve-3d;
    transition: all 0.6s cubic-bezier(0.23, 1, 0.32, 1);
}

.auth-glass:hover {
    transform: translateY(-5px) rotateX(1deg) rotateY(-1deg);
    box-shadow: 0 15px 45px rgba(11, 12, 16, 0.4);
}

.key-icon {
    font-size: 2.5rem;
    text-align: center;
    margin-bottom: 1.5rem;
    opacity: 0.8;
    filter: drop-shadow(0 0 10px rgba(163, 142, 235, 0.3));
}

.auth-input {
    width: 100%;
    padding: 1.2rem;
    margin: 1rem 0;
    background: rgba(30, 31, 41, 0.6);
    border: 2px solid transparent;
    border-radius: 0.75rem;
    color: var(--text);
    font-size: 1.1rem;
    transition: all 0.3s ease;
    box-shadow: inset 0 0 15px rgba(0, 0, 0, 0.1);
}

.auth-input::placeholder {
    color: #6B6685;
}

.auth-input:focus {
    outline: none;
    border-color: var(--primary);
    background: rgba(45, 46, 60, 0.6);
    box-shadow: 0 0 25px rgba(163, 142, 235, 0.15),
                inset 0 0 10px rgba(163, 142, 235, 0.1);
}

.auth-button {
    position: relative;
    width: 100%;
    padding: 1.3rem;
    margin-top: 1.5rem;
    background: linear-gradient(135deg, var(--primary), var(--accent));
    border: none;
    border-radius: 0.75rem;
    color: var(--bg);
    font-weight: 600;
    font-size: 1.1rem;
    cursor: pointer;
    overflow: hidden;
    transition: all 0.4s cubic-bezier(0.23, 1, 0.32, 1);
}

.auth-button span {
    position: relative;
    z-index: 2;
}

.auth-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
        120deg,
        transparent,
        rgba(255, 255, 255, 0.15),
        transparent
    );
    transition: 0.6s;
}

.auth-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 30px rgba(163, 142, 235, 0.35);
}

.auth-button:hover::before {
    left: 100%;
}

.button-loader {
    display: none;
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 24px;
    height: 24px;
    border: 3px solid rgba(255, 255, 255, 0.2);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
}

@keyframes spin {
    to { transform: translate(-50%, -50%) rotate(360deg); }
}

.status-message {
    margin-top: 1.5rem;
    padding: 1rem;
    border-radius: 0.5rem;
    text-align: center;
    font-size: 0.95rem;
    opacity: 0;
    transform: translateY(10px);
    transition: all 0.4s ease;
}

.status-message.visible {
    opacity: 1;
    transform: translateY(0);
}

.status-message.success {
    background: rgba(76, 175, 80, 0.15);
    border: 1px solid #4CAF50;
    color: #A5D6A7;
}

.status-message.error {
    background: rgba(244, 67, 54, 0.15);
    border: 1px solid #F44336;
    color: #EF9A9A;
}

    </style>
</head>
<body>
    <div class="cosmic-bg">
        <div class="nebula"></div>
        <canvas id="particles"></canvas>
        <div class="planet-system">
            <div class="planet" style="width: 400px; height: 400px; margin: -200px 0 0 -200px;">
                <div class="ring" style="width: 600px; height: 600px; margin: -300px 0 0 -300px; animation: rotate 80s infinite linear;"></div>
            </div>
        </div>
    </div>

    <div class="nav-wrapper">
        <nav>
            <div class="logo gradient-text">ExNightHook</div>
            <div class="nav-links">
                <a href="#loader">Loader</a>
            </div>
        </nav>
    </div>

    <section class="hero">
        <div class="hero-content">
            <div id="mainContent">
                <h1 class="scroll-reveal">
                    <span class="gradient-text">Rethink</span> your gaming experience
                </h1>
            <p class="scroll-reveal">ExNightHook - is the best gaming assistant for popular online games. The best prices in the CIS, fast and high-quality technical support for users. We develop only reliable and high-quality software for you.</p>
        </div>
        
        <div id="licenseContent" style="display: none;">
            <div class="license-status success-message">Key activated</div>
                <div class="license-info">
                    <p>Key: <span id="licenseKeyValue" class="gradient-text"></span></p>
                    <p>Expiry: <span id="licenseExpiryDate"></span></p>
                <div class="download-progress">
                    <div class="progress-bar"></div>
                </div>
            </div>
        </div>

    </section>

<div class="auth-container">
    <div class="auth-glass">
        <div class="key-icon">🔑</div>
        <input 
            type="text" 
            id="licenseKey" 
            placeholder="Enter key"
            class="auth-input"
        >
        <button onclick="activateLicense()" class="auth-button">
            <span>Login</span>
            <div class="button-loader"></div>
        </button>
        <div id="statusMessage" class="status-message"></div>
    </div>
</div>

    <script>
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('active');
                }
            });
        }, { threshold: 0.1 });

        document.querySelectorAll('.scroll-reveal').forEach((el) => {
            observer.observe(el);
        });

        document.addEventListener('mousemove', (e) => {
            const hero = document.querySelector('.hero');
            const x = (window.innerWidth - e.pageX * 2) / 90;
            const y = (window.innerHeight - e.pageY * 2) / 90;
            hero.style.transform = `translate(${x}px, ${y}px)`;
        });
    </script>

    <script>
        const canvas = document.getElementById('particles');
        const ctx = canvas.getContext('2d');
        let width = canvas.width = window.innerWidth;
        let height = canvas.height = window.innerHeight;

        class Particle {
            constructor() {
                this.reset();
            }

            reset() {
                this.x = Math.random() * width;
                this.y = Math.random() * height;
                this.size = Math.random() * 2;
                this.speed = Math.random() * 0.5 + 0.1;
                this.angle = Math.random() * Math.PI * 2;
            }

            update() {
                this.x += Math.cos(this.angle) * this.speed;
                this.y += Math.sin(this.angle) * this.speed;
                
                if (this.x < 0 || this.x > width || this.y < 0 || this.y > height) {
                    this.reset();
                }
            }

            draw() {
                ctx.fillStyle = `rgba(163, 142, 235, ${this.size/3})`;
                ctx.beginPath();
                ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        const particles = Array(200).fill().map(() => new Particle());

        function animateParticles() {
            ctx.clearRect(0, 0, width, height);
            particles.forEach(p => {
                p.update();
                p.draw();
            });
            requestAnimationFrame(animateParticles);
        }

        window.addEventListener('resize', () => {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
        });

        const planet = document.querySelector('.planet');
        let rotation = 0;

        function rotatePlanet() {
            rotation += 0.2;
            planet.style.transform = `rotate(${rotation}deg)`;
            requestAnimationFrame(rotatePlanet);
        }

        animateParticles();
        rotatePlanet();

        document.addEventListener('mousemove', (e) => {
            const particles = document.querySelectorAll('.particle');
            particles.forEach(p => {
                const dx = e.clientX - p.offsetLeft;
                const dy = e.clientY - p.offsetTop;
                const dist = Math.sqrt(dx * dx + dy * dy);
                p.style.transform = `scale(${1 + (50/dist)})`;
            });
        });

        document.querySelectorAll('.feature-card').forEach(card => {
            card.classList.add('hologram-effect');
        });

async function activateLicense() {
    const button = document.querySelector('.auth-button');
    const loader = button.querySelector('.button-loader');
    const status = document.getElementById('statusMessage');
    const keyInput = document.getElementById('licenseKey');
    const key = keyInput.value.trim();

    if (!key) {
        status.textContent = "License key not entered";
        status.classList.add('visible', 'error');
        return;
    }

    button.style.pointerEvents = 'none';
    loader.style.display = 'block';
    status.classList.remove('visible');

    try {
        const response = await fetch(`?key=${encodeURIComponent(key)}`);
        if (!response.ok) throw await response.json();
        
        const data = await response.json();
        
        document.getElementById('mainContent').style.display = 'none';
        
        const licenseContent = document.getElementById('licenseContent');
        licenseContent.style.display = 'block';
        licenseContent.classList.add('scroll-reveal', 'active');
        
        document.getElementById('licenseKeyValue').textContent = key;
        document.getElementById('licenseExpiryDate').textContent = 
            new Date(data.expiry).toLocaleDateString('ru-RU', {
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });

        const progressBar = document.querySelector('.progress-bar');
        progressBar.style.width = '100%';
        
        status.textContent = 'Access activated';
        status.classList.add('visible', 'success');

        setTimeout(() => {
            const link = document.createElement('a');
            link.href = `?key=${encodeURIComponent(key)}&download=1`;
            link.click();

            status.textContent = 'Download complete';
            status.classList.add('visible', 'success');

        }, 1000);

    } catch (error) {
        status.textContent = `${error.error || error.message || 'Connection error'}`;
        status.classList.add('visible', 'error');
    } finally {
        loader.style.display = 'none';
        button.style.pointerEvents = 'auto';
    }
}
        document.addEventListener('mousemove', (e) => {
            const hero = document.querySelector('.hero');
            hero.style.transform = `translate(
                ${(window.innerWidth/2 - e.clientX)/50}px,
                ${(window.innerHeight/2 - e.clientY)/50}px
            )`;
        });

        window.addEventListener('load', () => {
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('active');
                    }
                });
            }, { threshold: 0.1 });

            document.querySelectorAll('.scroll-reveal').forEach(el => observer.observe(el));
        });
    </script>
</body>
</html>