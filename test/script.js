const KeyAuthApp = {
    name: "ENH Site",
    ownerId: "Y2MUphthuF",
    version: "1.0",
    url: "https://keyauth.ru/api/1.1/",
    sessionid: null,
};

async function makeRequest(data) {
    try {
        const response = await axios.post(KeyAuthApp.url, new URLSearchParams(data));
        return response.data;
    } catch (error) {
        return { success: false, message: "Ошибка сети" };
    }
}

async function initialize() {
    const postData = {
        type: 'init',
        ver: KeyAuthApp.version,
        name: KeyAuthApp.name,
        ownerid: KeyAuthApp.ownerId
    };
    const jsonResponse = await makeRequest(postData);
    KeyAuthApp.sessionid = jsonResponse.sessionid;
}

async function handleRequest(licenseKey) {
    const postData = {
        type: 'license',
        key: licenseKey,
        sessionid: KeyAuthApp.sessionid,
        name: KeyAuthApp.name,
        ownerid: KeyAuthApp.ownerId
    };
    const jsonResponse = await makeRequest(postData);
    return jsonResponse;
}

// Инициализация
initialize().then(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const licenseKey = urlParams.get("key");
    if (licenseKey) {
        handleRequest(licenseKey).then(response => {
            // Удаляем все HTML и вставляем текст ответа
            document.body.innerHTML = `<pre>${JSON.stringify(response, null, 2)}</pre>`;
        });
    }
});
