# Ashkan Localhost - portable Windows launcher (Windows PowerShell 5.1+)
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Manifest = Join-Path $script:BaseDir 'apps.json'
$script:ServerProcess = $null
$script:CurrentApp = $null
$script:QuietStartup = $false

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $script:Manifest)) { return @{ defaultName = ''; apps = @() } }
    try {
        $data = Get-Content -LiteralPath $script:Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
        $apps = @(); if ($data.apps) { $apps = @($data.apps) }
        return @{ defaultName = [string]$data.defaultName; apps = $apps }
    } catch { return @{ defaultName = ''; apps = @() } }
}
function Save-Manifest($data) {
    $data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:Manifest -Encoding UTF8
}
function Find-FreePort {
    $used = @($script:data.apps | ForEach-Object { [int]$_.port })
    foreach ($p in 8000..8999) {
        if ($used -contains $p) { continue }
        $listener = $null
        try { $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $p); $listener.Start(); $listener.Stop(); return $p }
        catch { if ($listener) { try { $listener.Stop() } catch {} } }
    }
    throw 'No free port is available in the 8000-8999 range.'
}
function Show-Notice([string]$message, [string]$title='Ashkan Localhost', [System.Windows.Forms.MessageBoxIcon]$icon=[System.Windows.Forms.MessageBoxIcon]::Information) {
    [void][System.Windows.Forms.MessageBox]::Show($form, $message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
}
function Refresh-Apps([string]$selectName='') {
    $combo.Items.Clear()
    foreach ($app in $script:data.apps) { [void]$combo.Items.Add([string]$app.name) }
    if ($selectName) { $combo.SelectedItem = $selectName }
    elseif ($script:data.defaultName -and $combo.Items.Contains($script:data.defaultName)) { $combo.SelectedItem = $script:data.defaultName }
    elseif ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
    $defaultLabel.Text = if ($script:data.defaultName) { "Default app: $($script:data.defaultName)" } else { 'Default app: none selected' }
}
function Selected-App {
    if ($null -eq $combo.SelectedItem) { return $null }
    return $script:data.apps | Where-Object { $_.name -eq [string]$combo.SelectedItem } | Select-Object -First 1
}
function Start-SelectedApp([bool]$openBrowser=$true) {
    $app = Selected-App
    if (-not $app) { Show-Notice 'Add a project folder first, then select it from the list.' 'No app selected' ([System.Windows.Forms.MessageBoxIcon]::Warning); return }
    if (-not (Test-Path -LiteralPath $app.path -PathType Container)) { Show-Notice "The saved folder could not be found:`r`n$($app.path)`r`n`r`nEdit or add this app again with its current folder." 'Folder not found' ([System.Windows.Forms.MessageBoxIcon]::Error); return }
    if ($script:ServerProcess -and -not $script:ServerProcess.HasExited -and $script:CurrentApp.name -eq $app.name) {
        if ($openBrowser) { Start-Process $app.url }
        return
    }
    if ($script:ServerProcess -and -not $script:ServerProcess.HasExited) { try { Stop-Process -Id $script:ServerProcess.Id -Force } catch {} }
    $serverScript = Join-Path $script:BaseDir 'StaticServer.ps1'
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $serverScript + '"'),'-Root',('"' + $app.path + '"'),'-Port',[string]$app.port)
    try { $script:ServerProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru -WindowStyle Normal }
    catch { Show-Notice "Could not start Windows PowerShell.`r`n$($_.Exception.Message)" 'Launch failed' ([System.Windows.Forms.MessageBoxIcon]::Error); return }
    $script:CurrentApp = $app
    $url = [string]$app.url
    $status.Text = "Starting local web server for $($app.name)..."
    $status.ForeColor = [System.Drawing.Color]::FromArgb(255, 196, 116)
    $form.Refresh()
    $ready = $false
    for ($i=0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        try { $req = [Net.HttpWebRequest]::Create($url); $req.Timeout = 500; $req.Method='GET'; $resp=$req.GetResponse(); $resp.Close(); $ready=$true; break } catch {}
        try { $script:ServerProcess.Refresh(); if ($script:ServerProcess.HasExited) { break } } catch {}
        [System.Windows.Forms.Application]::DoEvents()
    }
    if (-not $ready) { $status.Text = 'Server failed to start. Check the PowerShell window for details.'; $status.ForeColor=[System.Drawing.Color]::Tomato; Show-Notice "The local server did not become ready at $url.`r`nCheck the PowerShell window for the error. The port may already be in use." 'Server startup failed' ([System.Windows.Forms.MessageBoxIcon]::Error); return }
    $status.Text = "Running: $url"
    $status.ForeColor = [System.Drawing.Color]::FromArgb(110, 222, 171)
    if ($openBrowser) { Start-Process $url }
}

