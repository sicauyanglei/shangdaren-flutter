1. 每次打开项目时，需要执行以下命令：
cd E:\AI-PRJ\shangdaren-game\flutter_app
每次切换到feature/frame/webgl分支后，需要执行以下命令：
更新feature/frame/webgl分支的代码
git pull origin feature/frame/webgl --rebase
2. 每次修改代码后，需要执行以下命令：
编译flutter flame项目 并打包成apk文件
flutter build apk --release
如果bluestacks启动了，需要执行以下命令：
bluestacks.exe -p E:\AI-PRJ\shangdaren-game\flutter_app\build\apk\release\shangdaren-game-release.apk
git add .
git commit -m "update feature/frame/webgl branch"
git push origin feature/frame/webgl
3. trae关闭前，需要执行以下命令：
git pull origin feature/frame/webgl --rebase
然后合入本地修改到feature/frame/webgl分支，更新master分支并完成远程推送
git merge feature/frame/webgl
git push origin feature/frame/webgl
