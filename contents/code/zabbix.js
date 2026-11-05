/*
 * Zabbix JSON-RPC 2.0 API client (pure QML/JS, uses XMLHttpRequest).
 *
 * Supports:
 *  - API token auth (Zabbix >= 5.4): "Authorization: Bearer <token>" header
 *  - Username/password auth (any version): user.login, session cached;
 *    automatically logs in again when the session expires.
 *
 * Session transport depends on the server version (detected via
 * apiinfo.version): Zabbix >= 6.4 requires the session token in the
 * "Authorization: Bearer" header and rejects an "auth" body parameter
 * (removed entirely in 7.0); older versions use the "auth" body parameter.
 */
.pragma library

// Cached login session id (only used for username/password mode)
var sessionId = "";

// Detected server versions: normalized url -> { major, minor }
var apiVersions = {};

// Zabbix default severity colors
var severityColors = [
    "#97aab5", // 0 Not classified
    "#797979", // 1 Information
    "#ffd966", // 2 Warning
    "#ffaa00", // 3 Average
    "#ff6c00", // 4 High
    "#e51c23"  // 5 Disaster
];

function severityColor(severity) {
    var s = parseInt(severity, 10);
    if (isNaN(s) || s < 0 || s > 5)
        s = 0;
    return severityColors[s];
}

function normalizeUrl(url) {
    return String(url).replace(/\/+$/, "");
}

// Returns tri-state: true/false if the detected version is (not) at least
// major.minor, null when the version is not (yet) known for this url.
function versionAtLeast(url, major, minor) {
    var v = apiVersions[normalizeUrl(url)];
    if (v === undefined)
        return null;
    if (v.major !== major)
        return v.major > major;
    return v.minor >= minor;
}

// Detect the server version (no auth required). callback(error)
function detectVersion(opts, callback) {
    var url = normalizeUrl(opts.url);
    if (apiVersions[url] !== undefined) {
        callback(null);
        return;
    }
    callApi(opts, "apiinfo.version", [], function (err, result) {
        if (err) {
            callback(err);
            return;
        }
        var m = String(result).match(/^(\d+)\.(\d+)/);
        apiVersions[url] = m
            ? { major: parseInt(m[1], 10), minor: parseInt(m[2], 10) }
            : { major: 7, minor: 0 }; // unknown format: assume modern
        callback(null);
    });
}

// Low-level JSON-RPC call. callback(error, result)
function callApi(opts, method, params, callback) {
    var xhr = new XMLHttpRequest;
    xhr.open("POST", normalizeUrl(opts.url) + "/api_jsonrpc.php");
    xhr.setRequestHeader("Content-Type", "application/json");
    if (opts.authMode === "token" && opts.token && method !== "apiinfo.version") {
        xhr.setRequestHeader("Authorization", "Bearer " + opts.token);
    }

    var body = {
        jsonrpc: "2.0",
        method: method,
        params: params,
        id: 1
    };
    // Session handling for username/password mode:
    //  - Zabbix >= 6.4: session token in the Authorization header; an "auth"
    //    body parameter is rejected ("unexpected parameter auth", 7.0+).
    //  - older: "auth" body parameter.
    // Zabbix >= 6.4 also rejects an "auth" body parameter next to a token.
    if (method !== "user.login" && method !== "apiinfo.version" && opts.authMode !== "token" && sessionId) {
        if (versionAtLeast(opts.url, 6, 4) === true)
            xhr.setRequestHeader("Authorization", "Bearer " + sessionId);
        else
            body.auth = sessionId;
    }

    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;
        if (xhr.status === 0) {
            callback({
                message: "Network error",
                data: "Could not reach " + normalizeUrl(opts.url) + ". Check the URL and your network connection. For self-signed TLS certificates, add the CA certificate to the system trust store."
            });
            return;
        }
        var resp = null;
        try {
            resp = JSON.parse(xhr.responseText);
        } catch (e) {
            callback({
                message: "Invalid response",
                data: "The server did not return JSON. Is " + normalizeUrl(opts.url) + " the correct Zabbix API URL?"
            });
            return;
        }
        if (resp.error) {
            callback(resp.error, null);
            return;
        }
        callback(null, resp.result);
    };

    try {
        xhr.send(JSON.stringify(body));
    } catch (e) {
        callback({ message: "Request failed", data: String(e) });
    }
}

// Perform user.login. Tries the modern "username" parameter first and falls
// back to the pre-6.4 "user" parameter.
function login(opts, callback) {
    callApi(opts, "user.login", { username: opts.username, password: opts.password }, function (err, result) {
        if (!err) {
            sessionId = result;
            callback(null);
            return;
        }
        var text = ((err.message || "") + " " + (err.data || "")).toLowerCase();
        if (text.indexOf("username") !== -1 || text.indexOf("unexpected parameter") !== -1) {
            // Zabbix < 6.4
            callApi(opts, "user.login", { user: opts.username, password: opts.password }, function (err2, result2) {
                if (!err2) {
                    sessionId = result2;
                    callback(null);
                } else {
                    callback(err2);
                }
            });
            return;
        }
        callback(err);
    });
}

function isAuthError(err) {
    var text = ((err.message || "") + " " + (err.data || "")).toLowerCase();
    return text.indexOf("not authorized") !== -1
        || text.indexOf("re-login") !== -1
        || text.indexOf("session") !== -1
        || text.indexOf("invalid session") !== -1;
}

