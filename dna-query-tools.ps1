function Get-SQLite{
    param(
        [string]$Query,
        [string]$File
        )

    Add-Type -Path ".\System.Data.SQLite.dll"
    $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $con.ConnectionString = "Data Source=$File"
    $con.Open()

    $sql = $con.CreateCommand()

    $sql.CommandText = "$Query"
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
    $data = New-Object System.Data.DataSet
    [void]$adapter.Fill($data)

    return $data
}

function Combine-CSVs{
    param(
        [string]$InputFolder,
        [string]$OutputFile,
        [int]$SkipLines
    )

    $ScanCSVs = Get-ChildItem -Path $InputFolder
    $y=0
    $outfile = New-Object System.IO.StreamWriter ("$OutputFile")

    foreach($s in $ScanCSVs){
        write-host "Reading from "$s.FullName
    
        # Strip first 10 lines
        if($y -eq 0)
        {
            $skip = $SkipLines
        }
        else{
            $skip = $SkipLines + 1
        }
    
        $infile = New-Object System.IO.StreamReader ($s.FullName)
    
        for( $i = 1; $i -le $skip -and !$infile.EndOfStream; $i++ ) {
            $infile.ReadLine() | Out-Null
        }
        while( !$infile.EndOfStream ) {
            $outfile.WriteLine( $infile.ReadLine() )
    
        }
        $infile.close()
        $infile.dispose()
        write-host "Finished reading "$s.FullName  
        $y++
    }
    $outfile.close()
    $outfile.dispose()
    
}

function Import-CSVData{
    param(
        [string]$CSVFile,
        [string]$database
    )
    # SQLite database path
    $sqldb = ".\dnaquery.db"

    Add-Type -Path ".\System.Data.SQLite.dll"
    $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $con.ConnectionString = "Data Source=$sqldb"
    $con.Open()

    $sql = $con.CreateCommand()

    $file = New-Object System.IO.StreamReader ("$CSVFile")
    $RecsPerTransaction = 50
    $insertioncount = 0
    $totalCount = 0
    $insertion = $null

    $header = $file.ReadLine() #| Out-Null
    $headertoken = $header -split ","
    $columns = $headertoken.Count
    #write-host $columns
    $newheader = $null
    foreach($h in $headertoken)
    {
        $newheader += '"' + $h + '",'
    }
    $newheader = $newheader.TrimEnd(",")

    while( !$file.EndOfStream ) {
        $line = $file.ReadLine()

        $token = $line -split ',(?=(?:[^"]|"[^"]*")*$)'
        if((!$token.Count -eq $columns) -or ($token[0] -eq "")){
            # write-host "Ignoring the following line, suspect broken CSV data:"
            # write-host $line
            # write-host $token.Count
        }
        else{
            #write-host $token.Count
            $newline = $null
            $t = $null
            $line = $line.Replace("`r`n",' ')
            foreach($t in $token){
                #$t = $t.Replace("`r`n",' ')
                $t = $t.Replace('"',"'")
                # $t = $t.Trim('"')
                $t = $t.Replace(",","")
                $t = '"'+$t+'"'
                $newline += $t + ","
            }
            $newline = $newline.TrimEnd(",")
            $testtoken = $newline.Split(",")
            if($testtoken.Count -eq $columns){
                $insertion += 'INSERT INTO '+ $database + ' ('+$newheader+') VALUES ('+$newline+');'
                $insertioncount++
            }
            else{
                write-host "Bad line: $newline"
            }

            # If Batch Size has been reach, begin bulk insert
            if($insertioncount -eq $RecsPerTransaction){
                $sql.CommandText = 'BEGIN TRANSACTION;' + $insertion + 'COMMIT;'
                #write-host $sql.CommandText
                $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
                $data = New-Object System.Data.DataSet
                [void]$adapter.Fill($data)
                $totalCount += $insertioncount
                $insertioncount = 0
                $insertion = $null
                write-progress -Activity "Inserted $totalCount records" 
                }
        }
    }
    # Add last batch if not enough for 50 unit INSERT
    $sql.CommandText = 'BEGIN TRANSACTION;' + $insertion + 'COMMIT;'
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
    $data = New-Object System.Data.DataSet
    [void]$adapter.Fill($data)

    #Close Database file
    $file.close()
    $file.dispose()

}