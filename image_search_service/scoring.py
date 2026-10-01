"""Relevance scoring: deciding which search result is the actual product.

Search engines happily return a phone case, a shopfront or an unrelated
variant for "Amul Butter 500g". A candidate is only accepted when the
*product* words are present, and it is heavily demoted when the brand named
in the sheet is missing from the result's own text.
"""

import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set

from . import config, textutil
from .models import ImageCandidate, ProductQuery

# How much each signal contributes to the final score.
#
# The three weights plus the bonuses below are budgeted to reach exactly 1.0
# on a perfect match. An earlier version summed to 1.0 in the weights alone
# and then added bonuses on top, which pushed every good result past 1.0 and
# clamped them all to the same value — the top of the grid became unordered
# and the best match was effectively random.
W_NAME = 0.45
W_BRAND = 0.25
W_SOURCE = 0.15

# Ceiling for an image that is provably not the product (see
# NOT_THE_PRODUCT). Deliberately below the 0.55 attach threshold in config so
# such a result can still be shown and hand-picked, never auto-attached.
DISQUALIFIED_SCORE = 0.45

# Sources that are a database of products rather than a photo library. An
# entry here was catalogued as an item for sale, so its photo is of that item
# and its name is the manufacturer's, which lets a synonym in the vendor's
# sheet ("Maggi Instant Noodles" vs "Nestle Maggi Noodles Masala") pass.
PRODUCT_DATABASE_SOURCES = {"openfoodfacts"}

# Query tiers that named the brand, so a result without it is a genuine miss.
# "generic" is the exception and is deliberately absent: that tier asks for the
# product on its own terms. See the brand block in ``score_candidate``.
BRAND_REQUESTING_TIERS = {"branded", "relaxed"}

# Bonus budget: 0.15 in total.
B_NAME_PHRASE = 0.06
B_BRAND_PHRASE = 0.03
B_VARIANT = 0.03
B_PACKSHOT = 0.03

# A caption can mention the product while the photograph shows something else
# entirely — "lunch with paratha, dahi, pickle and Amul butter" is a lunch
# photo, not a pack shot. These words demote a result towards the bottom of
# the grid without hiding it, since the vendor can still pick it.
SCENE_WORDS = {
    # meals and kitchens
    "lunch", "dinner", "breakfast", "meal", "meals", "table", "dining",
    "restaurant", "cafe", "kitchen", "cooking", "recipe", "recipes", "dish",
    "plate", "plates", "thali", "curry", "paratha", "daal", "dahi", "pickle",
    # places and events
    "street", "market", "shop", "store", "shelf", "supermarket", "cart",
    "people", "woman", "man", "child", "family", "crowd", "hands",
    "festival", "wedding", "party", "celebration", "poster", "advertisement",
    "advertising", "billboard", "mural", "painting", "statue", "stamp",
    "book", "cover", "newspaper", "magazine", "logo", "sign", "signboard",
    # Offices, companies and places. Brand names are frequently also common
    # words ("Tata", "Reliance", "Bajaj"), so a brand match alone can pull in a
    # photograph of a corporate office.
    "services", "service", "sector", "road", "street", "station", "bus",
    "metro", "airport", "terminal", "company", "corporate", "ltd", "limited",
    "group", "tower", "building", "headquarters", "office", "bank", "branch",
    "atm", "hospital", "clinic", "school", "college", "university", "museum",
    "bridge", "flyover", "city", "district", "sector", "complex", "centre",
    "center", "hotel", "hotel", "mall", "park", "stadium", "railway", "port",
    # Old, cross-sectioned and scrapyard photography. A Victorian stroller and
    # a lamp sawn open to show its filament both contain every word of the
    # product, and both are useless as a catalogue card.
    "vintage", "antique", "inside", "scrapyard", "derelict", "rusty",
    # Somebody else using, carrying or riding the product. A brand name on a
    # delivery scooter or a courier's jacket is not a photograph of the item.
    #
    # Deliberately narrower than it first looks. "Truck", "bike", "van" and
    # "package" are ordinary product words -- a Truck Battery and a Bike Tyre
    # are real catalogue rows -- so only the words that describe the transport
    # or the act are here, never the vehicle names themselves.
    "delivery", "courier", "rider", "riders", "scooters", "motorbike",
    "motorcycle", "cargo", "parcel", "parcels", "shipment", "shipments",
    "dispatch", "dispatched", "warehouse", "couriers", "deliveries",
    "driver", "driving", "riding", "runner", "runners", "wearing", "carrying",
    "haulage", "hauling", "logistics", "fulfilment", "fulfillment",
    "distributed", "distributor", "distributors", "wholesale", "retailer",
}

