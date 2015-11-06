#! /bin/bash

. ./conf_file

function build_war()
{
	cd "$APPCODE_PATH"
	git stash
	git status
	git pull
	echo "1. ===============build war start=============="
	mvn clean install -U -Dmaven.test.skip
	echo "2. ===============build war end============="
}

#需要指明参数，拷贝的目的机器地址 $HOST_SERVER":~/" or $BETA_SERVER":~/"
#拷贝war包到服务器
function copy_war()
{
	echo "========= 拷贝到 $1 start==========="
	scp -P 22222 -r $SRC_FILE $1 
	echo "========= 拷贝到 $1 end============="
}

function copy_conf_file()
{
	scp -P 22222 ./conf_file $1
}

function handle_ngnix()
{
	if [ "x$1" != 'x-beta' ] && [ "x$1" != 'x-host' ] && [ "x$1" != 'x-last' ]; then
		echo "参数输入: $1 有误，必须为-beta, -host或者-last"
		exit 1
	fi
	echo "============ 处理ngnix配置: $1 start=============="
	tmp_ngnix_sh="_tmp_handle_ngnix.sh"
	scp -P 22222 $LOCAL_RELOAD_NGINX_FILE $NGINX_SERVER":~/$tmp_ngnix_sh"
	copy_conf_file $NGINX_SERVER":~/tmp_conf_file"
	case $1 in
		"-beta")
			cmd="~/$tmp_ngnix_sh -remove_beta"
		;;
		"-host")
			cmd="~/$tmp_ngnix_sh -add_beta ; ~/$tmp_ngnix_sh -remove_host"
		;;
		"-last")
			cmd="~/$tmp_ngnix_sh -add_host"
		;;
	esac
	ssh -Tq $NGINX_SERVER -p 22222 << remotessh
		$cmd
		exit
remotessh
	cmd="sudo nginx -s reload ; rm ~/$tmp_ngnix_sh ~/tmp_conf_file; exit"
	ssh -tt $NGINX_SERVER -p 22222 $cmd
	echo "reload nginx 完成"
	echo "============ 处理ngnix配置: $1 end=============="
}


#需要指明参数：运行tomcat的机器地址 $HOST_SERVER or $BETA_SERVER
function handle_tomcat_proc()
{
	echo "5.========= kill远程tomcat服务,ip: $1 start========="
	#先拷贝kill process脚本到远程服务器，之后通过remotessh执行脚本，执行完成之后删除该脚本
	tmp_kill_proc_sh=$DATE"_killprocess.sh"
	scp -P 22222 $LOCAL_KILL_PROCESS_FILE $1":~/$tmp_kill_proc_sh" 
	ssh -Tq $1 -p 22222 << remotessh
	~/$tmp_kill_proc_sh
	rm ~/$tmp_kill_proc_sh 
	echo "6.========= kill远程tomcat服务,ip: $1 end========="

	echo "7.========= 拷贝$WAR_NAME.war，启动tomcat服务 start========="
	echo "TOMCAT_PATH: "$TOMCAT_PATH", DATE: "$DATE
	cd $TOMCAT_PATH
	mv ROOT.war ROOT.war.$DATE
	rm -rf ROOT 
	cp ~/$WAR_NAME.war $TOMCAT_PATH/ROOT.war
	$TOMCAT_PATH/../bin/startup.sh
	echo "8.========= 拷贝$WAR_NAME.war，启动tomcat服务 end==========="
	exit
remotessh
}

function print_help()
{
	tab='    '
	echo "$tab-build 执行代码同步，编译war包"
	if [ $BUILD_TYPE == 'double' ]; then
        echo "$tab-beta  执行BETA预发布，发布到机器：$BETA_SERVER"
	    echo "$tab-host  执行正式发布，发布到机器：$HOST_SERVER, 当然此时BETA机器上必须发布完成"
	else
        echo "$tab-single 单机发布, 机器ip配置以$HOST_SERVER为准"
	fi
	echo "$tab-h     查看帮助"
}

function need_continue()
{
	read -p "确定继续执行部署？(yes/no)"
	if [ 'x'$REPLY != 'xy' ] && [ 'x'$REPLY != 'xyes' ]; then
		echo "不执行部署，退出!"
		exit
	fi
}

function check_file_exist()
{
	if [ ! -d $APPCODE_PATH ]; then
		echo "本地code路径不存在：$APPCODE_PATH，不执行发布"
		exit
	fi
	if [ ! -f $LOCAL_KILL_PROCESS_FILE ]; then
		echo "kill远程进程脚本文件: $LOCAL_KILL_PROCESS_FILE不存在，不执行发布"
		exit 
	fi
	if [ ! -f $LOCAL_RELOAD_NGINX_FILE ]; then
		echo "nginx处理脚本文件: $LOCAL_RELOAD_NGINX_FILE不存在，不执行发布"
		exit 
	fi
}

case $1 in 
	"-build")
		check_file_exist
		build_war		
	;;
	"-beta")
        if [ $BUILD_TYPE == 'single' ]; then
            echo 'build type为single, 无法执行双机部署'
            exit
        fi
		check_file_exist
		copy_war $BETA_SERVER":~/"		
		handle_ngnix -beta
		need_continue
		handle_tomcat_proc $BETA_SERVER
	;;
	"-host")
        if [ $BUILD_TYPE == 'single' ]; then
            echo 'build type为single, 无法执行双机部署'
            exit
        fi
		check_file_exist
		copy_war $HOST_SERVER":~/"		
		##打开 BETA机器的时候要判断下 BETA 机器是否可用
		index_html=`curl --connect-timeout 50 $BETA_IP:$BETA_PORT`
		handle_ngnix -host
		need_continue
		handle_tomcat_proc $HOST_SERVER
		#请求HOST地址，等待HOST启动完成之后再配置双机
		sleep 5 
		index_html=`curl --connect-timeout 50 $HOST_IP:$HOST_PORT`
		handle_ngnix -last
	;;
	"-single")
        if [ $BUILD_TYPE == 'double' ]; then
            echo 'build type为double, 无法执行单机部署'
            exit
        fi
        check_file_exist
        copy_war $HOST_SERVER":~/"
        need_continue
        handle_tomcat_proc $HOST_SERVER
	;;
	"-h")
		print_help ;;
	*)
		echo "输入正确参数执行部署脚本, 如下："
		print_help
	;;
esac
