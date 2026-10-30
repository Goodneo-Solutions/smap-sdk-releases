using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using Superroute.SMap.WinForms;

namespace Superroute.SMap.Examples.WinForms;

/// <summary>
/// One window: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area and a 3D
/// buildings toggle. Set SMAP_TOKEN or SMAP_API_KEY (and optionally SMAP_BASE_URL) to use your own access.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new DemoForm());
    }
}

internal sealed class DemoForm : Form
{
    private readonly SMapView map = new(DemoData.Options()) { Dock = DockStyle.Fill };
    private readonly Label status = new() { AutoSize = true, Padding = new Padding(12, 6, 0, 0) };

    internal DemoForm()
    {
        Text = "sMap WinForms Example";
        ClientSize = new Size(1100, 760);

        var styles = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 120 };
        styles.Items.AddRange(SMapStyles.All.Select(s => (object)s.Name()).ToArray());
        styles.SelectedIndex = 0;
        styles.SelectedIndexChanged += (_, _) => map.SetStyle(SMapStyles.Parse((string)styles.SelectedItem!) ?? SMapStyle.Light);
        var languages = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 100 };
        languages.Items.AddRange(DemoData.Languages.Cast<object>().ToArray());
        languages.SelectedIndex = 0;
        languages.SelectedIndexChanged += (_, _) => map.SetLanguage((string)languages.SelectedItem!);
        var buildings = new CheckBox { Text = "3D buildings", AutoSize = true, Padding = new Padding(8, 3, 0, 0) };
        buildings.CheckedChanged += (_, _) => map.SetBuildings3D(buildings.Checked);
        var fit = new Button { Text = "Show the route", AutoSize = true };
        fit.Click += (_, _) => map.FitLayer("route");

        var bar = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(8), Enabled = false };
        bar.Controls.AddRange(new Control[] { styles, languages, buildings, fit, status });
        Controls.Add(map);
        Controls.Add(bar);

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
        // 1.5.0: circles in metres with a hover look, a double click that does not zoom, and a search over the app's own places.
        map.AddCircles("reach", DemoData.Depots(), DemoData.Reach());
        map.On(SMapEventType.DoubleClick, e => status.Text = $"Double click at {e.Position?.Lat:F5}, {e.Position?.Lng:F5}", preventDefault: true);
        map.On(SMapEventType.Unavailable, e => status.Text = "The map cannot be shown: " + e.Reason);
        map.AddTool("search", new SMapSearchOptions(DemoData.Search) { MinChars = 2, OnPick = r => status.Text = r.Label });
        map.ToolsChanged += (_, e) => status.Text = "Hidden tools: " + string.Join(", ", e.Hidden);
        map.Ready += (_, _) => bar.Enabled = true;
        map.Error += (_, e) => status.Text = e.Exception.Message;
    }
}
