"""Smoke tests for the image search pipeline.

Run with:  python3 -m pytest test_service.py -q     (or just run the file)

They do not hit the network except in ``test_live_wikimedia``, which is
skipped unless RUN_LIVE_TESTS=1.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from image_search_service import config, imaging, scoring, storage  # noqa: E402
from image_search_service.models import ImageCandidate, ProductQuery  # noqa: E402
from image_search_service.providers import (  # noqa: E402
    _off_thumbnail,
    asked_queries,
    asks_something_new,
    available_providers,
    build_queries,
    generic_product,
    relaxed_product,
)
from image_search_service.scoring import best_match, rank  # noqa: E402
from image_search_service.textutil import (  # noqa: E402
    clean,
    contains_phrase,
    coverage,
    strip_variant,
    token_set,
    tokens,
)
from image_search_service.textutil import _singular as textutil_singular  # noqa: E402
from image_search_service.textutil import token_set as textutil_token_set  # noqa: E402

FAILURES = []


def check(label, condition, detail=""):
    if condition:
        print(f"  PASS  {label}")
    else:
        print(f"  FAIL  {label} {detail}")
        FAILURES.append(label)


_URL_SEQ = iter(range(1, 10_000))


def candidate(title, source="wikimedia", width=1200, height=1200, page=None, tags=""):
    return ImageCandidate(
        full_url=f"https://example.com/img{next(_URL_SEQ)}.jpg",
        thumbnail_url="https://example.com/t.jpg",
        title=title,
        tags=tags,
        source=source,
        source_page=page,
        width=width,
        height=height,
    )


def off_candidate(title, width=400, height=400):
    """An entry as Open Food Facts would return it."""
    return candidate(title, source="openfoodfacts", width=width, height=height)


def scoring_module_min_accept():
    return config.Config.MIN_ACCEPT_SCORE


print("\n== textutil ==")
check("accents folded", clean("Crème Brûlée") == "creme brulee", clean("Crème Brûlée"))
check("trademark dropped", "registered" not in clean("Amul® Butter"))
check("size suffix split", tokens("500g") == ["500"], tokens("500g"))
check("stop words removed", "the" not in tokens("The Amul Butter"))
check(
    "variant stripped from name",
    strip_variant("Maggi 70g", "70g") == "maggi",
    strip_variant("Maggi 70g", "70g"),
)
check(
    "variant kept when unrelated",
    strip_variant("Tata Salt Iodised", "1kg") == "tata salt iodised",
)
check("coverage is a ratio", coverage({"a", "b"}, {"a", "b", "c"}) == 1.0)
check("token set drops filler", token_set("Amul Butter Pack of 2") == {"amul", "butter", "2"},
      token_set("Amul Butter Pack of 2"))

print("\n== query building ==")
p = ProductQuery(name="Amul Butter", brand="Amul", variant="500g", category="Grocery")
queries = build_queries(p)
check("brand is not repeated", queries[0] == "amul butter", queries)
check("no repeated size", all("500g" not in q for q in queries), queries)
check("no duplicate queries", len(queries) == len(set(queries)), queries)
check("second query adds the category", queries[1] == "amul butter grocery", queries)

barcode_q = build_queries(ProductQuery(name="Amul Butter", barcode="8901058000000"))
check("barcode is searched first", barcode_q[0] == "8901058000000", barcode_q)

generic = build_queries(ProductQuery(name="Butter", category="Grocery", subcategory="Dairy"))
check("generic name gets a category hint", "dairy" in generic[0].lower(), generic)

print("\n== ranking ==")
product = ProductQuery(name="Amul Butter", brand="Amul", variant="500g")
pack = candidate("Amul Butter 500g Pack", tags="amul butter")
same_text_other_source = candidate("Amul Butter 500g", source="pexels")
pool = [
    pack,
    same_text_other_source,
    candidate("Butter cake recipe", source="pexels"),
    candidate("Amul Gold Coin", tags="amul gold coin"),
    candidate("Amul Butter 500g", source="wikimedia", width=80, height=80),
]
ranked = rank(pool, product)
exact = {pack.full_url, same_text_other_source.full_url}
check("all candidates kept for manual review", len(ranked) == 5, len(ranked))
check(
    "the two exact matches rank above everything else",
    all(r.full_url in exact for r in ranked[:2]),
    [r.title for r in ranked],
)
check("a cake scores below an exact match", ranked[-1].score < ranked[0].score, [c.score for c in ranked])

brand_mismatch = next(c for c in ranked if c.title == "Butter cake recipe")
check("brand miss is flagged", brand_mismatch.brand_match is False)

tiny = next(c for c in ranked if c.title == "Amul Butter 500g" and c.source == "wikimedia")
check("tiny image demoted below the auto-attach threshold", tiny.score < 0.55, tiny.score)
check(
    "tiny image ranks last",
    ranked[-1] is tiny or ranked[-1].score <= tiny.score,
    [c.score for c in ranked],
)
check(
    "unknown size is not a hard penalty",
    rank([candidate("Amul Butter", width=0, height=0)], product)[0].score > 0.55,
)
check(
    "provider trust breaks an otherwise even match",
    rank([pack, same_text_other_source], product)[0].source == "pexels",
    [c.score for c in rank([pack, same_text_other_source], product)],
)

# The weights and bonuses are budgeted so a perfect match reaches 1.0 exactly.
# When they summed higher, every good result clamped to 1.0 and the top of the
# grid came back in arbitrary order.
variety = rank(
    [
        candidate("Amul Butter 500g Pack"),
        candidate("Amul Butter 200g Slice"),
        candidate("Amul Butter Cheese Block"),
        candidate("Amul Butter Salted 500g"),
    ],
    product,
)
scores = [c.score for c in variety]
check("scores are not all identical", len(set(scores)) > 1, scores)
check("no score is pinned at the ceiling", max(scores) < 1.0, scores)
check("the scores are ordered best first", scores == sorted(scores, reverse=True), scores)
check(
    "the right 500g size outranks the 200g one",
    variety[0].title == "Amul Butter 500g Pack",
    [c.title for c in variety],
)

winner = best_match(ranked, 0.55)
check("best match is an exact match", winner is not None and winner.full_url in exact)

none_found = best_match(rank([candidate("Toothpaste tube")], product), 0.55)
check("unrelated result is not auto-attached", none_found is None)

print("\n== scene photos vs pack shots ==")
scene = candidate(
    "Rich lunch having paratha with maa ki daal, dahi, pickle and Amul butter",
    source="wikimedia",
    tags="Amul butter is served with the meal",
)
packshot = candidate("Amul Butter 500g Pack", source="wikimedia")
ordered = rank([scene, packshot], product)
check("a meal photo is not the top hit", ordered[0] is packshot, ordered[0].title)
check("the meal photo is demoted, not hidden", ordered[-1] is scene, [c.score for c in ordered])
check("meal photo drops below the attach threshold", scene.score < 0.55, scene.score)

packshot2 = candidate("Amul butter packshot on white background", source="pexels")
check(
    "pack-shot vocabulary helps",
    rank([scene, packshot2], product)[0] is packshot2,
    [c.score for c in rank([scene, packshot2], product)],
)

# A description that merely mentions the product must not outweigh a file
# whose *name* is the product.
mentioned = candidate("Untitled upload 3", tags="Photograph of Amul Butter served daily")
named = candidate("Amul Butter 500g", source="pexels")
check(
    "the image's own name outranks a passing mention",
    rank([mentioned, named], product)[0] is named,
)

print("\n== brand token collisions ==")
# "Tata" is a brand and also a very common word in Indian place and company
# names. Token overlap alone scored this office photo a perfect match.
office = candidate(
    "Tata Consultancy Services - Ring Road Sector V - Salt Lake City",
    source="wikimedia",
    width=4000,
    height=3000,
)
real_salt = candidate("Tata Salt 1kg pack", source="wikimedia")
salt_product = ProductQuery(name="Tata Salt", brand="Tata", variant="1kg")
salt_ranked = rank([office, real_salt], salt_product)
check("an office photo never wins for Tata Salt", salt_ranked[0] is real_salt, salt_ranked[0].title)
check("the office photo is not auto-attachable", office.score < 0.55, office.score)
check("the pack shot is auto-attachable", real_salt.score >= 0.55, real_salt.score)

print("\n== images that are provably not the product ==")
# Token overlap alone matched these, because each contains the brand and the
# product name verbatim. "Amul Butter Girl Costume" scored 0.925 and was
# auto-attached to a block of butter.
butter = ProductQuery(name="Amul Butter", brand="Amul", variant="500g")
for title, why in [
    ("Amul Butter Girl Costume", "a costume"),
    ("Amul Butter doll", "a toy"),
    ("Amul Butter logo", "a logo"),
    ("Amul Butter shop in Mumbai", "a storefront"),
]:
    scored = rank([candidate(title, width=1600, height=1600)], butter)[0]
    check(
        f"{why} is never auto-attached",
        scored.score < 0.55 and best_match([scored], 0.55) is None,
        f"{title} scored {scored.score}",
    )
    check(f"{why} stays visible for a manual pick", scored.score > 0, scored.score)

# The product's own words must never disqualify it. "Baby" names the soap and
# "pack" describes the pack shot; only extra words are evidence of a mismatch.
for name, brand, variant, title in [
    ("Johnson Baby Soap", "Johnson", "", "Johnson Baby Soap 125g"),
    ("Amul Butter", "Amul", "500g", "Amul Butter 500g Pack"),
    ("Dove Beauty Bar", "Dove", "", "Dove Beauty Bar Pack of 4"),
]:
    product = ProductQuery(name=name, brand=brand, variant=variant)
    scored = rank([candidate(title, source="pexels")], product)[0]
    check(
        f"the product's own words do not disqualify it ({name})",
        scored.score >= 0.55,
        f"{title} scored {scored.score}",
    )

office_photo = candidate("Tata Motors Showroom Pune", width=2000, height=1400)
tata = ProductQuery(name="Tata Salt", brand="Tata", variant="1kg")
check(
    "a showroom is not a pack of salt",
    best_match(rank([office_photo], tata), 0.55) is None,
    office_photo.score,
)

print("\n== product database sources ==")
# A vendor sheet says "Maggi Instant Noodles"; the product database calls it
# "Nestle Maggi Noodles Masala". Same item, manufacturer's wording. Requiring
# the sheet's exact phrase would discard the best photo over a synonym.
maggi = ProductQuery(name="Maggi Instant Noodles", brand="Nestle", variant="70g")
db_pool = [
    off_candidate("nestle maggi"),
    off_candidate("nestle maggi noodles masala"),
    off_candidate("nestle maggi 2 masala noodles"),
]
db_ranked = rank(db_pool, maggi)
check(
    "a synonym in the sheet does not lose a real product photo",
    best_match(db_ranked, 0.55) is not None
    and "noodles" in best_match(db_ranked, 0.55).title,
    [(c.score, c.title) for c in db_ranked],
)
check(
    "a too-generic database entry stays below the threshold",
    next(c for c in db_ranked if c.title == "nestle maggi").score < 0.55,
    [(c.score, c.title) for c in db_ranked],
)
check(
    "a different product in the same database is not auto-attached",
    best_match(rank([off_candidate("amul gold coin")], ProductQuery(name="Amul Butter", brand="Amul")), 0.55)
    is None,
)
# The exemption is for databases only. A web image's file name is written by
# whoever uploaded it, so it stays on the strict verbatim rule.
check(
    "a web image is still held to the verbatim rule",
    best_match(
        rank(
            [candidate("nestle maggi noodles masala", source="wikimedia", width=1200, height=1200)],
            maggi,
        ),
        0.55,
    )
    is None,
)

print("\n== relaxed retry query ==")
long_name = ProductQuery(
    name="Colgate Strong Teeth Toothpaste", brand="Colgate", variant="150g"
)
relaxed = relaxed_product(long_name)
check("the retry searches brand + head noun", build_queries(relaxed)[0] == "colgate toothpaste",
      (relaxed.name, build_queries(relaxed)))
check("the size is dropped from the retry", "150" not in relaxed.name, relaxed.name)
check(
    "no brand keeps two words",
    relaxed_product(ProductQuery(name="Instant Noodles Masala")).name == "noodles masala",
    relaxed_product(ProductQuery(name="Instant Noodles Masala")).name,
)
check(
    "an already short name is left alone",
    relaxed_product(ProductQuery(name="Butter", brand="Amul")).name == "Butter",
    relaxed_product(ProductQuery(name="Butter", brand="Amul")).name,
)
check(
    "a numeric name is never reduced to a bare number",
    relaxed_product(ProductQuery(name="Maggi 70g", brand="Nestle")).name == "Maggi 70g",
    relaxed_product(ProductQuery(name="Maggi 70g", brand="Nestle")).name,
)

print("\n== relaxed results are held to the brand ==")
wrong_brand = candidate("Colgate Total 12 Toothpaste", tags="", width=1200, height=1200)
wrong_brand.matched_by = "relaxed"
wrong_brand.brand_match = False
right_brand = candidate("Colgate Toothpaste Pump", tags="", width=1200, height=1200)
right_brand.matched_by = "relaxed"
right_brand.brand_match = True
right_brand.score = 0.80
check(
    "a relaxed match without the brand is never auto-attached",
    best_match([wrong_brand], 0.55) is None,
)
check(
    "a relaxed match with the brand is fine",
    best_match([right_brand], 0.55) is right_brand,
)
check(
    "a low-scoring relaxed match is still rejected",
    best_match([ImageCandidate(**{**right_brand.model_dump(), "score": 0.2})], 0.55)
    is None,
)

print("\n== brand-free third pass ==")
# A brand is only in a free photo library if somebody happened to upload that
# brand. Wikimedia has photographs of steel rods and none of JSW Steel, so every
# query carrying "JSW" returns nothing at all: the row stayed blank not because
# the scoring rejected anything, but because nothing ever came back to score.
# These checks pin the query side of that, which is the actual fix.
jsw = ProductQuery(name="JSW Steel TMT Bar", brand="JSW Steel", category="Materials")
jsw_first = build_queries(jsw, max_queries=2)
check("the first pass still asks for the brand by name", "jsw" in jsw_first[0], jsw_first)
check(
    "the first pass is branded all the way down",
    all("jsw" in q for q in jsw_first),
    jsw_first,
)

jsw_relaxed = relaxed_product(jsw)
check(
    "the second pass still keeps the brand, as before",
    jsw_relaxed.brand == "JSW Steel",
    jsw_relaxed,
)
check(
    "the second pass still searches brand + head noun",
    build_queries(jsw_relaxed, max_queries=1)[0] == "jsw steel bar",
    build_queries(jsw_relaxed, max_queries=1),
)

jsw_generic = generic_product(jsw)
check("the third pass clears the brand from the field", jsw_generic.brand == "", jsw_generic)
check("the third pass keeps two words of the name", jsw_generic.name == "tmt bar", jsw_generic.name)
check(
    "no third-pass query mentions the brand",
    all("jsw" not in q for q in build_queries(jsw_generic, max_queries=2)),
    build_queries(jsw_generic, max_queries=2),
)
check(
    "the third pass asks a question the library can answer",
    asks_something_new(jsw_generic, 2, asked_queries(jsw, 2)),
    (build_queries(jsw_generic, max_queries=2), asked_queries(jsw, 2)),
)


def scored_as(title, tier, product, source="wikimedia", tags=""):
    """A candidate from ``tier``, scored the way the pipeline would score it."""
    c = candidate(title, source=source, tags=tags)
    c.tier = tier
    return scoring.score_candidate(c, scoring.build_target(product))


# The guard itself: the same photograph, judged against the same branded
# target, one tier where the brand was asked for and one where it was not.
tmt_photo = "Reinforcing Steel TMT Bar 12mm"
tmt_branded = scored_as(tmt_photo, "branded", jsw)
tmt_generic = scored_as(tmt_photo, "generic", jsw)
check(
    "a branded-tier result with no brand is demoted",
    tmt_branded.score < 0.50,
    tmt_branded.score,
)
check(
    "a generic-tier result is not demoted for a brand it was never asked for",
    abs(tmt_generic.score - tmt_branded.score / 0.3) < 0.001,
    (tmt_branded.score, tmt_generic.score),
)
check(
    "the relaxed tier is still held to the brand",
    scored_as(tmt_photo, "relaxed", jsw).score == tmt_branded.score,
    scored_as(tmt_photo, "relaxed", jsw).score,
)
# The tier relaxes the penalty only; it never touches the bonus. A file that
# does lead with the brand scores the same whichever query found it.
with_brand = "JSW Steel TMT Bar 12mm"
check(
    "a result carrying the brand scores the same at every tier",
    len({scored_as(with_brand, t, jsw).score for t in ("branded", "relaxed", "generic")})
    == 1,
    [scored_as(with_brand, t, jsw).score for t in ("branded", "relaxed", "generic")],
)

# End to end: the row that used to be blank now resolves, because the third
# pass is scored against the brand-free product rather than the branded one.
tmt_ranked = rank([candidate(tmt_photo, source="wikimedia")], jsw_generic)
check(
    "the third pass finds an attachable photo for a brand-free row",
    best_match(tmt_ranked, 0.60) is not None,
    [(c.title, c.score, c.matched_by) for c in tmt_ranked],
)
check(
    "a generic hit is still scored on name coverage, not on the brand",
    tmt_ranked[0].matched_by == "similar" and tmt_ranked[0].brand_match is True,
    (tmt_ranked[0].matched_by, tmt_ranked[0].brand_match),
)

print("\n== unbranded products are untouched by the third pass ==")
rods = ProductQuery(name="Steel Rods", category="Materials")
check(
    "an unbranded row keeps its category hint",
    "materials" in build_queries(rods)[0],
    build_queries(rods),
)
check(
    "an unbranded row has nothing left to ask for",
    not asks_something_new(rods, 2, asked_queries(rods, 2)),
    (build_queries(rods), generic_product(rods)),
)
check(
    "the brand-free helper is harmless on an unbranded row",
    generic_product(rods).name == "steel rods" and generic_product(rods).brand == "",
    generic_product(rods),
)

print("\n== the third pass cannot invent a match ==")
# Rows that repeat their brand inside the name are the important negative case.
# Clearing the brand field leaves their query string unchanged, so tier 3 never
# runs for them and cannot contribute a single candidate.
#
# Two of them -- Exide and Domino's -- are also cases where a wrong result is
# accepted today, at 0.889. That is pre-existing and provably untouched here:
# both titles contain the brand, so the tier never enters the branch that
# changed, and the third pass is skipped. They need the sibling-noun and
# evidence work (Fix 3 / Fix 4), which is deliberately out of scope. What is
# asserted below is only that Fix 1 + Fix 2 did not make either of them worse.
exide = ProductQuery(name="Exide Battery", brand="Exide", category="Automotive")
check(
    "Exide: the third pass is a repeat of the first",
    not asks_something_new(generic_product(exide), 2, asked_queries(exide, 2)),
    (build_queries(exide, 2), build_queries(generic_product(exide), 2)),
)
trucks = scored_as("Penske Truck Leasing Exide Battery", "branded", exide)
check(
    "Exide: the tier is irrelevant once the title carries the brand",
    len(
        {
            scored_as("Penske Truck Leasing Exide Battery", t, exide).score
            for t in ("branded", "relaxed", "generic")
        }
    )
    == 1,
    [
        scored_as("Penske Truck Leasing Exide Battery", t, exide).score
        for t in ("branded", "relaxed", "generic")
    ],
)
check(
    "Exide: the score is exactly what it was before this change",
    (trucks.score, trucks.matched_by, trucks.brand_match) == (0.889, "exact", True),
    (trucks.score, trucks.matched_by, trucks.brand_match),
)

nokia = ProductQuery(name="Nokia Feature Phone", brand="Nokia", category="Electronics")
nokia_generic = generic_product(nokia)
check(
    "Nokia: the third pass keeps the words that say what it is",
    nokia_generic.name == "feature phone" and nokia_generic.brand == "",
    nokia_generic,
)
check(
    "Nokia: the third pass does run, because the query really is new",
    asks_something_new(nokia_generic, 2, asked_queries(nokia, 2)),
    (build_queries(nokia, 2), build_queries(nokia_generic, 2)),
)
smartphone = rank([candidate("Nokia smartphone", source="wikimedia")], nokia_generic)
check(
    "Nokia: a smartphone is not an exact feature phone",
    smartphone[0].matched_by != "exact",
    (smartphone[0].score, smartphone[0].matched_by),
)
check(
    "Nokia: a smartphone is not auto-attached for a feature phone",
    best_match(smartphone, 0.60) is None,
    smartphone[0].score,
)
check(
    "Nokia: the same holds against the branded target",
    best_match(rank([candidate("Nokia smartphone", source="wikimedia")], nokia), 0.60)
    is None,
    rank([candidate("Nokia smartphone", source="wikimedia")], nokia)[0].score,
)

dominos = ProductQuery(name="Domino's Pizza", brand="Domino's", category="Restaurant")
check(
    "Domino's: the third pass is a repeat of the first",
    not asks_something_new(generic_product(dominos), 2, asked_queries(dominos, 2)),
    (build_queries(dominos, 2), build_queries(generic_product(dominos), 2)),
)
# "Domino's" and "Domino" clean to the same word, so the shopfront matches the
# brand outright. Pre-existing, and outside what query tiers can influence.
check(
    "Domino's: the tier is irrelevant once the title carries the brand",
    len(
        {
            scored_as("Domino Pizza, Plainmoor - geographical", t, dominos).score
            for t in ("branded", "relaxed", "generic")
        }
    )
    == 1,
    [
        scored_as("Domino Pizza, Plainmoor - geographical", t, dominos).score
        for t in ("branded", "relaxed", "generic")
    ],
)
check(
    "Domino's: the shopfront score is exactly what it was before this change",
    scored_as("Domino Pizza, Plainmoor - geographical", "branded", dominos).score
    == 0.889,
    scored_as("Domino Pizza, Plainmoor - geographical", "branded", dominos).score,
)

print("\n== plural and singular are the same product ==")
# A file name written by a person pluralises at least as often as a vendor's
# spreadsheet does not, and an exact comparison scored the photograph down for
# it. "20 mm TMT bars" is a photograph of the thing a sheet row calls "TMT Bar".
for plural, singular, why in [
    ("bar", "bars", "a plain s"),
    ("box", "boxes", "x takes es"),
    ("glass", "glasses", "ss takes es"),
    ("watch", "watches", "ch takes es"),
    ("battery", "batteries", "ies becomes y"),
    ("shoe", "shoes", "a bare s"),
]:
    check(
        f"a photograph saying {plural!r} answers a row saying {singular!r} ({why})",
        contains_phrase(f"20 mm {plural} on a table", singular)
        and contains_phrase(f"20 mm {singular} on a table", plural),
        (plural, singular),
    )
check(
    "the plural still does not match an unrelated word",
    not contains_phrase("20 mm steel plate", "bar"),
)
check(
    "a plural does not smuggle in a longer word",
    not contains_phrase("steel barrel", "bar"),
)
# The rules have to be narrow, or ordinary product words get mangled and start
# matching things they should not.
for invariant in [
    "bus", "glass", "chest", "steel", "brass", "press", "analysis", "virus",
    "razor", "dress", "watch", "scissors", "tongs", "jeans", "pliers",
]:
    other = textutil_singular(invariant)
    check(
        f"{invariant!r} is left alone",
        other == invariant,
        other,
    )
check(
    "a plural counts towards name coverage",
    coverage({"tmt", "bar"}, textutil_token_set("20 mm tmt bars")) == 1.0,
    coverage({"tmt", "bar"}, textutil_token_set("20 mm tmt bars")),
)
check(
    "coverage still reports a genuine miss as zero",
    coverage({"tmt", "bar"}, textutil_token_set("20 mm cement")) == 0.0,
)
check(
    "an Indic name is not run through English plural rules",
    textutil_singular("கிளிகள்") == "கிளிகள்",
    textutil_singular("கிளிகள்"),
)

print("\n== a generic-tier hit needs the brand before it attaches ==")
# Scoring a generic result against the brand-free product leaves brand_match
# vacuously true, so the evidence the sheet actually has has to be put back
# before anything is allowed to attach unattended.
voltas = ProductQuery(name="Voltas Air Conditioner", brand="Voltas", category="Home")
voltas_generic = generic_product(voltas)
daikin = rank([candidate("Daikin ceiling suspended air conditioner")], voltas_generic)
daikin[0].tier = "generic"
scoring.apply_brand_evidence(daikin, voltas)
check(
    "a rival's product is recognised as not carrying the brand",
    daikin[0].brand_match is False,
    daikin[0].brand_match,
)
check(
    "a rival's product is not auto-attached to a branded row",
    best_match(daikin, 0.60) is None,
    (daikin[0].score, daikin[0].matched_by),
)
check(
    "a rival's product is still offered to the vendor",
    len(daikin) == 1 and daikin[0].score > 0,
    daikin[0].score,
)
nivia = ProductQuery(name="Nivia Cricket Bat", brand="Nivia", category="Sports")
bat = rank([candidate("Hockerill Cricket Club cricket bat")], generic_product(nivia))
bat[0].tier = "generic"
scoring.apply_brand_evidence(bat, nivia)
check(
    "a club's bat is not auto-attached to a branded row",
    best_match(bat, 0.60) is None,
    bat[0].score,
)
# The other half of the rule: a generic hit that does name the brand is exactly
# the recovery this work was for, and must still attach.
good = rank([candidate("Nivia cricket bat Kashmir Willow")], generic_product(nivia))
good[0].tier = "generic"
scoring.apply_brand_evidence(good, nivia)
check(
    "a generic hit that does name the brand attaches",
    best_match(good, 0.60) is good[0],
    (good[0].score, good[0].brand_match),
)
check(
    "an unbranded row is unaffected by the rule",
    best_match(
        rank([candidate("Cutting steel rods with a Bench grinder")],
             ProductQuery(name="Steel Rods", category="Materials")),
        0.60,
    )
    is not None,
)

print("\n== the right object in an unusable photograph ==")
# NOT_THE_PRODUCT covers a different object. These are the same object in a
# photograph no retailer would use, and they scored 0.76-0.79 because a photo
# of a broken hammer really does contain every word for a hammer.
scored_products = {
    "Hammer": (ProductQuery(name="Hammer", category="Hardware"), "Broken hammer DIY", 0.767),
    "Cricket Bat": (
        ProductQuery(name="Cricket Bat", category="Sports"),
        "Hockerill Cricket Club abandoned cricket bat",
        0.788,
    ),
    "Wall Clock": (
        ProductQuery(name="Wall Clock", category="Home"),
        "Prompt used: wall clock as stencil on white background hyperrealistic",
        0.770,
    ),
    "LED Bulb": (
        ProductQuery(name="LED Bulb", category="Electronics"),
        "Inside of chaina led bulb (lamp)IMG 0548",
        0.761,
    ),
    "Baby Stroller": (
        ProductQuery(name="Baby Stroller", category="Baby & Kids"),
        "Vintage baby stroller (33110853082)",
        0.767,
    ),
}
for label, (prod, title, was) in scored_products.items():
    got = scoring.score_candidate(
        candidate(title), scoring.build_target(prod)
    )
    check(
        f"{title[:44]!r} is no longer auto-attached (was {was})",
        got.score < 0.60 and best_match([got], 0.60) is None,
        got.score,
    )
    check(
        f"{title[:44]!r} is still offered to the vendor",
        got.score > 0,
        got.score,
    )
# A product that genuinely is called one of those words keeps its photograph.
# Only the photograph is judged, never the product, so assert the rule itself.
check(
    "a product named 'Vintage' is not disqualified by its own name",
    not scoring._not_a_product_photo(
        candidate("Vintage Wall Clock Studio Shot"),
        scoring.build_target(ProductQuery(name="Vintage Wall Clock", category="Home")),
    ),
)
check(
    "a product named 'Broken Glass' is not disqualified by its own name",
    not scoring._not_a_product_photo(
        candidate("Broken Glass Safety Glasses, 6 pack"),
        scoring.build_target(
            ProductQuery(name="Broken Glass Safety Glasses", category="X")
        ),
    ),
)
# And the pack shots the scene filter must never touch.
for title, name, brand in [
    ("Closeup wooden chair", "Wooden Chair", ""),
    ("New pvc pipe vs cut pvc pipe", "PVC Pipe", ""),
    ("Aarong leather wallet", "Leather Wallet", ""),
    ("Dove shampoo bottle in black background", "Shampoo Bottle", ""),
    ("Folding umbrella 04", "Umbrella", ""),
    ("Philips LED bulb", "Philips LED Bulb", "Philips"),
    ("TITAN watch", "Titan Watch", "Titan"),
    ("Vicks VapoRub (51013600352)", "Vicks VapoRub", "Vicks"),
    ("EXIDE Technologies Exide Batteries", "Exide Battery", "Exide"),
    ("Puma football ball", "Puma Football", "Puma"),
    ("Birthday flower bouquet - 2021-08-26", "Flower Bouquet", ""),
    ("amul butter milk amul", "Amul Butter", "Amul"),
    ("haldiram aloo bhujia sev", "Haldiram's Aloo Bhujia", "Haldiram's"),
]:
    kept = scoring.score_candidate(
        candidate(title),
        scoring.build_target(ProductQuery(name=name, brand=brand, category="X")),
    )
    check(
        f"a good match survives: {title[:44]!r}",
        kept.score >= 0.60,
        kept.score,
    )

print("\n== a finished dish is not the ingredient being sold ==")
# A grocery sheet sells the raw ingredient, so a photograph of the meal is a
# different product. These all named every word of the product and nothing else,
# which is exactly why they scored high.
dishes = {
    "Al Kabeer Mutton": (
        ProductQuery(name="Al Kabeer Mutton", brand="Al Kabeer", category="Meat"),
        "al kabeer mutton samosas",
        0.7412,
    ),
    "Toor Dal": (
        ProductQuery(name="Toor Dal", category="Grocery"),
        "Toor dal pakodas",
        0.734,
    ),
    "Fresh Chicken Breast": (
        ProductQuery(
            name="Fresh Chicken Breast", brand="Fresh Chicken", category="Meat"
        ),
        "frankly fresh chicken breast burrito bowl",
        0.7436,
    ),
    "Chicken Tikka": (
        ProductQuery(name="Chicken Tikka", category="Meat"),
        "Chicken tikka masala",
        0.80,
    ),
    "Toor Dal halwa": (
        ProductQuery(name="Toor Dal", category="Grocery"),
        "Toor dal halwa",
        0.80,
    ),
    "Basmati Rice": (
        ProductQuery(name="Basmati Rice", category="Grocery"),
        "Biryani in a bowl",
        0.80,
    ),
}
for label, (prod, title, was) in dishes.items():
    got = scoring.score_candidate(candidate(title), scoring.build_target(prod))
    check(
        f"{title[:44]!r} is not offered as {label} (was {was})",
        got.score < 0.60,
        got.score,
    )
    check(
        f"{title[:44]!r} is still in the grid",
        got.score > 0,
        got.score,
    )

# Subtracting the product's own words is what keeps this rule from misfiring on a
# sheet that legitimately sells the dish, or on the plated word itself.
for title, name, brand, category in [
    ("Idli Sambar Food by Ms Ujwala Kasambe DSCN9744 (2)", "Idli Sambar", "", "Grocery"),
    ("Toor dal pakodas", "Toor Dal Pakoda", "", "Grocery"),
    ("Poha with onion", "Poha", "", "Grocery"),
    ("Idli Sambar", "Idli Sambar", "", "Grocery"),
    # "plate" and "samosa" are in PREPARED_FOOD but must not reach a non-food row
    ("Chopping Board", "Chopping Board", "", "Home"),
    ("Cake Stand", "Cake Stand", "", "Home"),
    ("Salad Dressing bottle", "Salad Dressing", "", "Grocery"),
    ("Amul butter milk amul", "Amul Butter", "Amul", "Grocery"),
]:
    kept = scoring.score_candidate(
        candidate(title),
        scoring.build_target(
            ProductQuery(name=name, brand=brand, category=category)
        ),
    )
    check(
        f"the dish is still attachable when it is the product: {title[:40]!r}",
        kept.score >= 0.60,
        kept.score,
    )
# A plural dish word still counts against a singular product name, and vice versa.
check(
    "'pakodas' is caught for a sheet selling 'Toor Dal'",
    scoring._cooked_dish_photo(
        candidate("Toor dal pakodas"),
        scoring.build_target(ProductQuery(name="Toor Dal", category="Grocery")),
    )
    == {"pakodas"},
)
check(
    "'pakoda' is not caught for a sheet selling 'Toor Dal Pakoda'",
    scoring._cooked_dish_photo(
        candidate("Toor dal pakodas"),
        scoring.build_target(ProductQuery(name="Toor Dal Pakoda", category="Grocery")),
    )
    == set(),
)

# Commons categorises every food file "X dishes", so the word arrives as a
# category label rather than as a claim about the photograph. Reading it as a
# cooked dish once cost this row its correct image.
check(
    "a Commons 'dishes' category does not disqualify the dish it labels",
    scoring._cooked_dish_photo(
        candidate("Toor dal pakodas", tags="Toor dal dishes|Dal pakoda"),
        scoring.build_target(ProductQuery(name="Toor Dal Pakoda", category="Grocery")),
    )
    == set(),
)

print("\n== a part of the product, or a place, is not the product ==")
# Both of these named every word of the sheet and nothing else. The noun that
# told them apart -- drill bit, shopfront -- is not in the sheet's vocabulary.
for title, name, brand, category, was in [
    ("Head of a hammer drill close-up", "Hammer", "", "Hardware", 0.767),
    (
        "Domino Pizza, Plainmoor - geograph.org.uk - 5959855",
        "Domino's Pizza",
        "Domino's",
        "Restaurant",
        0.889,
    ),
]:
    got = scoring.score_candidate(
        candidate(title),
        scoring.build_target(
            ProductQuery(name=name, brand=brand, category=category)
        ),
    )
    check(
        f"{title[:44]!r} is not auto-attached to {name!r} (was {was})",
        got.score < 0.60,
        got.score,
    )
    check(f"{title[:44]!r} stays in the grid", got.score > 0, got.score)

# "closeup" alone is pack-shot vocabulary, and must not trip the part rule.
closeup = scoring.score_candidate(
    candidate("Closeup wooden chair"),
    scoring.build_target(ProductQuery(name="Wooden Chair", category="Furniture")),
)
check("'Closeup wooden chair' is still a catalogue image", closeup.score >= 0.60, closeup.score)
# A product that genuinely is named after a part is not disqualified by it. Only
# the photograph is judged, so assert the rule itself: these names score 0.50 for
# unrelated reasons (a three-word name matches no brand bonus), and attaching
# them is the vendor's business.
for name in ["Head of a Hammer", "Interior of Castle Wall", "Detail of Belt"]:
    check(
        f"a product actually named {name!r} is not disqualified by its own name",
        not scoring._not_a_product_photo(
            candidate(name),
            scoring.build_target(ProductQuery(name=name, category="Hardware")),
        ),
    )
# A Geograph marker in the name is not a product word either.
check(
    "a catalogue product sharing a town name is unaffected",
    not scoring._not_a_product_photo(
        candidate("Plainmoor wall clock"),
        scoring.build_target(ProductQuery(name="Plainmoor Clock", category="Home")),
    ),
)

print("\n== the product is being transported, not sold ==")
# Removing the shopfront photograph just promoted a delivery-scooter photo into
# the top slot, which is still not a pizza. The brand name on a courier's box
# is not a picture of the food.
delivery = scoring.score_candidate(
    candidate("A speedy ride for Dominos Pizza Delivery. Portland"),
    scoring.build_target(
        ProductQuery(name="Domino's Pizza", brand="Domino's", category="Restaurant")
    ),
)
check(
    "a delivery photograph is not auto-attached as the pizza (was 0.865)",
    delivery.score < 0.60,
    delivery.score,
)
pizza = scoring.score_candidate(
    candidate("dominos pizza figue chevre"),
    scoring.build_target(
        ProductQuery(name="Domino's Pizza", brand="Domino's", category="Restaurant")
    ),
)
check(
    "an actual pizza still wins the row",
    pizza.score > delivery.score,
    (pizza.score, delivery.score),
)
# The vehicle words are omitted on purpose: a Truck Battery and a Bike Tyre are
# real catalogue rows, and "truck" in "Penske Truck Leasing Exide Battery"
# describes the haulier, not the battery.
check(
    "a Truck Battery is not demoted by the word 'truck'",
    len(
        {
            scoring.score_candidate(
                candidate(title),
                scoring.build_target(
                    ProductQuery(name=name, brand=brand, category="Automotive")
                ),
            ).score
            for title, name, brand in [
                ("Truck Battery 12V", "Truck Battery", ""),
                ("Exide Truck Battery", "Exide Truck Battery", "Exide"),
            ]
        }
    )
    == 2,
)
for title, name, brand in [
    ("Truck Battery 12V", "Truck Battery", ""),
    ("Exide Truck Battery", "Exide Truck Battery", "Exide"),
]:
    kept = scoring.score_candidate(
        candidate(title),
        scoring.build_target(
            ProductQuery(name=name, brand=brand, category="Automotive")
        ),
    )
    check(
        f"{title!r} is not demoted by its own product name",
        kept.score >= 0.60,
        kept.score,
    )

print("\n== Indian product names ==")
# Indian FMCG sheet names are long, modifier-heavy and frequently written in
# an Indian script, and most of these products carry no barcode, so the name is
# the only evidence available. Every case below failed before these rules
# existed: the marketing qualifiers were stop words, non-Latin script was
# erased, and a long name could never match a short file name.
for sheet, image_title, why in [
    ("Britannia Good Day Choco Vanilla Creamy Filled Biscuit", "Britannia Good Day Biscuit Pack", "a padded name"),
    ("Britannia Good Day Choco Vanilla Creamy Filled Biscuit", "Britannia Good Day Choco Vanilla Biscuit", "a partly padded name"),
    ("Britannia Good Day", "Britannia Good Day Biscuit Pack", "a two-word series name"),
    ("Tata Sampann Toor Dal", "Tata Sampann Toor Dal Pack", "a dal"),
    ("Parle Frooti Mango", "Parle Frooti Mango Juice Pack", "a fruit drink"),
]:
    product = ProductQuery(name=sheet, brand=sheet.split()[0])
    scored = rank([candidate(image_title, width=1200, height=1200)], product)[0]
    check(
        f"a real Indian pack shot is auto-attachable ({why})",
        scored.score >= 0.55 and best_match([scored], 0.55) is not None,
        f"{image_title!r} scored {scored.score}",
    )

# "Good Day" is the product. Treating "good" as filler searched for "britannia
# day" and found nothing, and mangled the phrase so the real pack shot was
# rejected even once it was found.
check(
    "a marketing qualifier that names the product survives",
    build_queries(ProductQuery(name="Britannia Good Day", brand="Britannia"))[0]
    == "britannia good day",
    build_queries(ProductQuery(name="Britannia Good Day", brand="Britannia")),
)
check(
    "a brand that is also a common word survives",
    build_queries(ProductQuery(name="India Gate Sella Rice", brand="India Gate"))[0]
    == "india gate sella rice",
    build_queries(ProductQuery(name="India Gate Sella Rice", brand="India Gate")),
)
check(
    "an ecommerce filler word is still dropped",
    "buy" not in build_queries(ProductQuery(name="Amul Butter", brand="Amul"))[0],
)

# Devanagari used to clean to "", which left no name tokens and no phrase. With
# no brand in the sheet the query list came back empty and no provider was ever
# called, so the row could not match anything at all.
devanagari = ProductQuery(name="मैग्गी इंस्टेंट नूडल्स मसाला")
check("a non-Latin name is not erased", bool(tokens(devanagari.name)), clean(devanagari.name))
check(
    "a non-Latin name with no brand still produces a query",
    bool(build_queries(devanagari)),
    build_queries(devanagari),
)
check(
    "a row of nothing but punctuation still produces a query",
    bool(build_queries(ProductQuery(name="***", category="Grocery"))),
    build_queries(ProductQuery(name="***", category="Grocery")),
)
# Combining marks are structural, not decorative. Folding them like Latin
# diacritics split one syllable into several tokens, and a plain [^\w] split
# them off the letters they belong to, so the provider was queried with
# fragments of words instead of words.
check("a Devanagari conjunct is not split", clean("मैग्गी") == "मैग्गी", clean("मैग्गी"))
check("a Tamil syllable stays one token", tokens("ஃபைசில்") == ["ஃபைசில்"], tokens("ஃபைசில்"))
check("a Telugu word stays one token", tokens("కాఫీ") == ["కాఫీ"], tokens("కాఫీ"))
check("a Bengali name survives", clean("ব্রিটানিয়া গুড ডে") == "ব্রিটানিয়া গুড ডে", clean("ব্রিটানিয়া গুড ডে"))
check(
    "Latin accents are still folded",
    clean("Crème Brûlée") == "creme brulee",
    clean("Crème Brûlée"),
)
check(
    "a brand and a native-script name are both sent",
    build_queries(ProductQuery(name="மெய்சில் 200 ML", brand="Ponds"))
    == ["ponds மெய்சில் 200 ml"],
    build_queries(ProductQuery(name="மெய்சில் 200 ML", brand="Ponds")),
)

# The relaxation that forgives a run of descriptive adjectives must not become
# a loophole. A missing run of adjectives is a description; a missing product
# claim, or an extra word the sheet never mentioned, means a different item.
for sheet, brand, image_title, why in [
    ("Amul Butter", "Amul", "Amul Butter Girl Costume", "a costume"),
    ("Amul Butter", "Amul", "Amul Butter doll", "a toy"),
    ("Amul Butter", "Amul", "Amul Butter shop in Mumbai", "a storefront"),
    ("Tata Salt", "Tata", "Tata Motors Showroom Pune", "a showroom"),
    ("Tata Salt", "Tata", "Tata Consultancy Services - Ring Road Sector V", "an office"),
    ("Maggi Instant Noodles", "Nestle", "nestle maggi noodles masala", "a synonym on a web image"),
    (
        "Britannia Good Day Choco Vanilla Creamy Filled Biscuit",
        "Britannia",
        "Britannia Good Day Butter Biscuit Pack",
        "a different flavour",
    ),
    (
        "Britannia Good Day Choco Vanilla Creamy Filled Biscuit",
        "Britannia",
        "Britannia Good Day Cashew Almond Biscuit",
        "another flavour",
    ),
    ("Parle Frooti Mango", "Parle", "Parle Frooti Apple Juice Pack", "a different fruit"),
    ("Amul Butter", "Amul", "Amul Gold Cheese Slice Pack", "a different product"),
]:
    product = ProductQuery(name=sheet, brand=brand)
    scored = rank([candidate(image_title, width=1200, height=1200)], product)[0]
    check(
        f"the relaxation never attaches {why}",
        scored.score < 0.55 and best_match([scored], 0.55) is None,
        f"{image_title!r} scored {scored.score}",
    )

print("\n== sibling variants from a product database ==")
# Found against the live Open Food Facts API: a full-text search answers with
# other products of the same brand, and the exemption from the verbatim rule
# let them be attached. "Tata Salt Lite" is a low-sodium product whose name
# contradicts the sheet; attaching it is worse than attaching nothing.
for name, brand, entry, why in [
    ("Tata Salt Iodised", "Tata", "tata salt lite", "a contradicting variant"),
    ("Amul Butter", "Amul", "amul gold coin", "another product"),
    ("Britannia Good Day Biscuit", "Britannia", "britannia good day choco vanilla", "another flavour"),
]:
    product = ProductQuery(name=name, brand=brand)
    scored = rank([off_candidate(entry)], product)[0]
    check(
        f"a database entry that renames the product is not attached ({why})",
        scored.score < 0.55 and best_match([scored], 0.55) is None,
        f"{entry!r} scored {scored.score}",
    )

# ...but the exemption still has to work, or nothing from a database is ever
# usable: the manufacturer simply words the name differently.
for name, brand, entry, why in [
    ("Maggi Instant Noodles", "Nestle", "nestle maggi noodles masala", "a synonym"),
    ("Amul Butter", "Amul", "amul butter milk amul", "an extra qualifier"),
    ("Haldiram's Aloo Bhujia", "Haldiram", "haldiram aloo bhujia sev", "an extra word"),
    ("Parle Frooti Mango", "Parle", "parle frooti mango drink", "an extra word"),
]:
    product = ProductQuery(name=name, brand=brand)
    scored = rank([off_candidate(entry)], product)[0]
    check(
        f"a database entry worded differently is still attached ({why})",
        scored.score >= 0.55,
        f"{entry!r} scored {scored.score}",
    )

print("\n== what gets an image and what stays blank ==")
# The importer attaches a photo only when the service is confident, and leaves
# the field blank otherwise. A blank product is recoverable; a product
# carrying the wrong photo ships to customers, so the bar is set on precision
# rather than on how many rows get filled in.
BAR = 0.60
check(
    "the configured bar is the one the client mirrors",
    abs(scoring_module_min_accept() - BAR) < 1e-9,
    scoring_module_min_accept(),
)
# Measured live against these rows on the keyless providers: the ones that
# clear the bar are the right product, and the ones held back are wrong
# variants or absent from every source.
for name, brand, title, expect_image in [
    ("Britannia Good Day Biscuit", "Britannia", "britannia good day", True),
    ("Britannia Marie Gold Biscuit", "Britannia", "britannia marie gold biscuit", True),
    ("Parle Frooti Mango", "Parle", "parle frooti mango drink", True),
    ("Haldiram's Aloo Bhujia", "Haldiram", "haldiram aloo bhujia sev", True),
    ("Tata Sampann Toor Dal", "Tata Sampann", "tata sampann unpolished toor dal", True),
    ("Tata Salt Iodised", "Tata Salt", "tata salt lite", False),
    ("Dove Beauty Bar", "Dove", "Dove IIII", False),
    ("Britannia Good Day Biscuit", "Britannia", "britannia good day cashew cookie", False),
]:
    product = ProductQuery(name=name, brand=brand)
    # Every one of these titles is an Open Food Facts entry, which is where the
    # measurement was taken. Scoring them as a web image instead would apply
    # the stricter verbatim rule and reject results the service really returns.
    scored = rank([off_candidate(title, width=1200, height=1200)], product)[0]
    attaches = best_match([scored], BAR) is not None
    check(
        f"{'an image is attached' if expect_image else 'the field stays blank'}: {title[:40]}",
        attaches == expect_image,
        f"scored {scored.score}",
    )
    check(
        f"a blank row is still offered for a manual pick: {title[:36]}",
        scored.score > 0,
        scored.score,
    )

print("\n== storage paths ==")
check(
    "content addressed without a folder",
    storage.object_path("abc123") == "auto/abc123.jpg",
    storage.object_path("abc123"),
)
check(
    "scoped to the global product when known",
    storage.object_path("abc123", "gp_42") == "gp_42/auto_abc123.jpg",
    storage.object_path("abc123", "gp_42"),
)
check(
    "path traversal is stripped",
    storage.object_path("abc123", "../../etc") == "etc/auto_abc123.jpg",
    storage.object_path("abc123", "../../etc"),
)
check(
    "public url points at the bucket",
    storage.public_url("auto/x.jpg").endswith("/object/public/global_products/auto/x.jpg"),
)

if os.environ.get("RUN_LIVE_TESTS") == "1":
    import asyncio

    from image_search_service.main import SearchRequest, search

    result = asyncio.get_event_loop().run_until_complete(
        search(SearchRequest(product=ProductQuery(name="Amul Butter", brand="Amul")))
    )
    check("live search returns candidates", len(result.candidates) > 0, result.provider_status)
    print("   top:", [(c.title[:40], c.score) for c in result.candidates[:3]])

print("\n== open food facts helpers ==")
check(
    "a 100px off image is requested at 400px",
    _off_thumbnail("https://images.openfoodfacts.org/images/products/890/1/front_en.1.100.jpg")
    == "https://images.openfoodfacts.org/images/products/890/1/front_en.1.400.jpg",
)
check(
    "an unexpected extension is left alone",
    _off_thumbnail("https://images.openfoodfacts.org/images/products/890/1/front.png")
    == "https://images.openfoodfacts.org/images/products/890/1/front.png",
)
check("open food facts needs no credentials", "openfoodfacts" in available_providers())

print("\n== image download limits ==")
# The service refused to host a 5472x7296 Wikimedia photo of Colgate toothpaste
# — the very image /resolve had just returned — because of a "long edge must be
# under 6000px" rule. That rule threw away most photos from a 24MP or 48MP
# phone, and /host answered 422, so the vendor silently kept a hotlink to
# Wikimedia instead of a copy of their own. The real bound is how many pixels
# have to be decoded, and _resize caps the output at 1200px regardless.


def _png_bytes(width, height):
    """A real PNG of the given size, flat colour so it encodes small."""
    from io import BytesIO

    from PIL import Image

    buffer = BytesIO()
    Image.new("RGB", (width, height), (200, 30, 30)).save(buffer, format="PNG")
    return buffer.getvalue()


def _forged_png_header(width, height):
    """A PNG header claiming a huge image, with no image data behind it.

    Decoding this would allocate width*height*3 bytes. The budget has to be
    enforced on the header, before load(), or the guard is what causes the
    crash it exists to prevent.
    """
    import struct
    import zlib

    def chunk(kind, payload):
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload))
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IEND", b"")


# The exact size that broke /host, pinned at the unit the rule used to live on.
for size, why in [
    ((5472, 7296), "the Wikimedia photo that broke /host"),
    ((4032, 6048), "a 24MP phone portrait"),
    ((8000, 6000), "a 48MP phone landscape"),
]:
    try:
        imaging._check_pixel_budget(size)
        check(f"{why} is within the decode budget", True)
    except imaging.ImageRejected as exc:
        check(f"{why} is within the decode budget", False, exc)

try:
    imaging._check_pixel_budget((40000, 40000))
    check("a 1.6 gigapixel claim is over budget", False, "accepted")
except imaging.ImageRejected:
    check("a 1.6 gigapixel claim is over budget", True)

# The budget is read from the header, before load() allocates the pixels. PNG
# happens to trip Pillow's own bomb check at open(), so the test that matters
# is that load() is never reached: that is the allocation the guard exists to
# prevent. Whichever check wins, the caller must see a clean rejection.
from PIL import Image as _PILImage  # noqa: E402

_load_calls = []


def _explode_if_loaded(self, *args, **kwargs):
    _load_calls.append(self.size)
    raise AssertionError("load() ran on an over-budget image")


_real_load = _PILImage.Image.load
_PILImage.Image.load = _explode_if_loaded
try:
    try:
        imaging.process(_forged_png_header(40000, 40000))
        check("an oversized image is rejected", False, "accepted 1.6 gigapixels")
    except imaging.ImageRejected as exc:
        check(
            "an oversized image is rejected",
            "pixel" in str(exc) or "size" in str(exc),
            str(exc),
        )
    except Exception as exc:  # noqa: BLE001 - anything else is a 500, not a 422
        check(
            "an oversized image is rejected",
            False,
            f"escaped as {type(exc).__name__} instead of ImageRejected",
        )
    check("an over-budget image is never decoded", not _load_calls, _load_calls)
finally:
    _PILImage.Image.load = _real_load

# A large photograph is accepted and capped for storage.
try:
    big = imaging.process(_png_bytes(2400, 1800))
    check(
        "a large photograph is accepted and downscaled",
        max(big.width, big.height) <= imaging.Config.TARGET_MAX_EDGE_PX
        and (big.width, big.height) == (1200, 900),
        f"{big.width}x{big.height}",
    )
except imaging.ImageRejected as exc:
    check("a large photograph is accepted and downscaled", False, exc)

# The genuinely unusable ones are still refused. These are the exact sizes
# Open Food Facts serves, and the bar is judged on the long edge: its "400px"
# is a long-edge cap, so a portrait pack shot arrives as 213x400 and used to be
# thrown away, leaving the product hotlinking the provider instead of a copy we
# host ourselves.
for size, should_pass, why in [
    ((53, 100), False, "OFF .100. thumbnail"),
    ((106, 200), False, "OFF .200. thumbnail"),
    ((213, 400), True, "OFF .400. portrait pack shot"),
    ((400, 400), True, "OFF .400. square pack shot"),
    ((400, 213), True, "OFF .400. landscape pack shot"),
    ((20, 2000), False, "a sliver with one long edge"),
    ((100, 100), False, "a 100px thumbnail"),
]:
    try:
        imaging.process(_png_bytes(*size))
        passed = True
        detail = "accepted"
    except imaging.ImageRejected as exc:
        passed = False
        detail = exc
    check(f"{why} is {'accepted' if should_pass else 'refused'}", passed is should_pass, detail)

# A file that is not an image at all must not take the endpoint down with it.
try:
    imaging.process(b"<html>404 not found</html>")
    check("a non-image is refused", False, "accepted HTML")
except imaging.ImageRejected:
    check("a non-image is refused", True)

# The size bar and the ranking bar have to agree: an image the service is
# willing to host must not have been scored as a low-quality result, or vice
# versa. scoring judges the long edge, so imaging must too.
for size, expected_ok in [((213, 400), True), ((53, 100), False), ((400, 400), True)]:
    try:
        imaging.process(_png_bytes(*size))
        imaging_ok = True
    except imaging.ImageRejected:
        imaging_ok = False
    scored = ImageCandidate(
        full_url="https://example.com/x.jpg",
        thumbnail_url="https://example.com/x.jpg",
        title="Amul Butter 500g Pack",
        source="openfoodfacts",
        width=size[0],
        height=size[1],
    )
    scored_quality_ok = scoring._quality_factor(scored) > 0.5
    check(
        f"imaging and scoring agree on {size[0]}x{size[1]}",
        imaging_ok is expected_ok and scored_quality_ok is expected_ok,
        f"imaging_ok={imaging_ok} scored_quality_ok={scored_quality_ok}",
    )

# A URL comes straight from a grid tile, so it is untrusted. These all used to
# escape as a 500: httpx raises a bare ValueError from urllib for a target it
# cannot parse, and that is not an HTTPError, so it passed through every handler.
for bad_url, why in [
    ("", "an empty url"),
    ("   ", "a blank url"),
    ("not a url", "a url that is not one"),
    ("/images/foo.jpg", "a bare path"),
    ("javascript:alert(1)", "a javascript: url"),
    ("file:///etc/passwd", "a file:// url"),
    ("ftp://example.com/a.jpg", "a non-http scheme"),
    ("https://", "a url with no host"),
]:
    try:
        imaging._check_url(bad_url)
        check(f"{why} is refused before any request", False, f"{bad_url!r} accepted")
    except imaging.ImageRejected:
        check(f"{why} is refused before any request", True)

# And a real url still goes through.
try:
    imaging._check_url("https://images.openfoodfacts.org/x/front.3.400.jpg")
    check("a normal https url is allowed", True)
except imaging.ImageRejected as exc:
    check("a normal https url is allowed", False, exc)

print("\n== a throttled provider is not an empty result ==")
# Open Food Facts rate-limits hard: measured against the live API, roughly every
# other anonymous request comes back as a 503 with an HTML body. _off_json used
# to swallow that and return None, so a throttled provider was reported as
# "ok: true, count: 0" — indistinguishable from a product that genuinely has no
# photograph. Half an import silently losing its images looked like a data
# problem rather than a rate limit.
import asyncio  # noqa: E402
import json as _json  # noqa: E402

from image_search_service import providers as providers_mod  # noqa: E402

_OFF_PRODUCT = _json.dumps(
    {
        "code": "8901262010320",
        "product_name": "Butter",
        "brands": "Amul",
        "image_front_url": "https://images.openfoodfacts.org/x/front.3.100.jpg",
    }
)


class _FakeResponse:
    def __init__(self, status_code, text):
        self.status_code = status_code
        self.text = text

    def json(self):
        return _json.loads(self.text)


class _ScriptedClient:
    """Replays a fixed list of responses, recording OFF's calls.

    Only requests to the Open Food Facts host are counted: the same script also
    serves the other providers, which are expected to fail and are not under
    test here.
    """

    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = 0

    async def get(self, url, params=None, **kwargs):
        if "openfoodfacts" in str(url):
            self.calls += 1
        index = min(self.calls - 1 if self.calls else 0, len(self.responses) - 1)
        return self.responses[index]


def _off_status(responses, product):
    """Runs one search pass with every provider scripted, returns OFF's status."""
    client = _ScriptedClient(responses)
    # Only OFF is under test; the other providers get the same script and are
    # expected to fail, which is why only the openfoodfacts entry is asserted.
    real_sleep = providers_mod._OFF_RETRY_AFTER_SECONDS
    providers_mod._OFF_RETRY_AFTER_SECONDS = 0  # keep the test fast
    try:
        loop = asyncio.new_event_loop()
        try:
            _, status = loop.run_until_complete(
                providers_mod.search_all(client, product)
            )
        finally:
            loop.close()
    finally:
        providers_mod._OFF_RETRY_AFTER_SECONDS = real_sleep
    return status.get("openfoodfacts", {}), client