$script:data = Read-Manifest
$form = New-Object Windows.Forms.Form
$form.Text = 'Ashkan Localhost'
$form.StartPosition = 'CenterScreen'
$form.Size = [System.Drawing.Size]::new(670, 560)
$form.MinimumSize = [System.Drawing.Size]::new(670, 560)
$form.BackColor = [System.Drawing.Color]::FromArgb(18, 24, 38)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = [System.Drawing.Font]::new('Segoe UI', 10)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$title = New-Object Windows.Forms.Label; $title.Text='ASHKAN LOCALHOST'; $title.Font=[System.Drawing.Font]::new('Segoe UI Semibold',20,[System.Drawing.FontStyle]::Bold); $title.ForeColor=[System.Drawing.Color]::FromArgb(113,206,255); $title.Location=[System.Drawing.Point]::new(28,22); $title.Size=[System.Drawing.Size]::new(600,38); $form.Controls.Add($title)
$subtitle = New-Object Windows.Forms.Label; $subtitle.Text='Local web preview launcher for your projects'; $subtitle.ForeColor=[System.Drawing.Color]::FromArgb(175,190,210); $subtitle.Location=[System.Drawing.Point]::new(30,62); $subtitle.Size=[System.Drawing.Size]::new(600,24); $form.Controls.Add($subtitle)

$group = New-Object Windows.Forms.GroupBox; $group.Text='Launch a project'; $group.ForeColor='White'; $group.Location=[System.Drawing.Point]::new(25,105); $group.Size=[System.Drawing.Size]::new(605,170); $form.Controls.Add($group)
$lbl = New-Object Windows.Forms.Label; $lbl.Text='Select app'; $lbl.Location=[System.Drawing.Point]::new(20,30); $lbl.Size=[System.Drawing.Size]::new(110,24); $group.Controls.Add($lbl)
$combo = New-Object Windows.Forms.ComboBox; $combo.DropDownStyle='DropDownList'; $combo.Location=[System.Drawing.Point]::new(135,27); $combo.Size=[System.Drawing.Size]::new(285,30); $combo.BackColor=[System.Drawing.Color]::FromArgb(31,42,61); $combo.ForeColor='White'; $group.Controls.Add($combo)
$launch = New-Object Windows.Forms.Button; $launch.Text='Launch app'; $launch.Location=[System.Drawing.Point]::new(435,25); $launch.Size=[System.Drawing.Size]::new(145,34); $launch.FlatStyle='Flat'; $launch.BackColor=[System.Drawing.Color]::FromArgb(32,133,202); $launch.ForeColor='White'; $group.Controls.Add($launch)
$defaultLabel = New-Object Windows.Forms.Label; $defaultLabel.Location=[System.Drawing.Point]::new(22,67); $defaultLabel.Size=[System.Drawing.Size]::new(380,24); $defaultLabel.ForeColor=[System.Drawing.Color]::FromArgb(175,190,210); $group.Controls.Add($defaultLabel)
$setDefault = New-Object Windows.Forms.Button; $setDefault.Text='Set selected as default'; $setDefault.Location=[System.Drawing.Point]::new(22,103); $setDefault.Size=[System.Drawing.Size]::new(205,36); $setDefault.FlatStyle='Flat'; $setDefault.BackColor=[System.Drawing.Color]::FromArgb(48,67,91); $setDefault.ForeColor='White'; $group.Controls.Add($setDefault)
$openFolder = New-Object Windows.Forms.Button; $openFolder.Text='Open app folder'; $openFolder.Location=[System.Drawing.Point]::new(238,103); $openFolder.Size=[System.Drawing.Size]::new(155,36); $openFolder.FlatStyle='Flat'; $openFolder.BackColor=[System.Drawing.Color]::FromArgb(48,67,91); $openFolder.ForeColor='White'; $group.Controls.Add($openFolder)
$stop = New-Object Windows.Forms.Button; $stop.Text='Stop server'; $stop.Location=[System.Drawing.Point]::new(404,103); $stop.Size=[System.Drawing.Size]::new(176,36); $stop.FlatStyle='Flat'; $stop.BackColor=[System.Drawing.Color]::FromArgb(97,53,68); $stop.ForeColor='White'; $group.Controls.Add($stop)

