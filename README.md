在文件目录下执行
Invoke-ps2exe -inputFile .\mouse_awake.ps1 -outputFile .\ScreenKeepAwake.exe -noConsole
就可以转换成exe文件了
Install-Module ps2exe -Scope CurrentUser -Force
要提前下载依赖