_amul = ProductQuery(name="Amul Butter", brand="Amul", variant="500g")

# Every attempt throttled: this is a provider failure, not an empty catalogue.
throttled, throttled_client = _off_status(
    [_FakeResponse(503, "<!DOCTYPE html><html>rate limited</html>")], _amul
)
check("a throttled open food facts is reported as an error", throttled.get("ok") is False, throttled)
check(
    "a throttled open food facts is retried before giving up",
    throttled_client.calls == providers_mod._OFF_MAX_ATTEMPTS,
    throttled_client.calls,
)
check(
    "the throttle reason is reported, not swallowed",
    any("rate limited" in e for e in throttled.get("errors", [])),
    throttled,
)

# A throttle followed by a good response is a success, not an error.
recovered, _ = _off_status(
    [
        _FakeResponse(503, "<!DOCTYPE html>rate limited</html>"),
        _FakeResponse(200, _json.dumps({"products": [_json.loads(_OFF_PRODUCT)]})),
    ],
    _amul,
)
check(
    "a retry after a throttle recovers",
    recovered.get("ok") is True and recovered.get("count") == 1,
    recovered,
)

# A 200 with an HTML body is OFF's other throttle shape.
html_200, _ = _off_status([_FakeResponse(200, "<html>please slow down</html>")], _amul)
check("a 200 with an HTML body is a throttle, not a result", html_200.get("ok") is False, html_200)

