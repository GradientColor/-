# 引入必要的程序集
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- 核心改进：导入底层 C# 鼠标事件 API ---
$TypeDefinition = @"
using System;
using System.Runtime.InteropServices;
public class MouseSimulator {
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, int dwExtraInfo);
}
"@
# 编译 C# 代码供 PowerShell 调用
Add-Type -TypeDefinition $TypeDefinition -ErrorAction SilentlyContinue

# --- 1. 自动设置开机自启 ---
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ScreenKeepAwake.lnk"
$CurrentExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

# 判断是否为 exe 运行，避免打包前创建错误快捷方式
if ($CurrentExe -match "\.exe$" -and -not (Test-Path $ShortcutPath)) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $CurrentExe
    $Shortcut.Save()
}

# --- 2. 创建系统托盘图标 ---
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
try {
    # 尝试提取 exe 自身的图标
    $NotifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($CurrentExe)
} catch {
    # 如果提取失败，使用系统默认的提示图标
    $NotifyIcon.Icon = [System.Drawing.SystemIcons]::Information
}
$NotifyIcon.Text = "防息屏工具 (运行中)"
$NotifyIcon.Visible = $true

# 创建右键菜单
$ContextMenu = New-Object System.Windows.Forms.ContextMenu
$ExitItem = $ContextMenu.MenuItems.Add("退出程序")
$ExitItem.add_Click({
    $NotifyIcon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
    Stop-Process -Id $PID
})
$NotifyIcon.ContextMenu = $ContextMenu

# --- 3. 硬件级鼠标模拟逻辑 ---
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 30000 # 改为每 30 秒触发一次
$Timer.add_Tick({
    # 0x0001 代表 MOUSEEVENTF_MOVE (鼠标移动)
    # 向右移动 1 像素
    [MouseSimulator]::mouse_event(0x0001, 1, 0, 0, 0)
    Start-Sleep -Milliseconds 50
    # 向左移动 1 像素，瞬间恢复原位
    [MouseSimulator]::mouse_event(0x0001, -1, 0, 0, 0)
})
$Timer.Start()

# --- 4. 保持后台运行 ---
[System.Windows.Forms.Application]::Run()