# Printed matter is a scene everywhere except in the category that sells it.
# "book", "cover" and "magazine" are scene words because they reject "Facebook
# cover photo" and a magazine advert standing in for a kitchen sponge. But a
# book has no photograph other than its cover, so applying them to the Books
# category left every book row with nothing to attach.
#
# The exemption is per category and as narrow as the category earns, because
# overreaching here is how the wrong thing happens twice: a "Book Stand" row
# lost its "on a magazine in a library" demotion when the Books category
# dropped *every* media word. So each category is only granted the forms it
# actually sells. Words naming a product's own form ("book", "newspaper") never
# need this -- ``own_words`` already subtracts them -- so what is left here is
# the words that appear only on a file: "cover" above all, which is what was
# holding the Books category at 0/4.
MEDIA_FORM_WORDS: Dict[str, Set[str]] = {
    "books": {"book", "books", "cover", "coverpage", "dust", "jacket"},
    "book": {"book", "books", "cover", "coverpage", "dust", "jacket"},
    "stationery": {"cover", "coverpage", "printed"},
    "media": {
        "book", "books", "cover", "coverpage", "magazine", "newspaper",
        "novel", "paperback", "hardcover", "jacket", "dvd", "bluray",
    },
    "music": {"album", "sleeve", "cover", "coverpage", "tracklist"},
    "movies": {"poster", "cover", "coverpage", "dvd", "bluray"},
    "films": {"poster", "cover", "coverpage", "dvd", "bluray"},
    "comics": {"cover", "coverpage", "issue", "panel", "page"},
}

# Retail packaging vocabulary: a strong hint that the photo is a usable
# product image rather than incidental.
PACKSHOT_WORDS = {
    "pack", "packs", "packet", "packets", "pouch", "pouches", "bottle",
    "bottles", "box", "boxes", "jar", "jars", "tube", "tubes", "sachet",
    "sachets", "tin", "tins", "can", "cans", "carton", "blister", "strip",
    "bundle", "wrapped", "packaging", "label", "labels", "retail", "aisle",
    "supermarket", "store", "shelf", "product", "products", "front",
    "isolated", "transparent", "background", "studio", "closeup", "close",
}

# Words that make an image definitively *not* a picture of the product, no
# matter how well the product name happens to appear in the file name.
#
# SCENE_WORDS above only demotes, because a meal photo of butter is still
# worth showing the vendor. These are different: a costume, a doll or an office
# building is never the item being sold, and token overlap alone happily
# matched them. "Amul Butter Girl Costume" contains the brand, contains the
# product name verbatim at position 0, and scored 0.925 — high enough to be
# auto-attached to a block of butter.
#
# A candidate carrying any of these is hard-capped below the attach threshold.
# It stays in the grid (the vendor can still choose it) but is never attached
# automatically, so a bad guess can cost a tap, never a product's photo.
#
# Only words *outside* the product's own name count — see
# ``_not_the_product``. Otherwise "Johnson's Baby Soap" would be disqualified
# by the word that names it, and "Amul Butter Pack" by "pack".
NOT_THE_PRODUCT = {
    # costumes, mascots and toys
    "costume", "costumes", "costumed", "costuming", "costumeball",
    "dress", "dresses", "uniform", "uniforms", "mascot", "witch", "clown",
    "santa", "doll", "dolls", "figurine", "figurines", "puppet",
    "plush", "stuffed", "merchandise", "swag",
    # people, by name or description
    "girl", "girls", "boy", "boys", "lady", "ladies", "gentleman",
    "kid", "kids", "person", "people", "crowd", "audience", "portrait",
    "headshot", "actor", "actress", "singer", "cricketer", "politician",
    "mannequin", "mannequins",
    # buildings, places and institutions
    "shop", "shops", "shopfront", "store", "stores", "showroom", "outlet",
    "warehouse", "branch", "atm", "bank", "banks", "campus", "headquarters",
    "hospital", "clinic", "stadium", "airport", "railway", "flyover",
    "highway", "overpass", "intersection", "mansion", "flat", "apartment",
    # documents, marks and artwork
    "logo", "logos", "wordmark", "billboard", "mural", "poster", "posters",
    "stamp", "stamps", "banknote", "coin", "cartoon", "meme", "screenshot",
    "plaque", "trophy", "medal", "manuscript", "comic",
}

# The product is in the picture, but the picture cannot be a catalogue card.
#
# NOT_THE_PRODUCT above covers a different object entirely. This covers the
# right object photographed or labelled in a way no retailer would use: a
# smashed hammer, a bat somebody left in a condemned cricket club, an AI
# prompt that leaked into the file name, a lamp cut open to show the filament.
# These scored between 0.76 and 0.79 and were being auto-attached, because a
# photograph of a broken hammer really does contain every word for a hammer.
#
# Kept apart from SCENE_WORDS, which only demotes. A meal photograph of butter
# is a useful hint to a vendor; a photograph of a broken hammer is not a
# picture of the hammer being sold, however many of the product's own words it
# happens to contain.
NOT_PRODUCT_PHOTOS = {
    # damaged, discarded or taken apart
    "broken", "shattered", "busted", "damaged", "wrecked", "wreck",
    "crushed", "dismantled", "disassembled", "abandoned", "derelict",
    "discarded", "demolished", "rusted", "corroded", "splintered",
    "shrivelled", "dented", "wornout",
    # a how-to rather than an item
    "diy", "tutorial", "homemade", "restoration", "reconditioned",
    # the file is not a photograph of an object at all
    "hyperrealistic", "photorealistic", "midjourney", "mockup", "template",
    "vector", "illustration", "render", "rendered", "rendering", "prompt",
    "stencil", "composite", "collage",
}

