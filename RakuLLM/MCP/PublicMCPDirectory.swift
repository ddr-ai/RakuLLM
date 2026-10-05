import Foundation

public enum ToolCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case search = "Search & Knowledge"
    case developer = "Developer Tools"
    case data = "Data & Databases"
    case productivity = "Productivity"
    case utilities = "Utilities"
    case science = "Math & Science"
    case finance = "Finance & Currency"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .search: return "magnifyingglass"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .data: return "cylinder.split.1x2"
        case .productivity: return "checklist"
        case .utilities: return "wrench.and.screwdriver"
        case .science: return "atom"
        case .finance: return "dollarsign.circle"
        }
    }
}

public struct DirectoryToolItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: ToolCategory
    public let description: String
    public let icon: String
    public let defaultURL: String
    public let requiresAuth: Bool
    public let isPopular: Bool

    public init(
        id: String,
        name: String,
        category: ToolCategory,
        description: String,
        icon: String,
        defaultURL: String,
        requiresAuth: Bool = false,
        isPopular: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.icon = icon
        self.defaultURL = defaultURL
        self.requiresAuth = requiresAuth
        self.isPopular = isPopular
    }
}

public final class PublicMCPDirectory {
    public static let shared = PublicMCPDirectory()

    public let items: [DirectoryToolItem]

