#!/bin/bash

toolName="kernbench"
toolRetDir="${toolName}-ret"

## TODO:搭建运行环境
##
KernbenchSetup(){
	# XML配置文件路径
	CONFIG_XML=$(dirname $0)/config/benchmark.xml
	# cfg配置文件路径
	source $(dirname $0)/config/benchmark.cfg
	# 加载解析XML库
	source ${AUTOTEST_ROOT}/lib/xmlParse.sh
}

## TODO:解析XML文件，获取工具安装位置等
##
KernbenchXMLParse(){
	localName=""
	localDep=""
	localPkgPath=""
	localPkgName=""
	localFileName=""
	localInstallPath=""

        XMLParse ${CONFIG_XML}
        XMLGetItemContent CaseName        xmlCaseName
        XMLGetItemContent CaseDepend      xmlCaseDep
        XMLGetItemContent CasePkgName     xmlCasePkgName
        XMLGetItemContent CaseFileName    xmlCaseFileName
	XMLGetItemNum     xmlCaseName     xmlCaseNum
        XMLUnsetup

        local border=$((${xmlCaseNum}-1))
        local index=0
        for index in `seq 0 ${border}`
        do
                if [ "${xmlCaseName[${index}]}" == "${toolName}" ];then
			localName="${xmlCaseName[$index]}"
                        localDep="${xmlCaseDep[$index]}"
			localPkgName="${xmlCasePkgName[$index]}"
			localFileName="${xmlCaseFileName[$index]}"
			break
                fi
        done
	localPkgPath="${AUTOTEST_ROOT}/${BENCHMARK_PKG_PATH}"
	localInstallPath="${BENCHMARK_PKG_INSTALL_PATH}"

	unset -v xmlCaseName xmlCaseDep xmlCasePkgName xmlCaseFileName xmlCaseNum 
	
#	echo "$localName -$localDep-$localPkgPath-$localPkgName-$localFileName-$localInstallPath "
}

## TODO:依赖关系检查
## Out :0=>TPASS
##	1=>TFAIL
##      2=>未安装指定依赖
KernbenchDep(){
	local depNum=0
	local depTmp=""

	depNum=$(echo $localDep | awk -F":" '{print NF}')
	if [ "${depNum}" -eq "1"  ];then
		if [ "${localDep}" == "-" ];then
                        return 0
                fi
        fi

        local index=0
	local failpkg=""
        for index in `seq 1 ${depNum}`
	do
		depTmp=$(echo $localDep | awk -F":" "{print \$${index}}")
		#判断是否安装依赖包
		$BENCHMARK_PKG_CMD $depTmp > /dev/null
		local ret="$?"
		#没有安装依赖
		if [ "${ret}" -ne "0"  ];then
			failpkg="$failpkg $depTmp"
		fi
	done

        if [ "X$failpkg" != "X" ];then
                echo "Not install ${failpkg}"
                return 2
        fi

	return 0
}

## TODO:安装前准备，初始化unixbench运行环境
## Out :0=>TPASS
##	1=>TFAIL
##      2=>TCONF
##
KernbenchInit(){
	local ret=0
	#判断安装包是否存在
	if [ ! -f "${localPkgPath}/${localPkgName}"  ];then
		echo "Not Find ${localPkgPath}/${localPkgName}"
		ret=2
	fi
	#判断安装路径是否存在
	if [ ! -f "${localInstallPath}" ];then
		mkdir -p ${localInstallPath}
		if [ "$?" -ne "0"  ];then
			ret=2
		fi
	fi

	#判断是否已经解压
	if [ -d "${localInstallPath}/${localFileName}" ];then
		echo "Clean :rm -rf ${localInstallPath}/${localFileName}"
		rm -rf ${localInstallPath}/${localFileName}
		if [ "$?" -ne "0"  ];then
			ret=2
		fi
	fi
        
	# 获取CPU个数
        KernbenchGetCpuNum
        local cpuNum=$?
        [ $cpuNum -le 0 ] && { echo "FAIL:cpu num is $cpuNum";ret=2; }

	return $ret
}