# The right object, but a picture of a *piece* of it rather than the item a
# customer buys. "Head of a hammer drill close-up" contains the word hammer and
# sells a drill bit; the vendor asked for a hammer.
#
# Every phrase here takes "of" or "on", which is what keeps the ordinary
# pack-shot vocabulary safe. "Closeup wooden chair" is a fine catalogue image
# and never matches, because there is no "of" to complete the phrase.
PART_PHOTOS = re.compile(
    r"\b(?:head|close[\s-]?up|detail|part|inside|underside|macro|"
    r"cross[\s-]?section|interior)\s+(?:shot\s+|view\s+|image\s+)?of\b"
    r"|\bmacro\s+shot\b"
)

# Geograph is a British and Irish place-photography project: every file on it is
# a street scene, and the file name always carries the site and a six-digit
# grid reference. A Domino's Pizza row was being filled with a shopfront in
# Plainmoor because the brand name appears on the building.
#
# Matched on the site name rather than on any single place word, so a catalogue
# product that happens to share a town name with a Geograph file is unaffected.
PLACE_PHOTO_SITES = re.compile(
    r"\bgeograph\b|images\s+from\s+geograph"
)

# A grocery catalogue sells the raw ingredient, so a photograph of the finished
# dish is a different product: mutton arrives as samosas, toor dal as pakodas,
# chicken breast in a burrito bowl. The ingredient is named and the dish is not,
# so every word of the product matches and the score looks high.
#
# ``own_words`` subtraction is what makes this safe. A vendor really selling
# "Idli Sambar" or "Toor Dal Pakoda" has the dish word in the product name, so
# the photograph is left alone.
# Same ceiling as DISQUALIFIED_SCORE: below the attach threshold, still offered
# to the vendor in the grid.
UNUSABLE_PHOTO_SCORE = 0.45

# A grocery catalogue sells the raw ingredient, so a photograph of the finished
# dish is a different product: mutton arrives as samosas, toor dal as pakodas,
# chicken breast inside a burrito bowl. Such a title names the ingredient and not
# the dish, so every word of the product matches and the score reads high.
# Every word here has to name a specific preparation. "dish"/"dishes" is
# deliberately absent: Commons categorises every food file "Toor dal dishes", so
# the word describes the file's category and not the photograph. "milk" and the
# other bare ingredients are absent for the same reason -- "amul butter milk
# amul" is the pack shot of a butter, not a dish.
#
# ``own_words`` subtraction in ``_cooked_dish_photo`` is the other half of the
# safety: a sheet that really sells "Idli Sambar" or "Toor Dal Pakoda" has the
# dish word in the product name, so its photograph is left alone.
PREPARED_FOOD = {
    # a named preparation rather than the raw ingredient
    "samosa", "pakora", "pakoda", "bhaji", "chaat", "bhel", "puri", "paratha",
    "chapati", "roti", "naan", "dosa", "idli", "vada", "uttapam", "upma",
    "poha", "biryani", "pulao", "pilaf", "tikka", "tandoori", "korma",
    "vindaloo", "butterchicken", "roganjosh", "curry", "masala", "gravy",
    "kebab", "kebabs",
    # a sweet that is made, not harvested
    "halwa", "laddu", "ladoo", "jalebi", "barfi", "rasgulla", "kheer",
    # served or cut, so the buyer sees the meal instead of the item
    "sandwich", "burger", "wrap", "toast", "omelette", "omelet", "fries",
    "chips", "noodles", "pasta", "pizza", "salad", "raita", "chutney",
    "pickle", "soup", "stew", "risotto", "smoothie", "lassi", "sherbet",
    "cocktail", "plate", "bowl", "platter", "thali", "meal", "recipe",
    # how it was made, which is never on a catalogue pack shot
    "cooked", "frying", "fry", "fried", "roasted", "boiled", "steamed",
    "grilled", "baked", "marinated", "dough", "batter", "stuffing",
}

# Matching form of PREPARED_FOOD, built once at import.
_PREPARED_FOOD_SINGULAR = {textutil._singular(w) for w in PREPARED_FOOD}

