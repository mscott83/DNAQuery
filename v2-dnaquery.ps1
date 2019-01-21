########################################################
#
# CyberArk DNA Executive Report Generator
# v0.4 (Beta - use with caution)
# by matthew.scott@cyberark.com
#
########################################################

### Script settings

# Set Culture for multi-language support

[threading.thread]::CurrentThread.CurrentCulture = 'en-US'

#### Variables - configure these to your and the customer's requirements ####
# Load user specific environment variables

. .\env.ps1

# Create destination folder if it does not exist

New-Item -ItemType Directory -Force -Path $ExportFolder | Out-Null

### Script Constants - DO NOT CHANGE UNLESS YOU KNOW WHAT YOU ARE DOING ###

$OutputLocation = (Get-Item -Path ".\").FullName

# Add helper functions
. .\dna-query-tools.ps1

$baseHTML = "$OutputLocation\DNAReport\template.html"
$exportHTML = "$OutputLocation\DNAReport\index.html"

# Load user specific environment variables

. "$OutputLocation\env.ps1"

# SQLite database path
$sqldb = ".\dnaquery.db"

# # Remove existing SQLite DB

# Remove-Item $sqldb

# # Build new SQLite database

# . "$OutputLocation\build_database.ps1"

Add-Type -Path "$OutputLocation\System.Data.SQLite.dll"
$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
$con.ConnectionString = "Data Source=$sqldb"
$con.Open()
$sql = $con.CreateCommand()

# Start stopwatch

$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

### Set initial conditions ###

write-host "Setting initial conditions..."

Copy-Item -Path $baseHTML -Destination $exportHTML

Get-ChildItem -path ".\working\" -Recurse -Filter *.csv | Remove-Item

### Import Scan Data and create temporary working CSV files

write-host "Importing DNA Scan Data and writing temporary CSVs..."

# Import All Reports from Import Folder

$Reports = Get-ChildItem -Path $ImportFolder -Filter *.xlsx
$i = 0

#[threading.thread]::CurrentThread.CurrentCulture = 'en-UK'

foreach($r in $Reports){
    write-host "Reading from file:" $r.FullName

    $Excel = New-Object -ComObject "Excel.Application"
    $Workbook = $Excel.workbooks.open($r.FullName)

    Write-Host "Outputting temporary CSV files"

    try{$Workbook.Worksheets.Item("Windows Scan").SaveAs("$OutputLocation\working\windows\$i.csv",6) }
    catch{}

    try{$Workbook.Worksheets.Item("Unix Scan").SaveAs("$OutputLocation\working\unix\$i.csv",6) }
    catch{}

    try{$Workbook.Worksheets.Item("Domain Scan").SaveAs("$OutputLocation\working\domain\$i.csv",6) }
    catch{}

    try{$Workbook.Worksheets.Item("SSH Key Trusts").SaveAs("$OutputLocation\working\sshkeys\$i.csv",6) }
    catch{}

    try{$Workbook.Worksheets.Item("Database Scan").SaveAs("$OutputLocation\working\database\$i.csv",6) }
    catch{}

    try{$Workbook.Worksheets.Item("Hard-Coded Credentials").SaveAs("$OutputLocation\working\hardcoded\$i.csv",6)}
    catch{}

    try{$Workbook.Worksheets.Item("Cloud Users").SaveAs("$OutputLocation\working\cloudusers\$i.csv",6) }
    catch{}

    try{$Workbook.Worksheets.Item("Cloud Instances").SaveAs("$OutputLocation\working\cloudinstances\$i.csv",6) }
    catch{}


    $i++
    $workbook.Close($false)
    $excel.Quit()
}

write-host "Completed exporting CSV Files..."
#region Import

### Combine Windows CSVs ###
write-host "Combining Windows Scan data..."
Combine-CSVs -InputFolder "$OutputLocation\working\windows" -OutputFile "$OutputLocation\working\windows\windows.csv" -SkipLines 10

### Combine Unix CSVs ###
write-host "Combining Unix Scan data..."
Combine-CSVs -InputFolder "$OutputLocation\working\unix" -OutputFile "$OutputLocation\working\unix\unix.csv" -SkipLines 10

### Combine Unix SSH Key CSVs ###
write-host "Combining SSH Key Scan data..."
Combine-CSVs -InputFolder "$OutputLocation\working\sshkeys" -OutputFile "$OutputLocation\working\sshkeys\sshkeys.csv" -SkipLines 10

### Combine Database CSVs ###
write-host "Combining Database Scan data..."
Combine-CSVs -InputFolder "$OutputLocation\working\database" -OutputFile "$OutputLocation\working\database\database.csv" -SkipLines 1

### Combine Domain CSVs ###
write-host "Combining Domain Scan data..."
Combine-CSVs -InputFolder "$OutputLocation\working\domain" -OutputFile "$OutputLocation\working\domain\domain.csv" -SkipLines 8

### Combine Hardcoded credentials CSVs ###
write-host "Combining Hardcoded credentials Scan data..."
Combine-CSVs -InputFolder "$OutputLocation\working\hardcoded" -OutputFile "$OutputLocation\working\hardcoded\hardcoded.csv" -SkipLines 1

### Combine Cloud Users Scans
write-host "Combining Cloud Users Scan data..."
Combine-CSVs -InputFolder "$OutputLocation\working\cloudusers" -OutputFile "$OutputLocation\working\cloudusers\cloudusers.csv" -SkipLines 8

### Create SQLite table

write-host "Creating SQLite Database..."

# Delete any existing data

Write-Host "Initialising SQLite Database..."
$databasetables = "WindowsScan","UnixScan","DomainScan","DatabaseScan","HardcodedScan","SSHKeysScan","CloudUsersScan"

foreach($d in $databasetables){
    $sql.CommandText = "DELETE FROM $d"
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
    $data = New-Object System.Data.DataSet
    [void]$adapter.Fill($data)
}

# Import Windows Scan data to SQLite

write-host "Importing Windows Scan data..."
Import-CSVData -database "WindowsScan" -CSVFile "$OutputLocation\working\windows\windows.csv"
Write-Host "Windows Scan import complete. Elapsed time: "$StopWatch.Elapsed.ToString()

$WindowsScanFoundQuery = 'SELECT COUNT(*) FROM WindowsScan'
$result = Get-SQLite -Query $WindowsScanFoundQuery -File $sqldb
$WindowsScanFoundResult = $result.tables.rows[0]

### Import Unix CSVs ###

write-host "Importing Unix Scan data..."
Import-CSVData -database "UnixScan" -CSVFile "$OutputLocation\working\unix\unix.csv"
Write-Host "Unix Scan import complete. Elapsed time: "$StopWatch.Elapsed.ToString()

$UnixScanFoundQuery = 'SELECT COUNT(*) FROM UnixScan WHERE "Account Name"!="N/A"'
$result = Get-SQLite -Query $UnixScanFoundQuery -File $sqldb
$UnixScanFoundResult = $result.tables.rows[0]

### Import Unix SSH Keys ###

write-host "Importing SSH Key Scan data..."
Import-CSVData -database "SSHKeysScan" -CSVFile "$OutputLocation\working\sshkeys\sshkeys.csv"
Write-Host "SSH Key credentials Scan import complete. Elapsed time: "$StopWatch.Elapsed.ToString()

### Import Domain Scan ###

write-host "Importing Domain Scan data..."
Import-CSVData -database "DomainScan" -CSVFile "$OutputLocation\working\domain\domain.csv"
Write-Host "Domain credentials Scan import complete. Elapsed time: "$StopWatch.Elapsed.ToString()

### Import Database Scans ###
write-host "Importing Database Scan data..."
Import-CSVData -database "DatabaseScan" -CSVFile "$OutputLocation\working\database\database.csv"
Write-Host "Database credentials Scan import complete. Elapsed time: "$StopWatch.Elapsed.ToString()

$DatabaseScanFoundQuery = 'SELECT COUNT(*) FROM DatabaseScan'
$result = Get-SQLite -Query $DatabaseScanFoundQuery -File $sqldb
$DatabaseScanFoundResult = $result.tables.rows[0]

### Import Hardcoded Credentials Data ###
write-host "Importing Hardcoded Credentials Scan data..."
Import-CSVData -database "HardcodedScan" -CSVFile "$OutputLocation\working\hardcoded\hardcoded.csv"
Write-Host "Hardcoded credentials Scan import complete. Elapsed time: "$StopWatch.Elapsed.ToString()

### Import Cloud Users ###
write-host "Importing Cloud Users Scan data..."
Import-CSVData -database "CloudUsersScan" -CSVFile "$OutputLocation\working\cloudusers\cloudusers.csv"
Write-Host "Cloud Users Scan import complete. Elapsed time: "$StopWatch.Elapsed.ToString()
#endregion

#region Overview
##########################
#                        #
# Generate Overview Data #
#                        #
##########################

write-host "Writing overview information..."

### Set author name ###

if($AuthorEMail)
    {
        (Get-Content $exportHTML) -replace "<insert>Author Email</insert>", $AuthorEMail | Set-Content $exportHTML
    }
else{
    (Get-Content $exportHTML) -replace "<insert>Author Email</insert>", "CyberArk" | Set-Content $exportHTML
}

### Number of Different Machines Scanned ###

$sql.CommandText = 'SELECT COUNT(DISTINCT "Machine Name") FROM WindowsScan WHERE "Machine Type"="Server"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$NumberWindowsServers = $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(DISTINCT "Machine Name") FROM WindowsScan WHERE "Machine Type"="Workstation"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$NumberWindowsDesktops = $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(DISTINCT "Machine Name") FROM UnixScan'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$NumberUnixMachines = $data.tables.rows[0]

$TotalMachines = $NumberUnixMachines + $NumberWindowsDesktops + $NumberWindowsServers

$OverView1 = New-Object -TypeName psobject

$OverView1 | Add-Member -NotePropertyName "Windows Servers" -NotePropertyValue $NumberWindowsServers
$OverView1 | Add-Member -NotePropertyName "Windows Desktops" -NotePropertyValue $NumberWindowsDesktops
$OverView1 | Add-Member -NotePropertyName "Unix Machines" -NotePropertyValue $NumberUnixMachines
$OverView1 | Add-Member -NotePropertyName "Total" -NotePropertyValue $TotalMachines

$OverViewTable1 = $OverView1 | ConvertTo-Html -Fragment -As List

(Get-Content $exportHTML) -replace "<insert>Overview Table 1</insert>", $OverviewTable1 | Set-Content $exportHTML

### Number of Different Account Types Scanned ###

$sql.CommandText = 'SELECT COUNT(DISTINCT "Account Name") FROM WindowsScan WHERE "Account Type" LIKE "Domain%" AND ("Account Category" LIKE "Privileged%" OR "Account Category"="Service Account")'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$WindowsPrivAccounts = $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(*) FROM (SELECT DISTINCT(("Machine Name"||"Account Name")) AS expr1 FROM WindowsScan WHERE "Account Type"="Local" AND ("Account Category" LIKE "Privileged%" OR "Account Category"="Service Account")) a'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$WindowsPrivAccounts += $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(DISTINCT "Account Name") FROM WindowsScan WHERE "Account Category" LIKE "Non-Privileged%" AND "Account Type" LIKE "Domain%"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$WindowsNonPrivAccounts = $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(*) FROM (SELECT DISTINCT(("Machine Name"||"Account Name")) AS expr1 FROM WindowsScan WHERE "Account Type"="Local" AND "Account Category" LIKE "Non-Privileged%") a'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$WindowsNonPrivAccounts += $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(DISTINCT "Account Name") FROM UnixScan WHERE "Account Category"="Privileged Domain"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$UnixPrivAccounts = $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(*) FROM (SELECT ("Machine Name"||"Account Name") AS expr1 FROM UnixScan WHERE "Account Category"="Privileged Local") a'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$UnixPrivAccounts += $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(DISTINCT "Account Name") FROM UnixScan WHERE "Account Category"="Non-Privileged Domain"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$UnixNonPrivAccounts = $data.tables.rows[0]

$sql.CommandText = 'SELECT COUNT(*) FROM (SELECT ("Machine Name"||"Account Name") AS expr1 FROM UnixScan WHERE "Account Category"="Non-Privileged Local") a'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$UnixNonPrivAccounts += $data.tables.rows[0]

$TotalAccounts = $WindowsPrivAccounts + $WindowsNonPrivAccounts + $UnixPrivAccounts + $UnixNonPrivAccounts

$OverView2 = New-Object -TypeName psobject
$OverView2 | Add-Member -NotePropertyName "Windows Privileged Accounts" -NotePropertyValue $WindowsPrivAccounts
$OverView2 | Add-Member -NotePropertyName "Windows Non-Privileged Accounts" -NotePropertyValue $WindowsNonPrivAccounts
$OverView2 | Add-Member -NotePropertyName "Unix Privileged Accounts" -NotePropertyValue $UnixPrivAccounts
$OverView2 | Add-Member -NotePropertyName "Unix Non-Privileged Accounts" -NotePropertyValue $UnixNonPrivAccounts
$OverView2 | Add-Member -NotePropertyName "Total Accounts" -NotePropertyValue $TotalAccounts

$OverViewTable2 = $OverView2 | ConvertTo-Html -Fragment -As List

(Get-Content $exportHTML) -replace "<insert>Overview Table 2</insert>", $OverviewTable2 | Set-Content $exportHTML

### Hardcoded Credentials Overview ###
 #WebSphere
$sql.CommandText = 'SELECT COUNT(DISTINCT "Machine Name") FROM HardcodedScan WHERE "Application Server" LIKE "WebSphere%"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$WebsphereServers += $data.tables.rows[0]

#WebLogic
$sql.CommandText = 'SELECT COUNT(DISTINCT "Machine Name") FROM HardcodedScan WHERE "Application Server" LIKE "WebLogic%"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$WeblogicServers += $data.tables.rows[0]

#IIS
$sql.CommandText = 'SELECT COUNT(DISTINCT "Machine Name") FROM HardcodedScan WHERE "Application Server" LIKE "IIS%"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$IISServers += $data.tables.rows[0]

#Ansible
$sql.CommandText = 'SELECT COUNT(DISTINCT "Hard-Coded in File") FROM HardcodedScan WHERE "Application Server" LIKE "Ansible%"'
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
[void]$adapter.Fill($data)

$AnsibleServers += $data.tables.rows[0]

#Combine into table
$OverView3 = New-Object -TypeName psobject
$OverView3 | Add-Member -NotePropertyName "Windows IIS Servers" -NotePropertyValue $IISServers
$OverView3 | Add-Member -NotePropertyName "Oracle WebLogic Servers" -NotePropertyValue $WeblogicServers
$OverView3 | Add-Member -NotePropertyName "IBM WebSphere Servers" -NotePropertyValue $WebsphereServers
$OverView3 | Add-Member -NotePropertyName "Ansible Playbooks" -NotePropertyValue $AnsibleServers

$OverViewTable3 = $OverView3 | ConvertTo-Html -Fragment -As List

(Get-Content $exportHTML) -replace "<insert>Overview Table 3</insert>", $OverviewTable3 | Set-Content $exportHTML

### Overall Account Health ###

$WinCompliantQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM WindowsScan WHERE "Account Type" LIKE "Domain%" AND ("Compliance Status" LIKE "Compliant%" OR "Compliance Status"="N/A")'
$result = Get-SQLite -Query $WinCompliantQuery -File $sqldb
$WindowsCompliant = $result.tables.rows[0]

$WinCompliantQuery2 = 'SELECT COUNT(*) FROM (SELECT DISTINCT(("Machine Name"||"Account Name")) AS expr1 FROM WindowsScan WHERE "Account Type"="Local" AND ("Compliance Status" LIKE "Compliant%" OR "Compliance Status"="N/A")) a'
$result = Get-SQLite -Query $WinCompliantQuery2 -File $sqldb
$WindowsCompliant += $result.tables.rows[0]

(Get-Content $exportHTML) -replace "<insert>WindowsCompliant</insert>", $WindowsCompliant | Set-Content $exportHTML

$WinNonCompliantQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM WindowsScan WHERE "Account Type" LIKE "Domain%" AND "Compliance Status" LIKE "Non-Compliant%"'
$result = Get-SQLite -Query $WinNonCompliantQuery -File $sqldb
$WindowsNonCompliant = $result.tables.rows[0]

$WinNonCompliantQuery2 = 'SELECT COUNT(*) FROM (SELECT DISTINCT(("Machine Name"||"Account Name")) AS expr1 FROM WindowsScan WHERE "Account Type"="Local" AND "Compliance Status" LIKE "Non-Compliant%") a'
$result = Get-SQLite -Query $WinNonCompliantQuery2 -File $sqldb
$WindowsNonCompliant += $result.tables.rows[0]

(Get-Content $exportHTML) -replace "<insert>WindowsNonCompliant</insert>", $WindowsNonCompliant | Set-Content $exportHTML

$UnixNonCompliantQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM UnixScan WHERE "Account Type" LIKE "Domain%" AND "Compliance Status" LIKE "Non-Compliant%"'
$result = Get-SQLite -Query $UnixNonCompliantQuery -File $sqldb
$UnixNonCompliant = $result.tables.rows[0]

$UnixNonCompliantQuery2 = 'SELECT COUNT(*) FROM (SELECT DISTINCT(("Machine Name"||"Account Name")) AS expr1 FROM UnixScan WHERE "Account Type"="Local" AND "Compliance Status" LIKE "Non-Compliant%") a'
$result = Get-SQLite -Query $UnixNonCompliantQuery2 -File $sqldb
$UnixNonCompliant += $result.tables.rows[0]

(Get-Content $exportHTML) -replace "<insert>UnixNonCompliant</insert>", $UnixNonCompliant | Set-Content $exportHTML

$UnixCompliantQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM UnixScan WHERE "Account Type" LIKE "Domain%" AND "Compliance Status" LIKE "Compliant%"'
$result = Get-SQLite -Query $UnixCompliantQuery -File $sqldb
$UnixCompliant = $result.tables.rows[0]

$UnixCompliantQuery2 = 'SELECT COUNT(*) FROM (SELECT DISTINCT(("Machine Name"||"Account Name")) AS expr1 FROM UnixScan WHERE "Account Type"="Local" AND "Compliance Status" LIKE "Compliant%") a'
$result = Get-SQLite -Query $UnixCompliantQuery2 -File $sqldb
$UnixCompliant += $result.tables.rows[0]

(Get-Content $exportHTML) -replace "<insert>UnixCompliant</insert>", $UnixCompliant | Set-Content $exportHTML

#endregion

#region Domain Admins
######################################
#                                    #
# Generate Windows Domain Admin Data #
#                                    #
######################################

if($WindowsScanFoundResult -gt 0){

    Write-Host "Writing Domain Administrator information..."

    $DomainSection = Get-Content '.\DNAReport\sections\domainadmins.html'
    (Get-Content $exportHTML) -replace "<!-- Domain Admins Section -->", $DomainSection | Set-Content $exportHTML

    ### Number of Domain Admin Hashes Found ###

    $DomainAdminsCountQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Privileged Domain Group" LIKE "%' + $DomainAdminsGroupName + '%" AND "Pass-the-Hash: Hash Found"="Yes"'
    $result = Get-SQLite -Query $DomainAdminsCountQuery -File $sqldb
    $DomainAdminsCount = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>DomainAdminsCount</insert>", $DomainAdminsCount | Set-Content $exportHTML

    $DomainAdminsTableQuery = 'SELECT "Account Name",COUNT("Machine Name") as "Machine Count","Password Age",MAX("Last Login Date") as "Last Login Date" FROM WindowsScan WHERE "Privileged Domain Group" LIKE "%' + $DomainAdminsGroupName + '%" AND "Pass-the-Hash: Hash Found"="Yes" GROUP BY "Account Name" ORDER BY "Machine Count" DESC LIMIT 10'
    $result = Get-SQLite -Query $DomainAdminsTableQuery -File $sqldb
    $DomainAdminsTable1 = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

    (Get-Content $exportHTML) -replace "<insert>DomainAdminsTable1</insert>", $DomainAdminsTable1 | Set-Content $exportHTML

    ### Number of Machines that contain Domain Admin Hashes ###

    $DomainAdminsMachineQuery = 'SELECT COUNT(DISTINCT "Machine Name") FROM WindowsScan WHERE "Privileged Domain Group" LIKE "%' + $DomainAdminsGroupName + '%" AND "Pass-the-Hash: Hash Found"="Yes"'
    $result = Get-SQLite -Query $DomainAdminsMachineQuery -File $sqldb
    $DomainAdminsMachineCount = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>DomainAdminsMachineCount</insert>", $DomainAdminsMachineCount | Set-Content $exportHTML

    $DomainAdminsMachineTableQuery = 'SELECT "Machine Name",COUNT("Account Name") as "Hash Count", "Machine Type","OS Version" FROM WindowsScan WHERE "Privileged Domain Group" LIKE "%' + $DomainAdminsGroupName + '%" AND "Pass-the-Hash: Hash Found"="Yes" GROUP BY "Machine Name" ORDER BY "Hash Count" DESC LIMIT 10'
    $result = Get-SQLite -Query $DomainAdminsMachineTableQuery -File $sqldb
    $DomainAdminsTable2 = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

    (Get-Content $exportHTML) -replace "<insert>DomainAdminsTable2</insert>", $DomainAdminsTable2 | Set-Content $exportHTML

    ### Unique Domain Administrator Accounts ###
    #$UnixOldestRootQuery = 'SELECT "Account Name","Machine Name","Password Age","Last Login Date" FROM (SELECT DISTINCT "Machine Name","Password Age", "Last Login Date", "Account Name" FROM UnixScan WHERE "Account Name"="root" ORDER BY "Password Age" DESC LIMIT 10) t'

    $DomainAdminsMachineTable3Query = 'SELECT "Account Name","Privileged Domain Group","Password Age","Last Login Date" FROM WindowsScan WHERE "Privileged Domain Group" LIKE "%' + $DomainAdminsGroupName + '%" GROUP BY "Account Name" ORDER BY "Password Age" DESC LIMIT 10'
    $result = Get-SQLite -Query $DomainAdminsMachineTable3Query -File $sqldb
    $DomainAdminsTable3 = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

    (Get-Content $exportHTML) -replace "<insert>DomainAdminsTable3</insert>", $DomainAdminsTable3 | Set-Content $exportHTML

    ### Unique Domain Admins Count ###

    $UniqueDomainAdminsQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM WindowsScan WHERE "Privileged Domain Group" LIKE "%' + $DomainAdminsGroupName + '%"'
    $result = Get-SQLite -Query $UniqueDomainAdminsQuery -File $sqldb
    $DomainAdminsTotalCount = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>DomainAdminsTotalCount</insert>", $DomainAdminsTotalCount | Set-Content $exportHTML
}
#endregion

#region Local SuperUsers
#################################
#                               #
# Generate Local Superuser Data #
#                               #
#################################

if(($WindowsScanFoundResult -gt 0) -or ($UnixScanFoundResult -gt 0) -or ($DatabaseScanFoundResult -gt 0)){

    Write-Host "Writing local account information..."

    $SuperusersSection = Get-Content '.\DNAReport\sections\localsuperusers.html'
    (Get-Content $exportHTML) -replace "<!-- Local Superusers Section -->", $SuperusersSection | Set-Content $exportHTML

    if($WindowsScanFoundResult -gt 0){

        $WindowsSection = Get-Content '.\DNAReport\sections\windowslocal.html'
        (Get-Content $exportHTML) -replace "<!-- Windows Local Admin Section -->", $WindowsSection | Set-Content $exportHTML

        ### Windows Server Versions ###

        $WindowsVersionsQuery = 'SELECT REPLACE("OS Version","Windows ","") AS "OS Version",COUNT(DISTINCT "Machine Name") AS "Machines" FROM WindowsScan WHERE "Machine Type"="Server" GROUP BY "OS Version"'
        $result = Get-SQLite -Query $WindowsVersionsQuery -File $sqldb
        $WindowsVersionsTable = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors #| ConvertTo-HTML -fragment

        #write-host $WindowsVersionsTable

        foreach($w in $WindowsVersionsTable){
            $WindowsDevicesList = $WindowsDevicesList + '["' + $w."OS Version" + '",' + $w."Machines" + '],'
            #$WindowsDevicesListCount = $WindowsDevicesListCount + '"' + $w."Machines" + '",'
        }

        (Get-Content $exportHTML) -replace "<insert>WindowsDevicesList</insert>", $WindowsDevicesList.TrimEnd(",") | Set-Content $exportHTML

        ### Oldest Windows Local Admin Password ###

        $OldestLocalAdminQuery = 'SELECT "Password Age" FROM WindowsScan WHERE "Machine Type"="Server" AND "Account Type"="Local" AND "Account Description" LIKE "Built-in account for administering%" ORDER BY "Password Age" DESC LIMIT 1'
        $result = Get-SQLite -Query $OldestLocalAdminQuery -File $sqldb
        $OldestLocalAdmin = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>OldestLocalAdminPassword</insert>", $OldestLocalAdmin | Set-Content $exportHTML

        ### Average Windows Local Admin Password Age ###
        $AverageLocalAdminQuery = 'SELECT avg("Password Age") FROM WindowsScan WHERE "Machine Type"="Server" AND "Account Type"="Local" AND "Account Description" LIKE "Built-in account for administering%"'
        $result = Get-SQLite -Query $AverageLocalAdminQuery -File $sqldb
        $AverageLocalAdmin = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>AverageLocalAdminPassword</insert>", [math]::Round($AverageLocalAdmin) | Set-Content $exportHTML

        ### Top 10 oldest Local admin passwords ###

        $WindowsOldestAdminQuery = 'SELECT "Account Name","Machine Name","Password Age","Account State","Last Login Date" FROM WindowsScan WHERE "Machine Type"="Server" AND "Account Type"="Local" AND "Account Description" LIKE "Built-in account for administering%" GROUP BY "Machine Name" ORDER BY "Password Age" DESC LIMIT 10'
        $result = Get-SQLite -Query $WindowsOldestAdminQuery -File $sqldb
        $OldestLocalAdminAccounts = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>OldestLocalAdminAccounts</insert>", $OldestLocalAdminAccounts | Set-Content $exportHTML

        ### User accounts with local admin privileges on servers ###

        $UsersWithLocalAdminQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Privileged Domain Group"="N/A" AND "Account Type"!="Local" AND "Account Group"="Administrators" AND "Machine Type"="Server"'
        $result = Get-SQLite -Query $UsersWithLocalAdminQuery -File $sqldb
        $UsersWithLocalAdmin = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>UsersWithLocalAdmin</insert>", $UsersWithLocalAdmin | Set-Content $exportHTML

    }

    if($UnixScanFoundResult -gt 0){
        $UnixSection = Get-Content '.\DNAReport\sections\unixadmin.html'
        (Get-Content $exportHTML) -replace "<!-- Unix Admin Section -->", $UnixSection | Set-Content $exportHTML

        ### Number of different Unix OS types ###

        $UnixVersionsQuery = 'SELECT "OS Version",COUNT(DISTINCT "Machine Name") AS "Machines" FROM UnixScan GROUP BY "OS Version"'
        $result = Get-SQLite -Query $UnixVersionsQuery -File $sqldb
        $UnixVersionsTable = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors #| ConvertTo-HTML -fragment

        foreach($u in $UnixVersionsTable){
            $UnixDevicesList = $UnixDevicesList + '["' + $u."OS Version" + '",' + $u."Machines" + '],'
        }

        (Get-Content $exportHTML) -replace "<insert>UnixDevicesList</insert>", $UnixDevicesList.TrimEnd(",") | Set-Content $exportHTML

        ### Oldest Unix Root Account ###

        $OldestUnixRootQuery = 'SELECT "Password Age" FROM UnixScan WHERE "Account Name"="root" ORDER BY "Password Age" DESC LIMIT 1'
        $result = Get-SQLite -Query $OldestUnixRootQuery -File $sqldb
        $OldestUnixRoot = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>OldestUnixRoot</insert>", $OldestUnixRoot | Set-Content $exportHTML

        ### Average Unix Root Account ###

        $AverageRootQuery = 'SELECT avg(t."Password Age") FROM (SELECT DISTINCT "Machine Name", "Password Age" FROM UnixScan WHERE "Account Name"="root") AS t'
        $result = Get-SQLite -Query $AverageRootQuery -File $sqldb
        $UnixRootAverage = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>AverageUnixRoot</insert>", [math]::Round($UnixRootAverage) | Set-Content $exportHTML

        ### Top 10 oldest root passwords ###
        $UnixOldestRootQuery = 'SELECT "Account Name","Machine Name","Password Age","Last Login Date" FROM (SELECT DISTINCT "Machine Name","Password Age", "Last Login Date", "Account Name" FROM UnixScan WHERE "Account Name"="root" ORDER BY "Password Age" DESC LIMIT 10) t'
        $result = Get-SQLite -Query $UnixOldestRootQuery -File $sqldb
        $OldestUnixRootAccounts = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>OldestUnixRootAccounts</insert>", $OldestUnixRootAccounts | Set-Content $exportHTML

        ### Unix sudoers accounts ###

        $UniqueSudoQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM UnixScan WHERE "Account Group" LIKE "%sudoers%" AND "Account Name"!="root"'
        $result = Get-SQLite -Query $UniqueSudoQuery -File $sqldb
        $UsersWithSudo = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>UsersWithSudo</insert>", $UsersWithSudo | Set-Content $exportHTML

        $UsersWithSudoQuery = 'SELECT "Account Name",COUNT("Machine Name") AS "Machine Count","Password Age","Last Login Date" FROM UnixScan WHERE "Account Group" LIKE "%sudoers%" AND "Account Name"!="root" GROUP BY "Account Name" ORDER BY "Password Age" DESC LIMIT 10'
        $result = Get-SQLite -Query $UsersWithSudoQuery -File $sqldb
        $UsersWithSudoList = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>UsersWithSudoTable</insert>", $UsersWithSudoList | Set-Content $exportHTML

    }

    ### SQL ACCOUNTS ###

    if($DatabaseScanFoundResult -gt 0){

        ### Replace SQL Section placeholders ###
        $SQLSection = Get-Content '.\DNAReport\sections\sqldatabase.html'
        (Get-Content $exportHTML) -replace "<!-- SQL Database Section -->", $SQLSection | Set-Content $exportHTML

        ### Get SQL Database Version ###

        $DatabaseVersionsQuery = 'SELECT "Instance Version",COUNT(DISTINCT "Machine Name") AS "Machines" FROM DatabaseScan GROUP BY "Instance Version"'
        $result = Get-SQLite -Query $DatabaseVersionsQuery -File $sqldb
        $DatabaseVersionsTable = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors #| ConvertTo-HTML -fragment

        foreach($d in $DatabaseVersionsTable){
            $DatabaseDevicesList = $DatabaseDevicesList + '["' + $d."Instance Version" + '",' + $d."Machines" + '],'
        }

        (Get-Content $exportHTML) -replace "<insert>DatabaseDevicesList</insert>", $DatabaseDevicesList.TrimEnd(",") | Set-Content $exportHTML

        ### Database SQL Login Accounts ###

        $DBSQLLoginsQuery = 'SELECT "Account Name", "Machine Name", "Instance Name","Permissions", "Roles" FROM DatabaseScan WHERE "Account Type"="Database Sql Login" OR "Account Type"="SqlLogin" AND "Context"="Server" LIMIT 10'
        $result = Get-SQLite -Query $DBSQLLoginsQuery -File $sqldb
        $DBSQLLogins = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>SQL Server users table</insert>", $DBSQLLogins | Set-Content $exportHTML

        ### Database Windows Local Login Accounts ###

        $DBLocalLoginsQuery = 'SELECT "Account Name", "Machine Name", "Instance Name","Permissions", "Roles" FROM DatabaseScan WHERE "Account Type"="Windows Local User" OR "Account Type"="WindowsGroup" AND "Context"="Server" LIMIT 10'
        $result = Get-SQLite -Query $DBLocalLoginsQuery -File $sqldb
        $DBLocalLogins = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>Windows Local SQL users table</insert>", $DBLocalLogins | Set-Content $exportHTML

        ### Database Domain Login Accounts ###
        $DBDomainLoginsQuery = 'SELECT "Account Name", "Machine Name", "Instance Name","Permissions", "Roles" FROM DatabaseScan WHERE "Account Type" LIKE "Windows Domain User%" AND "Context"="Server" LIMIT 10'
        $result = Get-SQLite -Query $DBDomainLoginsQuery -File $sqldb
        $DBDomainLogins = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>Windows Domain SQL users table</insert>", $DBDomainLogins | Set-Content $exportHTML
    }
}
#endregion

#region
#####################################
#                                   #
# Generate Endpoint LocalAdmin Data #
#                                   #
#####################################

Write-Host "Writing endpoint information..."

$NumberOfDesktopsQuery = 'SELECT COUNT(DISTINCT "Machine Name") FROM WindowsScan WHERE "Machine Type"="Workstation"'
$result = Get-SQLite -Query $NumberOfDesktopsQuery -File $sqldb
$WindowsDesktopDevices = $result.tables.rows[0]

if($WindowsDesktopDevices -gt 0){
    $EndpointScanFound = $true
}
else{
    $EndpointScanFound = $false
}

if($EndpointScanFound){

    ### Replace Endpoint Section placeholders ###
    $EndpointSection = Get-Content '.\DNAReport\sections\endpoints.html'
    (Get-Content $exportHTML) -replace "<!-- Endpoints Section -->", $EndpointSection | Set-Content $exportHTML
    $EndpointChartSection = Get-Content '.\DNAReport\sections\endpointscharts.html'
    (Get-Content $exportHTML) -replace "<!-- Endpoints Charts -->", $EndpointChartSection | Set-Content $exportHTML

    ### Windows Desktop Versions Found ###

    $WindowsDesktopVersionsQuery = 'SELECT "OS Version",COUNT(DISTINCT "Machine Name") AS "Machines" FROM WindowsScan WHERE "Machine Type"="Workstation" GROUP BY "OS Version" ORDER BY "OS Version"'
    $result = Get-SQLite -Query $WindowsDesktopVersionsQuery -File $sqldb
    $WindowsDesktopVersionsTable = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors #| ConvertTo-HTML -fragment

    foreach($w in $WindowsDesktopVersionsTable){
        $WindowsDesktopDevicesList = $WindowsDesktopDevicesList + '["' + $w."OS Version" + '",' + $w."Machines" + '],'
    }

    (Get-Content $exportHTML) -replace "<insert>WindowsDesktopDevicesList</insert>", $WindowsDesktopDevicesList.TrimEnd(",") | Set-Content $exportHTML

    ### Oldest Windows Local Admin Password ###

    $OldestLocalAdminQuery = 'SELECT "Password Age" FROM WindowsScan WHERE "Machine Type"="Workstation" AND "Account Type"="Local" AND "Account Description" LIKE "Built-in account for administering%" ORDER BY "Password Age" DESC LIMIT 1'
    $result = Get-SQLite -Query $OldestLocalAdminQuery -File $sqldb
    $OldestLocalAdmin = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>OldestEndpointLocalAdminPassword</insert>", $OldestLocalAdmin | Set-Content $exportHTML

    ### Average Windows Local Admin Password Age ###
    $AverageLocalAdminQuery = 'SELECT avg("Password Age") FROM WindowsScan WHERE "Machine Type"="Workstation" AND "Account Type"="Local" AND "Account Description" LIKE "Built-in account for administering%"'
    $result = Get-SQLite -Query $AverageLocalAdminQuery -File $sqldb
    $AverageLocalAdmin = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>AverageEndpointLocalAdminPassword</insert>", [math]::Round($AverageLocalAdmin) | Set-Content $exportHTML

    ### Top 10 oldest Local admin passwords ###

    $WindowsOldestAdminQuery = 'SELECT "Account Name","Machine Name","Password Age","Account State","Last Login Date" FROM WindowsScan WHERE "Machine Type"="Workstation" AND "Account Type"="Local" AND "Account Description" LIKE "Built-in account for administering%" GROUP BY "Machine Name" ORDER BY "Password Age" DESC LIMIT 10'
    $result = Get-SQLite -Query $WindowsOldestAdminQuery -File $sqldb
    $OldestLocalAdminAccounts = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

    (Get-Content $exportHTML) -replace "<insert>OldestEndpointLocalAdminAccounts</insert>", $OldestLocalAdminAccounts | Set-Content $exportHTML

    ### Active Users with Local Admin Rights on Desktops
    $WindowsDesktopAdminsQuery = 'SELECT "Account Name","Machine Name","Privileged Domain Group","Pass-the-Hash: Hash Found","Last Login Date" FROM WindowsScan WHERE "Machine Type"="Workstation" AND "Privileged Domain Group"="N/A" AND "Account Group"="Administrators" AND "Account Type"!="Local" GROUP BY "Account Name" LIMIT 10'
    $result = Get-SQLite -Query $WindowsDesktopAdminsQuery -File $sqldb
    $EndpointLocalAdmins = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

    (Get-Content $exportHTML) -replace "<insert>Endpoint Local Admin users table</insert>", $EndpointLocalAdmins | Set-Content $exportHTML

    ### User accounts with local admin privileges on desktops ###

    $UsersWithLocalAdminQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Machine Type"="Workstation" AND "Account Type"!="Local" AND "Privileged Domain Group"="N/A" AND "Account Group"="Administrators" '
    $result = Get-SQLite -Query $UsersWithLocalAdminQuery -File $sqldb
    $UsersWithLocalAdminDesktops = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>UsersWithLocalAdminDesktops</insert>", $UsersWithLocalAdminDesktops | Set-Content $exportHTML

}
else
{
    Write-Host "No endpoint data found, skipping..."
}
#endregion

#region
#####################################
#                                   #
# Generate Application Account Data #
#                                   #
#####################################

### Check if results found for appllication account sections

# Check accounts with SPNs
$AccountsWithSPNsQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM DomainScan'
$result = Get-SQLite -Query $AccountsWithSPNsQuery -File $sqldb
$AccountsWithSPNs = $result.tables.rows[0]

# Check Windows service accounts
$WindowsServicesCountQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Service Account Type"="Windows Service"'
$result = Get-SQLite -Query $WindowsServicesCountQuery -File $sqldb
$WindowsServicesCount = $result.tables.rows[0]

# Check Scheduled tasks
$WindowsTasksCountQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Service Account Type"="Scheduled Task"'
$result = Get-SQLite -Query $WindowsTasksCountQuery -File $sqldb
$WindowsScheduledCount = $result.tables.rows[0]

# Check IIS Application Pool Accounts
$AppPoolQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Service Account Type"="IIS Application Pool"'
$result = Get-SQLite -Query $AppPoolQuery -File $sqldb
$AppPoolCount = $result.tables.rows[0]

# Check IIS web.config hardcoded credentials
$IISQuery = 'SELECT COUNT(*) FROM HardcodedScan WHERE "Application Server" LIKE "IIS%"'
$result = Get-SQLite -Query $IISQuery -File $sqldb
$IISCount = $result.tables.rows[0]

# Check WebLogic
$WeblogicQuery = 'SELECT COUNT(*) FROM HardcodedScan WHERE "Application Server" LIKE "WebLogic%"'
$result = Get-SQLite -Query $WeblogicQuery -File $sqldb
$WebLogicHardcodedCredsCount = $result.tables.rows[0]

#Check WebSphere
$WebsphereQuery = 'SELECT COUNT(*) FROM HardcodedScan WHERE "Application Server" LIKE "WebSphere%"'
$result = Get-SQLite -Query $WebsphereQuery -File $sqldb
$WebsphereHardcodedCredsCount = $result.tables.rows[0]


# If any results, insert Application Account Section

if(
    ($AccountsWithSPNs -gt 0) -or
    ($WindowsServicesCount -gt 0) -or
    ($WindowsScheduledCount -gt 0) -or
    ($AppPoolCount -gt 0) -or
    ($IISCount -gt 0) -or
    ($WebLogicHardcodedCredsCount -gt 0) -or
    ($WebsphereHardcodedCredsCount -gt 0)
    )
{
    Write-Host "Writing application account information..."

    ### Replace Application Section placeholders ###
    $ApplicationSection = Get-Content '.\DNAReport\sections\applications.html'
    (Get-Content $exportHTML) -replace "<!-- Applications Section -->", $ApplicationSection | Set-Content $exportHTML

    ### Insert SPN ###
    if($AccountsWithSPNs -gt 0){

        $SPNSection = Get-Content '.\DNAReport\sections\windowsspns.html'
        (Get-Content $exportHTML) -replace "<!-- Windows SPN Section -->", $SPNSection | Set-Content $exportHTML

        (Get-Content $exportHTML) -replace "<insert>Number SPN Accounts</insert>", $AccountsWithSPNs | Set-Content $exportHTML

        ### Domain Service Accounts with SPNs discovered ###

        $DomainSPNsQuery = 'SELECT "Account Name","SPN Description","Account State","Password Age","Password Never Expires" FROM DomainScan GROUP BY "Account Name" ORDER BY "Password Age" DESC LIMIT 10'
        $result = Get-SQLite -Query $DomainSPNsQuery -File $sqldb
        $DomainSPNs = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>SPN Accounts</insert>", $DomainSPNs | Set-Content $exportHTML

        ### Oldest SPN password ###

        $OldestDomainSPNQuery = 'SELECT "Password Age" FROM DomainScan ORDER BY "Password Age" DESC LIMIT 1'
        $result = Get-SQLite -Query $OldestDomainSPNQuery -File $sqldb
        $OldestDomainSPN = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>Oldest SPN Account</insert>", $OldestDomainSPN | Set-Content $exportHTML

    }

    ### Insert Services ###
    if($WindowsServicesCount -gt 0){

        $WindowsServiceAccountsSection = Get-Content '.\DNAReport\sections\windowsserviceaccounts.html'
        (Get-Content $exportHTML) -replace "<!-- Windows Service Accounts -->", $WindowsServiceAccountsSection | Set-Content $exportHTML

        ### Service Accounts Running on Servers

        $WindowsServicesQuery = 'SELECT "Account Name","Machine Name",REPLACE("Service Account Description","Service Name: ","") AS "Service Name","Password Age" FROM WindowsScan WHERE "Machine Type"="Server" AND "Service Account Type"="Windows Service" ORDER BY "Password Age" DESC LIMIT 10'
        $result = Get-SQLite -Query $WindowsServicesQuery -File $sqldb
        $WindowsServices = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>Windows Services</insert>", $WindowsServices | Set-Content $exportHTML

        $WindowsServicesCountQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Machine Type"="Server" AND "Service Account Type"="Windows Service"'
        $result = Get-SQLite -Query $WindowsServicesCountQuery -File $sqldb
        $WindowsServicesCount = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>Windows Services Count</insert>", $WindowsServicesCount | Set-Content $exportHTML
    }

    ### Insert Schedule Tasks ###
    if($WindowsScheduledCount -gt 0){

        $WindowsScheduledSection = Get-Content '.\DNAReport\sections\scheduledtasks.html'
        (Get-Content $exportHTML) -replace "<!-- Windows Scheduled Tasks -->", $WindowsScheduledSection | Set-Content $exportHTML

        $WindowsScheduledQuery = 'SELECT "Account Name","Machine Name",REPLACE("Service Account Description","Task Name: ","") AS "Task Name","Password Age" FROM WindowsScan WHERE "Machine Type"="Server" AND "Service Account Type"="Scheduled Task" ORDER BY "Password Age" DESC LIMIT 10'
        $result = Get-SQLite -Query $WindowsScheduledQuery -File $sqldb
        $ScheduledTasks = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>Scheduled Tasks</insert>", $ScheduledTasks | Set-Content $exportHTML

        $WindowsScheduledCountQuery = 'SELECT COUNT(*) FROM WindowsScan WHERE "Machine Type"="Server" AND "Service Account Type"="Scheduled Task"'
        $result = Get-SQLite -Query $WindowsScheduledCountQuery -File $sqldb
        $ScheduledTasksCount = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>ScheduledTasksNumber</insert>", $ScheduledTasksCount | Set-Content $exportHTML

    }

    if($AppPoolCount -gt 0){
        $AppPoolSection = Get-Content '.\DNAReport\sections\iisapppools.html'
        (Get-Content $exportHTML) -replace "<!-- Windows IIS Application Pools -->", $AppPoolSection | Set-Content $exportHTML

        (Get-Content $exportHTML) -replace "<insert>AppPoolNumber</insert>", $AppPoolCount | Set-Content $exportHTML

        $IISAppPoolQuery = 'SELECT "Account Name", "Machine Name", REPLACE("Service Account Description","Application Pool Name: ","") AS "App Pool Description","Password Age" FROM WindowsScan WHERE "Service Account Type"="IIS Application Pool" ORDER BY "Password Age" DESC LIMIT 10'
        $result = Get-SQLite -Query $IISAppPoolQuery -File $sqldb
        $AppPools = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>App Pool Accounts</insert>", $AppPools | Set-Content $exportHTML
    }

    ### Insert IIS Hardcoded Creds ###
    if($IISCount -gt 0){
        $IISSection = Get-Content '.\DNAReport\sections\iissection.html'
        (Get-Content $exportHTML) -replace "<!-- IIS Section -->", $IISSection | Set-Content $exportHTML

        ### Unique Hardcoded IIS Accounts ##

        $IISHardcodedCredsCountQuery = 'SELECT COUNT(DISTINCT "Account Name") FROM HardcodedScan WHERE "Application Server" LIKE "IIS%"'
        $result = Get-SQLite -Query $IISHardcodedCredsCountQuery -File $sqldb
        $IISHardcodedCredsCount = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>IIS Passwords</insert>", $IISHardcodedCredsCount | Set-Content $exportHTML

        $IISHardcodedCredsQuery = 'SELECT "Account Name","Password Length","Application Name","Target System Address","Target System Type" FROM HardcodedScan WHERE "Application Server" LIKE "IIS%" GROUP BY "Account Name" ORDER BY "Password Length" LIMIT 10'
        $result = Get-SQLite -Query $IISHardcodedCredsQuery -File $sqldb
        $IISHardcodedCreds = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>IIS Hardcoded creds</insert>", $IISHardcodedCreds | Set-Content $exportHTML

    }

    ### Insert WebLogic Data ###
    if($WebLogicHardcodedCredsCount -gt 0){
        $WebLogicSection = Get-Content '.\DNAReport\sections\webLogic.html'
        (Get-Content $exportHTML) -replace "<!-- WebLogic Section -->", $WebLogicSection | Set-Content $exportHTML

        (Get-Content $exportHTML) -replace "<insert>WebLogic Hardcoded creds</insert>", $WebLogicHardcodedCredsCount | Set-Content $exportHTML

        $WebLogicHardcodedCredsQuery = 'SELECT "Account Name","Password Length","Application Name","Target System Address","Target System Type" FROM HardcodedScan WHERE "Application Server" LIKE "WebLogic%" ORDER BY "Password Length" LIMIT 10'
        $result = Get-SQLite -Query $WebLogicHardcodedCredsQuery -File $sqldb
        $WebLogicHardcodedCreds = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>WebLogic Hardcoded creds table</insert>", $WebLogicHardcodedCreds | Set-Content $exportHTML

    }

    ### Insert WebSphere Data ###
    if($WebsphereHardcodedCredsCount -gt 0){
        $WebsphereSection = Get-Content '.\DNAReport\sections\websphere.html'
        (Get-Content $exportHTML) -replace "<!-- WebSphere Section -->", $WebSphereSection | Set-Content $exportHTML

        (Get-Content $exportHTML) -replace "<insert>WebSphere Hardcoded creds</insert>", $WebSphereHardcodedCredsCount | Set-Content $exportHTML

        $WebSphereHardcodedCredsQuery = 'SELECT "Account Name","Password Length","Application Name","Target System Address","Target System Type" FROM HardcodedScan WHERE "Application Server" LIKE "WebSphere%" ORDER BY "Password Length" LIMIT 10'
        $result = Get-SQLite -Query $WebSphereHardcodedCredsQuery -File $sqldb
        $WebSphereHardcodedCreds = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>WebSphere Hardcoded creds table</insert>", $WebSphereHardcodedCreds | Set-Content $exportHTML
    }


}
else{write-host "No application results found, skipping"}
#endregion
#region
#################
#               #
# Unix SSH Keys #
#               #
#################

$SSHKeysQuery = 'SELECT COUNT(*) FROM SSHKeysScan'
$result = Get-SQLite -Query $SSHKeysQuery -File $sqldb
$SSHKeysFound = $result.tables.rows[0]

if($SSHKeysFound -gt 0){
    Write-Host "Writing SSH Keys information..."

    $SSHKeysSection = Get-Content '.\DNAReport\sections\sshkeys.html'
    (Get-Content $exportHTML) -replace "<!-- SSH Keys Section -->", $SSHKeysSection | Set-Content $exportHTML

    ### Oldest SSH Key age ###
    $OldestSSHKeyQuery = 'SELECT "Key Age (at least)" FROM SSHKeysScan WHERE "Key Age (at least)"!="N/A" ORDER BY "Key Age (at least)" DESC LIMIT 1'
    $result = Get-SQLite -Query $OldestSSHKeyQuery -File $sqldb
    $OldestSSHKey = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>Oldest SSH Key</insert>", $OldestSSHKey | Set-Content $exportHTML

    ### Top 10 oldest SSH keys ###

    $OldestSSHKeyListQuery = 'SELECT "Source Machine","Source Account","Target Machine","Target Account","Key Age (at least)" FROM SSHKeysScan WHERE "Key AGe (at least)"!="N/A" ORDER BY "Key Age (at least)" DESC LIMIT 10'
    $result = Get-SQLite -Query $OldestSSHKeyListQuery -File $sqldb
    $OldestSSHKeyList = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

    (Get-Content $exportHTML) -replace "<insert>Oldest SSH Key List</insert>", $OldestSSHKeyList | Set-Content $exportHTML


}
else{
    write-host "SSH Key data not found, skipping..."
}

#endregion
#region
##################
#                #
# Cloud & Devops #
#                #
##################
$AnsibleQuery = 'SELECT COUNT(*) FROM HardcodedScan WHERE "Application Server" LIKE "Ansible%"'
$result = Get-SQLite -Query $AnsibleQuery -File $sqldb
$AnsibleFound = $result.tables.rows[0]

$AWSUsersQuery = 'SELECT COUNT(*) FROM CloudUsersScan'
$result = Get-SQLite -Query $AWSUsersQuery -File $sqldb
$AWSFound = $result.tables.rows[0]


if(($AWSFound -gt 0) -or ($AnsibleFound -gt 0)){
    Write-Host "Writing Cloud & Devops information..."

    $CloudSection = Get-Content '.\DNAReport\sections\clouddevops.html'
    (Get-Content $exportHTML) -replace "<!-- Cloud and Devops Section -->", $CloudSection | Set-Content $exportHTML

    if($AWSFound -gt 0){

        $AWSSection = Get-Content '.\DNAReport\sections\aws.html'
        (Get-Content $exportHTML) -replace "<!-- AWS Section -->", $AWSSection | Set-Content $exportHTML

        ### AWS AdministratorAccess accounts ###

        $AWSAdminsCountQuery = 'SELECT COUNT(*) FROM CloudUsersScan WHERE "Privilege Policies"="AdministratorAccess"'
        $result = Get-SQLite -Query $AWSAdminsCountQuery -File $sqldb
        $AWSAdminAccountsCount = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>AWS AdministratorAccess</insert>", $AWSAdminAccountsCount | Set-Content $exportHTML

        $AWSAdminAccountsQuery = 'SELECT "User Name", "Type", "Status", "Password Age" FROM CloudUsersScan WHERE "Privilege Policies"="AdministratorAccess" ORDER BY "Password Age" DESC LIMIT 10'
        $result = Get-SQLite -Query $AWSAdminAccountsQuery -File $sqldb
        $AWSAdminAccounts = $result.tables[0]  | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>AWS AdministratorAccess table</insert>", $AWSAdminAccounts | Set-Content $exportHTML
    }

    ### Ansible Hardcoded Credentials ###

    if($AnsibleFound -gt 0){

        $AnsibleSection = Get-Content '.\DNAReport\sections\ansible.html'
        (Get-Content $exportHTML) -replace "<!-- Ansible Section -->", $AnsibleSection | Set-Content $exportHTML

        ### Ansible Hardcoded Credentials ###

        $AnsibleHardcodedCredsQuery = 'SELECT COUNT(*) FROM HardcodedScan WHERE "Application Server" LIKE "Ansible%"'
        $result = Get-SQLite -Query $AnsibleHardcodedCredsQuery -File $sqldb
        $AnsibleHardcodedCredsCount = $result.tables.rows[0]

        (Get-Content $exportHTML) -replace "<insert>Ansible Hardcoded creds</insert>", $AnsibleHardcodedCredsCount | Set-Content $exportHTML

        $AnsibleHardcodedCredsListQuery = 'SELECT "Account Name", "Machine Name","Password Length", "Hard-Coded in File" FROM HardcodedScan WHERE "Application Server" LIKE "Ansible%" ORDER BY "Password Length" LIMIT 10'
        $result = Get-SQLite -Query $AnsibleHardcodedCredsListQuery -File $sqldb
        $AnsibleHardcodedCreds = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

        (Get-Content $exportHTML) -replace "<insert>Ansible Hardcoded creds table</insert>", $AnsibleHardcodedCreds | Set-Content $exportHTML

    }

}
else{
    write-host "Cloud results not found, skipping..."
}
#endregion

#region
##################
#                #
# Business Users #
#                #
##################

# Domain users with non-admin access to servers

if($WindowsScanFoundResult -gt 0){
    Write-Host "Writing Business User information..."

    $BusinessUsersSection = Get-Content '.\DNAReport\sections\businessusers.html'
    (Get-Content $exportHTML) -replace "<!-- Privileged Business Users Section -->", $BusinessUsersSection | Set-Content $exportHTML

    ### Non-privileged Users with access to servers ###
    $BusinessUsersWithServerAccessQuery = 'SELECT COUNT (DISTINCT "Account Name") FROM WindowsScan WHERE "Machine Type"="Server" AND "Account Category" LIKE "Non-Privileged%" AND "Account Type" LIKE "Domain%"'
    $result = Get-SQLite -Query $BusinessUsersWithServerAccessQuery -File $sqldb
    $BusinessUsersWithServerAccessCount = $result.tables.rows[0]

    (Get-Content $exportHTML) -replace "<insert>Non-privileged Users with access to servers</insert>", $BusinessUsersWithServerAccessCount | Set-Content $exportHTML

    $BusinessUsersWithServerAccessListQuery = 'SELECT "Account Name",COUNT("Machine Name") AS "Machine Count","Account Group","Privileged Domain Group","Password Age" FROM WindowsScan WHERE "Machine Type"="Server" AND "Account Category" LIKE "Non-Privileged%" AND "Account Type" LIKE "Domain%" GROUP BY "Account Name" ORDER BY "Machine Count" DESC LIMIT 10'
    $result = Get-SQLite -Query $BusinessUsersWithServerAccessListQuery -File $sqldb
    $BusinessUsersWithServerAccess = $result.tables[0] | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML -fragment

    (Get-Content $exportHTML) -replace "<insert>Business Users table</insert>", $BusinessUsersWithServerAccess | Set-Content $exportHTML

}
#endregion
#################
#               #
# Cleanup Tasks #
#               #
#################

write-host "Cleaning up..."

### Cleanup HTML table formatting ###

(Get-Content $exportHTML) -replace "<table>", '<table class="table table-sm table-striped">' | Set-Content $exportHTML
(Get-Content $exportHTML) -replace "<insert>Customer Name</insert>", $CustomerName | Set-Content $exportHTML

### Output finished report file as PDF ###

$ChromePath = $env:LOCALAPPDATA

$Command = "$ChromePath\Google\Chrome\Application\chrome.exe"

& $Command --headless --print-to-pdf="$ExportFolder\DNA Executive Report - $CustomerName.pdf" "file:///$OutputLocation/DNAReport/index.html"

### Copy HTML files to output folder ###

Copy-Item .\DNAReport -Destination $ExportFolder -recurse -Force

### Copy SQLite Database to output folder ###

Copy-Item .\dnaquery.db -Destination $ExportFolder -force

### Clear SQLite DB for next run ###

# Write-Host "Initialising SQLite Database..."
$databasetables = "WindowsScan","UnixScan","DomainScan","DatabaseScan","HardcodedScan","SSHKeysScan","CloudUsersScan"

foreach($d in $databasetables){
    $sql.CommandText = "DELETE FROM $d"
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
    $data = New-Object System.Data.DataSet
    [void]$adapter.Fill($data)
}

$sql.CommandText = "VACUUM"
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
    $data = New-Object System.Data.DataSet
    [void]$adapter.Fill($data)

### Close SQLite connection ###

$sql.Dispose()
$con.Close()
$con.Dispose()
Unblock-File .\dnaquery.db

### Remove Working CSV Files ###

Get-ChildItem -path "$OutputLocation\working\" -Recurse -Filter *.csv | Remove-Item

### Remove completed report template ###
Remove-Item $exportHTML

### Completed ###

$StopWatch.Stop()
Write-Host "Elapsed time: "$StopWatch.Elapsed.ToString()

Write-Host "DNA Executive Report complete."

Write-Host "Press any key to exit..."
$void = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
(Get-Host).SetShouldExit(0)
