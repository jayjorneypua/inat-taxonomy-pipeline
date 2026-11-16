using System.Globalization;
using System.Text;

namespace Inat.Api.Infrastructure;

public static class CsvFormat
{
    // one value as a csv field: quoted when it holds a comma, quote or line break, and a leading
    // = + - @ gets a ' in front so excel shows it as text instead of running it as a formula
    public static string Field(object? value)
    {
        if (value is null || value is DBNull)
        {
            return string.Empty;
        }

        string text;
        if (value is DateTime dateTime)
        {
            text = dateTime.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        }
        else
        {
            text = Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
        }

        if (text.Length > 0 && "=+-@".Contains(text[0]))
        {
            text = "'" + text;
        }

        bool needsQuotes = text.Contains(',') || text.Contains('"') || text.Contains('\n') || text.Contains('\r');
        if (needsQuotes == false)
        {
            return text;
        }

        StringBuilder quoted = new StringBuilder(text.Length + 2);
        quoted.Append('"');
        quoted.Append(text.Replace("\"", "\"\""));
        quoted.Append('"');
        return quoted.ToString();
    }

    public static string Line(IReadOnlyList<object?> values)
    {
        List<string> fields = new List<string>(values.Count);
        foreach (object? value in values)
        {
            fields.Add(Field(value));
        }

        return string.Join(',', fields);
    }
}