# Only applied when the product itself is an ingredient, so that a "Cake Stand"
# or "Chopping Board" is unaffected by the word "plate" or "bowl".
_FOOD_TOKENS = {
    "mutton", "chicken", "beef", "pork", "fish", "prawn", "shrimp", "lobster",
    "lentil", "dal", "daal", "masoor", "toor", "chana", "chole", "rajma",
    "urad", "moong", "gram", "wheat", "flour", "atta", "maida", "semolina",
    "rice", "sugar", "salt", "spice", "spices", "masala", "cumin", "turmeric",
    "chilli", "pepper", "garlic", "ginger", "onion", "tomato", "potato",
    "milk", "ghee", "butter", "cheese", "paneer", "cream", "yogurt",
    "yoghurt", "curd", "honey", "jam", "oil", "juice", "tea", "coffee",
    "chocolate", "nuts", "nut", "seeds", "dry", "powder", "juice",
}

# How many missing words in a row count as a description of the product
# rather than a claim about which product it is. See
# ``_presentation_only_gap``.
PRESENTATION_MIN_RUN = 2

# Small ranking penalty for a match that needed the relaxation below, so a
# photograph whose file name really does carry the whole name still sorts
# above one that merely said most of it.
PRESENTATION_PENALTY = 0.95

# Source weights: how likely a provider is to lead with the product itself.
SOURCE_TRUST = {
    "serpapi": 1.00,        # Google Images tiles are the closest to "the photo"
    "google_cse": 0.96,
    "openfoodfacts": 0.95,  # a product database: the photo is of the item
    "pexels": 0.92,
    "unsplash": 0.88,
    "wikimedia": 0.90,      # genuinely the product, often a clean studio shot
    "openverse": 0.74,      # aggregated CC content, noisier metadata
    "grid": 0.70,           # picked by hand from the grid, metadata unknown
}


@dataclass
class Target:
    """The token-level representation of the product being pictured."""

    name_tokens: Set[str]
    brand_tokens: Set[str]
    variant_tokens: Set[str]
    core_phrase: str
    brand_phrase: str
    barcode: str
    # The name's tokens in order, without the 8-token cap that ``core_phrase``
    # needs for a search query. The head noun is the last of these, and the
    # cap would hide it on any long Indian product name.
    name_sequence: List[str] = field(default_factory=list)
    # The product's own words, stop words included. A word the product is
    # actually called cannot be evidence that a photo shows something else, so
    # disqualification subtracts these.
    own_words: Set[str] = field(default_factory=set)
    # The product's name and brand exactly as the sheet gave them, needed for
    # the pattern rules in ``_not_a_product_photo`` where the dropped "of" in
    # ``core_phrase`` would hide the very phrase being exempted.
    raw_name: str = ""
    # Category, kept so scene-word exemptions can look up without passing
    # product around.
    category: str = ""

    @property
    def core_tokens(self) -> Set[str]:
        return self.name_tokens | self.brand_tokens


def build_target(product: ProductQuery) -> Target:
    core_name = textutil.strip_variant(product.name, product.variant)
    return Target(
        name_tokens=textutil.token_set(core_name or product.name),
        brand_tokens=textutil.token_set(product.brand),
        variant_tokens=textutil.token_set(product.variant),
        core_phrase=textutil.name_phrase(core_name or product.name),
        brand_phrase=textutil.name_phrase(product.brand),
        barcode=textutil.clean(product.barcode),
        name_sequence=textutil.tokens(core_name or product.name),
        own_words=textutil.words(
            " ".join(
                p
                for p in (
                    core_name or product.name,
                    product.brand,
                    product.variant,
                    product.subcategory,
                    product.category,
                )
                if p
            )
        ),
        raw_name=" ".join(
            p for p in (product.name, product.brand, product.variant) if p
        ),
        category=product.category or "",
    )


def _quality_factor(candidate: ImageCandidate) -> float:
    """Multiplier applied to the whole score.

    It has to be multiplicative: an 80x80 thumbnail can otherwise collect every
    text bonus and still score 1.0, which would hand the vendor a 40-pixel
    image for a product that has a 1200px shot available.
    """
    long_edge = max(candidate.width or 0, candidate.height or 0)
    if long_edge <= 0:
        factor = 0.80  # unknown size: mild penalty, not a rejection
    elif long_edge < 240:
        factor = 0.15  # unusable as catalogue imagery
    elif long_edge < 400:
        factor = 0.50
    elif long_edge < 700:
        factor = 0.80
    else:
        factor = 1.0
    return factor * _aspect_factor(candidate)


def _aspect_factor(candidate: ImageCandidate) -> float:
    """Extreme panoramas or 1-pixel-tall strips make poor product cards."""
    w, h = candidate.width or 0, candidate.height or 0
    if w <= 0 or h <= 0:
        return 1.0
    ratio = w / h
    if 0.55 <= ratio <= 1.9:
        return 1.0
    return 0.7


def _primary_text(candidate: ImageCandidate) -> str:
    """The field that identifies the image: a file name, alt text or page title.

    Scored on its own, because a file called "Amul Butter 500g Pack.jpg" is a
    pack shot and a caption mentioning Amul butter inside a paragraph about a
    wedding lunch is not.
    """
    return candidate.title or ""


