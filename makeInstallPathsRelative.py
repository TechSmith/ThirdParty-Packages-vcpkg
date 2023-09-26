import subprocess
import sys
import os

if len(sys.argv) < 3:
   print('usage: ' + str(sys.argv[0]) + " <new path substring> <binary name>")
   sys.exit(1)
  
newPathSubStr = sys.argv[1]
staticLibPath = sys.argv[2]

p = subprocess.Popen('otool -L ' + staticLibPath, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

for lineData in p.stdout.readlines():
   line = lineData.decode("utf-8")
   if line[0] == '\t':
      path = line[1:line.find('(')]
      path = path.strip()

      dirname = os.path.dirname(path)
      # leave paths like /usr/lib and /System untouched
      if dirname.find('/usr/lib') == -1 and dirname.find('/System') == -1:
         oldPathSubStr = dirname
         oldPathLoc = path.find(oldPathSubStr)
         if oldPathLoc != -1:
            newPath = path.replace(oldPathSubStr, newPathSubStr)

            dylibName = os.path.basename(staticLibPath)
            print(os.path.basename(path) + "-" + dylibName)
            if os.path.basename(path) == dylibName:
               print("CHANGING ID")
               changeCmd = 'install_name_tool -id ' + newPath + ' ' + staticLibPath
            else:
               print("CHANGING PATH")
               changeCmd = 'install_name_tool -change ' + path + ' ' + newPath + ' ' + staticLibPath
            os.system(changeCmd)

         
print("********** FINAL RESULT*************")
p = subprocess.Popen('otool -L ' + staticLibPath, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
for line in p.stdout.readlines():
   print(line.decode("utf-8"))
