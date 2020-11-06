## Settings ##
$config = ConvertFrom-Json $configuration;
$IncludeStatusCodes = $config.IncludeCodes.split(',')
$ExcludeSchoolCodes = $config.ExcludeCodes.split(',')

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
$headers = @{
                "AERIES-CERT" = $config.certificateKey;
};
 
$schools = Invoke-RestMethod ("$($config.Baseuri)/api/v3/schools/") -Method 'GET' -Headers $headers
 
$students = [System.Collections.ArrayList]@{};
$studentsExtended = [System.Collections.ArrayList]@{};
 
#Retrieve Students
foreach($school in $schools)
{
   if($ExcludeSchoolCodes -contains $school.SchoolCode) { Write-Verbose -Verbose "Excluding School Code $($school.SchoolCode)"; continue; }
   $SchoolUri = "$($config.Baseuri)/api/v4/schools/$($school.SchoolCode)";
   Write-Verbose "$($SchoolUri)" -Verbose
   $schoolStudents = Invoke-RestMethod ("$($SchoolUri)/students") -Method 'GET' -Headers $headers
   if($schoolStudents -is [System.Array]) { [void]$students.AddRange($schoolStudents); } else { [void]$students.Add($schoolStudents);}
}
 
$activeStudents = $students.Where({$IncludeStatusCodes -contains $_.InactiveStatusCode})
 
#Process/Filter Students
$uniqueStudents = [Linq.Enumerable]::Distinct([string[]]$students.PermanentID)
 
foreach($student in $uniqueStudents)
{
    $objects = $activeStudents.Where({$_.PermanentID -eq $student});
 
    #Check for active records
    if($objects.count -lt 1) { Write-Verbose -Verbose "skip"; continue; }
 
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
