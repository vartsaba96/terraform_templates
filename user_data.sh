yum -y update
yum -y install httpd

#web site

sudo service httpd start
chkconfig httpd on