# A network error is a failure too, not an empty catalogue.
net_err, _ = _off_status([ConnectionError("boom")], _amul)
check("a network error is reported as a failure", net_err.get("ok") is False, net_err)

# The distinction that matters: a product that is genuinely not in the database
# is a healthy provider with zero results, and must stay that way.
absent, _ = _off_status([_FakeResponse(200, _json.dumps({"products": []}))], _amul)
check(
    "a product absent from the database is a healthy empty result",
    absent.get("ok") is True and absent.get("count") == 0,
    absent,
)

print("\n== API contract ==")
# The vendor dashboard calls these three endpoints and nothing else, and parses
# the response by key. A field that is null instead of a string crashes the
# grid, so the shape is asserted here rather than discovered on a device.
try:
    from fastapi.testclient import TestClient

    from image_search_service import main as api
    from image_search_service import providers as providers_mod

    packshot = ImageCandidate(
        full_url="https://images.openfoodfacts.org/images/products/890/1/front_en.1.400.jpg",
        thumbnail_url="https://images.openfoodfacts.org/images/products/890/1/front_en.1.400.jpg",
        title="amul butter 500g",
        source="openfoodfacts",
        width=400,
        height=400,
    )
    calls = []

    async def fake_search_all(client, product, max_queries=3, tier="branded", **kwargs):
        calls.append((tier, product.name))
        return [packshot.model_copy()], {"openfoodfacts": {"ok": True, "count": 1}}

    original = providers_mod.search_all
    providers_mod.search_all = fake_search_all
    try:
        # The context manager is what runs the lifespan, which is where the
        # shared HTTP client is created.
        with TestClient(api.app) as client:
            check("health responds", client.get("/health").status_code == 200)

            payload = {
                "product": {"name": "Amul Butter", "brand": "Amul", "variant": "500g"}
            }

            search = client.post("/search", json={**payload, "limit": 5, "host_top": 0})
            check("/search answers 200", search.status_code == 200, search.text[:200])
            body = search.json()
            check("/search reports found", body["found"] is True)
            check("/search returns candidates", len(body["candidates"]) >= 1)
            check(
                "every candidate field the dashboard reads is a string",
                all(
                    isinstance(c.get("thumbnail_url"), str)
                    and isinstance(c.get("full_url"), str)
                    for c in body["candidates"]
                ),
                body["candidates"][:1],
            )

            first = client.post("/resolve", json=payload)
            check("/resolve answers 200", first.status_code == 200, first.text[:200])
            check("/resolve finds the product", first.json()["found"] is True)
            best = first.json()["best"]
            check("/resolve best has a usable url", bool(best.get("full_url")), best)
            check(
                "/resolve best thumbnail is a string",
                isinstance(best.get("thumbnail_url"), str),
                best.get("thumbnail_url"),
            )

            # Second call must come from the cache, with no hosted copy in play
            # (storage is unconfigured here) — this used to raise a 500.
            before = len(calls)
            second = client.post("/resolve", json=payload)
            check(
                "a repeated resolve answers 200",
                second.status_code == 200,
                second.text[:200],
            )
            check("a repeated resolve is served from cache", len(calls) == before, calls)
            check(
                "a cached answer keeps its url",
                second.json()["best"]["full_url"] == best["full_url"],
            )

            check(
                "/resolve rejects a product with no name",
                client.post("/resolve", json={"product": {"name": "  "}}).status_code == 400,
            )

            # Which tiers each row actually reaches. A brand nobody has
            # photographed can only be rescued by the third pass, while a row
            # that repeats its brand inside the name generates an identical
            # brand-free query and must not pay for a repeat search.
            mark = len(calls)
            client.post(
                "/resolve",
                json={
                    "product": {
                        "name": "JSW Steel TMT Bar",
                        "brand": "JSW Steel",
                        "category": "Materials",
                    }
                },
            )
            jsw_tiers = [tier for tier, _ in calls[mark:]]
            check(
                "a brand with no photos of it still reaches the third pass",
                jsw_tiers == ["branded", "relaxed", "generic"],
                jsw_tiers,
            )

            mark = len(calls)
            client.post(
                "/resolve",
                json={
                    "product": {
                        "name": "Exide Battery",
                        "brand": "Exide",
                        "category": "Automotive",
                    }
                },
            )
            exide_tiers = [tier for tier, _ in calls[mark:]]
            # A two-word name is already as short as a query can usefully get,
            # so the relaxed pass short-circuits too and this row never leaves
            # the first tier. Nothing is re-asked, so no quota is spent.
            check(
                "a row that is already short spends exactly one search",
                exide_tiers == ["branded"],
                exide_tiers,
            )

            # The contrast: a longer branded name produces a genuinely new
            # brand-free phrase, so the third pass must still run for it. This
            # is what proves the skip above is a real repeat and not the guard
            # blocking every branded row.
            mark = len(calls)
            client.post(
                "/resolve",
                json={
                    "product": {
                        "name": "Britannia Good Day Biscuit",
                        "brand": "Britannia",
                        "category": "Grocery",
                    }
                },
            )
            britannia_tiers = [tier for tier, _ in calls[mark:]]
            check(
                "a longer branded row still reaches all three tiers",
                britannia_tiers == ["branded", "relaxed", "generic"],
                britannia_tiers,
            )

            # /host takes its URL from a grid tile. A target httpx cannot parse
            # used to raise a bare ValueError past every handler and surface as
            # a 500; the dashboard turns a 500 into "the service is having
            # trouble", which told the vendor nothing about what was wrong.
            for bad in ["", "   ", "not a url", "/images/x.jpg", "file:///etc/passwd"]:
                response = client.post("/host", json={"full_url": bad})
                check(
                    f"/host refuses {bad!r} without a server error",
                    response.status_code < 500,
                    f"{response.status_code} {response.text[:120]}",
                )
            check(
                "/host reports a blank url as a bad request",
                client.post("/host", json={"full_url": ""}).status_code == 422,
            )
    finally:
        providers_mod.search_all = original
