#! /bin/bash

#该脚本在ngnix运行的服务器地址运行

. ~/tmp_conf_file
#. conf_file

#添加注释行
function add_annotation() 
{
	cp $NGINX_CONF_FILE $NGINX_CONF_FILE".bak"
	regex_str="^ *server \+$1:$PORT"
	replace_str="      #server  $1:$PORT"
	sed -i "s/$regex_str/$replace_str/" $NGINX_CONF_FILE
}

#去掉注释行
function remove_annotation()
{
	cp $NGINX_CONF_FILE $NGINX_CONF_FILE".bak"
	regex_str="^ *#server \+$1:$PORT"
	replace_str="      server  $1:$PORT"
	sed -i "s/$regex_str/$replace_str/" $NGINX_CONF_FILE
}

function print_help()
{
	echo "修改nginx.conf文件，暂停或者添加ip配置"
	echo "-add_host 主机$HOST_IP 添加部署, 去除注释"
	echo "-add_beta BETA机器$BETA_IP添加部署, 去除注释"
	echo "-remove_host 主机$HOST_IP去除部署, 在相应配置文件中添加#，注释"
	echo "-remove_beta BETA机器$BETA_IP去除部署, 在相应配置文件中添加#，注释"
	echo "-reload 执行ngnix reload操作"
	echo "-h 查看帮助"
}

case $1 in
	"-add_host") 
		remove_annotation $HOST_IP
		echo "在$NGINX_CONF_FILE中添加$HOST_IP部署"
	;;
	"-add_beta") 
		remove_annotation $BETA_IP 
		echo "在$NGINX_CONF_FILE中添加$BETA_IP部署"
	;;
	"-remove_host") 
		add_annotation $HOST_IP 
		echo "在$NGINX_CONF_FILE中去除$HOST_IP部署"
	;;
	"-remove_beta") 
		add_annotation $BETA_IP 
		echo "在$NGINX_CONF_FILE中去除$BETA_IP部署"
	;;
	"-reload") 
 		sudo nginx -s reload
		echo "nginx reload 完成"
	;;
	"-h") 
		print_help ;;
	*)
		echo "输入参数有误，如下："
		print_help
	 ;;
esac
 
