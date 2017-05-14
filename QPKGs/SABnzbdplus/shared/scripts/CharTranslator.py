#!/opt/bin/python2.7 -OO
#-*- coding: iso-8859-15 -*-
#
# If a file has been archieved under an ISO-8859 environment and unarchived
# under an UTF8 environment, then you will get an encoding format problem.
# The file will not be readable through SAMBA.
#
# Renaming script for SABnzbd runnning under Synology NAS.
# By default the NZB software is running under UTF-8 encoding format
# in order to correctly handle the french accents (éèàç...) a SABnzbd
# post-script must be run in order to convert the file encoding.
#
# To fix this problem, you must convert the encoding format
# to the UTF8 (default Synology encoding)
# The script is trying to detect if the original file/directory are coming
# from a RAR archive. In this case the unrar command on your Syno system will
# unpack in CP437 format (DOS).
# NB: in all cases, files will be readable through samba, even if the detection
# failed. But converted characters will not be good, ex: Î? instead é
# 
# Remark: I guess it should work for any other encoding style. Just replace
# ISO-8859-15 (Western Europe) by the one coresponding to your country:  
# http://en.wikipedia.org/wiki/Character_encoding#Common_character_encodings
# 
# Done by LapinFou
#   date   | version |     comment
#--------------------------------------
# 12-04-22 |   1.0   | Initial version
# 12-04-22 |   1.1   | Change encoding to ISO-8859-15
#                    | Added CP437 special characters (0x80-0x9A)
# 12-04-24 |   1.2   | Mixed encoding is now supported
#                    | UTF-8 encoding format detected
# 12-04-24 |   1.3   | Fixed typo line 57 (test must be 0xA0, not 0xA1)
# 12-09-16 |   1.4   | Added an exception for "Â" character
#                    | Added 7z unpack
#                    | Added move option
#                    | Added Syno index option
#

# get library modules
import sys
import os
import subprocess
import shutil

# If empty, then no move
# Format must be synology full path (case sensitive). For ex: /volume1/video/News
# mv -rf srcFolder destFolder 
# By default disabled
MoveToThisFolder = ''

# If "True", then the folder will be indexed into Synology DLNA
# By default it is "False"
IndexInSynoDLNA = False

# If "True", all .7z files will be unpacked then source .7z file will be deleted
# By default it is "True"
Unpack7z = False

########################
# ----- Functions ---- #
########################

# Special character hex range:
# CP437: 0x80-0x9A (fortunately not used in ISO-8859-15)
# UTF-8: 1st hex code 0xC2-0xC3 followed by a 2nd hex code 0xA1-0xFF
# ISO-8859-15: 0xA0-0xFF
# The function will detect if fileDirName contains a special character
# If there is special character, detects if it is a UTF-8, CP437 or ISO-8859-15 encoding
def renameFunc(fullPath, fileDirName):
   encodingDetected = False
   # parsing all files/directories in odrer to detect if CP437 is used
   for Idx in range(len(fileDirName)):
      # /!\ detection is done 2char by 2char for UTF-8 special character
      if (len(fileDirName) != 1) & (Idx < (len(fileDirName) - 1)):
         # Detect UTF-8
         if ((fileDirName[Idx] == '\xC2') | (fileDirName[Idx] == '\xC3')) & ((fileDirName[Idx+1] >= '\xA0') & (fileDirName[Idx+1] <= '\xFF')):
            print os.path.join(fullPath, fileDirName) + " -> UTF-8 detected: Nothing to be done"
            encodingDetected = True
            break;
         # Detect CP437
         elif ((fileDirName[Idx] >= '\x80') & (fileDirName[Idx] <= '\x9A') | (fileDirName[Idx] == '\xB6')):
            utf8Name = fileDirName.decode('cp437')
            utf8Name = utf8Name.encode('utf-8')
            os.rename(os.path.join(fullPath, fileDirName), os.path.join(fullPath, utf8Name))
            print os.path.join(fullPath, utf8Name) + " -> CP437 detected: Renamed"
            encodingDetected = True
            break;
         # Detect ISO-8859-15
         elif (fileDirName[Idx] >= '\xA0') & (fileDirName[Idx] <= '\xFF'):
            utf8Name = fileDirName.decode('iso-8859-15')
            utf8Name = utf8Name.encode('utf-8')
            os.rename(os.path.join(fullPath, fileDirName), os.path.join(fullPath, utf8Name))
            print os.path.join(fullPath, utf8Name) + " -> ISO-8859-15 detected: Renamed"
            encodingDetected = True
            break;
      else:
         # Detect CP437
         if ((fileDirName[Idx] >= '\x80') & (fileDirName[Idx] <= '\x9A') | (fileDirName[Idx] == '\xB6')):
            utf8Name = fileDirName.decode('cp437')
            utf8Name = utf8Name.encode('utf-8')
            os.rename(os.path.join(fullPath, fileDirName), os.path.join(fullPath, utf8Name))
            print os.path.join(fullPath, utf8Name) + " -> CP437 detected: Renamed"
            encodingDetected = True
            break;
         # Detect ISO-8859-15
         elif (fileDirName[Idx] >= '\xA0') & (fileDirName[Idx] <= '\xFF'):
            utf8Name = fileDirName.decode('iso-8859-15')
            utf8Name = utf8Name.encode('utf-8')
            os.rename(os.path.join(fullPath, fileDirName), os.path.join(fullPath, utf8Name))
            print os.path.join(fullPath, utf8Name) + " -> ISO-8859-15 detected: Renamed"
            encodingDetected = True
            break;
   if (encodingDetected == False):
      print os.path.join(fullPath, fileDirName) + " -> No special characters detected: Nothing to be done"
   return