except ImportError as exc:  # pragma: no cover - optional test dependency
    print(f"  SKIP  API contract tests ({exc})")

print("\n== noun aliases: a neighbouring object is not the product ==")
# "Three leather belt attachment pouches" shares every word of a "Leather Belt"
# row, so it scored 0.77 and attached confidently -- the subject is the pouch.
alias_cases = [
    ("Three leather belt attachment pouches", "Leather Belt", "Fashion"),
    ("Face Cream En Vivo 10 Anos", "Face Cream", "Beauty"),
    (
        "Sony Spresense LTE Extension Board with Global SIM Card",
        "Extension Board",
        "Electronics",
    ),
]
for title, name, cat in alias_cases:
    p = ProductQuery(name=name, brand="", category=cat)
    s = scored_as(title, "branded", p)
    check(
        f"a neighbouring object is capped, not attached ({title[:34]!r})",
        s.score < scoring_module_min_accept(),
        f"{s.score:.3f}",
    )
    check(
        f"the alias is named in the log so the cap is explainable ({title[:24]!r})",
        bool(scoring._noun_alias_hit(candidate(title), scoring.build_target(p))),
        "no alias reported",
    )

# The guard that matters: every one of these is the right product and was lost
# by two earlier attempts at a general head-noun heuristic. If the table ever
# grows past these nouns, they are the regression that catches it.
survivors = [
    ("Hammer Drill 850W", ProductQuery(name="Hammer Drill", category="Hardware")),
    ("Leather Belt Pouch", ProductQuery(name="Belt Pouch", category="Fashion")),
    (
        "Extension Board for Rack",
        ProductQuery(name="Extension Board", category="Electronics"),
    ),
    ("Face Cream 100ml", ProductQuery(name="Face Cream", category="Beauty")),
    (
        "Puma football ball",
        ProductQuery(name="Puma football ball", category="Sports"),
    ),
    (
        "Ferrero Rocher chocolate balls",
        ProductQuery(
            name="Ferrero Rocher Chocolate Balls",
            brand="Ferrero Rocher",
            category="Grocery",
        ),
    ),
    ("SIM Card 128GB", ProductQuery(name="SIM Card", category="Electronics")),
]
for title, p in survivors:
    s = scored_as(title, "branded", p)
    check(
        f"a real match still attaches ({title[:38]!r})",
        s.score >= scoring_module_min_accept(),
        f"{s.score:.3f}",
    )

