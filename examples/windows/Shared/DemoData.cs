using System;
using System.Collections.Generic;
using System.Linq;
using Superroute.SMap;

namespace Superroute.SMap.Examples;

/// <summary>The demo's data and options, shared by the WPF and WinForms examples.</summary>
internal static class DemoData
{
    internal static readonly SMapLatLng Toronto = new(43.6532, -79.3832);
    internal static readonly string[] Languages = { "en", "fr", "de", "es", "zh-Hans" };

    /// <summary>Set SMAP_TOKEN or SMAP_API_KEY (and optionally SMAP_BASE_URL) to use your own access.</summary>
    internal static SMapOptions Options()
    {
        var o = new SMapOptions { Style = SMapStyle.Light, Language = "en", Center = Toronto, Zoom = 11 };
        if (Uri.TryCreate(Environment.GetEnvironmentVariable("SMAP_BASE_URL"), UriKind.Absolute, out var baseUrl)) o.BaseUrl = baseUrl;
        var token = Environment.GetEnvironmentVariable("SMAP_TOKEN");
        if (!string.IsNullOrEmpty(token)) o.Token = token;
        var key = Environment.GetEnvironmentVariable("SMAP_API_KEY");
        if (!string.IsNullOrEmpty(key)) o.ApiKey = key;
        return o;
    }

    /// <summary>2,000 points around Toronto, the same on every run.</summary>
    internal static IEnumerable<SMapPoint> Stops()
    {
        var random = new Random(42);
        return Enumerable.Range(1, 2000).Select(i => new SMapPoint(
            Toronto.Lat + (random.NextDouble() * 0.24 - 0.12),
            Toronto.Lng + (random.NextDouble() * 0.4 - 0.2))
        {
            Properties = new Dictionary<string, object?> { ["name"] = "Stop " + i },
        }).ToList();
    }

    internal static SMapLine Route() => new(new[]
    {
        new SMapLatLng(43.6426, -79.3871), new SMapLatLng(43.6515, -79.3800),
        new SMapLatLng(43.6629, -79.3957), new SMapLatLng(43.6677, -79.3948),
    });

    internal static SMapPolygon Block() => new(new[]
    {
        new SMapLatLng(43.6440, -79.3800), new SMapLatLng(43.6440, -79.3760),
        new SMapLatLng(43.6465, -79.3760), new SMapLatLng(43.6465, -79.3800),
    })
    {
        Properties = new Dictionary<string, object?> { ["height"] = 180 },
    };

    /// <summary>Adds the demo layers through the given calls (the controls of both toolkits have the same API).</summary>
    internal static void AddLayers(Action<string, SMapPolygon, SMapPolygonOptions> polygons, Action<string, SMapLine, SMapLineOptions> lines,
                                   Action<string, IEnumerable<SMapPoint>, SMapPointOptions> points)
    {
        polygons("block", Block(), new SMapPolygonOptions { Fill = "#f97316", Extrude = new SMapExtrude { Height = "height" } });
        lines("route", Route(), new SMapLineOptions { Color = "#16a34a", Width = 5, ZIndex = 1 });
        points("stops", Stops(), new SMapPointOptions { Cluster = new SMapCluster(), ZIndex = 2 });
    }
}