## TODO：安装测试工具
## Out :0=>TPASS
##	1=>TFAIL
##      2=>TCONF
KernbenchInstall(){
	local ret=0
	#解压缩
	tar -xvf ${localPkgPath}/${localPkgName} -C ${localInstallPath} > /dev/null 2>&1
	if [ "$?" -ne "0" ];then
		echo "解压缩失败"
		return 2
	fi	
	
	cd ${localInstallPath}/${localFileName}

	#配置
	./configure
	[ $? -ne 0 ] && return 1

        # 获取CPU个数
        KernbenchGetCpuNum
        local cpuNum=$?
        [ $cpuNum -le 0 ] && { echo "FAIL:cpu num is $cpuNum";return 2; }
	
	#编译
	if [ "$cpuNum" -eq "0" ];then
		make 
	else
		make -j ${cpuNum}
	fi
	[ $? -ne 0 ] && return 1

	#安装
	make install
	[ $? -ne 0 ] && return 1
	
	#修改kernbench工具
	cp /opt/ltp/testcases/bin/kernbench ./
	[ $? -ne 0 ] && return 1

	cat kernbench | grep "if \[\[ \! \-f include/linux/kernel.h \]\]"
	if [ "$?" -eq "0" ];then
		sed -i 's/if \[\[ \! \-f include/if \[\[ \! \-f \/usr\/include/' kernbench
	fi

	cd -

	return $ret
}


## TODO：运行测试
##
KernbenchRun(){
	cd ${localInstallPath}/${localFileName}
	
	./kernbench > kernbench.ret

	cd -
}


## TODO: 结果收集
##
KernbenchRet(){
	cd ${localInstallPath}/${localFileName}

	local retPath=${LOG_PATH}/${BENCHMARK_RET_PATH}
        if [ -d "${LOG_PATH}" ];then
		if [ ! -d "${retPath}" ];then
			mkdir -p ${retPath}
		fi

		[ ! -d "${retPath}/${toolRetDir}" ] && mkdir ${retPath}/${toolRetDir}

		# result
		cp kernbench.ret ${retPath}/${toolRetDir}
	fi
	
	cd -
}


KernbenchUnsetup(){
	rm -rf ${localInstallPath}/${localFileName}
}


## TODO:解析函数返回值
## exit：1->程序退出，失败
##     ：2->程序退出，阻塞
KernbenchRetParse(){
	local tmp="$?"
	if [ "${tmp}" -ne "0"  ];then
		exit ${tmp}
	fi	
}


## TODO:获取CPU个数
## Out :-1 => 获取失败
##   other => CPU个数
##
KernbenchGetCpuNum(){
        # 获取CPU个数
        local cpuNum=$(cat /proc/cpuinfo | grep "processor" | wc -l)
        [ $? -ne 0 ] && { echo "FAIL: Get cpu num failed";return -1; }

        # 判断 $cpuNum 是否为空 
        [ "X$cpuNum" == "X" ] && { echo "FAIL: Get CPU(s) is NULL";return -1; }

        # 判断 $cpuNum 是否为数字 
        echo ${cpuNum} | grep -q '[^0-9]'
        [ $? -eq 0 ] && { echo "FAIL:Get cpuNum is not digit";return -1; }

        echo "Success :Get cpu Num = $cpuNum"

        return $cpuNum
}


## TODO:安装并且运行测试
##
KernbenchRunTest(){
	KernbenchXMLParse

	KernbenchDep
	KernbenchRetParse

	KernbenchInit
	KernbenchRetParse

	KernbenchInstall
	KernbenchRetParse

	KernbenchRun
	KernbenchRet

	sleep ${BENCHMARK_WAIT_300S}
#	echo "hello Kernbench"
	
#	KernbenchUnsetup
}

## TODO:进行安装测试
##
KernbenchInstallTest(){
	KernbenchXMLParse

	KernbenchDep
	KernbenchRetParse

	KernbenchInit
	KernbenchRetParse

	KernbenchInstall
	KernbenchRetParse
}

main(){
	KernbenchSetup

        if [ "$#" -ne "0"  ] && [ "X$2" == "X${BENCHMARK_FLAG}" ];then
		KernbenchInstallTest
        else
		KernbenchRunTest
        fi
}

main $@

exit $?
