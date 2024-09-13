# Import SQL Server module (may need to install if not available)
Import-Module SqlServer

# Function to check SQL Server connectivity
function Test-SqlServerConnection {
    param (
        [string]$serverInstance
    )

    try {
        # Create a SQL Connection
        $connectionString = "Server=$serverInstance;Database=master;Integrated Security=True;"
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $sqlConnection.ConnectionString = $connectionString
        
        # Open the SQL connection
        $sqlConnection.Open()

        # Success message
        Write-Host "Connection to $serverInstance is successful." -ForegroundColor Green
        $sqlConnection.Close()
        return $true
    }
    catch {
        # Error message
        Write-Host "Failed to connect to $serverInstance." -ForegroundColor Red
        return $false
    }
}

# Function to check if the instance is part of an Availability Group
function Check-AvailabilityGroup {
    param (
        [string]$sqlServerInstance
    )

    try {
        # Check if the instance is part of an Availability Group
        Write-Host "`n--- Checking Availability Group status for: $sqlServerInstance ---`n"

        # Query to check for AG membership using replica states
        $agReplicaInfo = Invoke-Sqlcmd -ServerInstance $sqlServerInstance -Query @"
            SELECT rs.replica_id, rs.group_id, rs.role_desc, rs.connected_state_desc, ags.name AS AvailabilityGroupName
            FROM sys.dm_hadr_availability_replica_states rs
            JOIN sys.availability_groups ags
            ON rs.group_id = ags.group_id
"@ -TrustServerCertificate

        # Check if any replicas were found
        if ($agReplicaInfo.Count -gt 0) {
            Write-Host "$sqlServerInstance is part of an Availability Group." -ForegroundColor Green

            # Output AG details
            Write-Host "`n--- Availability Group Details ---" -ForegroundColor Cyan
            $agReplicaInfo | Format-Table -AutoSize
        } else {
            # If no rows were returned, the instance is standalone
            Write-Host "$sqlServerInstance is a standalone instance." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to retrieve AG status from $sqlServerInstance. Error: $_" -ForegroundColor Red
    }
}

# Main script to retrieve the SQL Server instances on the local machine
Write-Host "`n--- Starting SQL Server Health Check ---" -ForegroundColor Cyan
$serverInstances = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server" -Name "InstalledInstances"

if ($serverInstances.InstalledInstances.Count -eq 0) {
    Write-Host "No SQL Server instances found on this machine." -ForegroundColor Red
    exit 1
}

# Loop through each instance found
foreach ($instance in $serverInstances.InstalledInstances) {
    if ($instance -eq "MSSQLSERVER") {
        # Default instance
        $serverName = $env:COMPUTERNAME
    } else {
        # Named instance
        $serverName = "$env:COMPUTERNAME\$instance"
    }

    Write-Host "`nChecking SQL Server: $serverName" -ForegroundColor White
    Write-Host "------------------------------------" -ForegroundColor DarkGray

    # Check connection
    $isConnected = Test-SqlServerConnection -serverInstance $serverName
    if ($isConnected) {
        Write-Host "$serverName is healthy." -ForegroundColor Green

        # Check if part of an Availability Group or Standalone
        Check-AvailabilityGroup -sqlServerInstance $serverName
    } else {
        Write-Host "$serverName is down or unreachable." -ForegroundColor Red
    }

    Write-Host "------------------------------------`n" -ForegroundColor DarkGray
}

Write-Host "`n--- Health Check Completed ---" -ForegroundColor Cyan
