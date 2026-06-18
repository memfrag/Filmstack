//
//  Filmstack
//

import Foundation

/// Parses a Letterboxd diary RSS feed into watched-film entries.
///
/// Letterboxd publishes a public RSS feed per user at `letterboxd.com/<user>/rss/`.
/// Diary watch items carry custom `letterboxd:` and `tmdb:` elements we read here.
final class LetterboxdRSSParser: NSObject, XMLParserDelegate {

    static func parse(_ data: Data) -> [LetterboxdEntry] {
        let parser = LetterboxdRSSParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.entries
    }

    private var entries: [LetterboxdEntry] = []
    private var fields: [String: String] = [:]
    private var buffer = ""
    private var inItem = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        buffer = ""
        if elementName == "item" {
            inItem = true
            fields = [:]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            buffer += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            inItem = false
            if let entry = makeEntry(fields) {
                entries.append(entry)
            }
        } else if inItem {
            fields[elementName] = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        buffer = ""
    }

    // MARK: - Mapping

    private func makeEntry(_ fields: [String: String]) -> LetterboxdEntry? {
        // Only diary "watched" items have a watched date.
        guard let watchedString = fields["letterboxd:watchedDate"], !watchedString.isEmpty else {
            return nil
        }

        let title = fields["letterboxd:filmTitle"]
            ?? fields["title"]
            ?? "Untitled"
        let id = fields["guid"] ?? fields["link"] ?? title

        return LetterboxdEntry(
            id: id,
            tmdbID: fields["tmdb:movieId"].flatMap { Int($0) },
            title: title,
            year: fields["letterboxd:filmYear"].flatMap { Int($0) },
            watchedDate: Self.parseDate(watchedString),
            rating: fields["letterboxd:memberRating"].flatMap { Double($0) },
            rewatch: fields["letterboxd:rewatch"]?.lowercased() == "yes",
            posterURL: Self.posterURL(fromDescription: fields["description"]),
            link: fields["link"].flatMap { URL(string: $0) }
        )
    }

    /// Extracts the first `<img src="…">` URL from the item description HTML.
    private static func posterURL(fromDescription description: String?) -> URL? {
        guard let description,
              let range = description.range(of: #"src="([^"]+)""#, options: .regularExpression)
        else { return nil }
        let match = description[range]
        let urlString = match
            .replacingOccurrences(of: "src=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
        return URL(string: urlString)
    }

    private static func parseDate(_ string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar.date(from: components)
    }
}
