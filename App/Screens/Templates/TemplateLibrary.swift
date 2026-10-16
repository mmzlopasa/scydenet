import Foundation
import SCYDECore

/// Template categories. Every template is SCYDE's own recipe; previews are rendered on device.
enum TemplateCategory: String, CaseIterable, Identifiable, Hashable {
    case cars, travel, vlog, beat, cinematic, retro, minimal, slideshow, birthday, fitness
    case food, fashion, product, realEstate, sports, wedding, pets, nature, night, intro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cars: return "Cars"
        case .travel: return "Travel"
        case .vlog: return "Vlog"
        case .beat: return "Beat sync"
        case .cinematic: return "Cinematic"
        case .retro: return "Retro"
        case .minimal: return "Minimal"
        case .slideshow: return "Slideshow"
        case .birthday: return "Birthday"
        case .fitness: return "Fitness"
        case .food: return "Food"
        case .fashion: return "Fashion"
        case .product: return "Product"
        case .realEstate: return "Real estate"
        case .sports: return "Sports"
        case .wedding: return "Wedding"
        case .pets: return "Pets"
        case .nature: return "Nature"
        case .night: return "Night"
        case .intro: return "Intro"
        }
    }

    var icon: String {
        switch self {
        case .cars: return "car.fill"
        case .travel: return "airplane"
        case .vlog: return "video.fill"
        case .beat: return "waveform"
        case .cinematic: return "film"
        case .retro: return "tv"
        case .minimal: return "square.on.square"
        case .slideshow: return "photo.on.rectangle"
        case .birthday: return "birthday.cake.fill"
        case .fitness: return "dumbbell.fill"
        case .food: return "fork.knife"
        case .fashion: return "tshirt.fill"
        case .product: return "shippingbox.fill"
        case .realEstate: return "house.fill"
        case .sports: return "sportscourt.fill"
        case .wedding: return "heart.fill"
        case .pets: return "pawprint.fill"
        case .nature: return "leaf.fill"
        case .night: return "moon.stars.fill"
        case .intro: return "sparkles"
        }
    }

    /// Emoji shown on chips and cards.
    var emoji: String {
        switch self {
        case .cars: return "🏎️"
        case .travel: return "✈️"
        case .vlog: return "🎥"
        case .beat: return "🎧"
        case .cinematic: return "🎬"
        case .retro: return "📼"
        case .minimal: return "◻️"
        case .slideshow: return "🖼️"
        case .birthday: return "🎂"
        case .fitness: return "💪"
        case .food: return "🍜"
        case .fashion: return "👗"
        case .product: return "📦"
        case .realEstate: return "🏡"
        case .sports: return "⚽️"
        case .wedding: return "💍"
        case .pets: return "🐶"
        case .nature: return "🌿"
        case .night: return "🌙"
        case .intro: return "✨"
        }
    }

    /// Title look for the category's templates.
    var titleStyle: TextStyle {
        let id: String
        switch self {
        case .cars, .sports, .fitness: id = "bold-outline"
        case .beat, .birthday: id = "yellow"
        case .cinematic, .wedding, .realEstate: id = "cinema"
        case .retro: id = "retro"
        case .night, .intro: id = "neon"
        case .minimal, .fashion, .product: id = "minimal"
        case .vlog, .food, .pets: id = "highlight"
        default: id = "title"
        }
        var style = TextPreset.all.first { $0.id == id }?.style ?? .caption
        style.anchorY = id == "minimal" ? 0.32 : 0
        if style.animIn == .none { style.animIn = .rise }
        if style.animOut == .none { style.animOut = .fade }
        return style
    }

    /// Two-colour palette used by the preview artwork.
    var colors: [UInt32] {
        switch self {
        case .cars: return [0x14161D, 0xFFD76A]
        case .travel: return [0x2E8BC0, 0xFFE7A0]
        case .vlog: return [0xC4BBFF, 0xFF9AA8]
        case .beat: return [0x5A49E6, 0xFF5A8A]
        case .cinematic: return [0x0D0F14, 0xE9B84A]
        case .retro: return [0xFF9A62, 0x7A3A6A]
        case .minimal: return [0xEEF0F3, 0x6B678F]
        case .slideshow: return [0xA9C8FF, 0x5A49E6]
        case .birthday: return [0xFFB4C0, 0xFFD76A]
        case .fitness: return [0x0C8A60, 0x8EF0C8]
        case .food: return [0xE9B84A, 0xC4472B]
        case .fashion: return [0x262A35, 0xFFB4C0]
        case .product: return [0xF5F2FF, 0x4333BE]
        case .realEstate: return [0x8EC5FF, 0x2B6F7A]
        case .sports: return [0xFF5A3C, 0x1B1530]
        case .wedding: return [0xFFF0E6, 0xE9B84A]
        case .pets: return [0xFFD76A, 0x8EF0C8]
        case .nature: return [0x2B6F3A, 0xC8F08E]
        case .night: return [0x0B0A28, 0x5A49E6]
        case .intro: return [0x1A1D25, 0xC4BBFF]
        }
    }

    var looks: [String] {
        switch self {
        case .cars: return ["noir", "chrome", "cool"]
        case .travel: return ["vivid", "warm", "instant"]
        case .vlog: return ["warm", "instant", "vivid"]
        case .beat: return ["vivid", "process", "chrome"]
        case .cinematic: return ["fade", "tonal", "cool"]
        case .retro: return ["retro", "instant", "fade"]
        case .minimal: return ["mono", "fade", "original"]
        case .slideshow: return ["warm", "original", "vivid"]
        case .birthday: return ["vivid", "warm", "instant"]
        case .fitness: return ["process", "chrome", "noir"]
        case .food: return ["warm", "vivid", "instant"]
        case .fashion: return ["fade", "mono", "chrome"]
        case .product: return ["original", "vivid", "cool"]
        case .realEstate: return ["vivid", "warm", "original"]
        case .sports: return ["chrome", "vivid", "process"]
        case .wedding: return ["fade", "warm", "tonal"]
        case .pets: return ["vivid", "warm", "instant"]
        case .nature: return ["vivid", "cool", "warm"]
        case .night: return ["cool", "noir", "process"]
        case .intro: return ["original", "chrome", "noir"]
        }
    }

    /// (name, summary, on-screen title) for each of the six variants.
    var variants: [(String, String, String)] {
        switch self {
        case .cars: return [
            ("Night run", "Moody cuts for night drives.", "NIGHT RUN"),
            ("Garage reveal", "Slow push-ins that build to the car.", "THE REVEAL"),
            ("Track day", "Fast cuts for laps and launches.", "TRACK DAY"),
            ("Detail shots", "Close-ups of wheels, badges and lines.", "DETAILS"),
            ("Road trip", "Wide shots for the open road.", "ROAD TRIP"),
            ("Launch control", "Short, punchy, beat-ready.", "LAUNCH"),
        ]
        case .travel: return [
            ("Passport stamps", "One city per cut.", "PASSPORT"),
            ("Weekend away", "Three days in six clips.", "WEEKEND"),
            ("City hopper", "Quick slides between streets.", "CITY HOPPER"),
            ("Coastline", "Bright, warm and slow.", "COASTLINE"),
            ("Mountain escape", "Wide views with gentle zooms.", "ESCAPE"),
            ("Postcards", "Square frames like postcards.", "POSTCARDS"),
        ]
        case .vlog: return [
            ("Day in my life", "Morning to night in ten cuts.", "MY DAY"),
            ("Morning routine", "Soft and calm.", "MORNING"),
            ("Get ready", "Quick cuts while getting ready.", "GET READY"),
            ("Studio day", "Work-in-progress moments.", "STUDIO"),
            ("Week recap", "Seven days, one edit.", "THIS WEEK"),
            ("Behind the scenes", "Raw and honest.", "BTS"),
        ]
        case .beat: return [
            ("Drop", "Hold, then hit on the drop.", "DROP"),
            ("Pulse", "Even cuts on every beat.", "PULSE"),
            ("Strobe cuts", "Flash transitions, fast.", "STROBE"),
            ("Bass line", "Zooms that ride the bass.", "BASS"),
            ("Tempo", "Speeds up toward the end.", "TEMPO"),
            ("Snap", "Snappy slides.", "SNAP"),
        ]
        case .cinematic: return [
            ("Opening credits", "Slow fades and a title.", "OPENING"),
            ("Golden hour", "Warm, wide and calm.", "GOLDEN HOUR"),
            ("Slow reveal", "Long push-ins.", "REVEAL"),
            ("Wide horizon", "21:9 frames.", "HORIZON"),
            ("Film look", "Faded colour, soft cuts.", "FILM"),
            ("Final scene", "Ends on a long hold.", "THE END"),
        ]
        case .retro: return [
            ("VHS memories", "Tape-era colour.", "VHS"),
            ("90s tape", "Bright, fast and warm.", "1999"),
            ("Polaroid", "Square instants.", "POLAROID"),
            ("Film grain", "Faded and gentle.", "FILM"),
            ("Arcade", "Neon and quick cuts.", "ARCADE"),
            ("Mixtape", "A side, B side.", "MIXTAPE"),
        ]
        case .minimal: return [
            ("Clean cuts", "No effects, just rhythm.", "CLEAN"),
            ("White space", "Light and airy.", "SPACE"),
            ("Mono story", "Black and white.", "MONO"),
            ("Simple slides", "Gentle slides.", "SIMPLE"),
            ("Soft fade", "Fades only.", "SOFT"),
            ("Quiet", "Long, quiet holds.", "QUIET"),
        ]
        case .slideshow: return [
            ("Photo dump", "Ten photos, one second each.", "PHOTO DUMP"),
            ("Memories", "Warm, slow, nostalgic.", "MEMORIES"),
            ("Year in review", "Twelve moments.", "THIS YEAR"),
            ("Album", "Even pacing.", "ALBUM"),
            ("Then and now", "Pairs of photos.", "THEN & NOW"),
            ("Highlights", "The best bits.", "HIGHLIGHTS"),
        ]
        case .birthday: return [
            ("Party time", "Bright and fast.", "PARTY"),
            ("Cake moment", "Build-up to the candles.", "MAKE A WISH"),
            ("Birthday wishes", "Messages from friends.", "HAPPY BIRTHDAY"),
            ("Surprise", "Quick reveal.", "SURPRISE"),
            ("Throwback", "Old photos to today.", "THROWBACK"),
            ("Cheers", "Toasts and laughs.", "CHEERS"),
        ]
        case .fitness: return [
            ("Workout split", "Exercise by exercise.", "WORKOUT"),
            ("PR day", "Build to the lift.", "NEW PR"),
            ("Training block", "Week of training.", "TRAINING"),
            ("Run club", "Kilometres in clips.", "RUN CLUB"),
            ("Gym check", "Quick cuts.", "GYM"),
            ("Transformation", "Before to after.", "PROGRESS"),
        ]
        case .food: return [
            ("Recipe steps", "Step by step.", "RECIPE"),
            ("Plate up", "From pan to plate.", "PLATE UP"),
            ("Coffee break", "Slow and warm.", "COFFEE"),
            ("Street food", "Fast and colourful.", "STREET FOOD"),
            ("Brunch", "Bright table shots.", "BRUNCH"),
            ("Taste test", "Reactions and close-ups.", "TASTE TEST"),
        ]
        case .fashion: return [
            ("Outfit check", "Head to toe.", "OOTD"),
            ("Lookbook", "One look per cut.", "LOOKBOOK"),
            ("Fit of the day", "Quick spins.", "FIT CHECK"),
            ("Runway", "Walk-ins with zooms.", "RUNWAY"),
            ("Accessories", "Details only.", "DETAILS"),
            ("Style edit", "Faded, editorial.", "STYLE"),
        ]
        case .product: return [
            ("Unboxing", "Box to hands.", "UNBOXING"),
            ("Feature tour", "One feature per cut.", "FEATURES"),
            ("Before and after", "Two halves.", "BEFORE / AFTER"),
            ("Launch teaser", "Short and mysterious.", "COMING SOON"),
            ("Spec sheet", "Clean, square frames.", "SPECS"),
            ("Showcase", "Slow turntable feel.", "SHOWCASE"),
        ]
        case .realEstate: return [
            ("House tour", "Door to garden.", "HOUSE TOUR"),
            ("Room by room", "Even pacing per room.", "ROOM BY ROOM"),
            ("Exterior", "Wide outside shots.", "EXTERIOR"),
            ("Open house", "Invite-style.", "OPEN HOUSE"),
            ("Floor plan", "Calm slides.", "FLOOR PLAN"),
            ("Listing", "Square frames for listings.", "FOR SALE"),
        ]
        case .sports: return [
            ("Match day", "Warm-up to final whistle.", "MATCH DAY"),
            ("Highlights reel", "Best plays.", "HIGHLIGHTS"),
            ("Game winner", "Build to the moment.", "WINNER"),
            ("Team intro", "One player per cut.", "THE TEAM"),
            ("Skate session", "Tricks in fast cuts.", "SESSION"),
            ("Ride out", "Wide and fast.", "RIDE OUT"),
        ]
        case .wedding: return [
            ("Save the date", "Soft and romantic.", "SAVE THE DATE"),
            ("First look", "Slow reveal.", "FIRST LOOK"),
            ("Vows", "Long, quiet holds.", "VOWS"),
            ("Reception", "Dance-floor energy.", "CELEBRATE"),
            ("Getting ready", "Morning details.", "GETTING READY"),
            ("Just married", "Joyful ending.", "JUST MARRIED"),
        ]
        case .pets: return [
            ("Pet of the day", "Best side, best light.", "PET OF THE DAY"),
            ("Zoomies", "Fast and chaotic.", "ZOOMIES"),
            ("Nap time", "Slow and sleepy.", "NAP TIME"),
            ("Good boy", "Tricks and treats.", "GOOD BOY"),
            ("Paws", "Close-ups.", "PAWS"),
            ("Adoption day", "First day home.", "HOME"),
        ]
        case .nature: return [
            ("Into the wild", "Wide and slow.", "WILD"),
            ("Forest walk", "Green, calm cuts.", "FOREST"),
            ("Sunrise", "Warm build-up.", "SUNRISE"),
            ("Waves", "Blue and slow.", "WAVES"),
            ("Trail log", "Checkpoint by checkpoint.", "TRAIL"),
            ("Seasons", "Four seasons.", "SEASONS"),
        ]
        case .night: return [
            ("City lights", "Neon and motion.", "CITY LIGHTS"),
            ("After dark", "Moody and slow.", "AFTER DARK"),
            ("Neon", "Bright cuts.", "NEON"),
            ("Midnight drive", "Long road shots.", "MIDNIGHT"),
            ("Rooftop", "Views from above.", "ROOFTOP"),
            ("Late show", "Black and white.", "LATE SHOW"),
        ]
        case .intro: return [
            ("Channel intro", "Short and branded.", "WELCOME"),
            ("Title card", "One clean title.", "TITLE"),
            ("Logo sting", "Two-second sting.", "SCYDE"),
            ("Episode open", "Episode number and name.", "EPISODE 01"),
            ("Name drop", "Introduce yourself.", "HELLO"),
            ("Countdown", "3, 2, 1.", "3 · 2 · 1"),
        ]
        }
    }

    /// Alternative format for the fifth variant.
    var altAspect: CanvasAspect {
        switch self {
        case .cinematic, .travel, .realEstate, .cars, .nature, .sports: return .landscape16x9
        case .retro, .product, .slideshow, .minimal: return .square1x1
        default: return .portrait4x5
        }
    }
}