$addGroup = New-Object Windows.Forms.GroupBox; $addGroup.Text='Add an app'; $addGroup.ForeColor='White'; $addGroup.Location=[System.Drawing.Point]::new(25,290); $addGroup.Size=[System.Drawing.Size]::new(605,150); $form.Controls.Add($addGroup)
$n = New-Object Windows.Forms.Label; $n.Text='App name'; $n.Location=[System.Drawing.Point]::new(20,32); $n.Size=[System.Drawing.Size]::new(105,24); $addGroup.Controls.Add($n)
$nameBox = New-Object Windows.Forms.TextBox; $nameBox.Location=[System.Drawing.Point]::new(135,29); $nameBox.Size=[System.Drawing.Size]::new(435,28); $nameBox.BackColor=[System.Drawing.Color]::FromArgb(31,42,61); $nameBox.ForeColor='White'; $nameBox.BorderStyle='FixedSingle'; $addGroup.Controls.Add($nameBox)
$p = New-Object Windows.Forms.Label; $p.Text='App folder'; $p.Location=[System.Drawing.Point]::new(20,72); $p.Size=[System.Drawing.Size]::new(105,24); $addGroup.Controls.Add($p)
$pathBox = New-Object Windows.Forms.TextBox; $pathBox.Location=[System.Drawing.Point]::new(135,69); $pathBox.Size=[System.Drawing.Size]::new(335,28); $pathBox.BackColor=[System.Drawing.Color]::FromArgb(31,42,61); $pathBox.ForeColor='White'; $pathBox.BorderStyle='FixedSingle'; $addGroup.Controls.Add($pathBox)
$browse = New-Object Windows.Forms.Button; $browse.Text='Browse...'; $browse.Location=[System.Drawing.Point]::new(480,67); $browse.Size=[System.Drawing.Size]::new(90,32); $browse.FlatStyle='Flat'; $browse.BackColor=[System.Drawing.Color]::FromArgb(48,67,91); $browse.ForeColor='White'; $addGroup.Controls.Add($browse)
$save = New-Object Windows.Forms.Button; $save.Text='Save app'; $save.Location=[System.Drawing.Point]::new(465,108); $save.Size=[System.Drawing.Size]::new(105,30); $save.FlatStyle='Flat'; $save.BackColor=[System.Drawing.Color]::FromArgb(32,133,202); $save.ForeColor='White'; $addGroup.Controls.Add($save)

