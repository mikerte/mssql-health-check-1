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

        $agInfo = Invoke-Sqlcmd -ServerInstance $sqlServerInstance -Query "SELECT COUNT(*) AS AGCount FROM sys.availability_groups" -TrustServerCertificate

        # Extract the AGCount value
        $agCount = [int]$agInfo[0].AGCount

        if ($agCount -eq 0) {
            # If no availability group is found, the instance is standalone
            Write-Host "$sqlServerInstance is a standalone instance." -ForegroundColor Yellow
        } elseif ($agCount -gt 0) {
            # If part of an AG, provide details
            Write-Host "$sqlServerInstance is part of an Availability Group." -ForegroundColor Green

            # Output AG details
            $agStatus = Invoke-Sqlcmd -ServerInstance $sqlServerInstance -Query @"
                SELECT ags.name AS AvailabilityGroupName,
                       rs.replica_id,
                       rs.role_desc AS RoleDescription,
                       rs.connected_state_desc AS ConnectedState
                FROM sys.availability_groups ags
                JOIN sys.dm_hadr_availability_replica_states rs
                    ON ags.group_id = rs.group_id
"@ -TrustServerCertificate

            # Display AG details
            Write-Host "`n--- Availability Group Details ---" -ForegroundColor Cyan
            $agStatus | Format-Table -AutoSize
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
