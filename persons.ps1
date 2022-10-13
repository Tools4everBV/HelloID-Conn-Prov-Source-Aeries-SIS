[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

#region Initialize
    $config = ConvertFrom-Json $configuration;
    if($config.IncludeCodes -ne $null -and $config.ExcludeCodes -ne $null) {
        $IncludeStatusCodes = $config.IncludeCodes.split(',')
        $ExcludeSchoolCodes = $config.ExcludeCodes.split(',')
    } else { 
        Write-Information " one or more configuration values are null"

    }
#endregion Initialize

#region Data Pull
    Write-Information "Starting Aeries import."
    Write-Information "Include Status Codes [$($config.IncludeCodes)]"
    Write-Information "Exclude School Codes [$($config.ExcludeCodes)]"

    $headers = @{
                    "AERIES-CERT" = $config.certificateKey;
    };
    Write-Information "Getting Schools"
    $uri = "$($config.Baseuri)/api/v3/schools/"
    Write-Information "Retrieving $($uri)"
    $schools = Invoke-RestMethod $uri -Method 'GET' -Headers $headers
    
    $students = [System.Collections.ArrayList]@{};
    $studentsExtended = [System.Collections.ArrayList]@{};

    Write-Information ("Number of Schools Retrieved from API: {0}" -f $schools.Count)
    
    #Retrieve Students
    foreach($school in $schools)
    {
        if($ExcludeSchoolCodes -contains $school.SchoolCode) { Write-Verbose -Verbose "Excluding School Code [$($school.SchoolCode)]"; continue; }
        
        $SchoolUri = "$($config.Baseuri)/api/v4/schools/$($school.SchoolCode)";
        Write-Information "Getting students for school [$($school.SchoolCode)]";
        Write-Information "Retrieving $($SchoolUri)"
        $schoolStudents = Invoke-RestMethod ("$($SchoolUri)/students") -Method 'GET' -Headers $headers
        
        if($schoolStudents -is [System.Array]) 
        { 
            Write-Information "Retrieved [$($schoolStudents.count)] record(s)"
            [void]$students.AddRange($schoolStudents); 
        } 
        else 
        { 
            Write-Information "Retrieved [1] record(s)"
            [void]$students.Add($schoolStudents);
        }
    }
#endregion Data Pull

#region Process Persons
    Write-Information "Total Students: [$($students.count)] record(s)"
    
    $uniqueStudents = [Linq.Enumerable]::Distinct([string[]]$students.PermanentID)
    Write-Information "Unique Students: [$(([array]$uniqueStudents).count)] record(s)"
    
    Write-Information "Filtering Active Students"
    
    $activeStudents = $students.Where({$IncludeStatusCodes -contains $_.InactiveStatusCode})
    $activeStudentsHT = $activeStudents | Group-Object PermanentID -AsHashTable
    Write-Information "Active Students: [$($activeStudents.count)] record(s)"
    Write-Information "Unique Active Students: [$($activeStudentsHT.count)] record(s)"
    
    foreach($student in $uniqueStudents)
    {
        #$objectsOld = $activeStudents.Where({$_.PermanentID -eq $student});
        $objects = $activeStudentsHT[[int]$student]

        #Check for active records
        if($objects.count -lt 1) { 
            #Write-Information "[$($student)] - Skipping, no active records"; 
            continue; 
        }
    
        $person = @{};
        $person["ExternalId"] = $student;
        $person["DisplayName"] = "$($objects[0].FirstName) $($objects[0].LastName)"
        $person["Role"] = "Student"
        
        $person["Contracts"] = [System.Collections.ArrayList]@();
    
        foreach($o in $objects)
        {
            $contract = @{};
            foreach($prop in $o.PSObject.properties)
            {
                if(@("SchoolCode","InactiveStatusCode","StudentNumber","Grade","SchoolEnterDate","SchoolLeaveDate","DistrictEnterDate","HomeRoomTeacherNumber") -contains $prop.Name) {
                    $contract[$prop.Name] = "$($prop.Value)";
                }
    
                if(@("SchoolCode","InactiveStatusCode","StudentNumber") -contains $prop.Name) { continue; }
                $person[$prop.Name] = "$($prop.Value)";
            }
            [void]$person["Contracts"].Add($contract);
        
        }
        Write-Output $person | ConvertTo-Json -Depth 50
    }
#endregion Process Persons