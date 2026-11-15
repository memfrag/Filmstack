//
//  Filmstack
//

import SwiftUI

/// A compact row of white provider icons (where a movie can be streamed or
/// rented) for the picker's header. Only brands with a bundled icon are shown.
struct ProviderIconRow: View {

    let providers: [WatchProvider]

    /// Every icon is fitted inside a square of this size.
    private let iconSide: CGFloat = 16

    /// The brands to show, each once. Streaming first, then rentals.
    private var brands: [(brand: ProviderBrand, access: WatchProvider.Access)] {
        var seen = Set<ProviderBrand>()
        return (providers.filter { $0.access == .stream } + providers.filter { $0.access == .rent })
            .compactMap { provider in ProviderBrand(providerName: provider.name).map { ($0, provider.access) } }
            .filter { seen.insert($0.brand).inserted }
    }

    var body: some View {
        let brands = brands
        if !brands.isEmpty {
            HStack(spacing: 12) {
                ForEach(brands, id: \.brand) { item in
                    Image(item.brand.assetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .frame(width: iconSide, height: iconSide)
                        .opacity(0.92)
                        .accessibilityLabel("\(item.access.title) on \(item.brand.displayName)")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// The streaming brands shown in the picker header, each with a bundled white
/// template icon (`provider-<rawValue>` in Assets.xcassets/Providers). TMDB
/// names vary by region and tier, so several names map to one brand; any other
/// provider is left out.
enum ProviderBrand: String, CaseIterable, Hashable {
    case netflix, disney, max, appletv, prime, youtube, viaplay

    init?(providerName: String) {
        let name = providerName.lowercased()
        if name.hasPrefix("netflix") {
            self = .netflix
        } else if name.hasPrefix("disney") {
            self = .disney
        } else if name == "max" || name.hasPrefix("hbo") || name.hasPrefix("max ") {
            self = .max
        } else if name.hasPrefix("apple tv") {
            self = .appletv
        } else if name.hasPrefix("amazon prime") || name == "amazon video" || name.hasPrefix("prime video") {
            self = .prime
        } else if name.hasPrefix("youtube") {
            self = .youtube
        } else if name.hasPrefix("viaplay") {
            self = .viaplay
        } else {
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .netflix: "Netflix"
        case .disney: "Disney+"
        case .max: "HBO Max"
        case .appletv: "Apple TV"
        case .prime: "Prime Video"
        case .youtube: "YouTube"
        case .viaplay: "Viaplay"
        }
    }

    var assetName: String { "provider-\(rawValue)" }
}