    public init() {
        var catalog: [DirectoryToolItem] = []

        // MARK: - Search & Knowledge
        catalog.append(DirectoryToolItem(
            id: "duckduckgo",
            name: "DuckDuckGo Web",
            category: .search,
            description: "Instant web search, facts, definitions, and snippets without user tracking.",
            icon: "magnifyingglass",
            defaultURL: "https://mcp.ddr-ai.io/duckduckgo",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "wikipedia",
            name: "Wikipedia Knowledge",
            category: .search,
            description: "Search millions of encyclopedic articles, summaries, and references across languages.",
            icon: "book.fill",
            defaultURL: "https://mcp.ddr-ai.io/wikipedia",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "hackernews",
            name: "Hacker News Live",
            category: .search,
            description: "Top stories, comments, tech discussions, and Show HN projects.",
            icon: "newspaper.fill",
            defaultURL: "https://mcp.ddr-ai.io/hackernews",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "arxiv",
            name: "ArXiv Research",
            category: .search,
            description: "Search open-access scientific preprints in AI, physics, math, and biology.",
            icon: "doc.text.magnifyingglass",
            defaultURL: "https://mcp.ddr-ai.io/arxiv"
        ))
        catalog.append(DirectoryToolItem(
            id: "openmeteo",
            name: "Open-Meteo Weather",
            category: .search,
            description: "Real-time weather forecasts, hourly temperatures, and air quality index globally.",
            icon: "cloud.sun.fill",
            defaultURL: "https://mcp.ddr-ai.io/weather",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "pubmed",
            name: "PubMed Biomedical",
            category: .search,
            description: "Biomedical literature, clinical studies, and life sciences abstracts from MEDLINE.",
            icon: "cross.case.fill",
            defaultURL: "https://mcp.ddr-ai.io/pubmed"
        ))
        catalog.append(DirectoryToolItem(
            id: "nasa-apod",
            name: "NASA Astronomy",
            category: .search,
            description: "Astronomy picture of the day, Mars rover photos, and planetary telemetry.",
            icon: "moon.stars.fill",
            defaultURL: "https://mcp.ddr-ai.io/nasa"
        ))
        catalog.append(DirectoryToolItem(
            id: "wikidata",
            name: "Wikidata Graph",
            category: .search,
            description: "Query structured entity knowledge graphs and linked semantic open data.",
            icon: "network",
            defaultURL: "https://mcp.ddr-ai.io/wikidata"
        ))
        catalog.append(DirectoryToolItem(
            id: "wiktionary",
            name: "Wiktionary Dictionary",
            category: .search,
            description: "Word definitions, etymologies, pronunciations, and multilingual translations.",
            icon: "character.book.closed.fill",
            defaultURL: "https://mcp.ddr-ai.io/wiktionary"
        ))
        catalog.append(DirectoryToolItem(
            id: "openalex",
            name: "OpenAlex Papers",
            category: .search,
            description: "Global index of 250M+ scholarly works, citations, authors, and institutions.",
            icon: "graduationcap.fill",
            defaultURL: "https://mcp.ddr-ai.io/openalex"
        ))
        catalog.append(DirectoryToolItem(
            id: "usgs-earthquake",
            name: "USGS Earthquakes",
            category: .search,
            description: "Live real-time seismic event tracking and earthquake magnitude feeds.",
            icon: "waveform.path.ecg",
            defaultURL: "https://mcp.ddr-ai.io/earthquakes"
        ))
        catalog.append(DirectoryToolItem(
            id: "worldbank",
            name: "World Bank Data",
            category: .search,
            description: "Global economic indicators, GDP, population, and development statistics.",
            icon: "chart.bar.xaxis",
            defaultURL: "https://mcp.ddr-ai.io/worldbank"
        ))
        catalog.append(DirectoryToolItem(
            id: "spaceflight-news",
            name: "Spaceflight News",
            category: .search,
            description: "Space exploration articles, launch manifest reports, and aerospace news.",
            icon: "airplane.departure",
            defaultURL: "https://mcp.ddr-ai.io/spaceflight"
        ))
        catalog.append(DirectoryToolItem(
            id: "iss-tracker",
            name: "ISS Orbit Tracker",
            category: .search,
            description: "Live coordinates and ground telemetry for the International Space Station.",
            icon: "antenna.radiowaves.left.and.right",
            defaultURL: "https://mcp.ddr-ai.io/iss"
        ))
        catalog.append(DirectoryToolItem(
            id: "open-library",
            name: "Open Library Books",
            category: .search,
            description: "Search 30M+ book titles, authors, editions, ISBNs, and library subjects.",
            icon: "books.vertical.fill",
            defaultURL: "https://mcp.ddr-ai.io/books"
        ))
        catalog.append(DirectoryToolItem(
            id: "crossref",
            name: "CrossRef Metadata",
            category: .search,
            description: "Search scholarly publication DOIs, journal citation graphs, and preprints.",
            icon: "link.circle.fill",
            defaultURL: "https://mcp.ddr-ai.io/crossref"
        ))

        // MARK: - Developer Tools
        catalog.append(DirectoryToolItem(
            id: "github",
            name: "GitHub API",
            category: .developer,
            description: "Explore repositories, issues, pull requests, releases, and git commits.",
            icon: "terminal.fill",
            defaultURL: "https://mcp.ddr-ai.io/github",
            requiresAuth: true,
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "json-formatter",
            name: "JSON Formatter",
            category: .developer,
            description: "Beautify, minify, validate, and convert JSON schemas and payloads.",
            icon: "curlybraces",
            defaultURL: "https://mcp.ddr-ai.io/json-tools",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "regex-tester",
            name: "Regex Inspector",
            category: .developer,
            description: "Test regular expressions, explain match capture groups, and generate patterns.",
            icon: "asterisk",
            defaultURL: "https://mcp.ddr-ai.io/regex"
        ))
        catalog.append(DirectoryToolItem(
            id: "base64-crypto",
            name: "Crypto & Hash",
            category: .developer,
            description: "Generate SHA-256, HMAC, MD5 hashes, and Base64/Hex encoding utilities.",
            icon: "lock.shield.fill",
            defaultURL: "https://mcp.ddr-ai.io/crypto"
        ))
        catalog.append(DirectoryToolItem(
            id: "jwt-decoder",
            name: "JWT Token Inspector",
            category: .developer,
            description: "Parse and verify JWT headers, claims, expiration timestamps, and algorithms.",
            icon: "key.horizontal.fill",
            defaultURL: "https://mcp.ddr-ai.io/jwt"
        ))
        catalog.append(DirectoryToolItem(
            id: "crontab-explainer",
            name: "Cron Schedule Parser",
            category: .developer,
            description: "Explain crontab expressions and calculate upcoming execution timestamps.",
            icon: "clock.arrow.2.circlepath",
            defaultURL: "https://mcp.ddr-ai.io/cron"
        ))
        catalog.append(DirectoryToolItem(
            id: "http-status",
            name: "HTTP Inspector",
            category: .developer,
            description: "Reference HTTP status codes, standard headers, and REST specifications.",
            icon: "server.rack",
            defaultURL: "https://mcp.ddr-ai.io/http"
        ))
        catalog.append(DirectoryToolItem(
            id: "diff-viewer",
            name: "Diff & Patch",
            category: .developer,
            description: "Compute unified diffs, line comparisons, and apply patch blocks.",
            icon: "arrow.left.and.right",
            defaultURL: "https://mcp.ddr-ai.io/diff"
        ))
        catalog.append(DirectoryToolItem(
            id: "gitlab",
            name: "GitLab Services",
            category: .developer,
            description: "Access GitLab repositories, merge requests, CI pipelines, and snippets.",
            icon: "chevron.left.slash.chevron.right",
            defaultURL: "https://mcp.ddr-ai.io/gitlab",
            requiresAuth: true
        ))
        catalog.append(DirectoryToolItem(
            id: "code-sandbox",
            name: "Python Runner",
            category: .developer,
            description: "Safely execute isolated Python scripts and inspect stdout/stderr output.",
            icon: "play.circle.fill",
            defaultURL: "https://mcp.ddr-ai.io/python-sandbox",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "npm-registry",
            name: "NPM Package Search",
            category: .developer,
            description: "Look up JavaScript packages, semver versions, dependencies, and download counts.",
            icon: "shippingbox.fill",
            defaultURL: "https://mcp.ddr-ai.io/npm"
        ))
        catalog.append(DirectoryToolItem(
            id: "pypi-search",
            name: "PyPI Package Search",
            category: .developer,
            description: "Search Python wheels, releases, maintainers, and trove classifiers.",
            icon: "cube.box.fill",
            defaultURL: "https://mcp.ddr-ai.io/pypi"
        ))
        catalog.append(DirectoryToolItem(
            id: "crates-io",
            name: "Rust Crates",
            category: .developer,
            description: "Query Rust packages, cargo dependency versions, features, and documentation.",
            icon: "gearshape.2.fill",
            defaultURL: "https://mcp.ddr-ai.io/crates"
        ))
        catalog.append(DirectoryToolItem(
            id: "docker-hub",
            name: "Docker Hub Registry",
            category: .developer,
            description: "Search container images, architecture tags, digests, and manifest layers.",
            icon: "externaldrive.fill",
            defaultURL: "https://mcp.ddr-ai.io/docker"
        ))
        catalog.append(DirectoryToolItem(
            id: "caniuse",
            name: "Can I Use Web APIs",
            category: .developer,
            description: "Browser compatibility tables for modern HTML5, CSS3, and JavaScript APIs.",
            icon: "safari.fill",
            defaultURL: "https://mcp.ddr-ai.io/caniuse"
        ))

        // MARK: - Data & Databases
        catalog.append(DirectoryToolItem(
            id: "sqlite-memory",
            name: "SQLite In-Memory",
            category: .data,
            description: "Create in-memory relational tables, run SQL queries, and analyze schemas.",
            icon: "cylinder.fill",
            defaultURL: "https://mcp.ddr-ai.io/sqlite",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "duckdb-analytics",
            name: "DuckDB Analytics",
            category: .data,
            description: "Fast columnar SQL analytics on CSV, Parquet, and in-memory tables.",
            icon: "tablecells.badge.ellipsis",
            defaultURL: "https://mcp.ddr-ai.io/duckdb"
        ))
        catalog.append(DirectoryToolItem(
            id: "memory-kv",
            name: "Key-Value Store",
            category: .data,
            description: "Persistent key-value cache with namespace isolation and TTL expiration.",
            icon: "archivebox.fill",
            defaultURL: "https://mcp.ddr-ai.io/kv"
        ))
        catalog.append(DirectoryToolItem(
            id: "json-placeholder",
            name: "Mock REST API",
            category: .data,
            description: "Instant mock endpoints for posts, users, comments, and prototyping data.",
            icon: "tray.full.fill",
            defaultURL: "https://mcp.ddr-ai.io/mock-data"
        ))
        catalog.append(DirectoryToolItem(
            id: "countries-data",
            name: "REST Countries",
            category: .data,
            description: "Query country borders, capitals, currencies, languages, and flag emblems.",
            icon: "globe.americas.fill",
            defaultURL: "https://mcp.ddr-ai.io/countries"
        ))
        catalog.append(DirectoryToolItem(
            id: "open-food-facts",
            name: "Open Food Facts",
            category: .data,
            description: "Food product ingredients, allergens, nutritional scores, and barcodes.",
            icon: "cart.fill",
            defaultURL: "https://mcp.ddr-ai.io/food-facts"
        ))
        catalog.append(DirectoryToolItem(
            id: "city-geo",
            name: "GeoNames Cities",
            category: .data,
            description: "Lookup world cities, latitude/longitude, elevations, and administrative boundaries.",
            icon: "building.2.crop.circle.fill",
            defaultURL: "https://mcp.ddr-ai.io/cities"
        ))
        catalog.append(DirectoryToolItem(
            id: "nobel-prizes",
            name: "Nobel Prize Archive",
            category: .data,
            description: "Search Nobel laureates, scientific prize categories, and motivation citations.",
            icon: "medal.fill",
            defaultURL: "https://mcp.ddr-ai.io/nobel"
        ))

        // MARK: - Productivity
        catalog.append(DirectoryToolItem(
            id: "rss-reader",
            name: "RSS & Atom Feeds",
            category: .productivity,
            description: "Parse news feeds, blogs, podcasts, and newsletter updates automatically.",
            icon: "dot.radiowaves.up.forward",
            defaultURL: "https://mcp.ddr-ai.io/rss",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "world-clock",
            name: "Timezone & Clock",
            category: .productivity,
            description: "Convert time across global zones, calculate offsets, and format ISO-8601.",
            icon: "clock.fill",
            defaultURL: "https://mcp.ddr-ai.io/time"
        ))
        catalog.append(DirectoryToolItem(
            id: "markdown-html",
            name: "Markdown Convert",
            category: .productivity,
            description: "Render markdown syntax to semantic HTML, clean text, and table formatting.",
            icon: "doc.richtext.fill",
            defaultURL: "https://mcp.ddr-ai.io/markdown"
        ))
        catalog.append(DirectoryToolItem(
            id: "readability",
            name: "Article Extractor",
            category: .productivity,
            description: "Extract clean main body text from any web article, stripping clutter and ads.",
            icon: "newspaper",
            defaultURL: "https://mcp.ddr-ai.io/readability"
        ))
        catalog.append(DirectoryToolItem(
            id: "url-cleaner",
            name: "URL Cleaner",
            category: .productivity,
            description: "Strip tracking UTM parameters, resolve redirect loops, and sanitize links.",
            icon: "link",
            defaultURL: "https://mcp.ddr-ai.io/url-tools"
        ))
        catalog.append(DirectoryToolItem(
            id: "sunrise-sunset",
            name: "Solar & Dawn Times",
            category: .productivity,
            description: "Calculate civil twilight, nautical sunrise, sunset, and solar noon.",
            icon: "sun.and.horizon.fill",
            defaultURL: "https://mcp.ddr-ai.io/solar"
        ))
        catalog.append(DirectoryToolItem(
            id: "public-holidays",
            name: "Public Holidays",
            category: .productivity,
            description: "Global national, regional, and bank holidays calendar across 100+ countries.",
            icon: "calendar.badge.clock",
            defaultURL: "https://mcp.ddr-ai.io/holidays"
        ))

        // MARK: - Utilities
        catalog.append(DirectoryToolItem(
            id: "ip-geo",
            name: "IP Geolocation",
            category: .utilities,
            description: "Lookup IP addresses, autonomous system numbers (ASN), city, and ISP details.",
            icon: "location.fill",
            defaultURL: "https://mcp.ddr-ai.io/ip-geo"
        ))
        catalog.append(DirectoryToolItem(
            id: "dns-lookup",
            name: "DNS Resolver",
            category: .utilities,
            description: "Resolve A, AAAA, MX, TXT, CNAME, and NS records with DNSSEC verification.",
            icon: "network.badge.shield.half.filled",
            defaultURL: "https://mcp.ddr-ai.io/dns"
        ))
        catalog.append(DirectoryToolItem(
            id: "qr-generator",
            name: "QR Code Generator",
            category: .utilities,
            description: "Generate QR codes for URLs, WiFi credentials, vCards, and plain text.",
            icon: "qrcode",
            defaultURL: "https://mcp.ddr-ai.io/qrcode"
        ))
        catalog.append(DirectoryToolItem(
            id: "uuid-generator",
            name: "UUID & ID Tools",
            category: .utilities,
            description: "Generate UUID v4, v7, NanoID, ULID, and secure random byte strings.",
            icon: "number.square.fill",
            defaultURL: "https://mcp.ddr-ai.io/uuid"
        ))
        catalog.append(DirectoryToolItem(
            id: "color-tools",
            name: "Color Palette",
            category: .utilities,
            description: "Convert HEX, RGB, HSL, CMYK, calculate contrast ratios, and palettes.",
            icon: "paintpalette.fill",
            defaultURL: "https://mcp.ddr-ai.io/colors"
        ))
        catalog.append(DirectoryToolItem(
            id: "mime-types",
            name: "MIME Inspector",
            category: .utilities,
            description: "Lookup file extensions, IANA content-types, and binary magic bytes.",
            icon: "doc.badge.gearshape.fill",
            defaultURL: "https://mcp.ddr-ai.io/mime"
        ))
        catalog.append(DirectoryToolItem(
            id: "ssl-checker",
            name: "SSL & TLS Inspector",
            category: .utilities,
            description: "Inspect X.509 certificate expiry, issuer chains, and cipher suites.",
            icon: "lock.shield",
            defaultURL: "https://mcp.ddr-ai.io/ssl"
        ))
        catalog.append(DirectoryToolItem(
            id: "useragent-parser",
            name: "User-Agent Parser",
            category: .utilities,
            description: "Parse browser, engine, OS, device model, and CPU architecture strings.",
            icon: "macbook.and.iphone",
            defaultURL: "https://mcp.ddr-ai.io/ua"
        ))

        // MARK: - Math & Science
        catalog.append(DirectoryToolItem(
            id: "mathjs",
            name: "Math Evaluator",
            category: .science,
            description: "Evaluate complex mathematical expressions, matrices, statistics, and calculus.",
            icon: "function",
            defaultURL: "https://mcp.ddr-ai.io/math",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "unit-converter",
            name: "Unit & Dimensions",
            category: .science,
            description: "Convert physical units: length, mass, temperature, pressure, energy, speed.",
            icon: "scalemass.fill",
            defaultURL: "https://mcp.ddr-ai.io/units"
        ))
        catalog.append(DirectoryToolItem(
            id: "periodic-table",
            name: "Periodic Elements",
            category: .science,
            description: "Chemical elements atomic properties, electron configuration, and isotopes.",
            icon: "circle.hexagongrid.fill",
            defaultURL: "https://mcp.ddr-ai.io/chemistry"
        ))
        catalog.append(DirectoryToolItem(
            id: "physics-constants",
            name: "Physical Constants",
            category: .science,
            description: "Exact CODATA fundamental constants: speed of light, Planck constant, G.",
            icon: "slider.vertical.3",
            defaultURL: "https://mcp.ddr-ai.io/physics"
        ))
        catalog.append(DirectoryToolItem(
            id: "statistics-calc",
            name: "Descriptive Statistics",
            category: .science,
            description: "Calculate mean, median, mode, standard deviation, variance, and quantiles.",
            icon: "chart.xyaxis.line",
            defaultURL: "https://mcp.ddr-ai.io/stats"
        ))

        // MARK: - Finance & Currency
        catalog.append(DirectoryToolItem(
            id: "coingecko",
            name: "CoinGecko Crypto",
            category: .finance,
            description: "Real-time cryptocurrency market prices, volume, and 24h market trends.",
            icon: "bitcoinsign.circle.fill",
            defaultURL: "https://mcp.ddr-ai.io/crypto-prices",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "frankfurter",
            name: "Currency Rates",
            category: .finance,
            description: "European Central Bank foreign exchange rates and fiat currency conversion.",
            icon: "banknote.fill",
            defaultURL: "https://mcp.ddr-ai.io/forex",
            isPopular: true
        ))
        catalog.append(DirectoryToolItem(
            id: "compound-interest",
            name: "Loan & Interest",
            category: .finance,
            description: "Calculate mortgage amortization, compound interest, and investment returns.",
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            defaultURL: "https://mcp.ddr-ai.io/finance-math"
        ))
        catalog.append(DirectoryToolItem(
            id: "vat-calculator",
            name: "Sales Tax & VAT",
            category: .finance,
            description: "Compute gross and net prices, regional VAT rates, and sales taxes globally.",
            icon: "percent",
            defaultURL: "https://mcp.ddr-ai.io/tax"
        ))

        self.items = catalog
    }

    public func search(query: String, category: ToolCategory = .all) -> [DirectoryToolItem] {
        let trimmed = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            let categoryMatch = (category == .all || item.category == category)
            if trimmed.isEmpty {
                return categoryMatch
            }
            let textMatch = item.name.lowercased().contains(trimmed) ||
                           item.description.lowercased().contains(trimmed)
            return categoryMatch && textMatch
        }
    }
}