# scan .7z files and unpack them
def unpack7zFunc(DirName):
   print "Scanning for .7z file(s), then unpack them"
   print "Scanning files..."
   DetectedFiles = False
   for dirname, dirnames, filenames in os.walk(DirName):
      for filename in filenames:
         if (filename[-3:] == ".7z"):
            print "Unpack %s..." %(filename)
            DetectedFiles = True
            try:
               filepath = os.path.join(dirname, filename)
               syno7z_cmd = ['/usr/syno/bin/7z', 'x', '-y', filepath]
               p = subprocess.Popen(syno7z_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
               out, err = p.communicate()
               if (str(out) != ''):
                  print("7z result: " + filepath + " successfully unpacked")
                  os.remove(filepath)
                  print(filepath + " has been deleted")
               if (str(err) != ''):
                  print("7z failed: " + str(err))
            except OSError, e:
               print("Unable to run 7z: "+str(e))
   if DetectedFiles:
      print "Scanning for .7z files Done !"
   else:
      print "No .7z file Detected !"
   return

# add folder in the Syno index database (DLNA server)
def addToSynoIndex(DirName):
   print " "
   print "Adding folder in the DLNA server"
   synoindex_cmd = ['/usr/syno/bin/synoindex', '-A', DirName]
   try:
      p = subprocess.Popen(synoindex_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
      out, err = p.communicate()
      if (str(out) == ''):
         print("synoindex result: " + DirName + " successfully added to Synology database")
      else:
         print("synoindex result: " + str(out))
      if (str(err) != ''):
         print("synoindex failed: " + str(err))
   except OSError, e:
      print("Unable to run synoindex: "+str(e))
   return

########################
# --- Main Program --- #
########################

# get argument: directory of the SABnzbd job
os.chdir(sys.argv[1])

# display directory of the SABnzbd job
currentFolder = os.getcwd()
print "Current folder is " + currentFolder

# rename SABnzbd job directory (coming from SABnzbd: never in CP437 format)
print "Renaming destination folder to UTF-8 format..."
renameFunc('', currentFolder)
currentFolder = os.getcwd()
print "Destination folder renamed !"
print ""

# Unpack 7z file(s)
if (Unpack7z == True):
   unpack7zFunc(currentFolder)
   print ""

# process each sub-folders starting from the deepest level
print "Renaming folders to UTF-8 format..."
for dirname, dirnames, filenames in os.walk('.', topdown=False):
   for subdirname in dirnames:
      renameFunc(dirname, subdirname)
print "Folder renaming Done !"
print ""

# process each file recursively
print "Renaming files to UTF-8 format..."
for dirname, dirnames, filenames in os.walk('.'):
   for filename in filenames:
      renameFunc(dirname, filename)
print "Files renaming Done !"
print ""

# Move current folder to an another destination if the option has been configured
if (MoveToThisFolder != ''):
   print "Moving folder from"
   print os.getcwd()
   print "to"
   print MoveToThisFolder
   # Check if destination folder does exist and can be written
   if (os.access(MoveToThisFolder, os.F_OK) == False):
      os.makedirs(MoveToThisFolder)
      os.chmod(MoveToThisFolder, 0777)
   if (os.access(MoveToThisFolder, os.W_OK) == False):
      print "File(s)/Folder(s) can not be move in %s" %(MoveToThisFolder)
      print "Please, check Unix permissions"
      sys.exit()
   shutil.move(os.getcwd(), MoveToThisFolder)
   os.chdir(MoveToThisFolder)
   currentFolder = os.getcwd()
   print ""

# Add multimedia files in the Syno DLNa if the option has been enabled
if (IndexInSynoDLNA == True):
   addToSynoIndex(currentFolder)

print ""
print "Character encoding translation done!"
