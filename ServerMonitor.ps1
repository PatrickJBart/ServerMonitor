# PowerShell Systems Report
# Example usage: .\ServerMonitor.ps1 .\list.txt
# Remember that list.txt is the file containing a list of Server names to run this against

#region Variables and Arguments
$users = "youremail@yourcompany.com" # List of users to email your report to (separate by comma)
$fromemail = "youremail@yourcompany.com"
$server = "yourmailserver.yourcompany.com" #enter your own SMTP server DNS name / IP address here
$list = $args[0] #This accepts the argument you add to your scheduled task for the list of servers. i.e. list.txt
$ServicesArg = $args[1] 
$computers = Get-Content $list #grab the names of the servers/computers to check from the list.txt file.
$ServicesCheck = Get-Content $ServicesArg
$thresholdspace = 80 # Set free disk space threshold below in percent (default at 10%)
[int]$EventNumWarn = 20
[int]$EventNumErr = 20
[int]$ProccessNumToFetch = 10
$CustomerName = "Caesar Experts"
$ListOfAttachments = @()
$Report = @()
$CurrentTime = Get-Date
$CurrentDate = Get-Date -Format "dd-MM-yyyy"
#endregion

Function Create-PieChart() {
	param([string]$FileName)
		
	[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
	
	#Create our chart object 
	$Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
	$Chart.Width = 300
	$Chart.Height = 290 
	$Chart.Left = 10
	$Chart.Top = 10

	#Create a chartarea to draw on and add this to the chart 
	$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
	$Chart.ChartAreas.Add($ChartArea) 
	[void]$Chart.Series.Add("Data") 

	#Add a datapoint for each value specified in the arguments (args) 
    foreach ($value in $args[0]) {
		Write-Host "Now processing chart value: " + $value
		$datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $value)
	    $datapoint.AxisLabel = "Value" + "(" + $value + " GB)"
	    $Chart.Series["Data"].Points.Add($datapoint)
	}

	$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
	$Chart.Series["Data"]["PieLabelStyle"] = "Outside" 
	$Chart.Series["Data"]["PieLineColor"] = "Black" 
	$Chart.Series["Data"]["PieDrawingStyle"] = "Concave" 
	($Chart.Series["Data"].Points.FindMaxByValue())["Exploded"] = $true

	#Set the title of the Chart to the current date and time 
	$Title = new-object System.Windows.Forms.DataVisualization.Charting.Title 
	$Chart.Titles.Add($Title) 
	$Chart.Titles[0].Text = "C: Usage Chart (Used/Free)"

	#Save the chart to a file
	$Chart.SaveImage($FileName + ".png","png")
}

Function Get-HostUptime {
	param ([string]$ComputerName)
	$Uptime = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
	$LastBootUpTime = $Uptime.ConvertToDateTime($Uptime.LastBootUpTime)
	$Time = (Get-Date) - $LastBootUpTime
	Return '{0:00} Days, {1:00} Hours, {2:00} Minutes, {3:00} Seconds' -f $Time.Days, $Time.Hours, $Time.Minutes, $Time.Seconds
}