# ``own_words`` is what makes the table safe for a vendor who really does sell
# the compound: "Glow Recipe Watermelon Face Cream" must not be capped by an
# alias word that appears in its own name.
own_alias = ProductQuery(
    name="Face Cream En Vivo Aloe Range",
    brand="",
    category="Beauty",
)
check(
    "a product named for the alias word is exempt",
    scored_as("Face Cream En Vivo Aloe Range", "branded", own_alias).score
    >= scoring_module_min_accept(),
    scored_as("Face Cream En Vivo Aloe Range", "branded", own_alias).score,
)

print("\n== media category: a cover is the product, not a scene ==")
# Every Books row scored below the attach bar and so attached nothing at all.
# The cause is that "book" and "cover" are scene words: they exist to reject a
# Facebook cover photo or a magazine advert, but a book has no photograph other
# than its cover, so the words were demoting the one correct answer.
book_rows = [
    ("Children Story Book", "Children Story Book cover"),
    ("Novel Paperback", "Novel Paperback front cover"),
    ("Harry Potter Book Set", "Harry Potter Book Set"),
    ("Penguin Great Gatsby", "Penguin Great Gatsby book cover"),
]
for name, photo in book_rows:
    cat = ProductQuery(name=name, brand="Penguin" if "Penguin" in name else "", category="Books")
    s = scored_as(photo, "branded", cat)
    check(
        f"a Books cover photo is not demoted as a scene ({name})",
        s.score >= config.Config.MIN_ACCEPT_SCORE,
        f"{s.score:.3f}",
    )