def _support_text(candidate: ImageCandidate) -> str:
    """Weaker, longer-form evidence: descriptions, tags, the source page."""
    parts = [candidate.tags]
    if candidate.source_page:
        parts.append(candidate.source_page)
    return " ".join(p for p in parts if p)


def _phrase_position(text: str, phrase: str) -> Optional[int]:
    """Word offset of [phrase] in [text], or None when it is absent."""
    if not phrase:
        return None
    words = text.split()
    target = phrase.split()
    if not words or not target:
        return None
    for index in range(len(words) - len(target) + 1):
        if words[index : index + len(target)] == target:
            return index
    return None


def _cover(primary: str, support: str, needle: Set[str]) -> float:
    """Coverage, where supporting evidence counts slightly less than the
    image's own title."""
    if not needle:
        return 0.0
    primary_cov = textutil.coverage(needle, textutil.token_set(primary))
    support_cov = textutil.coverage(needle, textutil.token_set(f"{primary} {support}"))
    return max(primary_cov, 0.85 * support_cov)


def _not_the_product(candidate: ImageCandidate, target: Target) -> Set[str]:
    """Words proving the image is not the item, ignoring the product's own name.

    A word only disqualifies when it is *extra* to the product. "Baby" in
    "Johnson's Baby Soap" is part of what is being sold, so it must not
    disqualify the pack shot; "Girl" in "Amul Butter Girl Costume" is not.
    Comparing against the target's own words rather than a fixed list of
    exceptions keeps this correct for any product, including ones invented
    after this code was written.
    """
    seen = textutil.words(
        f"{_primary_text(candidate)} {_support_text(candidate)} "
        f"{candidate.full_url} {candidate.source_page or ''}"
    )
    return (seen & NOT_THE_PRODUCT) - target.own_words


def _not_a_product_photo(candidate: ImageCandidate, target: Target) -> Set[str]:
    """Words proving the image cannot be used as catalogue imagery.

    Same shape as ``_not_the_product`` and for the same reason: a word the
    product is itself called cannot count against it, so "Vintage Wall Clock"
    is not disqualified by "vintage".
    """
    seen = textutil.words(
        f"{_primary_text(candidate)} {_support_text(candidate)} "
        f"{candidate.full_url} {candidate.source_page or ''}"
    )
    blocked = (seen & NOT_PRODUCT_PHOTOS) - target.own_words

    # The two patterns cannot be subtracted word by word the way the sets above
    # can, so each is compared against the product's own name instead. A row
    # that really is called "Head of a Hammer" keeps its photograph.
    blob = textutil.clean(
        f"{_primary_text(candidate)} {_support_text(candidate)} "
        f"{candidate.source_page or ''}"
    )
    # ``core_phrase`` drops the "of", so the product name has to be compared in
    # its raw cleaned form: "Head of a Hammer" must be seen to contain the
    # pattern for its own photograph to survive.
    if PART_PHOTOS.search(blob) and not PART_PHOTOS.search(
        textutil.clean(target.raw_name)
    ):
        blocked.add("part")
    if PLACE_PHOTO_SITES.search(blob) and not PLACE_PHOTO_SITES.search(
        textutil.clean(target.raw_name)
    ):
        blocked.add("place")
    return blocked


def _cooked_dish_photo(candidate: ImageCandidate, target: Target) -> Set[str]:
    """Words showing the ingredient has been turned into a meal.

    A grocery catalogue sells the raw ingredient, so "al kabeer mutton samosas"
    is not a picture of mutton and "toor dal pakodas" is not a picture of dal.
    The title names the ingredient and not the dish, so every word of the
    product matches and the score reads high.

    Subtracting ``own_words`` is what keeps this honest: a vendor genuinely
    selling "Idli Sambar" or "Toor Dal Pakoda" has the dish word in the product
    name, so its photograph is left alone.
    """
    if not (target.core_tokens & _FOOD_TOKENS):
        return set()
    seen = textutil.words(
        f"{_primary_text(candidate)} {_support_text(candidate)}"
    )
    # Titles pluralise freely -- "samosas", "pakodas" -- so both sides are
    # compared in the singular, reusing the normalisation the rest of scoring
    # already relies on. Comparing raw forms would let "pakodas" dodge the
    # "pakoda" a vendor sells under, and re-introduce the very bug this fixes.
    own = {textutil._singular(w) for w in target.own_words}
    return {
        w
        for w in seen
        if textutil._singular(w) in _PREPARED_FOOD_SINGULAR
        and textutil._singular(w) not in own
    }