// Matches Zabbix validation errors like:
// Invalid parameter "/": unexpected parameter "selectHosts".
function isUnexpectedParam(err, param) {
    var text = ((err.data || "") + " " + (err.message || "")).toLowerCase();
    return text.indexOf("unexpected parameter") !== -1
        && text.indexOf('"' + param.toLowerCase() + '"') !== -1;
}

// Map triggerid -> host name for 7.0+, where problem.get no longer supports
// selectHosts. Best-effort: hosts simply stay empty if the lookup fails.
function attachTriggerHosts(opts, problems, callback) {
    var ids = [];
    for (var i = 0; i < problems.length; ++i) {
        var tid = problems[i].triggerid;
        if (tid && ids.indexOf(tid) === -1)
            ids.push(tid);
    }
    if (ids.length === 0) {
        callback(null, problems);
        return;
    }
    callApi(opts, "trigger.get", {
        triggerids: ids,
        output: ["triggerid"],
        selectHosts: ["host", "name"]
    }, function (err, result) {
        if (!err && result) {
            var map = {};
            for (var j = 0; j < result.length; ++j) {
                var t = result[j];
                if (t.hosts && t.hosts.length > 0)
                    map[String(t.triggerid)] = t.hosts[0].name || t.hosts[0].host;
            }
            for (var k = 0; k < problems.length; ++k) {
                if (map[problems[k].triggerid])
                    problems[k].host = map[problems[k].triggerid];
            }
        }
        callback(null, problems);
    });
}

/**
 * Fetch active problems.
 * opts: { url, authMode ("token"|"userpass"), token, username, password }
 * filter: { severities: ["2","3"], includeAcknowledged: bool, limit: int,
 *           maxAgeHours: int (0 = no limit) }
 * callback(error, problems)
 */
function fetchProblems(opts, filter, callback) {
    function parseProblems(result) {
        var problems = [];
        for (var i = 0; i < result.length; ++i) {
            var p = result[i];
            // Only show actual (still open) problems: a problem with a
            // recovery event id (r_eventid != "0") is resolved. problem.get
            // with recent:false should already exclude those, but some
            // servers/setups leak resolved entries through.
            if (p.r_eventid !== undefined && String(p.r_eventid) !== "0")
                continue;
            var ackRaw = p.acknowledges !== undefined ? p.acknowledges : p.acknowledged;
            var ackCount = ackRaw !== undefined ? parseInt(ackRaw, 10) : 0;
            if (isNaN(ackCount)) ackCount = 0;
            if (!filter.includeAcknowledged && ackCount > 0)
                continue;
            // Zabbix <= 6.x exposes "triggerid"; 7.0 dropped it in favour of
            // "objectid" (the related object for source 0 / object 0).
            var triggerid = "";
            if (p.triggerid !== undefined)
                triggerid = String(p.triggerid);
            else if (p.objectid !== undefined
                && (p.source === undefined || String(p.source) === "0")
                && (p.object === undefined || String(p.object) === "0"))
                triggerid = String(p.objectid);
            problems.push({
                eventid: String(p.eventid),
                triggerid: triggerid,
                name: p.name !== undefined ? String(p.name) : "",
                severity: parseInt(p.severity, 10) || 0,
                clock: parseInt(p.clock, 10) || 0,
                host: (p.hosts && p.hosts.length > 0)
                    ? (p.hosts[0].name || p.hosts[0].host)
                    : "",
                acknowledged: ackCount > 0
            });
        }
        return problems;
    }

    function doFetch(reauthTried, selectHostsTried) {
        var modern = versionAtLeast(opts.url, 7, 0) === true;
        var params = {
            output: "extend",
            selectAcknowledges: "count",
            source: 0,
            object: 0,
            recent: false,
            severities: filter.severities,
            sortfield: "eventid",
            sortorder: "DESC",
            limit: filter.limit
        };
        // Optional age limit, mirroring the web UI's default time filter:
        // without it the API also returns problems that are still open but
        // have been sitting there for weeks.
        if (filter.maxAgeHours > 0) {
            params.time_from = Math.floor(Date.now() / 1000)
                - filter.maxAgeHours * 3600;
        }
        if (!modern)
            params.selectHosts = ["host", "name"];

        function finish(result) {
            var problems = parseProblems(result);
            if (modern)
                attachTriggerHosts(opts, problems, callback);
            else
                callback(null, problems);
        }

        callApi(opts, "problem.get", params, function (err, result) {
            if (err) {
                // Server rejected selectHosts: it behaves like 7.0+. Remember
                // that and retry once without it.
                if (!selectHostsTried && !modern && isUnexpectedParam(err, "selectHosts")) {
                    apiVersions[normalizeUrl(opts.url)] = { major: 7, minor: 0 };
                    doFetch(reauthTried, true);
                    return;
                }
                if (!reauthTried && opts.authMode === "userpass" && isAuthError(err)) {
                    sessionId = "";
                    ensureSession(function () { doFetch(true, selectHostsTried); });
                    return;
                }
                callback(err, null);
                return;
            }
            finish(result);
        });
    }

    function ensureSession(then) {
        // The session transport (header vs body) depends on the server
        // version, so detect it before any authenticated call. Detection
        // failures are ignored: unknown version falls back to "auth".
        detectVersion(opts, function () {
            if (sessionId) {
                then();
            } else {
                login(opts, function (err) {
                    if (err) {
                        callback(err, null);
                    } else {
                        then();
                    }
                });
            }
        });
    }

    if (opts.authMode === "token") {
        doFetch(false, false);
    } else {
        ensureSession(function () { doFetch(false, false); });
    }
}
