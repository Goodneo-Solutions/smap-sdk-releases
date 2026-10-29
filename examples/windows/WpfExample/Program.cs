using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using Superroute.SMap.Wpf;

namespace Superroute.SMap.Examples.Wpf;

/// <summary>
/// One window: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area and a 3D
/// buildings toggle. Set SMAP_TOKEN or SMAP_API_KEY (and optionally SMAP_BASE_URL) to use your own access.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main()
    {
        var app = new Application();
        app.Run(new DemoWindow());
    }
}

internal sealed class DemoWindow : Window
{
    private readonly SMapView map = new(DemoData.Options());
    private readonly TextBlock status = new() { Margin = new Thickness(12, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };

    internal DemoWindow()
    {
        Title = "sMap WPF Example";
        Width = 1100;
        Height = 760;

        var styles = new ComboBox { ItemsSource = SMapStyles.All.Select(s => s.Name()).ToList(), SelectedIndex = 0, Width = 120 };
        styles.SelectionChanged += (_, _) => map.SetStyle(SMapStyles.Parse((string)styles.SelectedItem) ?? SMapStyle.Light);
        var languages = new ComboBox { ItemsSource = DemoData.Languages, SelectedIndex = 0, Width = 100, Margin = new Thickness(8, 0, 0, 0) };
        languages.SelectionChanged += (_, _) => map.SetLanguage((string)languages.SelectedItem);
        var buildings = new CheckBox { Content = "3D buildings", Margin = new Thickness(12, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };
        buildings.Checked += (_, _) => map.SetBuildings3D(true);
        buildings.Unchecked += (_, _) => map.SetBuildings3D(false);
        var fit = new Button { Content = "Show the route", Margin = new Thickness(12, 0, 0, 0), Padding = new Thickness(8, 2, 8, 2) };
        fit.Click += (_, _) => map.FitLayer("route");

        var bar = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(10) };
        foreach (var c in new UIElement[] { styles, languages, buildings, fit, status }) bar.Children.Add(c);
        bar.IsEnabled = false;

        var root = new DockPanel();
        DockPanel.SetDock(bar, Dock.Top);
        root.Children.Add(bar);
        root.Children.Add(map);
        Content = root;

        // Layers can be added before the map is ready; they are drawn once it is.
        DemoData.AddLayers(
            (id, p, o) => map.AddPolygons(id, new[] { p }, o),
            (id, l, o) => map.AddLines(id, new[] { l }, o),
            (id, pts, o) => map.AddPoints(id, pts, o));
        map.OnTap("stops", (properties, at) => status.Text = $"{properties["name"]} ({at.Lat:F5}, {at.Lng:F5})");
        map.OnTap("block", (properties, _) => status.Text = $"Block, {properties["height"]} m");
        // Map tools: zoom, compass and a scale bar on the map, shown and hidden from its tools control.
        map.AddTool("zoom", SMapToolKind.Zoom);
        map.AddTool("compass", SMapToolKind.Compass);
        map.AddTool("scale", SMapToolKind.Scale);
        map.ToolsChanged += (_, e) => status.Text = "Hidden tools: " + string.Join(", ", e.Hidden);
        map.Ready += (_, _) => bar.IsEnabled = true;
        map.Error += (_, e) => status.Text = e.Exception.Message;
        Closed += (_, _) => map.Dispose();
    }
}