def _noun_alias_hit(candidate: ImageCandidate, target: Target) -> Set[str]:
    """Words showing the photograph is of a neighbouring object, not the product.

    "Three leather belt attachment pouches" shares every word of a "Leather
    Belt" row -- the alias table in ``config`` records that a ``pouch`` next to
    ``belt`` means the pouch is the subject -- so without this the row attaches a
    photograph of three pouches at 0.77. Likewise "Face Cream En Vivo 10 Anos",
    which is a photograph of a Mexican banda.

    The key has to be in the product's own name for the rule to mean anything,
    and ``own_words`` is subtracted before the test so a vendor genuinely selling
    "Belt Pouch" or "SIM Card" is left alone. Deliberately a hand-written table
    rather than a general head-noun heuristic: two attempts at the general rule
    each caught one wrong image and lost four correct ones, because "hammer
    drill" is textually identical in shape to "head of a hammer drill".
    """
    if not target.name_tokens:
        return set()
    image_text = f"{_primary_text(candidate)} {_support_text(candidate)}"
    seen_singular = {textutil._singular(w) for w in textutil.words(image_text)}
    own = {textutil._singular(w) for w in target.own_words}
    hits: Set[str] = set()
    for key, aliases in config.Config.NOUN_ALIASES.items():
        # Keys may be multi-word ("face cream"), and a set of tokens can never
        # contain a phrase, so a phrase key is matched against the name phrase.
        key_present = (
            textutil.contains_phrase(target.core_phrase, key)
            if " " in key
            else key in target.name_tokens
        )
        if not key_present:
            continue
        for alias in aliases:
            # An alias may itself be a phrase -- "en vivo" is how the photo
            # names the banda -- and a bag of tokens cannot hold a phrase, so
            # multi-word aliases are matched against the image text directly.
            # The own-word guard still applies per word: a sheet selling
            # "Face Cream En Vivo" is exempt, and one selling just "Face Cream"
            # has nothing to exempt because "en vivo" is not its name.
            alias_words = {textutil._singular(w) for w in textutil.words(alias)}
            if alias_words & own:
                continue
            if " " in alias:
                if textutil.contains_phrase(image_text, alias):
                    hits.add(alias)
            elif textutil._singular(alias) in seen_singular:
                hits.add(alias)
    return hits


def _presentation_only_gap(
    candidate: ImageCandidate, target: Target, primary: str, scene_hits: int
) -> bool:
    """True when the name is missing from the title *only* as a run of
    adjectives describing the product.

    Indian FMCG sheet names are long and modifier-heavy -- "Britannia Good Day
    Choco Vanilla Creamy Filled Biscuit" is photographed as "Britannia Good Day
    Biscuit" -- and no file name carries the padding. Requiring the whole
    phrase rejected the correct photograph for essentially every long Indian
    product name, which is what this exists to undo.

    Four conditions, all of them needed:

    1. A run of at least ``PRESENTATION_MIN_RUN`` missing words sits together
       immediately before the head noun, so the gap is a phrase of modifiers
       and not a scattered subset of the name. This is what keeps "Maggi
       Instant Noodles" from matching "Maggi Masala Noodles": one missing word
       is a product claim, not a description.
    2. Nothing in the image's text contradicts the sheet. An extra word that
       is neither packaging nor scene vocabulary means the photograph is of a
       *different* item -- "Britannia Good Day Butter Biscuit" is not a "Choco
       Vanilla" row, and would otherwise sail through on the strength of the
       four adjectives it happens to share.
    3. The brand leads the image's own text, as it must for any other match.
    4. No scene and no disqualifying words, which together keep "Tata
       Consultancy Services - Ring Road Sector V" and "Amul Butter Girl
       Costume" out of a relaxed match.
    """
    if scene_hits or _not_the_product(candidate, target):
        return False
    if target.brand_tokens and not textutil.contains_phrase(primary, target.brand_phrase):
        return False

    sequence = target.name_sequence
    if len(sequence) < PRESENTATION_MIN_RUN + 1:
        return False

    present = textutil.token_set(primary)
    run = 0
    for word in reversed(sequence[:-1]):
        if word in present:
            break
        run += 1
    if run < PRESENTATION_MIN_RUN:
        return False

    unaccounted = present - target.core_tokens - target.variant_tokens
    return not (unaccounted - PACKSHOT_WORDS - SCENE_WORDS)


def _head_noun_substituted(target: Target, primary: str) -> bool:
    """True when the image names the same item under a *different* name word.

    A product database is exempt from the verbatim rule because the
    manufacturer names things differently from a vendor sheet, but that
    exemption was too generous: Open Food Facts answers a full-text search
    with sibling variants of the same brand, so "Tata Salt Iodised" was
    auto-attached a photograph of "Tata Salt Lite" -- a different product, and
    one whose name actively contradicts the sheet.

    The last word of the name is the one that says what the item is, so its
    absence is the signal. Its absence alone is not enough, though: the
    database's own wording is allowed to differ, and "Britannia Good Day
    Biscuit" is catalogued as "Britannia Good Day Cashew Cookie", which is the
    same shop's biscuit under another name. What makes "Lite" a substitution
    is that the entry supplies a *different* word in the noun's place. So both
    halves are required: the noun gone, and something put in its place.
    """
    sequence = [w for w in target.name_sequence if not w.isdigit()]
    if len(sequence) < 2:
        return False
    head = sequence[-1]
    if head in target.brand_tokens:
        return False
    if textutil.contains_phrase(primary, head):
        return False
    added = (
        textutil.token_set(primary)
        - target.core_tokens
        - target.variant_tokens
        - PACKSHOT_WORDS
        - SCENE_WORDS
    )
    return bool(added)


