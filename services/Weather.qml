pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root
    property real temperature: 0
    property real apparentTemperature: 0
    property int code: 0
    property bool isDay: true
    property var hourly: []
    property var daily: []
    property string updated: ""
    property string error: ""
    property bool expanded: false
    property var locations: []
    property bool searching: false
    property string cachePath: Quickshell.env("HOME") + "/.cache/dynamite/weather.json"

    function description(codeValue: int): string {
        if (codeValue === 0) return "Clear"
        if (codeValue <= 2) return "Partly cloudy"
        if (codeValue === 3) return "Overcast"
        if (codeValue <= 48) return "Fog"
        if (codeValue <= 67 || (codeValue >= 80 && codeValue <= 82)) return "Rain"
        if (codeValue <= 77 || (codeValue >= 85 && codeValue <= 86)) return "Snow"
        if (codeValue >= 95) return "Thunderstorm"
        return "Showers"
    }
    function icon(codeValue: int, day: bool): string {
        if (codeValue === 0) return day ? "sunny" : "clear_night"
        if (codeValue <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night"
        if (codeValue === 3) return "cloud"
        if (codeValue <= 48) return "foggy"
        if (codeValue <= 67 || (codeValue >= 80 && codeValue <= 82)) return "rainy"
        if (codeValue <= 77 || (codeValue >= 85 && codeValue <= 86)) return "weather_snowy"
        return "thunderstorm"
    }
    function applyData(data: var, cacheOnly: bool): void {
        if (!data || !data.current) return
        temperature = Number(data.current.temperature_2m || 0)
        apparentTemperature = Number(data.current.apparent_temperature || temperature)
        code = Number(data.current.weather_code || 0)
        isDay = Number(data.current.is_day ?? 1) === 1
        hourly = data.hourly || []
        daily = data.daily || []
        updated = data.updated || new Date().toLocaleTimeString()
        if (cacheOnly) error = "Offline · cached " + updated
    }
    function refresh(): void {
        if (Config.weather.lat === null || Config.weather.lon === null) { error = "Choose a location in Settings"; return }
        const unit = Config.weather.units === "fahrenheit" ? "&temperature_unit=fahrenheit" : ""
        const xhr = new XMLHttpRequest()
        xhr.timeout = 15000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { error = hourly.time?.length ? "Offline · cached " + updated : "Weather unavailable"; return }
            try {
                const payload = JSON.parse(xhr.responseText)
                payload.updated = new Date().toLocaleTimeString()
                applyData(payload, false)
                error = ""
                cacheWriter.command = ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/dynamite"]
                cacheWriter.running = true
                pendingCache = JSON.stringify(payload)
            } catch (e) { error = "Invalid weather response" }
        }
        xhr.ontimeout = function() { error = hourly.time?.length ? "Offline · cached " + updated : "Weather unavailable" }
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + Config.weather.lat +
            "&longitude=" + Config.weather.lon +
            "&current=temperature_2m,apparent_temperature,weather_code,is_day" +
            "&hourly=temperature_2m,weather_code,precipitation_probability" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset" +
            "&forecast_days=5&timezone=auto" + unit
        xhr.open("GET", url)
        xhr.send()
    }
    property string pendingCache: ""
    function searchLocation(query: string): void {
        if (!query.trim()) { locations = []; return }
        searching = true
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            searching = false
            if (xhr.status !== 200) { locations = []; return }
            try { locations = JSON.parse(xhr.responseText).results || [] } catch (e) { locations = [] }
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=5&language=en&format=json")
        xhr.send()
    }
    function chooseLocation(location: var): void {
        Config.weather.lat = location.latitude
        Config.weather.lon = location.longitude
        Config.weather.place = [location.name, location.admin1, location.country].filter(Boolean).join(", ")
        refresh()
    }
    FileView {
        id: cacheFile
        path: root.cachePath
        printErrors: false
        onLoaded: {
            if (root.hourly.time?.length || !text()) return
            try { root.applyData(JSON.parse(text()), true) } catch (e) { }
        }
    }
    Process {
        id: cacheWriter
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/dynamite"]
        onExited: (code) => {
            if (code === 0 && root.pendingCache) {
                cacheFile.setText(root.pendingCache)
                root.pendingCache = ""
            }
        }
    }
    Timer { interval: 900000; running: true; repeat: true; onTriggered: root.refresh() }
    Connections { target: Network; function onActiveChanged() { if (Network.active) root.refresh() } }
    Connections {
        target: Config.weather
        function onLatChanged() { root.refresh() }
        function onLonChanged() { root.refresh() }
        function onUnitsChanged() { root.refresh() }
    }
    Component.onCompleted: { cacheFile.reload(); refresh() }
}
