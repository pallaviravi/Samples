#!/usr/bin/python

#Read number of users required from command line

print "Enter the number of users required for in the ldif file"
users = raw_input()


#Convert string to integer
users=int(users)
print "The number of users in the ldif file are"
print users

#Open a file
fo=open("/root/Desktop/sample.ldif","a")

for num in range(0,users):
	string="user"+str(num)
	fo.write("dn: cn="+string+",ou=novell,o=one\n");
	fo.write( "changetype: add \n");
	fo.write( "objectclass: user \n");
	fo.write( "sh:"+string );
	fo.write( "\nuserpassword:novell \n");
	fo.write("\n");

#Close a file
fo.close()