def score_candidate(
    candidate: ImageCandidate, target: Target, min_name_coverage: float = 0.5
) -> ImageCandidate:
    """Returns the candidate with its score and brand_match filled in."""
    primary = _primary_text(candidate)
    support = _support_text(candidate)
    everything = f"{primary} {support}".strip()
    everything_tokens = textutil.token_set(everything)

    name_cov = _cover(primary, support, target.name_tokens)
    has_brand = bool(target.brand_tokens)
    # The brand has to appear in the image's *own* title, not merely somewhere
    # in the surrounding description or category list. Several free image APIs
    # tag loosely, and accepting a brand mention from a tag is what let
    # "Charcoal Toothpaste" pass as a match for Colgate Strong Teeth.
    brand_match = (not has_brand) or textutil.contains_phrase(primary, target.brand_phrase)

    score = W_NAME * name_cov + W_SOURCE * SOURCE_TRUST.get(candidate.source, 0.7)

    if has_brand:
        if brand_match:
            score += W_BRAND + B_BRAND_PHRASE
        elif candidate.tier in BRAND_REQUESTING_TIERS:
            # The sheet named a brand, the query we sent asked for it by name,
            # and the result does not lead with it: most likely a look-alike
            # product or a category photo.
            #
            # A "generic" tier result is exempt. That query was built with the
            # brand deliberately removed, so its absence is the answer to the
            # question rather than a miss, and it still collects the bonus above
            # if the brand turns out to be in the text after all. Without this
            # exemption the demotion landed on exactly the rows that had just
            # been rescued: nearly every photograph of an Indian FMCG brand
            # that is not catalogued in a product database is filed under the
            # plain product name, so penalising those is what collapsed branded
            # coverage to a fifth of unbranded coverage.
            score *= 0.3
    else:
        score += W_BRAND * 0.5  # no brand known, stay neutral

    # The whole product name appearing verbatim is a strong signal, and the
    # earlier it appears the more the file is about the product.
    position = _phrase_position(primary, target.core_phrase)
    if position is not None:
        early = max(0.0, 1.0 - min(position, 10) / 10.0)
        score += B_NAME_PHRASE * (0.5 + 0.5 * early)
    elif textutil.contains_phrase(everything, target.core_phrase):
        score += B_NAME_PHRASE * 0.4  # only the description mentions it
    # A size/flavour match means the photo is the right SKU, not the family.
    if target.variant_tokens and textutil.coverage(target.variant_tokens, everything_tokens) >= 0.5:
        score += B_VARIANT

    # Pack-shot vocabulary, then a demotion for scene photography.
    tokens = textutil.token_set(everything)
    if tokens & PACKSHOT_WORDS:
        score += B_PACKSHOT
    # ``own_words`` is subtracted so that a product genuinely called
    # "Truck Battery" or "Bike Tyre" is not demoted by its own name. Without
    # this, "Penske Truck Leasing Exide Battery" loses its photograph to the
    # word "truck" describing the haulier rather than the battery.
    exempt = MEDIA_FORM_WORDS.get(textutil.clean(target.category))
    scene_words = SCENE_WORDS - exempt if exempt else SCENE_WORDS
    scene_hits = len(tokens & (scene_words - target.own_words))
    if scene_hits:
        score *= 0.45 if scene_hits >= 3 else 0.65

    # Auto-attaching needs the product name to appear in the image's *own*
    # title. Token overlap alone is not enough: "Tata Consultancy Services
    # - Ring Road Sector V - Salt Lake City" contains both "tata" and "salt",
    # and scored a perfect match for Tata Salt before this rule existed. Such a
    # result stays in the grid for the vendor to choose, but is never attached
    # automatically.
    #
    # A run of descriptive adjectives is the one gap that is forgiven, because
    # otherwise every long Indian product name is unmatchable -- see
    # ``_presentation_only_gap`` for the conditions that keep the exception
    # from admitting the wrong product.
    #
    # The other exception is a curated product database. A sheet row reading "Maggi
    # Instant Noodles" matches the database entry "Nestle Maggi Noodles Masala"
    # — the same item, named the way the manufacturer named it. Requiring the
    # sheet's exact wording would throw away the best photo in the result set
    # over a synonym, so these sources are held to name coverage and the brand
    # instead. A web image gets no such benefit: its file name is written by
    # whoever uploaded it, and carries no such guarantee.
    if (
        target.core_phrase
        and candidate.source not in PRODUCT_DATABASE_SOURCES
        and not textutil.contains_phrase(primary, target.core_phrase)
    ):
        if _presentation_only_gap(candidate, target, primary, scene_hits):
            score *= PRESENTATION_PENALTY
        else:
            score = min(score, 0.50)

    if candidate.source in PRODUCT_DATABASE_SOURCES and _head_noun_substituted(
        target, primary
    ):
        # Exempt from the verbatim rule, not from being the same product.
        score = min(score, 0.50)

    score *= _quality_factor(candidate)

    if name_cov < min_name_coverage and not textutil.contains_phrase(
        everything, target.core_phrase
    ):
        # Not recognisably the same product — leave it for the manual picker
        # but never auto-attach it.
        score = min(score, 0.45)

    # A costume, an office or a scanned barcode is never the item being sold,
    # whatever else the file name says. Capped below the attach threshold
    # rather than dropped, so the vendor still sees it and can choose it
    # deliberately.
    if _not_the_product(candidate, target):
        score = min(score, DISQUALIFIED_SCORE)

    # Right object, unusable picture: a smashed hammer, a condemned club's bat,
    # a leaked AI prompt. Same treatment, kept as its own check so the reason
    # is visible in the log.
    if _not_a_product_photo(candidate, target):
        score = min(score, UNUSABLE_PHOTO_SCORE)

    if _cooked_dish_photo(candidate, target):
        score = min(score, UNUSABLE_PHOTO_SCORE)

    if _noun_alias_hit(candidate, target):
        score = min(score, UNUSABLE_PHOTO_SCORE)

    candidate.score = round(max(0.0, min(1.0, score)), 4)
    candidate.brand_match = brand_match
    candidate.matched_by = "barcode" if _barcode_match(candidate, target) else None
    if candidate.matched_by is None:
        candidate.matched_by = "exact" if score >= 0.85 else "similar"
    if candidate.matched_by == "barcode":
        candidate.score = 1.0
    return candidate