# The other half: the same words must still reject a non-media product. If
# dropping them for Books had leaked into every category, "Facebook cover
# photo" would start attaching to a kitchen sponge.
sponge = ProductQuery(name="Kitchen Sponge", brand="", category="Home Care")
for photo in ("Facebook cover photo", "Kitchen Sponge magazine advert"):
    s = scored_as(photo, "branded", sponge)
    check(
        f"cover/magazine still count as scene for a non-media row ({photo!r})",
        s.score < config.Config.MIN_ACCEPT_SCORE,
        f"{s.score:.3f}",
    )

# A product whose own name contains a media word keeps it demoted even in the
# Books category, so the exemption cannot be used to launder a scene photo.
own_media = ProductQuery(name="Book Stand", brand="", category="Books")
s = scored_as("Book stand on a magazine in a library", "branded", own_media)
check(
    "the category exemption does not rescue a genuine scene photo",
    s.score < config.Config.MIN_ACCEPT_SCORE,
    f"{s.score:.3f}",
)

print()
print("--- auth ---------------------------------------------------------")

# The door is the one thing a broken build locks every vendor out of, and the
# bug it replaced (calling identitytoolkit accounts:lookup with an ID token)
# rejected real, valid tokens. These run offline against a locally minted key
# pair so a regression cannot wait for the network to notice.
import asyncio as _asyncio  # noqa: E402

