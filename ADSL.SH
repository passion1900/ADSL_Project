#!/bin/bash

#下载文件并删除
download(){
   wget -P /home/download http://www.webll.net/HDSentinel_Pro_Portable.zip
   echo "下载完成,开始执行删除任务"
   rm -rf /home/download/*
}

#新建网卡
add_network(){
	for ((number=1; number<=length; number++ ));
	do
		ip link add link ens224 name wan$number type macvlan 
		ip link set wan$number up
	done
}

#删除网卡并新建网卡
reset_network(){
	
		ip link delete link dev wan1 
		ip link add link ens224 name wan1 type macvlan 
		ip link set wan1 up
}

#程序开始
touch /var/log/adsl.log
\cp -f /home/passwd-source.txt /home/passwd.txt	#对passwd.txt文件重置,主要是用于对之前已拨号的帐号进行删除,然后进行重定位
line=`sed -n '$=' /var/log/adsl.log`	#对之前的日志文件进行计数
if [ "$line" == "" ]			#对变量line进行判断,如果为空,说明里面没有数据,那么日志就从1开始写,
then
	line=1
else
	sed -i '1,'$line'd' /home/passwd.txt    #如果line不为空,那么说明有拨号数据了,计算行数,删除之前已经拨号的数据.
	let line=$line+1				#然后输入的行号需要加1,不然日志文件的编号就会重复
fi
user=($(awk '{print$1}' passwd.txt))    #读取帐号密码文件内的帐号项,赋值给数组user
passwd=($(awk '{print$2}' passwd.txt))  #读取帐号密码文件内的密码项,赋值给数组passwd
length=${#user[*]}						#对user数组计数,确定循环的次数
for ((count=0; count<length; count++,line++ ));
do
        sed -i 's/^user.*/user '${user[$count]}'/g' /etc/ppp/peers/wan1                 #修改拨号配置文件的user
        sed -i 's/^password.*/password '${passwd[$count]}'/g' /etc/ppp/peers/wan1       #修改拨号配置文件的password
        echo "开始执行第$line次任务"
		reset_network								#重置虚拟网卡,获取新的MAC地址
        poff wan1	> /dev/null						#先断开拨号,确保当前没有在使用的拨号线路
        pon wan1									#开始拨号
        sleep 10									#等待10秒,获取IP地址
        ip route add default dev ppp0				#配置默认网关
        ip=$(ip ad | grep peer | awk '{print $2}')	#对IP地址进行提取
        if [ "$ip" != "" ]							#如果获取到了IP地址,那么执行下载任务,并将信息写入日志,然后等待2分钟,继续下一轮循环
        then
                echo "拨号成功,当前ADSL链路IP地址为:$ip,开始执行下载任务,请稍后"
                echo "第$line次拨号,使用帐号'${user[$count]}',拨号成功,获取的IP地址为$ip,拨号时间`date`" >> /var/log/adsl.log
                download
                echo "下载任务执行完毕,开始执行挂机任务,10秒后将重新进行拨号"
                sleep 10
                echo -e "计时时间已到,开始执行下一轮任务\n"
        else
                echo -e "拨号失败,未获取到IP地址,请检查当前的ADSL线路\n" 
                echo "第$line次拨号,使用帐号'${user[$count]}',拨号失败,拨号时间`date`" >> /var/log/adsl.log
        fi
done

echo '----------'
echo '脚本执行完毕'
echo '----------'
