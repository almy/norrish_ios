// IconMapper.swift
// Loads a JSON mapping of detected class names to SF Symbol names, with sensible fallbacks.

import UIKit

final class IconMapper {
    static let shared = IconMapper()

    private var map: [String: String] = [:]
    private struct Rule: Codable { let keywords: [String]; let symbol: String }
    private var rules: [Rule] = []
    private static let fallbackRules: [Rule] = [
        // Drinks & vessels
        Rule(keywords: ["coffee","tea","cup","mug","latte","espresso"], symbol: "cup.and.saucer"),
        Rule(keywords: ["wine","beer","cocktail","champagne"], symbol: "wineglass"),
        Rule(keywords: ["juice","smoothie"], symbol: "cup.and.saucer"),
        Rule(keywords: ["bottle","flask","thermos"], symbol: "waterbottle"),

        // Food – produce & greens
        Rule(keywords: ["fruit","apple","banana","grape","berry","watermelon","orange","lemon","peach","pear","pineapple","strawberry","grapefruit","mango","fig","pomegranate","cantaloupe","common fig"], symbol: "leaf"),
        Rule(keywords: ["vegetable","salad","broccoli","cabbage","lettuce","tomato","cucumber","zucchini","artichoke","asparagus","radish","pumpkin","bell pepper","carrot","potato","squash","garden asparagus","winter melon"], symbol: "leaf"),
        Rule(keywords: ["herb","maple","willow","lavender","sunflower","palm tree","tree","plant","flower","rose","lily"], symbol: "leaf"),

        // Food – prepared & staples
        Rule(keywords: ["bread","cake","pastry","cookie","donut","muffin","waffle","dessert","pancake","croissant","baked","tart","pretzel","bagel","baked goods","pie"], symbol: "birthday.cake"),
        Rule(keywords: ["pizza","burger","sandwich","taco","pasta","noodle","rice","hot dog","burrito","sushi","waffle iron","pancake"], symbol: "fork.knife"),
        Rule(keywords: ["egg (food)","egg"], symbol: "fork.knife"),
        Rule(keywords: ["cheese","cream","dairy product","milk","yogurt"], symbol: "fork.knife"),
        Rule(keywords: ["seafood","shellfish","shrimp","lobster","oyster","crab","squid","octopus","fish","rays and skates"], symbol: "fish"),
        Rule(keywords: ["meat","chicken","beef","pork","turkey","ham","sausage"], symbol: "fork.knife"),
        Rule(keywords: ["snack","fast food","popcorn","french fries","guacamole","sauce","ketchup"], symbol: "fork.knife"),

        // Tableware & utensils
        Rule(keywords: ["fork","knife","spoon","chopsticks","tableware","plate","bowl","saucer","cup","teapot","pitcher","mug"], symbol: "fork.knife"),
        Rule(keywords: ["whisk","spatula","frying pan","wok","ladle"], symbol: "frying.pan"),

        // Animals – general & mammals
        Rule(keywords: ["animal","mammal","carnivore","invertebrate","vertebrate","herbivore"], symbol: "pawprint"),
        Rule(keywords: ["alpaca","armadillo","antelope","bear","brown bear","bull","camel","cat","cheetah","cattle","deer","dog","dolphin","duck","elephant","fox","frog","giraffe","goat","hamster","hippopotamus","horse","jaguar","kangaroo","koala","leopard","lion","lizard","monkey","mule","otter","panda","pig","polar bear","rabbit","raccoon","red panda","rhinoceros","skunk","squirrel","tiger","zebra","lynx","crocodile","alligator","sheep","harbor seal"], symbol: "pawprint"),

        // Birds, insects, reptiles, marine
        Rule(keywords: ["bird","owl","eagle","falcon","penguin","swan","sparrow","parrot","canary","blue jay","magpie","raven","woodpecker"], symbol: "bird"),
        Rule(keywords: ["insect","ant","bee","beetle","butterfly","ladybug","caterpillar","centipede","dragonfly","moths and butterflies","tick"], symbol: "ant"),
        Rule(keywords: ["reptile","snake","tortoise","turtle","lizard"], symbol: "tortoise"),
        Rule(keywords: ["marine mammal","marine invertebrates","whale","shark","squid","starfish","sea lion","sea turtle","seahorse","ray","rays and skates"], symbol: "fish"),

        // People & body
        Rule(keywords: ["person","man","woman","boy","girl","human"], symbol: "person.crop.circle"),
        Rule(keywords: ["human arm","hand"], symbol: "hand.raised"),
        Rule(keywords: ["human ear","ear"], symbol: "ear"),
        Rule(keywords: ["human eye","eye"], symbol: "eye"),
        Rule(keywords: ["human mouth","mouth","lips"], symbol: "mouth"),
        Rule(keywords: ["human nose","nose"], symbol: "nose"),
        Rule(keywords: ["human foot","foot"], symbol: "shoeprints.fill"),
        Rule(keywords: ["human hair","hair","beard"], symbol: "person"),

        // Clothing & accessories
        Rule(keywords: ["clothing","shirt","t-shirt","trousers","pants","shorts","dress","coat","scarf","suit","jeans","skirt"], symbol: "tshirt"),
        Rule(keywords: ["hat","cowboy hat","sun hat","sombrero","fedora","tiara","crown"], symbol: "graduationcap"),
        Rule(keywords: ["shoe","footwear","high heels","sandal","sock"], symbol: "shoeprints.fill"),
        Rule(keywords: ["glasses","sunglasses","goggles"], symbol: "eyeglasses"),
        Rule(keywords: ["earrings","necklace","lipstick","cosmetics","face powder","perfume"], symbol: "sparkles"),

        // Furniture & home
        Rule(keywords: ["chair","sofa","couch","stool","bench","loveseat","furniture","table","desk","nightstand","cupboard","cabinetry","wardrobe","shelf","bookshelf","bookcase","drawer","drawers","dressing table"], symbol: "chair"),
        Rule(keywords: ["bed","infant bed","bunk bed"], symbol: "bed.double"),
        Rule(keywords: ["lamp","light","lantern","flashlight"], symbol: "lightbulb"),
        Rule(keywords: ["curtain","window","window blind"], symbol: "curtains.open"),
        Rule(keywords: ["door","door handle"], symbol: "door.left.hand.open"),
        Rule(keywords: ["mirror"], symbol: "rectangle.on.rectangle"),
        Rule(keywords: ["clock","alarm clock","digital clock"], symbol: "clock"),

        // Kitchen & appliances
        Rule(keywords: ["blender","mixer","mixing bowl","grinder","coffeemaker","kettle"], symbol: "blender"),
        Rule(keywords: ["microwave oven","microwave","oven","toaster","slow cooker","pressure cooker","wok","cooktop"], symbol: "microwave"),
        Rule(keywords: ["dishwasher","washing machine"], symbol: "washer"),
        Rule(keywords: ["refrigerator"], symbol: "refrigerator"),

        // Bathroom & fixtures
        Rule(keywords: ["bathtub","shower","sink","bidet","toilet","plumbing fixture","humidifier","soap dispenser","towel"], symbol: "shower"),

        // Tools & hardware
        Rule(keywords: ["tool","tools","hammer","screwdriver","wrench","chisel","drill","axe","ratchet","saw","chainsaw","whisk","spatula","knife","scissors","tape","adhesive tape"], symbol: "wrench.and.screwdriver"),
        Rule(keywords: ["ladle","spoon","fork","chopsticks"], symbol: "fork.knife"),

        // Office & supplies
        Rule(keywords: ["book","books","bookcase","bookshelf","picture frame"], symbol: "books.vertical"),
        Rule(keywords: ["pen","pencil","pencil case","pencil sharpener","marker","highlighter"], symbol: "pencil"),
        Rule(keywords: ["paper cutter","stapler","ruler","eraser","envelope","paper towel"], symbol: "ruler"),
        Rule(keywords: ["printer","fax","photocopier"], symbol: "printer"),
        Rule(keywords: ["whiteboard","blackboard","scoreboard"], symbol: "rectangle.and.pencil.and.ellipsis"),

        // Electronics
        Rule(keywords: ["computer monitor","monitor","display","television","tv"], symbol: "tv"),
        Rule(keywords: ["computer keyboard","keyboard"], symbol: "keyboard"),
        Rule(keywords: ["computer mouse","mouse"], symbol: "mouse"),
        Rule(keywords: ["laptop","laptop computer"], symbol: "laptopcomputer"),
        Rule(keywords: ["tablet computer","tablet","ipad"], symbol: "ipad"),
        Rule(keywords: ["mobile phone","cell phone","iphone"], symbol: "iphone"),
        Rule(keywords: ["camera","video camera","camcorder"], symbol: "camera"),
        Rule(keywords: ["microphone","mic"], symbol: "mic"),
        Rule(keywords: ["headphones","headset"], symbol: "headphones"),
        Rule(keywords: ["remote control","remote"], symbol: "appletvremote.gen3"),

        // Vehicles & transport
        Rule(keywords: ["car","automobile"], symbol: "car"),
        Rule(keywords: ["van","minivan"], symbol: "car"),
        Rule(keywords: ["taxi","cab"], symbol: "car"),
        Rule(keywords: ["bus"], symbol: "bus"),
        Rule(keywords: ["truck","pickup","lorry"], symbol: "box.truck"),
        Rule(keywords: ["train","railroad"], symbol: "train.side.front.car"),
        Rule(keywords: ["tram","streetcar"], symbol: "tram"),
        Rule(keywords: ["subway","metro"], symbol: "tram"),
        Rule(keywords: ["bicycle","bike","bicycle wheel","bicycle helmet"], symbol: "bicycle"),
        Rule(keywords: ["motorcycle"], symbol: "motorcycle"),
        Rule(keywords: ["segway","scooter"], symbol: "scooter"),
        Rule(keywords: ["unicycle"], symbol: "bicycle"),
        Rule(keywords: ["aircraft","airplane","jet"], symbol: "airplane"),
        Rule(keywords: ["helicopter"], symbol: "helicopter"),
        Rule(keywords: ["boat","barge","canoe","gondola","ship","watercraft","ferry"], symbol: "ferry"),
        Rule(keywords: ["sailboat"], symbol: "sailboat"),
        Rule(keywords: ["submarine"], symbol: "submarine"),
        Rule(keywords: ["rocket","missile"], symbol: "rocket"),

        // Sports & fitness
        Rule(keywords: ["ball","football","soccer","volleyball","basketball","baseball","tennis ball","golf ball","cricket ball","rugby ball"], symbol: "sportscourt"),
        Rule(keywords: ["golf cart","golf"], symbol: "figure.golf"),
        Rule(keywords: ["skateboard"], symbol: "skateboard"),
        Rule(keywords: ["snowboard"], symbol: "snowboard"),
        Rule(keywords: ["surfboard"], symbol: "surfboard"),
        Rule(keywords: ["racket","tennis racket","table tennis racket"], symbol: "tennis.racket"),
        Rule(keywords: ["dumbbell","training bench","treadmill","indoor rower"], symbol: "dumbbell"),
        Rule(keywords: ["horizontal bar","balance beam"], symbol: "figure.gymnastics"),

        // Music & instruments
        Rule(keywords: ["guitar","guitars"], symbol: "guitars"),
        Rule(keywords: ["piano","organ","harpsichord","keyboard"], symbol: "pianokeys"),
        Rule(keywords: ["violin","cello"], symbol: "music.note"),
        Rule(keywords: ["drum"], symbol: "drum"),
        Rule(keywords: ["trumpet"], symbol: "trumpet"),
        Rule(keywords: ["saxophone"], symbol: "saxophone"),
        Rule(keywords: ["flute","oboe"], symbol: "music.note"),
        Rule(keywords: ["harp"], symbol: "harp"),
        Rule(keywords: ["trombone"], symbol: "trombone"),
        Rule(keywords: ["maracas"], symbol: "maracas"),
        Rule(keywords: ["harmonica"], symbol: "music.note"),

        // Buildings & places
        Rule(keywords: ["house","home"], symbol: "house"),
        Rule(keywords: ["building","office building","skyscraper","tower"], symbol: "building.2"),
        Rule(keywords: ["lighthouse"], symbol: "lighthouse"),
        Rule(keywords: ["castle"], symbol: "building.columns"),
        Rule(keywords: ["tree house"], symbol: "house.and.flag"),
        Rule(keywords: ["porch"], symbol: "house"),
        Rule(keywords: ["parking meter"], symbol: "parkingsign.circle"),
        Rule(keywords: ["traffic light"], symbol: "trafficlight"),
        Rule(keywords: ["stop sign"], symbol: "octagon"),
        Rule(keywords: ["flag"], symbol: "flag"),
        Rule(keywords: ["map","atlas","globe"], symbol: "map"),
        Rule(keywords: ["billboard","poster"], symbol: "rectangle.portrait"),

        // Medical & health
        Rule(keywords: ["stethoscope"], symbol: "stethoscope"),
        Rule(keywords: ["syringe"], symbol: "syringe"),
        Rule(keywords: ["crutch","wheelchair","stretcher"], symbol: "cross.case"),
        Rule(keywords: ["scale","weighing scale"], symbol: "scalemass"),

        // Miscellaneous
        Rule(keywords: ["alarm","bell","chime"], symbol: "bell"),
        Rule(keywords: ["binoculars"], symbol: "binoculars"),
        Rule(keywords: ["flashlight"], symbol: "flashlight.on.fill"),
        Rule(keywords: ["billiard table","pool table"], symbol: "sportscourt"),
        Rule(keywords: ["bomb"], symbol: "exclamationmark.triangle"),
        Rule(keywords: ["gun","rifle","shotgun","weapon"], symbol: "target"),
        Rule(keywords: ["umbrella"], symbol: "umbrella"),
        Rule(keywords: ["teddy bear"], symbol: "teddybear"),
        Rule(keywords: ["toy","doll"], symbol: "puzzlepiece"),
        Rule(keywords: ["calendar","clock"], symbol: "calendar"),
        Rule(keywords: ["coin"], symbol: "coloncurrencysign.circle"),
        Rule(keywords: ["fire hydrant","fireplace","flame"], symbol: "flame"),
        Rule(keywords: ["fountain"], symbol: "fountain"),
        Rule(keywords: ["soap"], symbol: "drop"),
        Rule(keywords: ["trash","waste container"], symbol: "trash"),
        Rule(keywords: ["ladder"], symbol: "ladder"),
        Rule(keywords: ["segway"], symbol: "scooter")
    ]

