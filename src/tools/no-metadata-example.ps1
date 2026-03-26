Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="No Metadata Example"
    Width="360"
    Height="160"
    ResizeMode="CanMinimize"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI"
    FontSize="13">
    <Grid>
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <TextBlock Text="This tool has no metadata"
                       FontSize="16"
                       FontWeight="SemiBold"
                       HorizontalAlignment="Center"
                       Margin="0,0,0,12"/>
            <Button x:Name="OkButton"
                    Content="OK"
                    Width="80"
                    Padding="0,6"
                    HorizontalAlignment="Center"
                    Background="#0078D4"
                    Foreground="White"
                    BorderThickness="0"
                    Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
'@

$window   = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))
$okButton = $window.FindName('OkButton')

$okButton.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null