# Assemble the HTML Header and CSS for our Report
$HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>Systems Report for $CustomerName $CurrentDate</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

    #report { width: 835px; }

    table{
	border-collapse: collapse;
	border: none;
	font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
	color: black;
	margin-bottom: 10px;
}

    table td{
	font-size: 12px;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

    table th {
	font-size: 12px;
	font-weight: bold;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

h2{ clear: both; font-size: 130%; }

h3{
	clear: both;
	font-size: 115%;
	margin-left: 20px;
	margin-top: 30px;
}

p{ margin-left: 20px; font-size: 12px; }

table.list{ float: left; }

    table.list td:nth-child(1){
	font-weight: bold;
	border-right: 1px grey solid;
	text-align: right;
}

table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px  grey solid; }
div.second{ margin-left: 30px; }
table{ margin-left: 20px; }
-->
</style>
</head>
<body>

"@

foreach ($computer in $computers) {

    #get disks with less than thresholdspace free
    $DiskInfoLow= Get-WMIObject -ComputerName $computer Win32_LogicalDisk | Where-Object{$_.DriveType -eq 3} | Where-Object{ ($_.freespace/$_.Size)*100 -lt $thresholdspace} `
	| Select-Object SystemName, DriveType, VolumeName, Name, @{n='Size (GB)';e={"{0:n2}" -f ($_.size/1gb)}}, @{n='FreeSpace (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}}, @{n='PercentFree';e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | ConvertTo-HTML -fragment

    #get all other disks
    $DiskInfo= Get-WMIObject -ComputerName $computer Win32_LogicalDisk | Where-Object{$_.DriveType -eq 3} | Where-Object{ ($_.freespace/$_.Size)*100 -gt $thresholdspace} `
	| Select-Object SystemName, DriveType, VolumeName, Name, @{n='Size (GB)';e={"{0:n2}" -f ($_.size/1gb)}}, @{n='FreeSpace (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}}, @{n='PercentFree';e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | ConvertTo-HTML -fragment

	#$DiskInfo= Get-WMIObject -ComputerName $computer Win32_LogicalDisk | Where-Object{$_.DriveType -eq 3}|Select-Object SystemName, DriveType, VolumeName, Name, @{n='Size (GB)';e={"{0:n2}" -f ($_.size/1gb)}}, @{n='FreeSpace (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}}, @{n='PercentFree';e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | ConvertTo-HTML -fragment
	
	#region System Info
	$OS = (Get-WmiObject Win32_OperatingSystem -computername $computer).caption
	$SystemInfo = Get-WmiObject -Class Win32_OperatingSystem -computername $computer | Select-Object Name, TotalVisibleMemorySize, FreePhysicalMemory
	$TotalRAM = $SystemInfo.TotalVisibleMemorySize/1MB
	$FreeRAM = $SystemInfo.FreePhysicalMemory/1MB
	$UsedRAM = $TotalRAM - $FreeRAM
	$RAMPercentFree = ($FreeRAM / $TotalRAM) * 100
	$TotalRAM = [Math]::Round($TotalRAM, 2)
	$FreeRAM = [Math]::Round($FreeRAM, 2)
	$UsedRAM = [Math]::Round($UsedRAM, 2)
	$RAMPercentFree = [Math]::Round($RAMPercentFree, 2)

	$SystemInfo = get-WmiObject win32_logicaldisk -computername $computer -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace
	$TotalSpace = $SystemInfo.Size/1MB
	$FreeSpace = $SystemInfo.FreeSpace/1MB
	$UsedSpace = $TotalSpace - $FreeSpace
	$SpacepercentFree = ($FreeSpace / $TotalSpace) * 100
	$TotalSpace = [Math]::Round($TotalSpace, 2)
	$FreeSpace = [Math]::Round($FreeSpace, 2)
	$UsedSpace = [Math]::Round($UsedSpace, 2)
	$SpacePercentFree = [Math]::Round($SpacePercentFree, 2)
	#endregion
	
	$TopProcesses = Get-Process -ComputerName $computer | Sort WS -Descending | Select ProcessName, WS -First $ProccessNumToFetch | ConvertTo-Html -Fragment
	
	#region Services Report
	$ServicesReport = @()
	$Services = Get-WmiObject -Class Win32_Service -ComputerName $computer | Where {($_.StartMode -eq "Auto") -and ($_.State -eq "Stopped")}

	foreach ($Service in $Services) {
		$row = New-Object -Type PSObject -Property @{
	   		Name = $Service.Name
			Status = $Service.State
			StartMode = $Service.StartMode
		}
		
	$ServicesReport += $row
	
	}
	
	$ServicesReport = $ServicesReport | ConvertTo-Html -Fragment

     $ServicesCheckReport = @()
            foreach ($service in $ServicesCheck){
            Get-WmiObject Win32_Service |Where-Object {$_.name -eq $Service}| 
            ForEach-Object {$row = New-Object -Type PSObject -Property @{
	   		Name = $Service.Name
			State = $Service.State
            Status = $Service.Status
			StartMode = $Service.StartMode
		}
    $ServicesCheckReport += $row
        } }
    $ServicesCheckReport = $ServicesCheckReport | ConvertTo-Html -Fragment
	#endregion
		
	#region Event Logs Report
	$SystemErrEventsReport = @()
	$SystemErrEvents = Get-Eventlog -computername $computer -log system -after ((get-date).addDays(-1)) -EntryType Error
	foreach ($event in $SystemErrEvents) {
		$row = New-Object -Type PSObject -Property @{
			TimeGenerated = $event.TimeGenerated
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
			Message = $event.Message
		}
		$SystemErrEventsReport += $row
	}
			
	$SystemErrEventsReport = $SystemErrEventsReport | ConvertTo-Html -Fragment
	
	$SystemWarnEventsReport = @()
	$SystemWarnEvents = Get-Eventlog -computername $computer -log system -after ((get-date).addDays(-1)) -EntryType Warning
	foreach ($event in $SystemWarnEvents) {
		$row = New-Object -Type PSObject -Property @{
			TimeGenerated = $event.TimeGenerated
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
			Message = $event.Message
		}
		$SystemWarnEventsReport += $row
	}
			
	$SystemWarnEventsReport = $SystemWarnEventsReport | ConvertTo-Html -Fragment

	$ApplicationErrEventsReport = @()
	$ApplicationErrEvents = Get-Eventlog -computername $computer -log application -after ((get-date).addDays(-1)) -EntryType Error
	foreach ($event in $ApplicationErrEvents) {
		$row = New-Object -Type PSObject -Property @{
			TimeGenerated = $event.TimeGenerated
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
			Message = $event.Message
		}
		$ApplicationErrEventsReport += $row
	}
	
	$ApplicationErrEventsReport = $ApplicationErrEventsReport | ConvertTo-Html -Fragment

	$ApplicationWarnEventsReport = @()
	$ApplicationWarnEvents = Get-Eventlog -computername $computer -log application -after ((get-date).addDays(-1)) -EntryType Warning
	foreach ($event in $ApplicationWarnEvents) {
		$row = New-Object -Type PSObject -Property @{
			TimeGenerated = $event.TimeGenerated
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
			Message = $event.Message
		}
		$ApplicationWarnEventsReport += $row
	}
	
	$ApplicationWarnEventsReport = $ApplicationWarnEventsReport | ConvertTo-Html -Fragment
	
    #Generate CSV files of System logs errors and warnings
	$SystemWarnEventsReportCSV = @()
	$SystemWarnEventsCSV = Get-Eventlog -computername $computer -log system -after ((get-date).addDays(-1)) -EntryType Warning
	foreach ($event in $SystemWarnEventsCSV) {
		$row = New-Object -Type PSObject -Property @{
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
            TimeGenerated = $event.TimeGenerated
					}
		$SystemWarnEventsReportCSV += $row
	}

    $SystemWarnEventsReportCSV = $SystemWarnEventsReportCSV | Export-Csv -Path ((Get-Location).Path + "\LogSystemWarn_$computer.csv")
    $ListOfAttachments += "LogSystemWarn_$computer.csv"


	$SystemErrEventsReportCSV = @()
	$SystemErrEventsCSV = Get-Eventlog -computername $computer -log system -after ((get-date).addDays(-1)) -EntryType Error
	foreach ($event in $SystemErrEventsCSV) {
		$row = New-Object -Type PSObject -Property @{
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
            TimeGenerated = $event.TimeGenerated
					}
		$SystemErrEventsReportCSV += $row
	}

    $SystemErrEventsReportCSV = $SystemErrEventsReportCSV | Export-Csv -Path ((Get-Location).Path + "\LogSystemErr_$computer.csv")
    $ListOfAttachments += "LogSystemErr_$computer.csv"
    
    #Generate CSV files of Application logs errors and warnings
    $ApplicationWarnEventsReportCSV = @()
	$ApplicationWarnEventsCSV = Get-Eventlog -computername $computer -log application -after ((get-date).addDays(-1)) -EntryType Warning
	foreach ($event in $ApplicationWarnEventsCSV) {
		$row = New-Object -Type PSObject -Property @{
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
            TimeGenerated = $event.TimeGenerated
					}
		$ApplicationWarnEventsReportCSV += $row
	}

    $ApplicationWarnEventsReportCSV = $ApplicationWarnEventsReportCSV | Export-Csv -Path ((Get-Location).Path + "\LogApplicationWarn_$computer.csv")
    $ListOfAttachments += "LogApplicationWarn_$computer.csv"

	$ApplicationErrEventsReportCSV = @()
	$ApplicationErrEventsCSV = Get-Eventlog -computername $computer -log application -after ((get-date).addDays(-1)) -EntryType Error
	foreach ($event in $ApplicationErrEventsCSV) {
		$row = New-Object -Type PSObject -Property @{
			EntryType = $event.EntryType
			Source = $event.Source
            InstanceID = $event.InstanceId
            TimeGenerated = $event.TimeGenerated
					}
		$ApplicationErrEventsReportCSV += $row
	}

    $ApplicationErrEventsReportCSV = $ApplicationErrEventsReportCSV | Export-Csv -Path ((Get-Location).Path + "\LogApplicationErr_$computer.csv")
    $ListOfAttachments += "LogApplicationErr_$computer.csv"

    #endregion

	
	# Create the chart using our Chart Function
	# Create-PieChart -FileName ((Get-Location).Path + "\chart-$computer") $FreeSpace, $UsedSpace
	# $ListOfAttachments += "chart-$computer.png"
	#region Uptime
	#Fetch the Uptime of the current system using our Get-HostUptime Function.
	$SystemUptime = Get-HostUptime -ComputerName $computer
	#endregion

	# Create HTML Report for the current System being looped through
	$CurrentSystemHTML = @"
	<hr noshade size=3 width="100%">
	<div id="report">
	<p><h2>$computer Report</p></h2>
	<h3>System Info</h3>
	<table class="list">
	<tr>
	<td>System Uptime</td>
	<td>$SystemUptime</td>
	</tr>
	<tr>
	<td>OS</td>
	<td>$OS</td>
	</tr>
	<tr>
	<td>Total RAM (GB)</td>
	<td>$TotalRAM</td>
	</tr>
	<tr>
	<td>Free RAM (GB)</td>
	<td>$FreeRAM</td>
	</tr>
	<tr>
	<td>Percent free RAM</td>
	<td>$RAMPercentFree</td>
	</tr>
	</table>
	
		
	<h3>Disk Info</h3>
	<p style="color:red"> All drives with with less than $thresholdspace % free space</p>
	<table class="normal" style="color:red">$DiskInfoLow</table>
	<br></br></font>
	<p>Other drives</p>
	<table class="normal">$DiskInfo</table>
	<br></br>
	
	<div class="first column">
	<h3>System Processes - Top $ProccessNumToFetch Highest Memory Usage</h3>
	<p>The following $ProccessNumToFetch processes are those consuming the highest amount of Working Set (WS) Memory (bytes) on $computer</p>
	<table class="normal">$TopProcesses</table>
	</div>
	<div class="second column">
	
	<h3>System Services - Automatic Startup but not Running</h3>
	<p>The following services are those which are set to Automatic startup type, yet are currently not running on $computer</p>
	<table class="normal">
	$ServicesCheckReport
	</table>
	</div>
	
	<h3>Events Report - System/Application Log Events that were Errors or Warings in the last 24 hours</h3>
	<p>The following is a list of the <b>System log</b> events that had an Event Type Error on $computer</p>
	<table class="normal">$SystemErrEventsReport</table>
    <p>The following is a list of the <b>System log</b> events that had an Event Type Warning on $computer</p>
	<table class="normal">$SystemWarnEventsReport</table>
	<p>The following is a list of the <b>Application log</b> events that had an Event Type Error on $computer</p>
	<table class="normal">$ApplicationErrEventsReport</table>
    <p>The following is a list of the <b>Application log</b> events that had an Event Type Warning on $computer</p>
	<table class="normal">$ApplicationWarnEventsReport</table>
"@
	# Add the current System HTML Report into the final HTML Report body
	$HTMLMiddle += $CurrentSystemHTML
	
	}

# Assemble the closing HTML for our report.
$HTMLEnd = @"
</div>
</body>
</html>
"@


# Assemble the final report from all our HTML sections
$HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
# Save the report out to a file in the current path
$HTMLmessage | Out-File ((Get-Location).Path + "\report.html")
# Email our report out
# <remove remark to send emails> send-mailmessage -from $fromemail -to $users -subject "Systems Report for $CustomerName $CurrentDate" -Attachments $ListOfAttachments -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer $server