    private init() {
        loadMapping()
        loadRules()
    }

    private func loadMapping() {
        // Try to load IconMapping.json from the main bundle
        if let url = Bundle.main.url(forResource: "IconMapping", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            // Normalize keys to lowercase for case-insensitive matching
            var lowered: [String: String] = [:]
            for (k, v) in dict { lowered[k.lowercased()] = v }
            self.map = lowered
            return
        }
        // Fallback defaults (minimal)
        self.map = [
            "apple": "apple.logo",
            "banana": "leaf",
            "broccoli": "leaf",
            "artichoke": "leaf",
            "bagel": "fork.knife",
            "baked goods": "birthday.cake",
            "beer": "wineglass",
            "bell pepper": "leaf",
            "bread": "birthday.cake",
            "cake": "birthday.cake",
            "candy": "birthday.cake",
            "carrot": "leaf",
            "cheese": "fork.knife",
            "chicken": "fork.knife",
            "coconut": "leaf",
            "coffee": "cup.and.saucer",
            "coffee cup": "cup.and.saucer",
            "cookie": "birthday.cake",
            "crab": "fish",
            "cream": "cup.and.saucer",
            "croissant": "birthday.cake",
            "cucumber": "leaf",
            "dairy product": "cup.and.saucer",
            "dessert": "birthday.cake",
            "donut": "birthday.cake",
            "egg (food)": "fork.knife",
            "fast food": "fork.knife",
            "fish": "fish",
            "food": "fork.knife",
            "fruit": "leaf",
            "frying pan": "fork.knife",
            "garden asparagus": "leaf",
            "grape": "leaf",
            "grapefruit": "leaf",
            "guacamole": "leaf",
            "hamburger": "fork.knife",
            "hot dog": "fork.knife",
            "juice": "cup.and.saucer",
            "kettle": "cup.and.saucer",
            "lemon": "leaf",
            "milk": "cup.and.saucer",
            "muffin": "birthday.cake",
            "mug": "mug",
            "mushroom": "leaf",
            "orange": "leaf",
            "pancake": "birthday.cake",
            "pasta": "fork.knife",
            "pastry": "birthday.cake",
            "peach": "leaf",
            "pear": "leaf",
            "pineapple": "leaf",
            "pizza": "fork.knife",
            "plate": "fork.knife",
            "potato": "leaf",
            "pretzel": "birthday.cake",
            "pumpkin": "leaf",
            "radish": "leaf",
            "salad": "leaf",
            "sandwich": "fork.knife",
            "seafood": "fish",
            "shellfish": "fish",
            "shrimp": "fish",
            "snack": "fork.knife",
            "strawberry": "leaf",
            "sushi": "fork.knife",
            "taco": "fork.knife",
            "tea": "cup.and.saucer",
            "teapot": "cup.and.saucer",
            "tomato": "leaf",
            "vegetable": "leaf",
            "waffle": "birthday.cake",
            "wine": "wineglass",
            "wine glass": "wineglass",
            "watermelon": "leaf",
            "zucchini": "leaf",
            "chair": "chair",
            "plant": "leaf",
            "table": "chair",
            "desk": "chair",
            "sofa": "chair",
            "couch": "chair",
            "bed": "bed.double",
            "lamp": "lightbulb",
            "flower": "leaf",
            "tree": "leaf"
        ]
    }

    private func loadRules() {
        if let url = Bundle.main.url(forResource: "IconRules", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Rule].self, from: data) {
            self.rules = decoded
            return
        }
        // Fallback to baked-in rules
        self.rules = Self.fallbackRules
    }

    func symbolName(for label: String) -> String? {
        let key = label.lowercased()
        if let mapped = map[key] { return mapped }
        for rule in rules {
            if rule.keywords.contains(where: { key.contains($0) }) {
                return rule.symbol
            }
        }
        // No mapping found — return nil so callers can choose to show text-only
        return nil
    }

    func icon(for label: String) -> UIImage? {
        if let name = symbolName(for: label) {
            return UIImage(systemName: name)
        }
        return nil
    }
}
