import tempfile
import unittest
from pathlib import Path
from temperature import cpu_temperature

class TemperatureTests(unittest.TestCase):
    def test_only_cpu_sensors_contribute(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            for i,(kind,value) in enumerate([('x86_pkg_temp','92000'),('TCPU','91000'),('iwlwifi_1','110000')]):
                z=root/f'thermal_zone{i}'; z.mkdir(); (z/'type').write_text(kind); (z/'temp').write_text(value)
            self.assertEqual(cpu_temperature(root),92)
    def test_missing_invalid_or_implausible_sensors_return_unknown(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            self.assertIsNone(cpu_temperature(root))
            z=root/'thermal_zone0'; z.mkdir(); (z/'type').write_text('x86_pkg_temp')
            for value in ['bad','-1000','200000']:
                (z/'temp').write_text(value)
                self.assertIsNone(cpu_temperature(root))
if __name__=='__main__': unittest.main()