def _barcode_match(candidate: ImageCandidate, target: Target) -> bool:
    if not target.barcode or len(target.barcode) < 8:
        return False
    haystack = f"{candidate.title} {candidate.tags} {candidate.source_page or ''} {candidate.full_url}"
    return target.barcode in textutil.clean(haystack)


def apply_brand_evidence(
    candidates: List[ImageCandidate], product: ProductQuery
) -> List[ImageCandidate]:
    """Re-checks generic-tier results against the *sheet's* brand.

    A generic-tier result is scored against the brand-free product, so its
    ``brand_match`` is vacuously true -- the target simply had no brand in it.
    That is the right thing for scoring, and the wrong thing for deciding
    whether a photograph may be attached without a human, because the evidence
    it needs is exactly the evidence that was removed. The vendor's grid and
    ``best_match`` both need to know whether the picture actually names the
    brand the sheet asked for, and only the original product knows that.

    In place, and returns the same list, so it can be called after ``rank``.
    """
    brand_phrase = textutil.name_phrase(product.brand)
    if not brand_phrase:
        return candidates
    for candidate in candidates:
        candidate.brand_match = textutil.contains_phrase(
            _primary_text(candidate), brand_phrase
        )
    return candidates


def rank(
    candidates: List[ImageCandidate], product: ProductQuery
) -> List[ImageCandidate]:
    """Scores, filters and sorts candidates best-first."""
    if not candidates:
        return []
    target = build_target(product)
    scored = [score_candidate(c, target) for c in candidates]
    good = [c for c in scored if c.score > 0]
    deduped = _dedupe(good)
    deduped.sort(key=lambda c: (c.score, c.width or 0), reverse=True)
    return deduped


def _dedupe(candidates: List[ImageCandidate]) -> List[ImageCandidate]:
    """One entry per distinct image, keyed on the URL without its query string."""
    seen = set()
    out: List[ImageCandidate] = []
    for c in candidates:
        key = c.hosted_url or c.full_url.split("?")[0].rstrip("/").lower()
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(c)
    return out


def best_match(
    candidates: List[ImageCandidate], min_score: float
) -> Optional[ImageCandidate]:
    """The single result good enough to attach without a human looking."""
    for c in candidates:
        if c.score < min_score:
            continue
        # A relaxed second-pass result is matched on a shortened phrase
        # ("Colgate Toothpaste"), so the brand has to be there too.
        if c.matched_by == "relaxed" and not c.brand_match:
            continue
        # A generic-tier result was found by a query that left the brand out,
        # so its score rests on the product name alone. That is not enough to
        # attach unattended: without the brand there is no evidence the picture
        # is of *this* item rather than of a rival's, and it duly attached
        # "Daikin ceiling suspended air conditioner" to a Voltas row and a
        # cricket club's abandoned bat to a Nivia one. It stays in the vendor's
        # grid, where one tap turns a guess into a decision, and only the
        # minority of generic hits that happen to name the brand attach.
        if c.tier == "generic" and not c.brand_match:
            continue
        return c
    return None
