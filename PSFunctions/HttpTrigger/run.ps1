param($Timer)

$InstrumentationKey = $ENV:AvailabilityResults_InstrumentationKey
$webtests = $ENV:webtests -split ","
$GEOLOCATION = $ENV:geolocation
$FunctionAppName = $ENV:FunctionAppName
function convert-rawHTTPResponseToObject {
    param(
        [string] $rawHTTPResponse
    )
    
    if ("$rawHTTPResponse" -match '(\d\d\d) \(((\w+|\s)+)\)') {
       
        $props = @{
            StatusCode    = $Matches[1]
            StatusMessage = $Matches[2]
        
        }
        return new-object psobject -Property $props 
    }
    else {
        write-error "Could not extract data from input"
    }  
}
$OriginalErrorActionPreference = "Stop";
foreach ($webtest in $webtests) {
    
    $webtest -match 'https?://([a-zA-Z_0-9.]+)'
    $TestName = $Matches[1]
    $Uri = $webtest 
    $Expected = 200

    $EndpointAddress = "https://dc.services.visualstudio.com/v2/track";
    $Channel = [Microsoft.ApplicationInsights.Channel.InMemoryChannel]::new();
    $Channel.EndpointAddress = $EndpointAddress;
    $TelemetryConfiguration = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::new(
        $InstrumentationKey,  
        $Channel
    );
    $TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new($TelemetryConfiguration);


    $TestLocation = "$GEOLOCATION ($FunctionAppName)"; # you can use any string for this
    $OperationId = (New-Guid).ToString("N");

    $Availability = [Microsoft.ApplicationInsights.DataContracts.AvailabilityTelemetry]::new();
    $Availability.Id = $OperationId;
    $Availability.Name = $TestName;
    $Availability.RunLocation = $TestLocation;
    $Availability.Success = $False;

    $Stopwatch = [System.Diagnostics.Stopwatch]::New()
    $Stopwatch.Start();

    Try {
        # Run test
        $Response = Invoke-WebRequest -Uri $Uri  -SkipCertificateCheck;
        
    }
    Catch {
        $s = [string]$_.Exception.Message
        $Response = convert-rawHTTPResponseToObject -rawHTTPResponse  "$s"
        
    }
    Finally {
        $Success = $Response.StatusCode -eq $Expected;
        if ($Success) {
            Write-host "Testing $TestName on $Uri (Successful: The server retuned the expected statuscode $Expected)"
        }
        else {
            Write-host "Testing $TestName on $Uri (Failed: expected $Expected. Got: "  $Response.StatusCode  ")"
        }
        $Availability.Success = $Success;
        
        $ExceptionTelemetry = [Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry]::new($_.Exception);
        $ExceptionTelemetry.Context.Operation.Id = $OperationId;
        $ExceptionTelemetry.Properties["TestName"] = $TestName;
        $ExceptionTelemetry.Properties["TestLocation"] = $TestLocation;
        $TelemetryClient.TrackException($ExceptionTelemetry);

        $Stopwatch.Stop();
        $Availability.Duration = $Stopwatch.Elapsed;
        $Availability.Timestamp = [DateTimeOffset]::UtcNow;
        
        # Submit Availability details to Application Insights
        $TelemetryClient.TrackAvailability($Availability);
        # call flush to ensure telemetry is sent
        $TelemetryClient.Flush();
    }

}









# using namespace System.Net

# # Input bindings are passed in via param block.
# param($Request, $TriggerMetadata)

# # Write to the Azure Functions log stream.
# Write-Host "PowerShell HTTP trigger function processed a request."

# # Interact with query parameters or the body of the request.
# $name = $Request.Query.Name
# if (-not $name) {
#     $name = $Request.Body.Name
# }

# $body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."

# if ($name) {
#     $body = "Hello, $name. This HTTP triggered function executed successfully."
# }

# # Associate values to output bindings by calling 'Push-OutputBinding'.
# Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
#     StatusCode = [HttpStatusCode]::OK
#     Body = $body
# })
