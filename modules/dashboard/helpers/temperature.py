"""Read the CPU package sensor; no privileged access or third party dependencies."""
import json
from pathlib import Path


def cpu_temperature(root=Path("/sys/class/thermal")):
    readings = []
    for zone in root.glob("thermal_zone*"):
        try:
            if (zone / "type").read_text().strip() not in ("x86_pkg_temp", "cpu-thermal", "cpu_thermal", "TCPU"):
                continue
            value = int((zone / "temp").read_text()) / 1000
            if 0 < value <= 125:
                readings.append(value)
        except (OSError, ValueError):
            continue
    return max(readings) if readings else None


if __name__ == "__main__":
    print(json.dumps({"temperature": cpu_temperature()}))
