# TOOL_NAME: System Info
# TOOL_DESC: Display key system information including CPU, RAM, OS, and uptime
# TOOL_ICON: 💻
# TOOL_CATEGORY: System
# TOOL_TYPE: gui

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="System Info"
    Width="480"
    Height="420"
    ResizeMode="CanMinimize"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI"
    FontSize="13">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0"
                   Text="System Information"
                   FontSize="20"
                   FontWeight="SemiBold"
                   Margin="0,0,0,14"/>

        <Border Grid.Row="1"
                Background="#F7F7F7"
                BorderBrush="#CCCCCC"
                BorderThickness="1"
                CornerRadius="4"
                Padding="14,10">
            <Grid x:Name="InfoGrid">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="160"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Row 0: Hostname -->
                <TextBlock Grid.Row="0" Grid.Column="0"
                           Text="Hostname" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="0" Grid.Column="1"
                           x:Name="ValHostname" Text="..."
                           Margin="0,4" TextWrapping="Wrap"/>

                <!-- Row 1: OS -->
                <TextBlock Grid.Row="1" Grid.Column="0"
                           Text="Operating System" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="1"
                           x:Name="ValOS" Text="..."
                           Margin="0,4" TextWrapping="Wrap"/>

                <!-- Row 2: OS Version -->
                <TextBlock Grid.Row="2" Grid.Column="0"
                           Text="OS Version" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="2" Grid.Column="1"
                           x:Name="ValOSVersion" Text="..."
                           Margin="0,4"/>

                <!-- Row 3: CPU -->
                <TextBlock Grid.Row="3" Grid.Column="0"
                           Text="Processor" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="3" Grid.Column="1"
                           x:Name="ValCPU" Text="..."
                           Margin="0,4" TextWrapping="Wrap"/>

                <!-- Row 4: Logical Cores -->
                <TextBlock Grid.Row="4" Grid.Column="0"
                           Text="Logical Cores" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="4" Grid.Column="1"
                           x:Name="ValCores" Text="..."
                           Margin="0,4"/>

                <!-- Row 5: RAM -->
                <TextBlock Grid.Row="5" Grid.Column="0"
                           Text="Total RAM" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="5" Grid.Column="1"
                           x:Name="ValRAM" Text="..."
                           Margin="0,4"/>

                <!-- Row 6: Uptime -->
                <TextBlock Grid.Row="6" Grid.Column="0"
                           Text="System Uptime" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="6" Grid.Column="1"
                           x:Name="ValUptime" Text="..."
                           Margin="0,4"/>

                <!-- Row 7: PowerShell -->
                <TextBlock Grid.Row="7" Grid.Column="0"
                           Text="PowerShell" FontWeight="SemiBold"
                           Foreground="#444444" Margin="0,4"/>
                <TextBlock Grid.Row="7" Grid.Column="1"
                           x:Name="ValPS" Text="..."
                           Margin="0,4"/>
            </Grid>
        </Border>

        <Button Grid.Row="2"
                x:Name="RefreshButton"
                Content="Refresh"
                HorizontalAlignment="Right"
                Padding="20,7"
                Margin="0,12,0,0"
                Background="#0078D4"
                Foreground="White"
                BorderThickness="0"
                Cursor="Hand"/>
    </Grid>
</Window>
'@

$window        = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))
$valHostname   = $window.FindName('ValHostname')
$valOS         = $window.FindName('ValOS')
$valOSVersion  = $window.FindName('ValOSVersion')
$valCPU        = $window.FindName('ValCPU')
$valCores      = $window.FindName('ValCores')
$valRAM        = $window.FindName('ValRAM')
$valUptime     = $window.FindName('ValUptime')
$valPS         = $window.FindName('ValPS')
$refreshButton = $window.FindName('RefreshButton')

function Update-SystemInfo {
    try {
        $os  = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cpu = Get-CimInstance -ClassName Win32_Processor       -ErrorAction Stop |
               Select-Object -First 1

        $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $bootTime   = $os.LastBootUpTime
        $uptime     = (Get-Date) - $bootTime
        $uptimeStr  = '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes

        $valHostname.Text  = $env:COMPUTERNAME
        $valOS.Text        = $os.Caption
        $valOSVersion.Text = $os.Version
        $valCPU.Text       = $cpu.Name.Trim()
        $valCores.Text     = "$($cpu.NumberOfLogicalProcessors) logical / $($cpu.NumberOfCores) physical"
        $valRAM.Text       = "$totalRamGB GB"
        $valUptime.Text    = $uptimeStr
        $valPS.Text        = "PowerShell $($PSVersionTable.PSVersion)"
    }
    catch {
        $valOS.Text = "Error retrieving data: $($_.Exception.Message)"
    }
}

$refreshButton.Add_Click({ Update-SystemInfo })

$window.Add_Loaded({ Update-SystemInfo })

$window.ShowDialog() | Out-Null