$status = New-Object Windows.Forms.Label; $status.Text='Ready. Choose a saved app or add a project folder.'; $status.Location=[System.Drawing.Point]::new(30,453); $status.Size=[System.Drawing.Size]::new(590,28); $status.ForeColor=[System.Drawing.Color]::FromArgb(175,190,210); $form.Controls.Add($status)
$hint = New-Object Windows.Forms.Label; $hint.Text='Projects are served over HTTP on 127.0.0.1. Select the folder that contains index.html (for example, dist).'; $hint.Location=[System.Drawing.Point]::new(30,486); $hint.Size=[System.Drawing.Size]::new(600,32); $hint.Font=[System.Drawing.Font]::new('Segoe UI',8); $hint.ForeColor=[System.Drawing.Color]::FromArgb(140,155,175); $form.Controls.Add($hint)

$browse.Add_Click({ $dialog=New-Object Windows.Forms.FolderBrowserDialog; $dialog.Description='Select the web app folder (the folder containing index.html)'; if ($dialog.ShowDialog() -eq 'OK') { $pathBox.Text=$dialog.SelectedPath } })
$save.Add_Click({
    $appName=$nameBox.Text.Trim(); $appPath=$pathBox.Text.Trim()
    if (-not $appName) { Show-Notice 'Enter an app name.' 'Missing app name' ([System.Windows.Forms.MessageBoxIcon]::Warning); return }
    if (-not (Test-Path -LiteralPath $appPath -PathType Container)) { Show-Notice 'Choose an existing app folder.' 'Folder required' ([System.Windows.Forms.MessageBoxIcon]::Warning); return }
    $existing=$script:data.apps | Where-Object { $_.name -eq $appName } | Select-Object -First 1
    if ($existing) { $existing.path=(Resolve-Path -LiteralPath $appPath).Path; $app=$existing }
    else { $port=Find-FreePort; $url="http://127.0.0.1:$port/"; $app=[pscustomobject]@{ name=$appName; path=(Resolve-Path -LiteralPath $appPath).Path; port=$port; url=$url }; $script:data.apps += $app }
    try { Save-Manifest $script:data; Refresh-Apps $appName; $status.Text="Saved $appName. Select it and click Launch app."; $status.ForeColor=[System.Drawing.Color]::FromArgb(110,222,171); $nameBox.Clear(); $pathBox.Clear() }
    catch { Show-Notice "Could not save apps.json. Make sure this folder is writable.`r`n$($_.Exception.Message)" 'Save failed' ([System.Windows.Forms.MessageBoxIcon]::Error) }
})
$setDefault.Add_Click({ $app=Selected-App; if (-not $app) { Show-Notice 'Select an app first.' 'No app selected' ([System.Windows.Forms.MessageBoxIcon]::Warning); return }; $script:data.defaultName=$app.name; try { Save-Manifest $script:data; Refresh-Apps $app.name; $status.Text="$($app.name) will launch automatically next time."; $status.ForeColor=[System.Drawing.Color]::FromArgb(110,222,171) } catch { Show-Notice $_.Exception.Message 'Save failed' ([System.Windows.Forms.MessageBoxIcon]::Error) } })
$launch.Add_Click({ Start-SelectedApp $true })
$openFolder.Add_Click({ $app=Selected-App; if ($app -and (Test-Path -LiteralPath $app.path)) { Start-Process explorer.exe -ArgumentList ('"'+$app.path+'"') } })
$stop.Add_Click({ if ($script:ServerProcess -and -not $script:ServerProcess.HasExited) { try { Stop-Process -Id $script:ServerProcess.Id -Force } catch {}; $status.Text='Local server stopped.'; $status.ForeColor=[System.Drawing.Color]::FromArgb(255,196,116); $script:CurrentApp=$null; $script:ServerProcess=$null } else { $status.Text='No local server is running.' } })
$combo.Add_SelectedIndexChanged({ $app=Selected-App; if ($app) { $status.Text="Ready to launch $($app.name) at $($app.url)"; $status.ForeColor=[System.Drawing.Color]::FromArgb(175,190,210) } })
Refresh-Apps
$form.Add_Shown({ if ($script:data.defaultName -and $combo.SelectedItem) { $script:QuietStartup=$true; Start-SelectedApp $true; $script:QuietStartup=$false } })
[void]$form.ShowDialog()