/// A built-in recipe: format, clip slots, transition, look and an optional title.
struct ProjectTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let category: TemplateCategory
    let aspect: CanvasAspect
    let slots: [Double]
    let colors: [UInt32]
    let transition: TransitionKind?
    let filter: String?
    let title: String?
    let kenBurns: Bool

    var totalDuration: Double { slots.reduce(0, +) }

    private static let slotPatterns: [[Double]] = [
        Array(repeating: 1.2, count: 6),
        [2, 2, 3],
        Array(repeating: 0.6, count: 10),
        [1.5, 1, 1, 1.5, 2],
        [3, 2, 3],
        Array(repeating: 0.8, count: 8),
    ]

    /// The whole library: 20 categories × 6 variants.
    static let all: [ProjectTemplate] = {
        var result: [ProjectTemplate] = []
        let kinds = TransitionKind.allCases.filter { $0 != .dissolve }
        for (ci, category) in TemplateCategory.allCases.enumerated() {
            for (vi, variant) in category.variants.enumerated() {
                var slots = slotPatterns[vi % slotPatterns.count]
                if category == .beat { slots = slots.map { min($0, 0.8) } }
                if category == .cinematic || category == .wedding { slots = slots.map { max($0, 2) } }
                let aspect: CanvasAspect
                switch vi {
                case 4: aspect = category.altAspect
                case 5: aspect = category == .cinematic ? .cinema21x9 : .portrait4x5
                default: aspect = .portrait9x16
                }
                let transition: TransitionKind? = category == .minimal && vi == 0 ? nil : kinds[(ci + vi) % kinds.count]
                let look = category.looks[vi % category.looks.count]
                result.append(ProjectTemplate(
                    id: "\(category.rawValue)-\(vi)",
                    name: variant.0,
                    summary: variant.1,
                    category: category,
                    aspect: aspect,
                    slots: slots,
                    colors: category.colors,
                    transition: transition,
                    filter: look == "original" ? nil : look,
                    title: variant.2,
                    kenBurns: vi % 2 == 0
                ))
            }
        }
        return result
    }()
}
