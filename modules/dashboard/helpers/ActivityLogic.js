.pragma library

function remaining(deadline, now) {
    return Math.max(0, deadline - now);
}

function timerRemaining(running, deadline, saved, now) {
    return running ? remaining(deadline, now) : saved;
}

function durationMinutes(value) {
    const n = Number(value);
    return value !== null && Number.isInteger(n) && n >= 1 && n <= 180 ? n : 0;
}

function nextPhase(phase, completed) {
    return phase === "focus" ? completed % 4 === 0 ? "longBreak" : "break" : "focus";
}

function batteryLevel(present, onBattery, fraction) {
    if (!present || !onBattery || typeof fraction !== "number" || !Number.isFinite(fraction) || fraction < 0 || fraction > 1)
        return 0;
    return fraction <= .1 ? 2 : fraction <= .2 ? 1 : 0;
}

function temperatureState(temperature, samples, active) {
    if (typeof temperature !== "number" || !Number.isFinite(temperature) || temperature <= 0 || temperature > 125)
        return { samples: 0, active: false };
    const count = temperature >= 90 ? samples + 1 : 0;
    return { samples: Math.min(count, 2), active: active ? temperature >= 85 : count >= 2 };
}

function clock(seconds) {
    const s = Math.max(0, Math.ceil(seconds));
    return `${Math.floor(s / 60).toString().padStart(2, "0")}:${(s % 60).toString().padStart(2, "0")}`;
}
