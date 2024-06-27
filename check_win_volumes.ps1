<#
check_win_volumes.ps1
an Opsview and Nagios compatible PowerShell script to monitor usage of Windows drives and volumes
Copyright (C) 2024  Jon Wageman (jwageman at itrsgroup.com)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>
#>
param(
    [Alias("h")][Switch] $help,
    [Alias("l")][Switch] $list_volumes,
    [Alias("e")]$exclude_list = "",
    [Alias("w")]$warning = 90,
    [Alias("c")]$critical = 95
)

$global:message_array = @()
$global:critical_flag = 0
$global:warning_flag = 0
$global:perf_data = "| "

function Show-Help {
    Write-Host "
    This script monitors all Windows volume capacity, including drives and mount points, as an Opsview / Nagios plugin.

    USAGE:
    check_win_volumes -w WARNING_PCT -c CRITICAL_PCT -e 'EXCLUDEDVOLUMES'

    EXAMPLE ALL VOLUMES:
    check_win_volumes -w 90 -c 95

    EXAMPLE WITH EXCLUDED VOLUMES:
    check_win_volumes -w 90 -c 95 -e 'D:\'

    FLAGS:
    -h : Displays this message
    -l : lists volumes only
    -e : list of volumes to exclude
    -w : Set warning level as a percentage (Default: 90)
    -c : Set critical level as a percentage (Default: 95)
    "
    exit 0    
}

function Check-Volumes {
    Get-WmiObject Win32_Volume -Filter "DriveType='3'" | ForEach-Object {
        $name = $_.Name
        if ($exclude_list.Contains($name)) { return }
        $label = $_.Label
        $free_space = ([Math]::Round($_.FreeSpace /1GB,2))
        $total_size = ([Math]::Round($_.Capacity /1GB,2))
        $disk_used = ($total_size - $free_space)
        $pct_used = ([Math]::Round(($disk_used / $total_size),4) * 100)
        if ($pct_used -ge $critical) {
            $status = "CRITICAL: "
            $global:critical_flag = 1    
        } 
        elseif ($pct_used -ge $warning) {
            $status = "WARNING:"
            $global:warning_flag = 1
        }
        else {
            $status = "OK:"
        }
        $global:message_array += @("$status ${name} % Disk Used is ${pct_used}% (${disk_used}GB of ${total_size}GB) ")
        $global:perf_data += "'$name %'=${pct_used}% "
   }
}

function List-Volumes {
    $vol_list = "VOLUMES:  "
    Get-WmiObject Win32_Volume -Filter "DriveType='3'" | ForEach-Object {
        $name = $_.Name
        $label = $_.Label
        $vol_list += "$name($label)  "
    }
    Write-Host $vol_list
    exit 0
}

function Process-Parameters {
    if ($help) {Show-Help}
    if ($list_volumes) {List-Volumes}

}

function Build-Message {
    $message = ""
    $global:message_array | Foreach {
        if ($_.Contains("WARNING:")) {
            $message = $_ + $message
        }
        elseif ($_.Contains("CRITICAL:")) {
            $message = $_ + $message
        }
        else {
            $message = $message + $_
        }
    }
    return $message
}

function Main {
    Process-Parameters
    Check-Volumes
    $message = Build-Message
    Write-Host $message $global:perf_data
    if ($global:critical_flag -eq 1) {exit 2}
    elseif ($global:warning_flag -eq 1) {exit 1}
    else {exit 0}
}

Main
