# TOOL_NAME: DNS Lookup
# TOOL_DESC: Resolve hostnames and domain names to IP addresses using DNS
# TOOL_ICON: 🔍
# TOOL_CATEGORY: Network
# TOOL_TYPE: gui

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="DNS Lookup"
    Width="520"
    Height="400"
    ResizeMode="CanResize"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI"
    FontSize="13">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0"
                   Text="DNS Lookup"
                   FontSize="20"
                   FontWeight="SemiBold"
                   Margin="0,0,0,12"/>

        <Grid Grid.Row="1" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name="HostnameInput"
                     Grid.Column="0"
                     Padding="8,6"
                     VerticalContentAlignment="Center"
                     Margin="0,0,8,0"
                     BorderBrush="#AAAAAA"
                     Text="example.com"/>
            <Button x:Name="ResolveButton"
                    Grid.Column="1"
                    Content="Resolve"
                    Padding="16,6"
                    Background="#0078D4"
                    Foreground="White"
                    BorderThickness="0"
                    Cursor="Hand"/>
        </Grid>

        <TextBox x:Name="ResultsBox"
                 Grid.Row="2"
                 IsReadOnly="True"
                 TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto"
                 FontFamily="Consolas"
                 FontSize="12"
                 Padding="10"
                 Background="#F7F7F7"
                 BorderBrush="#CCCCCC"
                 AcceptsReturn="True"
                 Text="Enter a hostname above and click Resolve."/>

        <TextBlock Grid.Row="3"
                   x:Name="StatusBar"
                   Text="Ready"
                   Foreground="#666666"
                   FontSize="11"
                   Margin="0,6,0,0"/>
    </Grid>
</Window>
'@

$window       = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))
$hostnameInput = $window.FindName('HostnameInput')
$resolveButton = $window.FindName('ResolveButton')
$resultsBox    = $window.FindName('ResultsBox')
$statusBar     = $window.FindName('StatusBar')

function Invoke-DnsLookup {
    $hostname = $hostnameInput.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($hostname)) {
        $resultsBox.Text = 'Please enter a hostname or IP address.'
        $statusBar.Text  = 'No input provided.'
        return
    }

    $resolveButton.IsEnabled = $false
    $statusBar.Text          = "Resolving $hostname ..."
    $resultsBox.Text         = ''

    try {
        $records = Resolve-DnsName -Name $hostname -ErrorAction Stop

        $sb = [System.Text.StringBuilder]::new()
        $null = $sb.AppendLine("Results for: $hostname")
        $null = $sb.AppendLine(('-' * 48))

        foreach ($record in $records) {
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("  Name    : $($record.Name)")
            $null = $sb.AppendLine("  Type    : $($record.Type)")
            $null = $sb.AppendLine("  TTL     : $($record.TTL) seconds")

            switch ($record.Type) {
                'A'     { $null = $sb.AppendLine("  Address : $($record.IPAddress)") }
                'AAAA'  { $null = $sb.AppendLine("  Address : $($record.IPAddress)") }
                'CNAME' { $null = $sb.AppendLine("  Target  : $($record.NameHost)") }
                'MX'    {
                    $null = $sb.AppendLine("  Exchange: $($record.NameExchange)")
                    $null = $sb.AppendLine("  Priority: $($record.Preference)")
                }
                'TXT'   { $null = $sb.AppendLine("  Strings : $($record.Strings -join ' ')") }
                'NS'    { $null = $sb.AppendLine("  Server  : $($record.NameHost)") }
                'SOA'   {
                    $null = $sb.AppendLine("  Primary : $($record.PrimaryServer)")
                    $null = $sb.AppendLine("  Admin   : $($record.Administrator)")
                }
                default {
                    # Surface any remaining notable properties
                    $extra = $record | Select-Object -ExcludeProperty Name, Type, TTL, Section |
                                       Format-List | Out-String
                    $null = $sb.Append($extra.Trim())
                }
            }
        }

        $resultsBox.Text = $sb.ToString()
        $statusBar.Text  = "Resolved $($records.Count) record(s) for $hostname."
    }
    catch {
        $resultsBox.Text = "Error resolving '$hostname':`n`n$($_.Exception.Message)"
        $statusBar.Text  = "Resolution failed."
    }
    finally {
        $resolveButton.IsEnabled = $true
    }
}

$resolveButton.Add_Click({ Invoke-DnsLookup })

$hostnameInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq 'Return') { Invoke-DnsLookup }
})

$window.ShowDialog() | Out-Null
