# TOOL_NAME: Color Picker
# TOOL_DESC: Pick a color using RGB sliders and copy the hex code to the clipboard
# TOOL_ICON: 🎨
# TOOL_CATEGORY: Utilities
# TOOL_TYPE: gui

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Color Picker"
    Width="420"
    Height="440"
    ResizeMode="CanMinimize"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI"
    FontSize="13">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="160"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Title -->
        <TextBlock Grid.Row="0"
                   Text="Color Picker"
                   FontSize="20"
                   FontWeight="SemiBold"
                   Margin="0,0,0,12"/>

        <!-- Color Preview -->
        <Border Grid.Row="1"
                x:Name="ColorPreview"
                Background="#FF0000"
                CornerRadius="6"
                Margin="0,0,0,14"/>

        <!-- Hex Display -->
        <StackPanel Grid.Row="2"
                    Orientation="Horizontal"
                    HorizontalAlignment="Center"
                    Margin="0,0,0,16">
            <TextBlock Text="Hex:"
                       VerticalAlignment="Center"
                       FontWeight="SemiBold"
                       Margin="0,0,8,0"/>
            <TextBlock x:Name="HexLabel"
                       Text="#FF0000"
                       FontFamily="Consolas"
                       FontSize="18"
                       FontWeight="Bold"
                       Foreground="#333333"
                       VerticalAlignment="Center"/>
        </StackPanel>

        <!-- R Slider -->
        <Grid Grid.Row="3" Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="20"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="44"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="R"
                       FontWeight="Bold" Foreground="#CC2200"
                       VerticalAlignment="Center"/>
            <Slider Grid.Column="1"
                    x:Name="SliderR"
                    Minimum="0" Maximum="255" Value="255"
                    TickFrequency="1" IsSnapToTickEnabled="True"
                    Margin="6,0"/>
            <TextBlock Grid.Column="2"
                       x:Name="LabelR"
                       Text="255"
                       FontFamily="Consolas"
                       TextAlignment="Right"
                       VerticalAlignment="Center"/>
        </Grid>

        <!-- G Slider -->
        <Grid Grid.Row="4" Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="20"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="44"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="G"
                       FontWeight="Bold" Foreground="#007700"
                       VerticalAlignment="Center"/>
            <Slider Grid.Column="1"
                    x:Name="SliderG"
                    Minimum="0" Maximum="255" Value="0"
                    TickFrequency="1" IsSnapToTickEnabled="True"
                    Margin="6,0"/>
            <TextBlock Grid.Column="2"
                       x:Name="LabelG"
                       Text="0"
                       FontFamily="Consolas"
                       TextAlignment="Right"
                       VerticalAlignment="Center"/>
        </Grid>

        <!-- B Slider -->
        <Grid Grid.Row="5" Margin="0,0,0,14">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="20"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="44"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="B"
                       FontWeight="Bold" Foreground="#0000CC"
                       VerticalAlignment="Center"/>
            <Slider Grid.Column="1"
                    x:Name="SliderB"
                    Minimum="0" Maximum="255" Value="0"
                    TickFrequency="1" IsSnapToTickEnabled="True"
                    Margin="6,0"/>
            <TextBlock Grid.Column="2"
                       x:Name="LabelB"
                       Text="0"
                       FontFamily="Consolas"
                       TextAlignment="Right"
                       VerticalAlignment="Center"/>
        </Grid>

        <!-- Copy Button -->
        <Button Grid.Row="6"
                x:Name="CopyButton"
                Content="Copy Hex to Clipboard"
                HorizontalAlignment="Stretch"
                Padding="0,8"
                Background="#0078D4"
                Foreground="White"
                BorderThickness="0"
                FontSize="13"
                Cursor="Hand"/>
    </Grid>
</Window>
'@

$window       = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))
$colorPreview = $window.FindName('ColorPreview')
$hexLabel     = $window.FindName('HexLabel')
$sliderR      = $window.FindName('SliderR')
$sliderG      = $window.FindName('SliderG')
$sliderB      = $window.FindName('SliderB')
$labelR       = $window.FindName('LabelR')
$labelG       = $window.FindName('LabelG')
$labelB       = $window.FindName('LabelB')
$copyButton   = $window.FindName('CopyButton')

function Update-Color {
    $r = [int]$sliderR.Value
    $g = [int]$sliderG.Value
    $b = [int]$sliderB.Value

    $labelR.Text = $r.ToString()
    $labelG.Text = $g.ToString()
    $labelB.Text = $b.ToString()

    $hex = '#{0:X2}{1:X2}{2:X2}' -f $r, $g, $b
    $hexLabel.Text = $hex

    $brush = [System.Windows.Media.SolidColorBrush]::new(
        [System.Windows.Media.Color]::FromRgb($r, $g, $b)
    )
    $colorPreview.Background = $brush
}

$sliderR.Add_ValueChanged({ Update-Color })
$sliderG.Add_ValueChanged({ Update-Color })
$sliderB.Add_ValueChanged({ Update-Color })

$copyButton.Add_Click({
    [System.Windows.Clipboard]::SetText($hexLabel.Text)
    $copyButton.Content = 'Copied!'
    $window.Dispatcher.InvokeAsync({
        Start-Sleep -Milliseconds 1500
        $copyButton.Content = 'Copy Hex to Clipboard'
    }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
})

$window.ShowDialog() | Out-Null