import jwt as _jwt  # noqa: E402

from image_search_service import main as service_main  # noqa: E402

try:
    from cryptography.hazmat.primitives import hashes as _hashes
    from cryptography.hazmat.primitives.asymmetric import rsa as _rsa
    from cryptography.hazmat.primitives import serialization as _ser

    _TEST_KEY = _rsa.generate_private_key(public_exponent=65537, key_size=2048)
    _TEST_KID = "test-key-1"

    def _mint(aud="multiverses-8d207", sub="vendor-1", exp=9999999999, **over):
        claims = {
            "aud": aud,
            "iss": f"https://securetoken.google.com/{aud}",
            "sub": sub,
            "email": "vendor@example.com",
            "iat": 1790000000,
            "exp": exp,
        }
        claims.update(over)
        return _jwt.encode(claims, _TEST_KEY, algorithm="RS256", headers={"kid": _TEST_KID})

    async def _verify(token):
        async def _certs(force=False):
            return {
                _TEST_KID: _TEST_KEY.public_key()
                .public_bytes(
                    _ser.Encoding.PEM, _ser.PublicFormat.SubjectPublicKeyInfo
                )
                .decode()
            }

        real_certs = service_main._google_certs
        real_project = service_main._firebase_project_id
        service_main._google_certs = _certs
        service_main._firebase_project_id = lambda: "multiverses-8d207"
        try:
            return await service_main._verify_firebase_token(token)
        finally:
            service_main._google_certs = real_certs
            service_main._firebase_project_id = real_project

    ok = _asyncio.run(_verify(_mint()))
    check(
        "a valid token is accepted and the vendor identified",
        ok["uid"] == "vendor-1" and ok["email"] == "vendor@example.com",
        str(ok),
    )

    def _rejects(label, token, want_status=401):
        try:
            _asyncio.run(_verify(token))
            check(f"{label} is rejected", False, "accepted it")
        except Exception as exc:  # noqa: BLE001 - any refusal is a pass
            status = getattr(exc, "status_code", None)
            check(f"{label} is rejected", status == want_status, f"{status}: {exc}")

    good = _mint()
    _rejects("an expired token", _mint(exp=1000))
    _rejects(
        "a token signed for another project",
        _mint(aud="attacker-project"),
    )
    _rejects(
        "a tampered signature",
        good[:-6] + ("AAAAAA" if not good.endswith("AAAAAA") else "BBBBBB"),
    )
    # An HMAC token claiming Google's key id: the classic alg-confusion attack.
    # Rejecting it means pinning RS256, so verify that explicitly.
    _rejects(
        "a token signed by a non-Google key",
        _jwt.encode(
            {
                "aud": "multiverses-8d207",
                "iss": "https://securetoken.google.com/multiverses-8d207",
                "sub": "attacker",
                "iat": 1790000000,
                "exp": 9999999999,
            },
            "attacker-secret",
            algorithm="HS256",
            headers={"kid": _TEST_KID},
        ),
    )
    _rejects("a malformed token", "not-a-jwt")
    _rejects("an unsigned token", "..")

    async def _no_project():
        # Blank the env var rather than replacing the function, so the real
        # guard runs. _google_certs is patched too, to keep this offline.
        real_env = os.environ.get("FIREBASE_PROJECT_ID")
        real_certs = service_main._google_certs

        async def _certs(force=False):
            return {}

        os.environ["FIREBASE_PROJECT_ID"] = ""
        service_main._google_certs = _certs
        try:
            await service_main._verify_firebase_token(good)
            return None
        except Exception as exc:  # noqa: BLE001
            return exc
        finally:
            if real_env is None:
                os.environ.pop("FIREBASE_PROJECT_ID", None)
            else:
                os.environ["FIREBASE_PROJECT_ID"] = real_env
            service_main._google_certs = real_certs

    missing = _asyncio.run(_no_project())
    check(
        "a missing project id fails loudly instead of accepting anyone",
        getattr(missing, "status_code", None) == 500,
        str(missing),
    )

except ImportError:  # pragma: no cover - crypto not installed
    print("  SKIP  auth checks (install requirements.txt)")

print()
if FAILURES:
    print(f"{len(FAILURES)} failing check(s): {FAILURES}")
    sys.exit(1)
print("all checks passed")
