// api.js — OpenWhale API client for TensorAgent OS
.pragma library

var BASE_URL = "http://localhost:7777";
var sessionId = "";

function setSession(id) {
    sessionId = id;
}

function request(method, endpoint, body, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open(method, BASE_URL + endpoint);
    xhr.setRequestHeader("Content-Type", "application/json");
    if (sessionId) {
        xhr.setRequestHeader("Cookie", "owSessionId=" + sessionId);
    }
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            var data = null;
            try { data = JSON.parse(xhr.responseText); } catch (e) { data = { error: xhr.responseText }; }
            if (callback) callback(xhr.status, data);
        }
    };
    xhr.send(body ? JSON.stringify(body) : null);
}

function login(username, password, callback) {
    request("POST", "/dashboard/api/auth/login", { username: username, password: password }, function (status, data) {
        if (status === 200 && data.sessionId) {
            sessionId = data.sessionId;
        }
        callback(status, data);
    });
}

function logout(callback) {
    request("POST", "/dashboard/api/auth/logout", null, callback);
    sessionId = "";
}

function checkAuth(callback) {
    request("GET", "/dashboard/api/auth/me", null, callback);
}

function chat(message, callback) {
    request("POST", "/dashboard/api/chat", { message: message }, callback);
}

function getProviders(callback) {
    request("GET", "/dashboard/api/providers", null, callback);
}

function saveProvider(type, config, callback) {
    request("POST", "/dashboard/api/providers/" + type + "/config", config, callback);
}

function testAI(provider, callback) {
    request("POST", "/dashboard/api/setup/test-ai", { provider: provider }, callback);
}

function getTools(callback) {
    request("GET", "/dashboard/api/tools", null, callback);
}

function getSkills(callback) {
    request("GET", "/dashboard/api/skills", null, callback);
}

function getMdSkills(callback) {
    request("GET", "/dashboard/api/md-skills", null, callback);
}

function getExtensions(callback) {
    request("GET", "/dashboard/api/extensions", null, callback);
}

function runExtension(name, callback) {
    request("POST", "/dashboard/api/extensions/" + name + "/run", null, callback);
}

function toggleExtension(name, callback) {
    request("POST", "/dashboard/api/extensions/" + name + "/toggle", null, callback);
}

function deleteExtension(name, callback) {
    request("DELETE", "/dashboard/api/extensions/" + name, null, callback);
}

function getChannels(callback) {
    request("GET", "/dashboard/api/channels", null, callback);
}

function getChatHistory(callback) {
    request("GET", "/dashboard/api/chat/history", null, callback);
}

function clearChatHistory(callback) {
    request("DELETE", "/dashboard/api/chat/history", null, callback);
}

// Conversation management
function getConversations(callback) {
    request("GET", "/dashboard/api/chat/conversations", null, callback);
}

function newConversation(callback) {
    request("POST", "/dashboard/api/chat/conversations/new", null, callback);
}

function switchConversation(id, callback) {
    request("POST", "/dashboard/api/chat/conversations/" + id + "/switch", null, callback);
}

function deleteConversation(id, callback) {
    request("DELETE", "/dashboard/api/chat/conversations/" + id, null, callback);
}

// OS config persistence
function getOsConfig(callback) {
    request("GET", "/dashboard/api/os-config", null, callback);
}

function saveOsConfig(config, callback) {
    request("POST", "/dashboard/api/os-config", config, callback);
}

function getConfig(callback) {
    request("GET", "/dashboard/api/config", null, callback);
}

function saveConfig(config, callback) {
    request("POST", "/dashboard/api/config", config, callback);
}

function getHealth(callback) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE_URL + "/dashboard/api/auth/me");
    xhr.timeout = 3000;
    if (sessionId) {
        xhr.setRequestHeader("Cookie", "owSessionId=" + sessionId);
    }
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            callback(xhr.status >= 200 && xhr.status < 500);
        }
    };
    xhr.ontimeout = function () { callback(false); };
    xhr.send();
}

function execCommand(cmd, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", BASE_URL + "/dashboard/api/chat");
    xhr.setRequestHeader("Content-Type", "application/json");
    if (sessionId) {
        xhr.setRequestHeader("Cookie", "owSessionId=" + sessionId);
    }
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            var data = null;
            try { data = JSON.parse(xhr.responseText); } catch (e) { data = { raw: xhr.responseText }; }
            if (callback) callback(xhr.status, data);
        }
    };
    xhr.send(JSON.stringify({ message: cmd }));
}

function getLogs(lines, callback) {
    execCommand("Run this exact command and return the full raw output: journalctl -u openwhale -n " + lines + " --no-pager", callback);
}
