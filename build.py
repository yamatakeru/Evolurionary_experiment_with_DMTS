import sys
import subprocess

cmd = ["nimble", "build", "-d:release", "--threads:on", "--nilseqs:on"]
subprocess.run(cmd)
