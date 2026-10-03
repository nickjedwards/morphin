pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Weather for the week around today, from Open-Meteo (free, no key): the
// last three days as they were, today, and three days ahead — the seven days
// the calendar strip shows when it opens. The place is the one
// named in settings or, with none set, the city of the system's time zone —
// so nothing has to look up where the machine is. It is turned into
// coordinates once, then the forecast is refreshed every half hour.
Singleton {
    id: root

    readonly property bool enabled: Config.weather.enabled
    readonly property string unit: Config.weather.unit === "f" ? "fahrenheit" : "celsius"

    // [{ date, code, max, min }], oldest first: 3 days back, today, 3 ahead.
    property var days: []
    // The same, by "yyyy-mm-dd".
    readonly property var byDate: {
        const map = {};
        for (const d of days)
            map[d.date] = d;
        return map;
    }
    // The temperature right now; NaN until known.
    property real current: NaN
    property string place: ""
    property string error: ""
    readonly property bool ready: days.length > 0

    // ── Where ────────────────────────────────────────────────────────
    // The city of the system's time zone, which morpher resolves at
    // startup: …/zoneinfo/Australia/Melbourne → "Melbourne"
    readonly property string zoneCity: (Morpher.info.zone ?? "").split("/").pop().replace(/_/g, " ")
    readonly property string query: Config.weather.location.trim() || zoneCity
    property var coords: null            // { latitude, longitude }

    onQueryChanged: locate()
    onEnabledChanged: locate()
    onUnitChanged: fetch()

    function get(url: string, done): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            if (xhr.status === 200) {
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {}
            }
            done(data);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function locate(): void {
        if (!root.enabled || root.query === "")
            return;
        const asked = root.query;
        root.get(`https://geocoding-api.open-meteo.com/v1/search?count=1&name=${encodeURIComponent(asked)}`, data => {
            if (asked !== root.query)
                return;
            const hit = data?.results?.[0];
            if (!hit) {
                root.coords = null;
                root.days = [];
                root.error = data ? `No place called "${asked}"` : "Couldn't reach the weather service";
                retry.restart();
                return;
            }
            root.place = hit.name;
            root.coords = { latitude: hit.latitude, longitude: hit.longitude };
            root.fetch();
        });
    }

    function fetch(): void {
        if (!root.enabled || !root.coords)
            return;
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${root.coords.latitude}&longitude=${root.coords.longitude}` + `&current=temperature_2m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&past_days=3&forecast_days=4&temperature_unit=${root.unit}`;
        root.get(url, data => {
            const d = data?.daily;
            if (!d?.time) {
                root.error = "Couldn't reach the weather service";
                retry.restart();
                return;
            }
            root.error = "";
            root.current = data.current?.temperature_2m ?? NaN;
            root.days = d.time.map((date, i) => ({ date, code: d.weather_code[i], max: d.temperature_2m_max[i], min: d.temperature_2m_min[i] }));
        });
    }

    Timer {
        interval: 30 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.coords ? root.fetch() : root.locate()
    }

    // After a failure (offline at login, say), try again sooner.
    Timer {
        id: retry
        interval: 2 * 60 * 1000
        onTriggered: root.coords ? root.fetch() : root.locate()
    }

    // WMO weather codes, as Open-Meteo reports them.
    function icon(code: int): string {
        if (code === 0 || code === 1)
            return Icons.weatherSunny;
        if (code === 2)
            return Icons.weatherPartlyCloudy;
        if (code === 3)
            return Icons.weatherCloudy;
        if (code === 45 || code === 48)
            return Icons.weatherFog;
        if (code >= 95)
            return Icons.weatherStorm;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return Icons.weatherSnowy;
        if (code === 65 || code === 67 || code === 82)
            return Icons.weatherPouring;
        return Icons.weatherRainy;       // drizzle, rain and showers
    }

    function describe(code: int): string {
        if (code === 0 || code === 1)
            return "Clear";
        if (code === 2)
            return "Partly cloudy";
        if (code === 3)
            return "Cloudy";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 95)
            return "Storms";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "Snow";
        if (code >= 51 && code <= 57)
            return "Drizzle";
        if (code >= 80 && code <= 82)
            return "Showers";
        return "Rain";
    }
}
