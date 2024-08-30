$serviceName = "MSOLAP$<InstanceName>"

$service = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
$failureActions = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName").FailureActions

if ($failureActions -ne $null) {
    # Read the first 4 bytes for the reset period (DWORD)
    $resetPeriod = [BitConverter]::ToUInt32($failureActions, 0)
    
    # Read the next 4 bytes for the reboot message length (not usually used)
    $rebootMsgLen = [BitConverter]::ToUInt32($failureActions, 4)
    
    # Read the next 4 bytes for the command length (not usually used)
    $commandLen = [BitConverter]::ToUInt32($failureActions, 8)
    
    # Read the next 4 bytes for the number of actions (DWORD)
    $actionCount = [BitConverter]::ToUInt32($failureActions, 12)
    
    # Each action is represented by a pair of DWORDs: type and delay
    for ($i = 0; $i -lt $actionCount; $i++) {
        $actionType = [BitConverter]::ToUInt32($failureActions, 16 + ($i * 12))
        $actionDelay = [BitConverter]::ToUInt32($failureActions, 20 + ($i * 12))
        
        # Decode action type
        switch ($actionType) {
            0 { $actionTypeDesc = "None" }
            1 { $actionTypeDesc = "Restart the Service" }
            2 { $actionTypeDesc = "Reboot the Computer" }
            3 { $actionTypeDesc = "Run a Command" }
            default { $actionTypeDesc = "Unknown" }
        }
        
        Write-Host "Action $($i+1): $actionTypeDesc after $actionDelay milliseconds"
    }
} else {
    Write-Host "No failure actions configured or service not found."
}


-- claude response --
# Define the service name
$serviceName = "MSOLAP`$SQL2019" # Adjust this to match your SSAS instance name

# Function to parse sc.exe output
function Parse-ScOutput {
    param ($output)
    $result = @{}
    $output | ForEach-Object {
        if ($_ -match '^\s*(\w+)\s*:(.*)$') {
            $result[$matches[1]] = $matches[2].Trim()
        }
    }
    return $result
}

# Get service recovery information
$scOutput = sc.exe qfailure $serviceName
$recoveryInfo = Parse-ScOutput $scOutput

if ($recoveryInfo.ContainsKey('RESET_PERIOD')) {
    Write-Host "Recovery settings for SSAS service ($serviceName):"
    Write-Host "Reset period: $($recoveryInfo['RESET_PERIOD'])"
    Write-Host "First failure action: $($recoveryInfo['1ST_FAILURE'])"
    Write-Host "Second failure action: $($recoveryInfo['2ND_FAILURE'])"
    Write-Host "Subsequent failures: $($recoveryInfo['SUBSEQUENT_FAILURES'])"

    if ($recoveryInfo['1ST_FAILURE'] -eq 'RESTART' -or 
        $recoveryInfo['2ND_FAILURE'] -eq 'RESTART' -or 
        $recoveryInfo['SUBSEQUENT_FAILURES'] -eq 'RESTART') {
        Write-Host "The SSAS service is set to restart on at least one failure condition."
    } else {
        Write-Host "The SSAS service is not set to restart on any failure condition."
    }
} else {
    Write-Host "Unable to retrieve recovery information for the SSAS service. Please check if the service name is correct and if you have the necessary permissions."
}
