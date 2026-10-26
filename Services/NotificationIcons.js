.pragma library

function normalize(value) {
    return String(value || "").trim().replace(/\.desktop$/i, "").toLowerCase();
}

// Use exact metadata matches, never notification titles or message contents.
function candidates(appIcon, desktopEntry, appName, applications) {
    const result = [];
    function add(icon) {
        const value = String(icon || "").trim();
        if (value && result.indexOf(value) === -1)
            result.push(value);
    }
    add(appIcon);
    const id = normalize(desktopEntry);
    const name = normalize(appName);
    const tiers = [
        applications.filter(app => id && normalize(app.id) === id),
        applications.filter(app => id && normalize(app.startupClass) === id),
        applications.filter(app => name &&
            (normalize(app.name) === name || normalize(app.id) === name))
    ];
    for (const matches of tiers) {
        if (matches.length === 1) {
            add(matches[0].icon);
            break;
        }
        // An ambiguous identity should not select an unrelated app's icon.
        if (matches.length > 1)
            break;
    }
    add(id);
    add(name);
    add("application-x-executable");
    return result;
}
