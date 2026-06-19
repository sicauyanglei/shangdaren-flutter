默认查看最新的"E:\Upload\game_log_2026*.log"，每次解决问题时，先查看当前最新的log文件
每次代码修改前后先rebase先feature/frame/webgl分支，保证每次编译都是最新的代码
代码修改完成后进行编译，默认编译release版本，编译完成后推送到bluestacks
仅限 flutter_app 目录下的代码修改需要编译APK并推送到bluestacks
测试代码与release代码做隔离，测试代码不要影响release代码的运行
每次 flutter_app 代码修改完成后，执行编译 release 版本，推送到bluestacks
拉取代码后，直接执行编译 release 版本，推送到bluestacks
推送APK到bluestacks后，直接启动游戏，命令：adb -s 127.0.0.1:5555 shell am start -n com.shangdaren.game/.MainActivity
