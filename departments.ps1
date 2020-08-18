## Settings ##
$Baseuri = "{CUSTOMER URL HERE}";
$CertificateKey = "{CERTIFICATE KEY HERE}";


[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
$headers = @{
                "AERIES-CERT" = $CertificateKey;
};
 
$schools = Invoke-RestMethod ("$($Baseuri)/api/v3/schools/") -Method 'GET' -Headers $headers
 
foreach($school in $schools)
{
    $department =
        @{
            ExternalId="$($school.SchoolCode)";
            DisplayName="$($school.Name)";
            Name="$($school.Name)";
        };
 
    Write-Output $department | ConvertTo-Json
}
 
 
Write-Verbose -Verbose "Department import completed";