import sys
import subprocess

args = sys.argv

if args[1] == "-a":
    for i in range(0, int(args[3])):
        cmd = ["time", "bin/main", args[2]+str(i), "-a:true"]

        subprocess.run(cmd)
elif args[1] == "-ia":
    cmd = ["time", "bin/main", args[2], "-ia:"+args[3]]
    print(cmd)

    subprocess.run(cmd)
else:
    for i in range(0, int(args[2])):
        cmd1 = ["time", "bin/main", args[1]+str(i)]
        cmd2 = ["time", "bin/main", args[1]+str(i), "-a:true"]

        subprocess.run(cmd1)
        subprocess.run(cmd2)
