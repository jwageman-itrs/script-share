# Nagios status codes
$OK = 0
$WARNING = 1
$CRITICAL = 2
$UNKNOWN = 3
 
# Initialize status variables
$overallStatus = $OK
$availabilityGroupStatus = @()
 
function Check-ClusterStatus {
    param (
        [string]$ClusterName
    )
   
    try {
        Import-Module FailoverClusters
        $clusterInfo = Get-Cluster
        $localnode = $env:COMPUTERNAME
 
        $cluster = Get-Cluster #$ClusterName
        $nodestate = (Get-ClusterNode -Name $localnode).State
      
 
        if ($nodestate -ne 'Up') {
            return $CRITICAL, "Cluster $ClusterName is not online."
        }
       
        return $OK, "Cluster $ClusterName is online."
    } catch {
        return $CRITICAL, "Cluster $ClusterName status check failed: $_"
    }
}
 
function Check-AvailabilityGroups {
    param (
        [string]$ClusterName
    )
   
    try {
        Import-Module SqlServer
        $sqlInstances = Get-ClusterGroup | Where-Object { $_.GroupType -eq 'Clustered SQL Server' }
       
        foreach ($instance in $sqlInstances) {
            $sqlInstanceName = $instance.Name
            $agStatus = Get-SqlAvailabilityGroup -ServerInstance $sqlInstanceName
           
            foreach ($ag in $agStatus) {
                $agName = $ag.Name
                $agRole = $ag.Role
                $agSyncState = $ag.SyncState
               
                if ($agRole -ne 'Primary') {
                    $availabilityGroupStatus += "AG $agName is not in Primary role. Current role: $agRole"
                    $overallStatus = [Math]::Max($overallStatus, $CRITICAL)
                }
               
                if ($agSyncState -ne 'Synchronized') {
                    $availabilityGroupStatus += "AG $agName is not synchronized. Current sync state: $agSyncState"
                    $overallStatus = [Math]::Max($overallStatus, $WARNING)
                }
            }
        }
       
        return $OK, "All availability groups are in expected state."
    } catch {
        return $CRITICAL, "Availability Groups status check failed: $_"
    }
}
 
function Check-ClusterResources {
    param (
        [string]$ClusterName
    )
   
    try {
        $resources = Get-ClusterResource
        $offlineResources = $resources | Where-Object { $_.State -ne 'Online' }
       
        if ($offlineResources.Count -gt 0) {
            return $WARNING, "There are offline cluster resources: $($offlineResources.Name -join ', ')"
        }
       
        return $OK, "All cluster resources are online."
    } catch {
        return $CRITICAL, "Cluster resources status check failed: $_"
    }
}
 
# Main script execution
try {
    Import-Module FailoverClusters
    $clusters = Get-Cluster | Select-Object -ExpandProperty Name
 
    if ($clusters.Count -eq 0) {
        Write-Output "No clusters found on this machine."
        #exit $UNKNOWN
    }
 
    foreach ($cluster in $clusters) {
        Write-Output "Checking status for cluster: $cluster"
 
        $clusterStatusCode, $clusterStatusMessage = Check-ClusterStatus -ClusterName $cluster
        $availabilityGroupStatusCode, $availabilityGroupStatusMessage = Check-AvailabilityGroups -ClusterName $cluster
        $clusterResourcesStatusCode, $clusterResourcesStatusMessage = Check-ClusterResources -ClusterName $cluster
 
        # Combine results
        $overallMessage = "$clusterStatusMessage; $availabilityGroupStatusMessage; $clusterResourcesStatusMessage"
        Write-Output $overallMessage
 
        #$overallStatus = [Math]::Max($overallStatus, $clusterStatusCode, $availabilityGroupStatusCode, $clusterResourcesStatusCode)
        $overallStatus = [Math]::Max($overallStatus, [Math]::Max($clusterStatusCode, [Math]::Max($availabilityGroupStatusCode, $clusterResourcesStatusCode)))
 
    }
} catch {
    Write-Output "An error occurred: $_"
    exit $UNKNOWN
}
 
exit $overallStatus
